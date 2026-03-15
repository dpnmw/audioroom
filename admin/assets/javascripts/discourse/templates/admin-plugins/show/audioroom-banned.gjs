import AudioroomBannedList from "discourse/plugins/audioroom/admin/components/audioroom-banned-list";

<template>
  <AudioroomBannedList
    @bannedUsers={{@controller.computedBannedUsers}}
    @onUnban={{@controller.unban}}
  />
</template>
