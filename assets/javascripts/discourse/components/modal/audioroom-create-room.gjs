import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AudioroomRoomForm from "discourse/plugins/audioroom/discourse/components/audioroom-room-form";

export default class AudioroomCreateRoomModal extends Component {
  @service audioroomRooms;
  @service toasts;

  @action
  async handleSubmit(data) {
    try {
      const result = await ajax("/audioroom/rooms", {
        type: "POST",
        data: { room: data },
      });
      this.audioroomRooms.handleDirectoryEvent({
        type: "created",
        room: result.room,
      });
      this.toasts.success({ data: { message: i18n("audioroom.room.created") } });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "audioroom.sidebar.create"}}
      class="audioroom-create-room-modal"
    >
      <:body>
        <AudioroomRoomForm @onSubmit={{this.handleSubmit}} />
      </:body>
    </DModal>
  </template>
}
