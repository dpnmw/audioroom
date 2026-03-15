# frozen_string_literal: true

module Audioroom
  class AdminRoomsController < ::Admin::AdminController
    requires_plugin "audioroom"

    def index
      rooms = Audioroom::Room.includes(:creator, :room_memberships).order(:name).all

      render_serialized rooms, AdminRoomSerializer, root: :rooms
    end

    def show
      room = Audioroom::Room.includes(:creator, :room_memberships).find(params[:id])
      render_serialized room, AdminRoomSerializer, root: :room
    end

    def create
      room = Audioroom::Room.new(room_params)
      room.creator = current_user

      if room.save
        render_serialized room, AdminRoomSerializer, root: :room, status: :created
      else
        render_json_error room
      end
    end

    def update
      room = Audioroom::Room.find(params[:id])

      if room.update(room_params)
        if room.saved_change_to_room_type? && room.stage?
          room.room_memberships.find_or_create_by!(user_id: room.creator_id) do |m|
            m.role = Audioroom::RoomMembership::ROLE_MODERATOR
          end
        end
        render_serialized room, AdminRoomSerializer, root: :room
      else
        render_json_error room
      end
    end

    def destroy
      room = Audioroom::Room.find(params[:id])
      room.destroy!
      head :no_content
    end

    def archive
      room = Audioroom::Room.find(params[:id])
      room.update!(archived: true)
      render_serialized room, AdminRoomSerializer, root: :room
    end

    def unarchive
      room = Audioroom::Room.find(params[:id])
      room.update!(archived: false)
      render_serialized room, AdminRoomSerializer, root: :room
    end

    private

    def room_params
      params.require(:room).permit(
        :name,
        :description,
        :public,
        :max_participants,
        :room_type,
        :youtube_stream_key,
        :broadcast_background,
        :broadcast_watermark,
      )
    end
  end
end
