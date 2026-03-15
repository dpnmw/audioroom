# frozen_string_literal: true

class AddArchivedToAudioroomRooms < ActiveRecord::Migration[7.0]
  def change
    add_column :audioroom_rooms, :archived, :boolean, default: false, null: false
  end
end
