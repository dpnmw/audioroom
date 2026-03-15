# frozen_string_literal: true

module Audioroom
  class RoomFollow < ActiveRecord::Base
    self.table_name = "audioroom_room_follows"
    belongs_to :user
    belongs_to :room, class_name: "Audioroom::Room"
    validates :user_id, uniqueness: { scope: :room_id }
  end
end
