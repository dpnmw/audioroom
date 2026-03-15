import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AudioroomRoomsIndexRoute extends DiscourseRoute {
  @service store;

  model() {
    return this.store.findAll("audioroom-room");
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
