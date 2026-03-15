# frozen_string_literal: true

module Audioroom
  class ApplicationController < ::ApplicationController
    requires_plugin ::Audioroom::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_enabled!

    private

    def ensure_enabled!
      unless Audioroom.enabled?
        raise Discourse::InvalidAccess.new(I18n.t("audioroom.errors.not_enabled"))
      end
    end

    def guardian
      @guardian ||= Guardian.new(current_user)
    end
  end
end
