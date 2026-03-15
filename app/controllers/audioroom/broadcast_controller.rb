# frozen_string_literal: true

module Audioroom
  class BroadcastController < ::ApplicationController
    # This page is loaded by LiveKit Egress headless Chrome — no auth required.
    skip_before_action :check_xhr
    skip_before_action :redirect_to_login_if_required
    skip_before_action :verify_authenticity_token

    before_action :disable_mini_profiler

    layout false

    # CSP is handled by Audioroom::BroadcastCspMiddleware (Rack level)
    # to reliably override Discourse's strict-dynamic policy.
    content_security_policy false

    def show
      @room = Audioroom::Room.find_by(slug: params[:slug])
      raise Discourse::NotFound unless @room
      raise Discourse::NotFound if @room.archived?

      @layout = %w[speaker grid].include?(params[:layout]) ? params[:layout] : "speaker"
      @livekit_url = SiteSetting.audioroom_livekit_url
      @livekit_token = Audioroom::EgressClient.egress_token(@room)
      @room_name = @room.name
      @site_name = SiteSetting.title

      render :show, layout: false
    end

    private

    def disable_mini_profiler
      if defined?(Rack::MiniProfiler)
        Rack::MiniProfiler.deauthorize_request
      end
    end
  end
end
