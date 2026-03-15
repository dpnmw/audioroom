import RestAdapter from "discourse/adapters/rest";

export default class AudioroomRoomAdapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/audioroom/";
  }

  pathFor(store, type, id) {
    return id === undefined
      ? "/admin/plugins/audioroom/rooms.json"
      : `/admin/plugins/audioroom/rooms/${id}.json`;
  }

  apiNameFor() {
    return "room";
  }
}
