import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AudioroomDangerZoneController extends Controller {
  @service dialog;
  @service toasts;

  @tracked confirmText = "";

  get resetConfirmed() {
    return this.confirmText.trim() === "RESET";
  }

  get resetDisabled() {
    return !this.resetConfirmed;
  }

  @action
  updateConfirmText(event) {
    this.confirmText = event.target.value;
  }

  @action
  async resetPlugin() {
    if (!this.resetConfirmed) {
      return;
    }

    await this.dialog.confirm({
      message: i18n("audioroom.admin.danger_zone.confirm_message"),
      didConfirm: async () => {
        try {
          await ajax("/admin/plugins/audioroom/reset.json", { type: "POST" });
          this.confirmText = "";
          this.toasts.success({
            data: { message: i18n("audioroom.admin.danger_zone.reset_success") },
            duration: 4000,
          });
          window.location.reload();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }
}
