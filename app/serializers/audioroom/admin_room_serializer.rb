# frozen_string_literal: true

module Audioroom
  class AdminRoomSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :slug,
               :description,
               :public,
               :max_participants,
               :member_count,
               :created_at,
               :updated_at,
               :live,
               :egress_id,
               :broadcast_layout,
               :youtube_stream_key,
               :archived

    has_one :creator, serializer: BasicUserSerializer, embed: :objects

    def member_count
      object.room_memberships.size
    end

    def live
      object.live?
    end
  end
end
