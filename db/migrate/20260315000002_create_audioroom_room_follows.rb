# frozen_string_literal: true

class CreateAudioroomRoomFollows < ActiveRecord::Migration[7.0]
  def change
    create_table :audioroom_room_follows do |t|
      t.bigint :user_id, null: false
      t.bigint :room_id, null: false
      t.timestamps
    end

    add_index :audioroom_room_follows, %i[user_id room_id], unique: true
    add_foreign_key :audioroom_room_follows, :users
    add_foreign_key :audioroom_room_follows, :audioroom_rooms, column: :room_id
  end
end
