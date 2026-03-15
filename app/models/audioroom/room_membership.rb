# frozen_string_literal: true

module Audioroom
  class RoomMembership < ActiveRecord::Base
    self.table_name = "#{Audioroom.table_name_prefix}room_memberships"

    belongs_to :room, class_name: "Audioroom::Room"
    belongs_to :user

    ROLE_PARTICIPANT = 0
    ROLE_MODERATOR = 1
    ROLE_SPEAKER = 2
    ROLES = {
      "participant" => ROLE_PARTICIPANT,
      "moderator" => ROLE_MODERATOR,
      "speaker" => ROLE_SPEAKER,
    }.freeze

    scope :moderator, -> { where(role: ROLE_MODERATOR) }
    scope :speaker, -> { where(role: ROLE_SPEAKER) }

    def moderator?
      role == ROLE_MODERATOR
    end

    def participant?
      role == ROLE_PARTICIPANT
    end

    def speaker?
      role == ROLE_SPEAKER
    end

    def can_speak?
      moderator? || speaker?
    end

    def role_name
      ROLES.key(role) || "participant"
    end

    def self.role_value(key)
      return ROLE_PARTICIPANT if key.blank?

      ROLES[key.to_s] || ROLE_PARTICIPANT
    end

    validates :room_id, presence: true
    validates :user_id, presence: true, uniqueness: { scope: :room_id }
  end
end

# == Schema Information
#
# Table name: audioroom_room_memberships
#
#  id         :bigint           not null, primary key
#  role       :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  room_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_audioroom_room_memberships_on_room_and_user  (room_id,user_id) UNIQUE
#  index_audioroom_room_memberships_on_room_id      (room_id)
#  index_audioroom_room_memberships_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (room_id => audioroom_rooms.id)
#  fk_rails_...  (user_id => users.id)
#
