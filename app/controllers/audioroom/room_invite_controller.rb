# frozen_string_literal: true

module Audioroom
  class RoomInviteController < ApplicationController
    # GET /audioroom/invite/:token
    def show
      @room = Audioroom::Room.find_by!(invite_token: params[:token])
      guardian.ensure_can_join_audioroom_room!(@room)

      is_stage = @room.room_type == "stage"

      unless is_stage
        # Auto-grant membership for open rooms only
        @room.room_memberships.find_or_create_by!(user: current_user) do |m|
          m.role = Audioroom::RoomMembership::ROLE_PARTICIPANT
        end
      end

      render json: {
        room: serialize_room(@room),
        requires_confirmation: is_stage
      }
    end

    private

    def serialize_room(room)
      Audioroom::RoomSerializer.new(room, scope: guardian, root: false).as_json
    end
  end
end
