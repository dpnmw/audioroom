import { withPluginApi } from "discourse/lib/plugin-api";
import AudioroomVoiceCanvas from "discourse/plugins/audioroom/discourse/components/audioroom/voice-canvas";

function loadLiveKitSdk() {
  return new Promise((resolve, reject) => {
    if (window.LivekitClient) {
      resolve();
      return;
    }
    const script = document.createElement("script");
    script.src = "/plugins/audioroom/javascripts/livekit-client.umd.js";
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

export default {
  name: "audioroom-voice-canvas",

  initialize(owner) {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();
      const siteSettings = owner.lookup("service:site-settings");

      if (!currentUser || !siteSettings.audioroom_enabled) {
        return;
      }

      // Load LiveKit SDK bundle before the voice canvas mounts
      loadLiveKitSdk().catch((e) => {
        // eslint-disable-next-line no-console
        console.error("[Audioroom] Failed to load LiveKit SDK:", e);
      });

      api.renderInOutlet("below-site-header", AudioroomVoiceCanvas);
    });
  },
};
