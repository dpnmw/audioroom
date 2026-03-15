# frozen_string_literal: true

module Audioroom
  class RoomServiceClient
    # Creates a LiveKit room with empty_timeout so it auto-closes when empty.
    # empty_timeout: seconds before LiveKit closes an empty room (default 5 min)
    # departure_timeout: seconds LiveKit waits after last participant leaves before closing
    def self.create_room(room, empty_timeout: 300, departure_timeout: 20)
      client = build_client
      return unless client

      client.create_room(
        room.slug,
        empty_timeout: empty_timeout,
        departure_timeout: departure_timeout,
        max_participants: room.max_participants || 0,
      )
      Rails.logger.info("[Audioroom] RoomServiceClient.create_room: #{room.slug}")
    rescue => e
      Rails.logger.error("[Audioroom] RoomServiceClient.create_room failed: #{e.message}")
    end

    # Deletes a LiveKit room, disconnecting all participants immediately.
    def self.delete_room(room)
      client = build_client
      return unless client

      client.delete_room(room.slug)
      Rails.logger.info("[Audioroom] RoomServiceClient.delete_room: #{room.slug}")
    rescue => e
      Rails.logger.error("[Audioroom] RoomServiceClient.delete_room failed: #{e.message}")
    end

    # Ensures a LiveKit room exists — creates it if not. Safe to call on every join
    # so that rooms created before this feature was added still get proper timeouts.
    def self.ensure_room(room)
      create_room(room)
    end

    # Updates a participant's metadata on the LiveKit server, triggering
    # ParticipantMetadataChanged on all subscribers (including the broadcast page).
    def self.update_participant_metadata(room, user, metadata_hash)
      client = build_client
      return unless client

      client.update_participant(room.slug, user.id.to_s, metadata: metadata_hash.to_json)
      Rails.logger.info("[Audioroom] RoomServiceClient.update_participant_metadata: #{room.slug}/#{user.id}")
    rescue => e
      Rails.logger.error("[Audioroom] RoomServiceClient.update_participant_metadata failed: #{e.message}")
    end

    # Server-side mute/unmute of a participant's audio track via LiveKit API.
    # Fires real TrackMuted/TrackUnmuted events on all subscribers including the
    # muted participant themselves and the broadcast page.
    # Returns true on success, false if the participant has no audio track.
    def self.mute_participant(room, user_id, muted:)
      client = build_client
      return false unless client

      identity = user_id.to_s
      participant = client.get_participant(room: room.slug, identity: identity)
      audio_track = participant&.tracks&.find { |t| t.type == ::LiveKit::TrackType::AUDIO }
      return false unless audio_track

      client.mute_published_track(
        room: room.slug,
        identity: identity,
        track_sid: audio_track.sid,
        muted: muted,
      )
      Rails.logger.info("[Audioroom] RoomServiceClient.mute_participant: #{room.slug}/#{user_id} muted=#{muted}")
      true
    rescue => e
      Rails.logger.error("[Audioroom] RoomServiceClient.mute_participant failed: #{e.message}")
      false
    end

    # Updates a participant's publish/subscribe permissions on the LiveKit server
    # without requiring the participant to reconnect. Used when promoting a listener
    # to speaker in a stage room — grants canPublish so their mic works immediately.
    def self.update_participant_permissions(room, user_id, can_publish:, can_publish_data:)
      client = build_client
      return unless client

      identity = user_id.to_s
      permission =
        ::LiveKit::ParticipantPermission.new(
          canPublish: can_publish,
          canSubscribe: true,
          canPublishData: can_publish_data,
        )
      client.update_participant(room.slug, identity, permission: permission)
      Rails.logger.info(
        "[Audioroom] RoomServiceClient.update_participant_permissions: #{room.slug}/#{user_id} canPublish=#{can_publish}",
      )
    rescue => e
      Rails.logger.error(
        "[Audioroom] RoomServiceClient.update_participant_permissions failed: #{e.message}",
      )
    end

    # Updates an existing LiveKit room's metadata (e.g. max_participants).
    def self.update_room(room)
      client = build_client
      return unless client

      client.update_room_metadata(room.slug, room.name)
      Rails.logger.info("[Audioroom] RoomServiceClient.update_room: #{room.slug}")
    rescue => e
      Rails.logger.error("[Audioroom] RoomServiceClient.update_room failed: #{e.message}")
    end

    class << self
      private

      def build_client
        url = SiteSetting.audioroom_livekit_api_url.presence
        key = SiteSetting.audioroom_livekit_api_key.presence
        secret = SiteSetting.audioroom_livekit_api_secret.presence

        unless url && key && secret
          Rails.logger.warn("[Audioroom] RoomServiceClient: LiveKit API URL or credentials not configured.")
          return nil
        end

        require "livekit"
        ::LiveKit::RoomServiceClient.new(url, api_key: key, api_secret: secret)
      end
    end
  end
end
