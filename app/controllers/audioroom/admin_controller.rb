# frozen_string_literal: true

module Audioroom
  class AdminController < ::Admin::AdminController
    requires_plugin "audioroom"

    def index
    end

    def new
    end

    def edit
    end

    def reset
      raise Discourse::InvalidAccess unless current_user.admin?

      # 1. Flush all audioroom Redis keys
      Discourse.redis.scan_each(match: "audioroom:*") do |key|
        Discourse.redis.del(key)
      end

      # 2. Truncate all audioroom tables in dependency order
      %w[
        audioroom_room_follows
        audioroom_co_presences
        audioroom_sessions
        audioroom_room_memberships
        audioroom_rooms
      ].each do |table|
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table} CASCADE")
      end

      # 3. Reseed default room
      Audioroom::Room.find_or_create_by!(slug: "thelounge") do |room|
        room.name = "TheLounge"
        room.description = I18n.t("audioroom.defaults.thelounge_description")
        room.room_type = Audioroom::Room::ROOM_TYPE_OPEN
        room.public = true
        room.creator_id = Discourse.system_user.id
      end

      # 4. Log to staff action log
      StaffActionLogger.new(current_user).log_custom(
        "audioroom_plugin_reset",
        { reset_by: current_user.username },
      )

      render json: success_json
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
end
