# frozen_string_literal: true

module Audioroom
  class WebhookController < ApplicationController
    # LiveKit POSTs JSON with a signature header — no session/CSRF needed.
    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required
    skip_before_action :check_xhr

    def receive
      body = request.raw_post
      auth_header = request.headers["Authorization"]

      unless verify_signature(body, auth_header)
        Rails.logger.warn("[Audioroom] Webhook: invalid signature, rejecting request")
        head :unauthorized
        return
      end

      event = parse_event(body)
      unless event
        head :bad_request
        return
      end

      handle_event(event)
      head :ok
    rescue => e
      Rails.logger.error("[Audioroom] Webhook error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      head :internal_server_error
    end

    private

    def verify_signature(body, auth_header)
      return false if auth_header.blank?

      api_key    = SiteSetting.audioroom_livekit_api_key.presence
      api_secret = SiteSetting.audioroom_livekit_api_secret.presence
      return false unless api_key && api_secret

      require "livekit"
      ::LiveKit::WebhookReceiver.new(api_key: api_key, api_secret: api_secret)
                                .receive(body, auth_header)
      true
    rescue => e
      Rails.logger.warn("[Audioroom] Webhook signature verification failed: #{e.message}")
      false
    end

    def parse_event(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def handle_event(event)
      event_type = event["event"]
      Rails.logger.info("[Audioroom] Webhook event: #{event_type}")

      case event_type
      when "participant_joined"
        on_participant_joined(event)
      when "participant_left"
        on_participant_left(event)
      when "room_finished"
        on_room_finished(event)
      end
    end

    def on_participant_joined(event)
      room_slug = event.dig("room", "name")
      identity  = event.dig("participant", "identity")
      return unless room_slug && identity

      # Egress participants have no numeric identity — ignore them
      user_id = identity.to_i
      return unless user_id > 0

      room = Audioroom::Room.find_by(slug: room_slug)
      return unless room

      # Ensure participant is tracked (covers reconnect edge cases)
      Audioroom::ParticipantTracker.add(room.id, user_id)

      # Notify followers/members when room goes live (first participant joins)
      participant_count = Audioroom::ParticipantTracker.user_ids(room.id).size
      if participant_count == 1 && SiteSetting.audioroom_room_notifications_enabled
        Jobs.enqueue(
          Audioroom::NotifyRoomLiveJob,
          room_id: room.id,
          joining_user_id: user_id
        )
      end

      Audioroom::RoomBroadcaster.publish_participants(room)
    end

    def on_participant_left(event)
      room_slug = event.dig("room", "name")
      identity  = event.dig("participant", "identity")
      return unless room_slug && identity

      user_id = identity.to_i
      return unless user_id > 0

      room = Audioroom::Room.find_by(slug: room_slug)
      return unless room

      # Only remove if not already cleaned up by the leave action
      return unless Audioroom::ParticipantTracker.user_ids(room.id).include?(user_id)

      session = close_session(room.id, user_id)
      Audioroom::ParticipantTracker.remove(room.id, user_id)

      user = User.find_by(id: user_id)
      if user
        Audioroom::UserStatusManager.clear_voice_status(user)
        Audioroom::BadgeGranterHooks.on_leave(user, session, room: room)
      end

      Audioroom::RoomBroadcaster.publish_participants(room)
    end

    def on_room_finished(event)
      room_slug = event.dig("room", "name")
      return unless room_slug

      room = Audioroom::Room.find_by(slug: room_slug)
      return unless room

      # Clear all participant state — room is gone on LiveKit side
      Audioroom::ParticipantTracker.user_ids(room.id).each do |user_id|
        session = close_session(room.id, user_id)
        user = User.find_by(id: user_id)
        if user
          Audioroom::UserStatusManager.clear_voice_status(user)
          Audioroom::BadgeGranterHooks.on_leave(user, session, room: room)
        end
      end

      Audioroom::ParticipantTracker.clear(room.id)
      Audioroom::RoomBroadcaster.publish_participants(room)
    end

    def close_session(room_id, user_id)
      metadata = Audioroom::ParticipantTracker.get_metadata(room_id, user_id)
      return unless metadata[:session_id]

      session = Audioroom::Session.find_by(id: metadata[:session_id])
      session&.close!
      session
    end
  end
end
