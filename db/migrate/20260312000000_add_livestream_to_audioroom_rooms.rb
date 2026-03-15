# frozen_string_literal: true

class AddLivestreamToAudioroomRooms < ActiveRecord::Migration[7.0]
  def change
    add_column :audioroom_rooms, :egress_id, :string
    add_column :audioroom_rooms, :youtube_stream_key, :string
    add_column :audioroom_rooms, :broadcast_layout, :string, default: "speaker", null: false
  end
end
