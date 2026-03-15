# frozen_string_literal: true

module Audioroom
  class NotifyRoomLiveJob < ::Jobs::Base
    def execute(args)
      room = Audioroom::Room.find_by(id: args[:room_id])
      return unless room
      Audioroom::RoomNotifier.notify_room_live(room, args[:joining_user_id])
    end
  end
end
