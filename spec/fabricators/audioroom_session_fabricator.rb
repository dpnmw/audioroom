# frozen_string_literal: true

Fabricator(:audioroom_session, class_name: "Audioroom::Session") do
  user
  room { Fabricate(:audioroom_room) }
  joined_at { 1.hour.ago }
  left_at { Time.current }
end
