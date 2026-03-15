import AudioroomDangerZone from "discourse/plugins/audioroom/admin/components/audioroom-danger-zone";

<template>
  <AudioroomDangerZone
    @confirmText={{@controller.confirmText}}
    @resetConfirmed={{@controller.resetConfirmed}}
    @resetDisabled={{@controller.resetDisabled}}
    @onUpdateConfirmText={{@controller.updateConfirmText}}
    @onReset={{@controller.resetPlugin}}
  />
</template>
