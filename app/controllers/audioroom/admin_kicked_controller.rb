# frozen_string_literal: true

module Audioroom
  class AdminKickedController < ::Admin::AdminController
    requires_plugin "audioroom"

    def index
      rooms = Audioroom::Room.order(:created_at)
      result = []

      rooms.each do |room|
        kicked_ids = Discourse.redis.smembers(
          "audioroom:room:#{room.id}:kicked"
        ).map(&:to_i).select(&:positive?)

        next if kicked_ids.empty?

        users = User.where(id: kicked_ids)
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

      render json: { kicked_users: result }
    end

    def unkick
      room = Audioroom::Room.find(params[:room_id])
      user_id = params.require(:user_id).to_i
      Audioroom::ParticipantTracker.unkick(room.id, user_id)
      render json: success_json
    end
  end
end
