# frozen_string_literal: true

module Audioroom
  class AdminBannedController < ::Admin::AdminController
    requires_plugin "audioroom"

    def index
      rooms = Audioroom::Room.order(:created_at)
      result = []

      rooms.each do |room|
        banned_ids = Discourse.redis.smembers(
          "audioroom:room:#{room.id}:banned"
        ).map(&:to_i).select(&:positive?)

        next if banned_ids.empty?

        users = User.where(id: banned_ids)
        users.each do |user|
          result << {
            room_id: room.id,
            room_name: room.name,
            room_slug: room.slug,
            user_id: user.id,
            username: user.username,
            name: user.name,
            avatar_template: user.avatar_template,
          }
        end
      end

      render json: { banned_users: result }
    end

    def unban
      room = Audioroom::Room.find(params[:room_id])
      user_id = params.require(:user_id).to_i
      Audioroom::ParticipantTracker.unban(room.id, user_id)
      render json: success_json
    end
  end
end
