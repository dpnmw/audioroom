# frozen_string_literal: true

module ::Audioroom
  PLUGIN_NAME = "audioroom"
  ROOM_CHANNEL_PREFIX = "/audioroom/rooms"
  ROOM_INDEX_CHANNEL = "/audioroom/rooms/index"

  def self.table_name_prefix
    "audioroom_"
  end

  def self.enabled?
    SiteSetting.audioroom_enabled
  end

  def self.room_channel(room_id)
    "#{ROOM_CHANNEL_PREFIX}/#{room_id}"
  end

  def self.room_index_channel
    ROOM_INDEX_CHANNEL
  end
end

require_relative "audioroom/engine"
require_relative "audioroom/guardian_extension"
require_relative "audioroom/user_status_manager"
