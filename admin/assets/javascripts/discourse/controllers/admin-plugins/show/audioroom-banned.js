import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AudioroomBannedController extends Controller {
  @tracked bannedUsers = null;

  get computedBannedUsers() {
    return this.bannedUsers ?? this.model?.banned_users ?? [];
  }

  @action
  async unban(entry) {
    try {
      await ajax(
        `/admin/plugins/audioroom/banned/${entry.room_id}/unban.json`,
        { type: "POST", data: { user_id: entry.user_id } }
      );
      this.bannedUsers = this.computedBannedUsers.filter(
        (e) => !(e.room_id === entry.room_id && e.user_id === entry.user_id)
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
