# frozen_string_literal: true

module Audioroom
  class RoomFollowsController < ApplicationController
    before_action :load_room

    def create   # POST /audioroom/rooms/:room_id/follow
      guardian.ensure_can_join_audioroom_room!(@room)
      @room.room_follows.find_or_create_by!(user: current_user)
      head :no_content
    end

    def destroy  # DELETE /audioroom/rooms/:room_id/follow
      @room.room_follows.find_by(user: current_user)&.destroy
      head :no_content
    end

    private

    def load_room
      @room = Audioroom::Room.find(params[:room_id])
    end
  end
end
