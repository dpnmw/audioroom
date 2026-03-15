# frozen_string_literal: true

module Audioroom
  # Rack middleware that replaces Discourse's strict-dynamic CSP with a
  # permissive policy on the broadcast page.  This page is rendered with
  # `layout: false` and loaded only by LiveKit Egress headless Chrome,
  # so a relaxed policy is safe.
  class BroadcastCspMiddleware
    BROADCAST_PATH = %r{\A/audioroom/broadcast/}

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      if env["PATH_INFO"]&.match?(BROADCAST_PATH)
        headers.delete("Content-Security-Policy")
        headers.delete("Content-Security-Policy-Report-Only")
        headers["Content-Security-Policy"] =
          "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:; " \
          "script-src * 'unsafe-inline' 'unsafe-eval' blob:; " \
          "connect-src * wss: ws:;"
      end

      [status, headers, response]
    end
  end
end
