import RestModel from "discourse/models/rest";

export default class AudioroomRoom extends RestModel {
  createProperties() {
    return this.getProperties([
      "name",
      "description",
      "public",
      "room_type",
      "max_participants",
      "broadcast_background",
      "broadcast_watermark",
    ]);
  }

  updateProperties() {
    return this.getProperties([
      "name",
      "description",
      "public",
      "room_type",
      "max_participants",
      "broadcast_background",
      "broadcast_watermark",
    ]);
  }
}
