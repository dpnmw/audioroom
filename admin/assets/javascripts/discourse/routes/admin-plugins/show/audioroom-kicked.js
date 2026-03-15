import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AudioroomKickedRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/audioroom/kicked.json");
  }
}
