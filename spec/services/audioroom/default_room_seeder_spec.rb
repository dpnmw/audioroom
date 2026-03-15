# frozen_string_literal: true
require "rails_helper"
require_relative "../../../db/migrate/20241107000000_create_audioroom_rooms"

RSpec.describe Audioroom::DefaultRoomSeeder do
  before do
    ActiveRecord::Migration.suppress_messages do
      unless ActiveRecord::Base.connection.table_exists?(:audioroom_rooms)
        CreateAudioroomRooms.new.change
      end
    end
  end

  before { wipe_rooms! }

  it "creates a Watercooler room when audioroom is enabled and no rooms exist" do
    SiteSetting.audioroom_enabled = true
    wipe_rooms!

    expect { described_class.ensure! }.to change { Audioroom::Room.count }.by(1)

    room = Audioroom::Room.first
    expect(room.name).to eq("Watercooler")
    expect(room.public).to eq(true)
  end

  it "does nothing if audioroom is disabled" do
    SiteSetting.audioroom_enabled = false

    expect { described_class.ensure! }.not_to change { Audioroom::Room.count }
  end

  it "does nothing if rooms already exist" do
    SiteSetting.audioroom_enabled = true
    wipe_rooms!
    Fabricate(:audioroom_room, name: "Existing", creator: Fabricate(:admin))

    expect { described_class.ensure! }.not_to change { Audioroom::Room.count }
  end

  def wipe_rooms!
    Audioroom::RoomMembership.delete_all
    Audioroom::Room.delete_all
  end
end
