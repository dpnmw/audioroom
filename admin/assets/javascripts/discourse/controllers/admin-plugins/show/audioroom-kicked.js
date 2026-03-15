import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AudioroomKickedController extends Controller {
  @tracked kickedUsers = null;

  get computedKickedUsers() {
    return this.kickedUsers ?? this.model?.kicked_users ?? [];
  }

  @action
  async unkick(entry) {
    try {
      await ajax(
        `/admin/plugins/audioroom/kicked/${entry.room_id}/unkick.json`,
        { type: "POST", data: { user_id: entry.user_id } }
      );
      this.kickedUsers = this.computedKickedUsers.filter(
        (e) => !(e.room_id === entry.room_id && e.user_id === entry.user_id)
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
