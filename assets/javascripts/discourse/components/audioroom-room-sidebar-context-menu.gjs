import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import AudioroomRoomInfoModal from "./modal/audioroom-room-info";
import AudioroomLivestreamModal from "./modal/audioroom-livestream";

export default class AudioroomRoomSidebarContextMenu extends Component {
  @service modal;
  @service audioroomWebrtc;
  @service currentUser;

  get room() {
    return this.args.data.room;
  }

  get isConnected() {
    return this.audioroomWebrtc.connectionStateFor(this.room.id) === "connected";
  }

  get isAdmin() {
    return this.currentUser?.admin;
  }

  @action
  openRoomInfo() {
    this.modal.show(AudioroomRoomInfoModal, { model: { room: this.room } });
    this.args.close();
  }

  @action
  editRoom() {
    this.modal.show(AudioroomRoomInfoModal, {
      model: { room: this.room, isEditing: true },
    });
    this.args.close();
  }

  @action
  leaveRoom() {
    this.audioroomWebrtc.leave(this.room);
    this.args.close();
  }

  @action
  openLivestream() {
    this.modal.show(AudioroomLivestreamModal, { model: { room: this.room } });
    this.args.close();
  }

  <template>
    <DropdownMenu class="audioroom-room-sidebar-context-menu" as |dropdown|>
      <dropdown.item>
        <DButton
          @action={{this.openRoomInfo}}
          @icon="circle-info"
          @label="audioroom.room.info"
          @title="audioroom.room.info"
          class="audioroom-room-sidebar-context-menu__room-info"
        />
      </dropdown.item>
      {{#if this.room.can_manage}}
        <dropdown.item>
          <DButton
            @action={{this.editRoom}}
            @icon="pencil"
            @label="audioroom.room.edit"
            @title="audioroom.room.edit"
            class="audioroom-room-sidebar-context-menu__edit-room"
          />
        </dropdown.item>
      {{/if}}
      {{#if this.isAdmin}}
        <dropdown.item>
          <DButton
            @action={{this.openLivestream}}
            @icon={{if this.room.live "circle-stop" "circle-play"}}
            @label={{if this.room.live "audioroom.livestream.stop" "audioroom.livestream.go_live"}}
            @title={{if this.room.live "audioroom.livestream.stop" "audioroom.livestream.go_live"}}
            class="audioroom-room-sidebar-context-menu__livestream {{if this.room.live '--live'}}"
          />
        </dropdown.item>
      {{/if}}
      {{#if this.isConnected}}
        <dropdown.item>
          <DButton
            @action={{this.leaveRoom}}
            @icon="phone-slash"
            @label="audioroom.room.leave"
            @title="audioroom.room.leave"
            class="audioroom-room-sidebar-context-menu__leave-room --danger"
          />
        </dropdown.item>
      {{/if}}
    </DropdownMenu>
  </template>
}
