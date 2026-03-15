# frozen_string_literal: true

module Audioroom
  class Room < ActiveRecord::Base
    self.table_name = "#{Audioroom.table_name_prefix}rooms"

    ROOM_TYPE_OPEN = 0
    ROOM_TYPE_STAGE = 1
    ROOM_TYPES = { "open" => ROOM_TYPE_OPEN, "stage" => ROOM_TYPE_STAGE }.freeze

    belongs_to :creator, class_name: "User"
    has_many :room_memberships, class_name: "Audioroom::RoomMembership", dependent: :destroy
    has_many :members, through: :room_memberships, source: :user
    has_many :sessions, class_name: "Audioroom::Session", dependent: :destroy
    has_many :room_follows, class_name: "Audioroom::RoomFollow", dependent: :destroy
    has_many :followers, through: :room_follows, source: :user
    belongs_to :topic, class_name: "Topic", optional: true

    validates :name, presence: true, length: { maximum: 80 }
    validates :broadcast_background, length: { maximum: 500 }, allow_nil: true
    validates :schedule, absence: true, unless: -> { schedule.nil? || schedule.is_a?(Hash) }
    validates :slug, presence: true, uniqueness: true
    validates :room_type, inclusion: { in: ROOM_TYPES.values }
    validates :max_participants,
              numericality: {
                only_integer: true,
                allow_nil: true,
                greater_than_or_equal_to: 2,
                less_than_or_equal_to: ->(r) { r.stage? ? 200 : 50 },
              }

    before_validation :ensure_slug
    before_save :cook_description
    before_create :generate_invite_token
    after_commit :ensure_creator_membership, on: :create
    after_find :clear_missing_topic

    scope :public_rooms, -> { where(public: true) }
    scope :active, -> { where(archived: false) }

    def open?
      room_type == ROOM_TYPE_OPEN
    end

    def stage?
      room_type == ROOM_TYPE_STAGE
    end

    def room_type_name
      ROOM_TYPES.key(room_type) || "open"
    end

    def live?
      egress_id.present?
    end

    def moderator_ids
      room_memberships.moderator.pluck(:user_id)
    end

    def member_ids
      room_memberships.pluck(:user_id)
    end

    def message_bus_targets
      if public?
        { group_ids: [Group::AUTO_GROUPS[:trust_level_0]] }
      else
        { user_ids: member_ids }
      end
    end

    def next_scheduled_at
      return next_session_at if next_session_at.present?
      return nil unless schedule.present?
      days = schedule["days"] || []
      time_str = schedule["time"] || "00:00"
      tz = schedule["timezone"] || "UTC"
      now = Time.now.in_time_zone(tz)
      hour, min = time_str.split(":").map(&:to_i)
      days.map do |d|
        candidate = now.beginning_of_week(:sunday) + d.days
        candidate = candidate.change(hour: hour, min: min)
        candidate += 1.week if candidate <= now
        candidate
      end.min
    end

    def follower_and_member_ids
      (room_follows.pluck(:user_id) + room_memberships.pluck(:user_id)).uniq
    end

    def clear_missing_topic
      if topic_id.present? && topic.nil?
        update_column(:topic_id, nil)
      end
    end

    private

    def generate_invite_token
      self.invite_token = SecureRandom.urlsafe_base64(12)
    end

    def ensure_slug
      self.slug = Slug.for(name) if slug.blank? && name.present?
    end

    def cook_description
      self.cooked_description = (PrettyText.cook(description) if description.present?)
    end

    def ensure_creator_membership
      room_memberships.find_or_create_by!(user: creator) do |membership|
        membership.role = Audioroom::RoomMembership::ROLE_MODERATOR
      end
    end
  end
end

# == Schema Information
#
# Table name: audioroom_rooms
#
#  id                 :bigint           not null, primary key
#  cooked_description :text
#  description        :text
#  max_participants   :integer
#  name               :string           not null
#  public             :boolean          default(FALSE), not null
#  room_type          :integer          default(0), not null
#  slug               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  creator_id         :bigint           not null
#
# Indexes
#
#  index_audioroom_rooms_on_creator_id  (creator_id)
#  index_audioroom_rooms_on_slug        (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
