# frozen_string_literal: true

class AddBroadcastOptionsToAudioroomRooms < ActiveRecord::Migration[7.0]
  def change
    add_column :audioroom_rooms, :broadcast_background, :string
    add_column :audioroom_rooms, :broadcast_watermark, :boolean, default: true, null: false
  end
end
