# frozen_string_literal: true

# Developed by DPN Media Works — https://dpnmediaworks.com

module Audioroom
  class RoomsController < ApplicationController
    # Allow Discourse User API Key authentication (for React / external apps)
    skip_before_action :verify_authenticity_token, if: :user_api_key_request?

    before_action :load_room,
                  only: %i[
                    show
                    update
                    destroy
                    join
                    leave
                    participants
                    kick
                    unkick
                    hard_mute
                    hard_unmute
                    ban
                    unban
                    heartbeat
                    toggle_mute
                    mute_participant
                    raise_hand
                    lower_hand
                    archive
                    unarchive
                  ]

    def index
      scope = Audioroom::Room.includes(:room_memberships).order(:created_at)
      scope = scope.active unless params[:include_archived] == "true" && guardian.is_admin?

      rooms = scope.select { |room| guardian.can_see_audioroom_room?(room) }

      render json: {
               rooms: serialize_data(rooms, Audioroom::RoomSerializer),
               can_create_room: guardian.can_manage_audioroom_rooms?,
             }
    end

    def show
      guardian.ensure_can_see_audioroom_room!(@room)
      render_serialized @room, Audioroom::RoomSerializer, root: :room, include_visit_count: true
    end

    def create
      guardian.ensure_can_create_audioroom_room!

      if current_user.audioroom_rooms.count >= SiteSetting.audioroom_max_rooms_per_user
        raise Discourse::InvalidParameters.new(I18n.t("audioroom.errors.room_limit"))
      end

      room = Audioroom::Room.new(room_params)
      room.creator = current_user

      if room.save
        Audioroom::RoomServiceClient.create_room(room)
        Audioroom::DirectoryBroadcaster.broadcast(action: :created, room: room)
        Audioroom::BadgeGranterHooks.on_room_create(current_user)
        render_serialized room, Audioroom::RoomSerializer, root: :room
      else
        render_json_error room
      end
    end

    def update
      guardian.ensure_can_manage_audioroom_room!(@room)

      name_changed = room_params[:name].present? && room_params[:name] != @room.name

      if @room.update(room_params)
        Audioroom::DirectoryBroadcaster.broadcast(action: :updated, room: @room)
        refresh_participant_statuses(@room) if name_changed
        render_serialized @room, Audioroom::RoomSerializer, root: :room
      else
        render_json_error @room
      end
    end

    def destroy
      guardian.ensure_can_manage_audioroom_room!(@room)
      Audioroom::RoomServiceClient.delete_room(@room)
      Audioroom::ParticipantTracker.clear(@room.id)
      @room.destroy!
      Audioroom::DirectoryBroadcaster.broadcast(action: :destroyed, room: @room)
      render json: success_json
    end

    def archive
      guardian.ensure_can_manage_audioroom_room!(@room)
      @room.update!(archived: true)
      Audioroom::DirectoryBroadcaster.broadcast(action: :destroyed, room: @room)
      render json: success_json
    end

    def unarchive
      guardian.ensure_can_manage_audioroom_room!(@room)
      @room.update!(archived: false)
      Audioroom::DirectoryBroadcaster.broadcast(action: :updated, room: @room)
      render json: success_json
    end

    def join
      guardian.ensure_can_join_audioroom_room!(@room)

      if Audioroom::ParticipantTracker.banned?(@room.id, current_user.id)
        render json: { error: I18n.t("audioroom.errors.banned") }, status: :forbidden
        return
      end

      if Audioroom::ParticipantTracker.kicked?(@room.id, current_user.id)
        render json: { error: I18n.t("audioroom.errors.kicked") }, status: :forbidden
        return
      end

      existing_room_id = Audioroom::ParticipantTracker.active_room_id_for_user(current_user.id)
      if existing_room_id && existing_room_id != @room.id
        existing_room = Audioroom::Room.find_by(id: existing_room_id)
        return render json: {
                 error: I18n.t("audioroom.errors.already_in_room"),
                 conflicting_room_id: existing_room_id,
                 conflicting_room_name: existing_room&.name,
               },
               status: :conflict
      end

      if @room.max_participants.present?
        current_ids = Audioroom::ParticipantTracker.user_ids(@room.id)
        if !current_ids.include?(current_user.id) && current_ids.length >= @room.max_participants
          render json: { error: I18n.t("audioroom.errors.room_full") }, status: :unprocessable_entity
          return
        end
      end

      Audioroom::RoomServiceClient.ensure_room(@room)
      Audioroom::ParticipantTracker.add(@room.id, current_user.id)

      membership = @room.room_memberships.find_by(user_id: current_user.id)
      membership_role = membership&.role_name || "participant"

      # Derive the metadata role that will be embedded in the JWT and broadcast
      # to all subscribers. This must reflect actual publish permissions, not just
      # the DB membership role.
      metadata_role =
        if current_user.id == @room.creator_id
          "moderator"
        elsif @room.stage?
          can_publish = %w[moderator speaker].include?(membership_role)
          if can_publish
            membership_role # "moderator" or "speaker"
          else
            "listener"
          end
        else
          "participant"
        end

      metadata = { role: metadata_role }

      if SiteSetting.audioroom_analytics_enabled
        session = Audioroom::Session.create!(user: current_user, room: @room, joined_at: Time.current)
        metadata[:session_id] = session.id
      end

      metadata[:skip_status] = true if params[:skip_status].present?
      Audioroom::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)
      Audioroom::RoomBroadcaster.publish_participants(@room)

      participants = Audioroom::ParticipantTracker.list(@room.id)
      Audioroom::BadgeGranterHooks.on_join(current_user, @room, participants)

      if params[:skip_status].blank?
        Audioroom::UserStatusManager.set_voice_status(current_user, @room)
      end

      livekit_token = generate_livekit_token(metadata_role)

      render json: {
               room:
                 Audioroom::RoomSerializer.new(
                   @room,
                   scope: guardian,
                   root: false,
                   include_visit_count: true,
                 ).as_json,
               livekit_token: livekit_token,
               livekit_url: SiteSetting.audioroom_livekit_url,
             }
    end

    def leave
      guardian.ensure_can_join_audioroom_room!(@room)
      session = close_session_for(@room.id, current_user.id)
      Audioroom::ParticipantTracker.remove(@room.id, current_user.id)
      Audioroom::UserStatusManager.clear_voice_status(current_user)
      Audioroom::RoomBroadcaster.publish_participants(@room)
      Audioroom::BadgeGranterHooks.on_leave(current_user, session, room: @room)
      head :no_content
    end

    def heartbeat
      guardian.ensure_can_join_audioroom_room!(@room)

      if Audioroom::ParticipantTracker.kicked?(@room.id, current_user.id) ||
           Audioroom::ParticipantTracker.banned?(@room.id, current_user.id)
        render json: { error: I18n.t("audioroom.errors.not_authorized") }, status: :forbidden
        return
      end

      Audioroom::ParticipantTracker.add(@room.id, current_user.id)

      metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, current_user.id)

      if params.key?(:skip_status)
        bool = ActiveModel::Type::Boolean.new
        metadata[:skip_status] = bool.cast(params[:skip_status])
      end

      if params.key?(:idle_state)
        idle_state = params[:idle_state].to_s
        if %w[active idle afk].include?(idle_state)
          metadata[:idle_state] = idle_state
        end
      end

      Audioroom::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)
      Audioroom::RoomBroadcaster.publish_participants(@room)

      if !metadata[:skip_status] && Audioroom::UserStatusManager.audioroom_status_active?(current_user)
        if metadata[:idle_state] == "afk"
          Audioroom::UserStatusManager.set_afk_status(current_user, @room)
        else
          Audioroom::UserStatusManager.set_voice_status(current_user, @room)
        end
      end

      head :no_content
    end

    def participants
      guardian.ensure_can_join_audioroom_room!(@room)
      all_metadata = Audioroom::ParticipantTracker.get_all_metadata(@room.id)
      render json: {
               participants:
                 Audioroom::ParticipantTracker
                   .list(@room.id)
                   .map do |user|
                     BasicUserSerializer
                       .new(user, scope: guardian, root: false)
                       .as_json
                       .merge(all_metadata[user.id] || {})
                   end,
             }
    end

    def toggle_mute
      guardian.ensure_can_join_audioroom_room!(@room)

      bool = ActiveModel::Type::Boolean.new
      wants_unmute = params.key?(:muted) && !bool.cast(params[:muted])

      if wants_unmute && @room.stage? && !guardian.can_speak_in_audioroom_room?(@room)
        raise Discourse::InvalidAccess.new(I18n.t("audioroom.errors.listeners_cannot_unmute"))
      end

      metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, current_user.id)
      metadata[:is_muted] = bool.cast(params[:muted]) if params.key?(:muted)
      metadata[:is_deafened] = bool.cast(params[:deafened]) if params.key?(:deafened)
      Audioroom::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)

      Audioroom::RoomBroadcaster.publish_participants(@room)

      head :no_content
    end

    def kick
      guardian.ensure_can_manage_audioroom_room!(@room)

      user_id = params.require(:user_id).to_i

      if user_id == current_user.id
        raise Discourse::InvalidParameters.new(I18n.t("audioroom.errors.cannot_kick_self"))
      end

      if user_id == @room.creator_id
        raise Discourse::InvalidParameters.new(I18n.t("audioroom.errors.cannot_kick_creator"))
      end

      session = close_session_for(@room.id, user_id)
      Audioroom::ParticipantTracker.kick(@room.id, user_id)

      kicked_user = User.find_by(id: user_id)
      Audioroom::UserStatusManager.clear_voice_status(kicked_user) if kicked_user

      Audioroom::BadgeGranterHooks.on_leave(kicked_user, session, room: @room) if kicked_user
      Audioroom::RoomBroadcaster.publish_kick(@room, user_id)
      Audioroom::RoomBroadcaster.publish_participants(@room)

      head :no_content
    end

    def unkick
      guardian.ensure_can_manage_audioroom_room!(@room)
      user_id = params.require(:user_id).to_i
      Audioroom::ParticipantTracker.unkick(@room.id, user_id)
      render json: success_json
    end

    def hard_mute
      guardian.ensure_can_manage_audioroom_room!(@room)
      user_id = params.require(:user_id).to_i
      Audioroom::RoomServiceClient.update_participant_permissions(
        @room, user_id, can_publish: false, can_publish_data: false
      )
      metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, user_id)
      metadata[:hard_muted] = true
      Audioroom::ParticipantTracker.update_metadata(@room.id, user_id, metadata)
      Audioroom::RoomBroadcaster.publish_participants(@room)
      render json: success_json
    end

    def hard_unmute
      guardian.ensure_can_manage_audioroom_room!(@room)
      user_id = params.require(:user_id).to_i
      Audioroom::RoomServiceClient.update_participant_permissions(
        @room, user_id, can_publish: true, can_publish_data: true
      )
      metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, user_id)
      metadata[:hard_muted] = false
      Audioroom::ParticipantTracker.update_metadata(@room.id, user_id, metadata)
      Audioroom::RoomBroadcaster.publish_participants(@room)
      render json: success_json
    end

    def ban
      guardian.ensure_can_manage_audioroom_room!(@room)

      user_id = params.require(:user_id).to_i

      if user_id == current_user.id
        raise Discourse::InvalidParameters.new(I18n.t("audioroom.errors.cannot_kick_self"))
      end

      if user_id == @room.creator_id
        raise Discourse::InvalidParameters.new(I18n.t("audioroom.errors.cannot_kick_creator"))
      end

      session = close_session_for(@room.id, user_id)
      Audioroom::ParticipantTracker.ban(@room.id, user_id)

      banned_user = User.find_by(id: user_id)
      Audioroom::UserStatusManager.clear_voice_status(banned_user) if banned_user
      Audioroom::BadgeGranterHooks.on_leave(banned_user, session, room: @room) if banned_user
      Audioroom::RoomBroadcaster.publish_kick(@room, user_id)
      Audioroom::RoomBroadcaster.publish_participants(@room)

      head :no_content
    end

    def unban
      guardian.ensure_can_manage_audioroom_room!(@room)
      user_id = params.require(:user_id).to_i
      Audioroom::ParticipantTracker.unban(@room.id, user_id)
      render json: success_json
    end

    def raise_hand
      guardian.ensure_can_join_audioroom_room!(@room)
      unless @room.stage?
        render json: { error: "Not a stage room" }, status: :unprocessable_entity
        return
      end

      metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, current_user.id)
      role = metadata[:role].to_s
      if %w[moderator speaker].include?(role)
        render json: { error: I18n.t("audioroom.errors.speakers_cannot_raise_hand") }, status: :unprocessable_entity
        return
      end

      metadata[:hand_raised] = true
      Audioroom::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)
      Audioroom::RoomBroadcaster.publish_participants(@room)
      head :no_content
    end

    def lower_hand
      guardian.ensure_can_join_audioroom_room!(@room)
      metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, current_user.id)
      metadata[:hand_raised] = false
      Audioroom::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)
      Audioroom::RoomBroadcaster.publish_participants(@room)
      head :no_content
    end

    def mute_participant
      guardian.ensure_can_manage_audioroom_room!(@room)

      user_id = params.require(:user_id).to_i
      bool = ActiveModel::Type::Boolean.new
      muted = bool.cast(params.require(:muted))

      unless Audioroom::ParticipantTracker.user_ids(@room.id).include?(user_id)
        render json: { error: I18n.t("audioroom.errors.participant_not_found") }, status: :unprocessable_entity
        return
      end

      success = Audioroom::RoomServiceClient.mute_participant(@room, user_id, muted: muted)

      unless success
        render json: { error: I18n.t("audioroom.errors.participant_not_found") }, status: :unprocessable_entity
        return
      end

      # Also update Redis metadata so participants list reflects the mute state
      metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, user_id)
      metadata[:is_muted] = muted
      Audioroom::ParticipantTracker.update_metadata(@room.id, user_id, metadata)
      Audioroom::RoomBroadcaster.publish_participants(@room)

      head :no_content
    end

    private

    def user_api_key_request?
      request.env["HTTP_USER_API_KEY"].present?
    end

    def generate_livekit_token(role)
      return nil unless SiteSetting.audioroom_livekit_api_key.present? &&
                         SiteSetting.audioroom_livekit_api_secret.present?

      require "livekit"

      can_publish =
        if @room.stage?
          %w[moderator speaker].include?(role)
        else
          true
        end

      token =
        LiveKit::AccessToken.new(
          api_key: SiteSetting.audioroom_livekit_api_key,
          api_secret: SiteSetting.audioroom_livekit_api_secret,
        )
      token.identity = current_user.id.to_s
      token.name = current_user.username
      token.metadata = {
        username: current_user.username,
        name: current_user.name || current_user.username,
        avatar_template: current_user.avatar_template,
        role: role,
      }.to_json
      token.video_grant =
        LiveKit::VideoGrant.new(
          roomJoin: true,
          room: @room.slug,
          canPublish: can_publish,
          canSubscribe: true,
          canPublishData: %w[moderator speaker].include?(role),
        )
      token.to_jwt
    rescue => e
      Rails.logger.error("[Audioroom] LiveKit token generation failed: #{e.message}")
      nil
    end

    def refresh_participant_statuses(room)
      Audioroom::ParticipantTracker
        .user_ids(room.id)
        .each do |uid|
          user = User.find_by(id: uid)
          next unless user
          next unless Audioroom::UserStatusManager.audioroom_status_active?(user)
          Audioroom::UserStatusManager.set_voice_status(user, room)
        end
    end

    def close_session_for(room_id, user_id)
      metadata = Audioroom::ParticipantTracker.get_metadata(room_id, user_id)
      return unless metadata[:session_id]

      session = Audioroom::Session.find_by(id: metadata[:session_id])
      session&.close!
      session
    end

    def room_params
      permitted =
        params.require(:room).permit(
          :name,
          :description,
          :public,
          :max_participants,
          :room_type,
          :topic_id,
          :next_session_at,
          :broadcast_background,
          :broadcast_watermark,
          schedule: [:time, :timezone, days: []],
        )
      if permitted.key?(:room_type)
        permitted[:room_type] = Audioroom::Room::ROOM_TYPES[permitted[:room_type].to_s] ||
          Audioroom::Room::ROOM_TYPE_OPEN
      end
      unless SiteSetting.audioroom_broadcast_customization_enabled
        permitted.delete(:broadcast_background)
        permitted.delete(:broadcast_watermark)
      end
      permitted
    end

    def load_room
      @room =
        Audioroom::Room.find_by(id: params[:id]) ||
          Audioroom::Room.find_by!(slug: params[:id] || params[:slug])
    end
  end
end
