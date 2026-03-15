# frozen_string_literal: true

class AddCookedDescriptionToAudioroomRooms < ActiveRecord::Migration[7.2]
  def change
    add_column :audioroom_rooms, :cooked_description, :text
  end
end
