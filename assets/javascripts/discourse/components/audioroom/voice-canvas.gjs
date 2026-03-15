// Developed by DPN Media Works — https://dpnmediaworks.com

import Component from "@glimmer/component";

// With LiveKit, remote audio elements are created and managed directly by
// the audioroom-webrtc service. This component just provides the container
// that those elements are appended to.
export default class AudioroomVoiceCanvas extends Component {
  <template>
    <section id="audioroom-voice-canvas" class="audioroom-voice-canvas" />
  </template>
}
