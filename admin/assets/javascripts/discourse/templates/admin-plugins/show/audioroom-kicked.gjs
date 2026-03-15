import AudioroomKickedList from "discourse/plugins/audioroom/admin/components/audioroom-kicked-list";

<template>
  <AudioroomKickedList
    @kickedUsers={{@controller.computedKickedUsers}}
    @onUnkick={{@controller.unkick}}
  />
</template>
