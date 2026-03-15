import AudioroomRoomList from "discourse/plugins/audioroom/admin/components/audioroom-room-list";

<template>
  <AudioroomRoomList
    @rooms={{@controller.model.content}}
    @onDestroy={{@controller.destroyRoom}}
  />
</template>
