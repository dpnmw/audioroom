# frozen_string_literal: true

class AddScheduleToAudioroomRooms < ActiveRecord::Migration[7.0]
  def change
    add_column :audioroom_rooms, :schedule, :jsonb
    add_index  :audioroom_rooms, :schedule, using: :gin
    add_column :audioroom_rooms, :next_session_at, :datetime
    add_column :audioroom_rooms, :invite_token, :string
    add_column :audioroom_rooms, :topic_id, :bigint
    add_index  :audioroom_rooms, :invite_token, unique: true
    add_index  :audioroom_rooms, :topic_id
  end
end
