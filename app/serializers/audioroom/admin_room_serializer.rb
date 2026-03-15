# frozen_string_literal: true

module Audioroom
  class AdminRoomSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :slug,
               :description,
               :public,
               :room_type,
               :max_participants,
               :member_count,
               :created_at,
               :updated_at,
               :live,
               :egress_id,
               :broadcast_layout,
               :broadcast_background,
               :broadcast_watermark,
               :youtube_stream_key,
               :archived

    has_one :creator, serializer: BasicUserSerializer, embed: :objects

    def room_type
      object.room_type_name
    end

    def member_count
      object.room_memberships.size
    end

    def live
      object.live?
    end

    def archived
      object.respond_to?(:archived) ? object.archived : false
    end
  end
end
