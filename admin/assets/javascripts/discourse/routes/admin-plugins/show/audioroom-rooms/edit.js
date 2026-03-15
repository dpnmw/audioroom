import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AudioroomRoomsEditRoute extends DiscourseRoute {
  @service store;

  model(params) {
    return this.store.find("audioroom-room", params.id);
  }
}
