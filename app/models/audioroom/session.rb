# frozen_string_literal: true

module Audioroom
  class Session < ActiveRecord::Base
    self.table_name = "#{Audioroom.table_name_prefix}sessions"

    belongs_to :user
    belongs_to :room, class_name: "Audioroom::Room"

    scope :orphaned, -> { where(left_at: nil) }

    def close!(at: Time.current)
      update!(left_at: at)
    end
  end
end

# == Schema Information
#
# Table name: audioroom_sessions
#
#  id         :bigint           not null, primary key
#  joined_at  :datetime         not null
#  left_at    :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  room_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_audioroom_sessions_orphaned                                (left_at) WHERE (left_at IS NULL)
#  index_audioroom_sessions_on_room_id                            (room_id)
#  index_audioroom_sessions_on_room_id_and_joined_at              (room_id,joined_at)
#  index_audioroom_sessions_on_user_id                            (user_id)
#  index_audioroom_sessions_on_user_id_and_joined_at              (user_id,joined_at)
#  index_audioroom_sessions_on_user_id_and_room_id_and_joined_at  (user_id,room_id,joined_at)
#
# Foreign Keys
#
#  fk_rails_...  (room_id => audioroom_rooms.id)
#  fk_rails_...  (user_id => users.id)
#
