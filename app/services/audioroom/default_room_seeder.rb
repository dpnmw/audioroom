# frozen_string_literal: true

module Audioroom
  class DefaultRoomSeeder
    DEFAULT_NAME = "TheLounge"
    MUTEX = "audioroom-default-room-seeder"

    def self.ensure!
      return unless SiteSetting.audioroom_enabled?
      return unless ActiveRecord::Base.connection.table_exists?(:audioroom_rooms)

      DistributedMutex.synchronize(MUTEX) do
        next if Audioroom::Room.exists?

        room =
          Audioroom::Room.create!(
            name: DEFAULT_NAME,
            description: I18n.t("audioroom.defaults.thelounge_description"),
            public: true,
            creator: Discourse.system_user,
          )

        Audioroom::DirectoryBroadcaster.broadcast(action: :created, room: room)
      end
    end
  end
end
