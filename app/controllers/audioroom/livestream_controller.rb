# frozen_string_literal: true

module Audioroom
  class LivestreamController < ApplicationController
    before_action :ensure_admin
    before_action :load_room

    def start
      if @room.live?
        render json: { error: I18n.t("audioroom.livestream.already_live") }, status: :conflict
        return
      end

      stream_key = params[:stream_key].presence || @room.youtube_stream_key
      unless stream_key.present?
        render json: { error: I18n.t("audioroom.livestream.missing_stream_key") }, status: :unprocessable_entity
        return
      end

      layout = %w[speaker grid].include?(params[:layout]) ? params[:layout] : "speaker"
      rtmp_url = "rtmp://a.rtmp.youtube.com/live2/#{stream_key}"
      broadcast_base = Discourse.base_url

      egress_id = Audioroom::EgressClient.start_stream(@room, rtmp_url, layout, broadcast_base)

      unless egress_id.present?
        render json: { error: I18n.t("audioroom.livestream.start_failed") }, status: :service_unavailable
        return
      end

      @room.update!(
        egress_id: egress_id,
        broadcast_layout: layout,
        youtube_stream_key: stream_key,
      )

      Audioroom::DirectoryBroadcaster.broadcast(action: :updated, room: @room)

      render json: {
        room: { id: @room.id, live: true, broadcast_layout: @room.broadcast_layout },
      }
    end

    def stop
      unless @room.live?
        render json: { error: I18n.t("audioroom.livestream.not_live") }, status: :conflict
        return
      end

      Audioroom::EgressClient.stop_stream(@room.egress_id)
      @room.update!(egress_id: nil)

      Audioroom::DirectoryBroadcaster.broadcast(action: :updated, room: @room)

      render json: { room: { id: @room.id, live: false } }
    end

    def layout
      unless @room.live?
        render json: { error: I18n.t("audioroom.livestream.not_live") }, status: :conflict
        return
      end

      new_layout = %w[speaker grid].include?(params[:layout]) ? params[:layout] : "speaker"

      Audioroom::EgressClient.update_layout(@room.egress_id, new_layout)
      @room.update!(broadcast_layout: new_layout)

      render json: { room: { id: @room.id, broadcast_layout: new_layout } }
    end

    private

    def load_room
      @room = Audioroom::Room.find(params[:room_id])
    end

    def ensure_admin
      raise Discourse::InvalidAccess unless current_user&.admin?
    end
  end
end
