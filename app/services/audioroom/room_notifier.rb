# frozen_string_literal: true

module Audioroom
  class RoomNotifier
    COOLDOWN_KEY = "audioroom:notify_cooldown:room:%d"
    COOLDOWN_TTL = 3600 # 1 hour — don't re-notify within 1 hour of last notification

    def self.notify_room_live(room, joining_user_id)
      cooldown_key = COOLDOWN_KEY % room.id
      return if Discourse.redis.get(cooldown_key)

      # Set cooldown first (prevent double-fire from rapid joins)
      Discourse.redis.setex(cooldown_key, COOLDOWN_TTL, "1")

      # Notify all members + followers, excluding the person who just joined
      recipient_ids = room.follower_and_member_ids - [joining_user_id]
      return if recipient_ids.empty?

      recipient_ids.each do |user_id|
        Discourse::Notification.create!(
          notification_type: Notification.types[:custom],
          user_id: user_id,
          data: {
            message: "audioroom.notifications.room_live",
            display_username: User.find_by(id: joining_user_id)&.username,
            room_name: room.name,
            room_id: room.id,
            room_slug: room.slug,
          }.to_json,
        )
      end

      # Hook for push notifications — implement when mobile push layer is ready
      DiscourseEvent.trigger(:audioroom_room_live, room, joining_user_id, recipient_ids)
    rescue => e
      Rails.logger.error("[Audioroom] RoomNotifier failed: #{e.message}")
    end
  end
end
