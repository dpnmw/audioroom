# frozen_string_literal: true

module Audioroom
  class RoomMembershipsController < ApplicationController
    before_action :load_room

    def index
      guardian.ensure_can_manage_audioroom_room!(@room)
      render_serialized @room.room_memberships,
                        Audioroom::RoomMembershipSerializer,
                        root: :memberships
    end

    def create
      guardian.ensure_can_manage_audioroom_room!(@room)
      user = fetch_user
      role = Audioroom::RoomMembership.role_value(params[:role])
      membership = @room.room_memberships.find_or_initialize_by(user: user)
      membership.role = role
      membership.save!

      if Audioroom::ParticipantTracker.user_ids(@room.id).include?(user.id)
        metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, user.id)
        metadata[:role] = membership.role_name
        metadata[:hand_raised] = false
        Audioroom::ParticipantTracker.update_metadata(@room.id, user.id, metadata)
        Audioroom::RoomBroadcaster.publish_role_change(@room, user.id, membership.role_name)
        Audioroom::RoomBroadcaster.publish_participants(@room)
        sync_livekit_participant_metadata(@room, user, metadata)
      end

      render_serialized membership, Audioroom::RoomMembershipSerializer, root: :membership
    end

    def update
      guardian.ensure_can_manage_audioroom_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      new_role = params.require(:role)
      membership.update!(role: Audioroom::RoomMembership.role_value(new_role))

      if Audioroom::ParticipantTracker.user_ids(@room.id).include?(membership.user_id)
        user = User.find_by(id: membership.user_id)
        metadata = Audioroom::ParticipantTracker.get_metadata(@room.id, membership.user_id)
        metadata[:role] = membership.role_name
        metadata[:hand_raised] = false
        Audioroom::ParticipantTracker.update_metadata(@room.id, membership.user_id, metadata)
        Audioroom::RoomBroadcaster.publish_role_change(
          @room,
          membership.user_id,
          membership.role_name,
        )
        Audioroom::RoomBroadcaster.publish_participants(@room)
        sync_livekit_participant_metadata(@room, user, metadata) if user
      end

      render_serialized membership, Audioroom::RoomMembershipSerializer, root: :membership
    end

    def destroy
      guardian.ensure_can_manage_audioroom_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      membership.destroy!
      head :no_content
    end

    private

    def fetch_user
      if params[:user_id]
        User.find(params[:user_id])
      elsif params[:username]
        User.find_by_username_or_email(params[:username])
      else
        raise Discourse::InvalidParameters
      end
    end

    def load_room
      @room = Audioroom::Room.find(params[:room_id])
    end

    def sync_livekit_participant_metadata(room, user, metadata)
      membership_role = metadata[:role].to_s

      # Derive the broadcast metadata role the same way the join action does.
      # In stage rooms a participant-role member without publish permission is
      # a "listener" in the broadcast — use "listener" so ParticipantMetadataChanged
      # fires with the correct role and the broadcast tile updates immediately.
      broadcast_role =
        if user.id == room.creator_id
          "moderator"
        elsif room.stage?
          can_publish = %w[moderator speaker].include?(membership_role)
          can_publish ? membership_role : "listener"
        else
          "participant"
        end

      livekit_metadata = {
        username: user.username,
        name: user.name || user.username,
        avatar_template: user.avatar_template,
        role: broadcast_role,
      }
      Audioroom::RoomServiceClient.update_participant_metadata(room, user, livekit_metadata)

      if room.stage?
        can_publish = %w[moderator speaker].include?(membership_role)
        Audioroom::RoomServiceClient.update_participant_permissions(
          room,
          user.id,
          can_publish: can_publish,
          can_publish_data: can_publish,
        )
      end
    end
  end
end
