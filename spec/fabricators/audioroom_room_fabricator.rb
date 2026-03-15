# frozen_string_literal: true
Fabricator(:audioroom_room, class_name: "Audioroom::Room") do
  name { sequence(:audioroom_room_name) { |i| "Audioroom #{i}" } }
  public { false }
  creator { Fabricate(:user) }
end
