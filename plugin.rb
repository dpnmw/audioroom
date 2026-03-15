# frozen_string_literal: true

# name: audioroom
# about: LiveKit-powered voice rooms for Discourse
# version: 0.1.0
# authors: DPN Media Works
# url: https://dpnmediaworks.com

gem "twirp", "1.13.1", require: false
gem "livekit-server-sdk", "0.9.0", require: false

enabled_site_setting :audioroom_enabled

register_svg_icon "microphone-lines"
register_svg_icon "phone"
register_svg_icon "waveform"
register_svg_icon "ear-listen"
register_svg_icon "volume-high"
register_svg_icon "microphone"
register_svg_icon "microphone-slash"
register_svg_icon "ban"
register_svg_icon "volume-xmark"
register_svg_icon "walkie-talkie"
register_svg_icon "keyboard"
register_svg_icon "phone-slash"
register_svg_icon "podcast"
register_svg_icon "handshake"
register_svg_icon "users"
register_svg_icon "user-group"
register_svg_icon "compass"
register_svg_icon "calendar"
register_svg_icon "house"
register_svg_icon "bullhorn"
register_svg_icon "star"
register_svg_icon "moon"
register_svg_icon "sun"
register_svg_icon "people-group"
register_svg_icon "calendar-week"
register_svg_icon "trophy"
register_svg_icon "clock"
register_svg_icon "circle-play"
register_svg_icon "circle-stop"
register_asset "stylesheets/common/audioroom.scss"
register_asset "stylesheets/common/audioroom-admin.scss", :admin

add_admin_route "audioroom.admin.title", "audioroom", use_new_show_route: true

require_relative "lib/audioroom"
require_relative "lib/audioroom/broadcast_csp_middleware"

# Strip Discourse's strict-dynamic CSP on the broadcast page (headless Chrome only)
# Must be registered at config time — the middleware stack is frozen after initialization.
Rails.configuration.middleware.use Audioroom::BroadcastCspMiddleware

after_initialize do
  require_relative "lib/audioroom/user_extension"

  Discourse::Application.routes.append { mount ::Audioroom::Engine, at: "/audioroom" }

  Guardian.prepend Audioroom::GuardianExtension

  on(:site_setting_changed) do |name, _old_value, new_value|
    if name.to_sym == :audioroom_enabled
      clear_all_audioroom_statuses unless new_value
    end

    if name.to_sym == :audioroom_badges_enabled
      if new_value
        Audioroom::BadgeGranterHooks.enable_all!
      else
        Audioroom::BadgeGranterHooks.disable_all!
      end
    end

    clear_all_audioroom_statuses if name.to_sym == :audioroom_auto_status_enabled && !new_value
  end

  def self.clear_all_audioroom_statuses
    UserStatus
      .where(emoji: [Audioroom::UserStatusManager::EMOJI, Audioroom::UserStatusManager::AFK_EMOJI])
      .find_each { |status| User.find_by(id: status.user_id)&.clear_status! }
  end
end
