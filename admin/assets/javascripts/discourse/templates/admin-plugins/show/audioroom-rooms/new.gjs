import AudioroomRoomForm from "discourse/plugins/audioroom/discourse/components/audioroom-room-form";

<template>
  <AudioroomRoomForm
    @room={{@controller.model}}
    @onSave={{@controller.saveRoom}}
  />
</template>
