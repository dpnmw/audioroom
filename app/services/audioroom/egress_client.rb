# frozen_string_literal: true

module Audioroom
  class EgressClient
    # Starts a RoomComposite egress that renders the broadcast view in headless Chrome
    # and pushes the result to an RTMP endpoint (e.g. YouTube).
    #
    # Returns the egress_id string on success, nil on failure.
    def self.start_stream(room, rtmp_url, layout, broadcast_base_url)
      client = build_client
      return nil unless client

      broadcast_template_url = "#{broadcast_base_url}/audioroom/broadcast/#{room.slug}"

      output =
        ::LiveKit::Proto::StreamOutput.new(
          protocol: ::LiveKit::Proto::StreamProtocol::RTMP,
          urls: [rtmp_url],
        )

      video_options = ::LiveKit::Proto::EncodingOptions.new(
        width: 1280,
        height: 720,
        depth: 24,
        framerate: 30,
        video_codec: ::LiveKit::Proto::VideoCodec::H264_MAIN,
        video_bitrate: 4500,
        key_frame_interval: 2,
        audio_codec: ::LiveKit::Proto::AudioCodec::AAC,
        audio_bitrate: 128,
        audio_frequency: 44100,
      )

      resp =
        client.start_room_composite_egress(
          room.slug,
          output,
          layout: layout,
          custom_base_url: broadcast_template_url,
          audio_only: false,
          advanced: video_options,
        )

      return nil if resp.nil?
      if resp.error
        Rails.logger.error("[Audioroom] EgressClient.start_stream error: #{resp.error.inspect}")
        return nil
      end
      egress_id = resp.data&.egress_id
      Rails.logger.info("[Audioroom] EgressClient.start_stream success: egress_id=#{egress_id.inspect}")
      egress_id
    rescue => e
      Rails.logger.error("[Audioroom] EgressClient.start_stream failed: #{e.message} / #{e.class}")
      nil
    end

    # Stops an active egress by egress_id.
    def self.stop_stream(egress_id)
      client = build_client
      return unless client

      client.stop_egress(egress_id)
    rescue => e
      Rails.logger.error("[Audioroom] EgressClient.stop_stream failed: #{e.message}")
    end

    # Updates the layout URL for a running egress (live layout switch).
    def self.update_layout(egress_id, layout_url)
      client = build_client
      return unless client

      client.update_layout(egress_id, layout_url)
    rescue => e
      Rails.logger.error("[Audioroom] EgressClient.update_layout failed: #{e.message}")
    end

    # Generates a subscriber-only LiveKit token for the headless Chrome broadcast page.
    def self.egress_token(room)
      return nil unless SiteSetting.audioroom_livekit_api_key.present? &&
                         SiteSetting.audioroom_livekit_api_secret.present?

      require "livekit"

      token =
        ::LiveKit::AccessToken.new(
          api_key: SiteSetting.audioroom_livekit_api_key,
          api_secret: SiteSetting.audioroom_livekit_api_secret,
        )
      token.identity = "egress-#{room.slug}-#{SecureRandom.hex(4)}"
      token.name = "Egress"
      token.video_grant =
        ::LiveKit::VideoGrant.new(
          roomJoin: true,
          room: room.slug,
          canPublish: false,
          canSubscribe: true,
          canPublishData: false,
          hidden: true,
        )
      token.to_jwt
    rescue => e
      Rails.logger.error("[Audioroom] EgressClient.egress_token failed: #{e.message}")
      nil
    end

    class << self
      private

      def build_client
        url = SiteSetting.audioroom_egress_url.presence
        key = SiteSetting.audioroom_livekit_api_key.presence
        secret = SiteSetting.audioroom_livekit_api_secret.presence

        unless url && key && secret
          Rails.logger.warn("[Audioroom] EgressClient: egress URL or LiveKit credentials not configured.")
          return nil
        end

        require "livekit"
        ::LiveKit::EgressServiceClient.new(url, api_key: key, api_secret: secret)
      end
    end
  end
end
