# frozen_string_literal: true

module Audioroom
  class RoomSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :slug,
               :description,
               :cooked_description,
               :public,
               :room_type,
               :max_participants,
               :created_at,
               :updated_at,
               :member_count,
               :active_participants,
               :creator_id,
               :can_manage,
               :description_excerpt,
               :visit_count,
               :live,
               :broadcast_layout,
               :schedule,
               :next_session_at,
               :topic_id,
               :topic_url,
               :is_following,
               :broadcast_background,
               :broadcast_watermark,
               :has_youtube_stream_key,
               :archived

    def live
      object.live?
    end

    def has_youtube_stream_key
      object.youtube_stream_key.present?
    end

    has_one :membership, serializer: Audioroom::RoomMembershipSerializer, embed: :objects

    def membership
      object.room_memberships.find { |membership| membership.user_id == scope.user&.id }
    end

    def member_count
      object.room_memberships.size
    end

    def active_participants
      all_metadata = Audioroom::ParticipantTracker.get_all_metadata(object.id)
      Audioroom::ParticipantTracker
        .list(object.id)
        .map do |user|
          BasicUserSerializer
            .new(user, scope: scope, root: false)
            .as_json
            .merge(all_metadata[user.id] || {})
        end
    end

    def room_type
      object.room_type_name
    end

    def can_manage
      scope.can_manage_audioroom_room?(object)
    end

    def description_excerpt
      object.description&.lines&.first&.truncate(150)
    end

    def visit_count
      Audioroom::Session.where(user_id: scope.user.id, room_id: object.id).count
    end

    def include_visit_count?
      scope.user.present? && @options[:include_visit_count]
    end

    def schedule
      object.schedule  # already a Hash from Postgres jsonb — no JSON.parse needed
    end

    def topic_url
      return nil unless object.topic_id && object.topic&.present?
      "#{Discourse.base_url}/t/#{object.topic_id}"
    end

    def is_following
      return false unless scope.user
      object.room_follows.exists?(user_id: scope.user.id)
    end
  end
end
