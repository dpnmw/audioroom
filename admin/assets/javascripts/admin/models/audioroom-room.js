import RestModel from "discourse/models/rest";

export default class AudioroomRoom extends RestModel {
  createProperties() {
    return this.getProperties([
      "name",
      "description",
      "public",
      "room_type",
      "max_participants",
    ]);
  }

  updateProperties() {
    return this.getProperties([
      "name",
      "description",
      "public",
      "room_type",
      "max_participants",
    ]);
  }
}
