# Video & Screen Sharing

## Overview

Add optional video and screen sharing to voice rooms. P2P only, practical for
up to ~3 video streams. The main challenge is UI — Audioroom currently lives
entirely in the sidebar with no dedicated page or panel. Video needs real
estate.

## Constraints

- **5 participants default for video, up to 8** — the bottleneck is CPU and
  browser peer connection overhead, not bandwidth. Full mesh P2P with video
  at 720p works well up to 5 users on modern hardware. 6-8 is feasible but
  may strain low-end laptops. Beyond 8, an SFU is needed regardless of
  bandwidth.
- **Screen share counts as a video stream** — a user sharing their screen
  consumes one stream slot. A user can share camera OR screen, not both
  simultaneously (keeps it simple).
- **Audio-only users can coexist** — a room with 8 audio participants and 3
  video participants is fine. Only video streams are limited.
- **No video in Stage rooms (for now)** — Stage rooms have their own complexity.
  Video is only available in Open rooms initially.

## UI approach: the Video Panel

Video cannot live in the sidebar — there's no room. Instead, introduce a
**Video Panel** that slides out from the sidebar as a resizable floating panel
overlaying the Discourse content area.

### Layout modes

**Mode 1: Sidebar only (current, no video)**

```
┌──────────┬─────────────────────────────┐
│ Sidebar  │                             │
│          │                             │
│ 🎙 Room  │      Discourse content      │
│  👤 Alice│                             │
│  👤 Bob  │                             │
│  👤 You  │                             │
│          │                             │
└──────────┴─────────────────────────────┘
```

No changes. Audio-only rooms work exactly as today.

**Mode 2: Video panel (someone enables video or screen share)**

```
┌──────────┬──────────────┬──────────────┐
│ Sidebar  │ Video Panel  │              │
│          │              │              │
│ 🎙 Room  │ ┌──────────┐ │  Discourse   │
│  👤 Alice│ │  Alice 🎥 │ │  content     │
│  👤 Bob  │ ├──────────┤ │  (narrower)  │
│  👤 You  │ │  You  🎥  │ │              │
│          │ └──────────┘ │              │
│          │ [📷] [🖥️]   │              │
└──────────┴──────────────┴──────────────┘
```

- Panel appears between sidebar and content.
- Discourse content area shrinks to accommodate (CSS transition).
- Panel width is resizable by dragging the right edge (min 280px, max 50vw).
- Panel width persisted in localStorage.
- Video tiles stack vertically in the panel.

**Mode 3: Expanded / focused view**

Double-click a video tile or click an expand button to go full-width:

```
┌──────────┬─────────────────────────────┐
│ Sidebar  │ ┌─────────────────────────┐ │
│          │ │                         │ │
│ 🎙 Room  │ │    Alice (focused)      │ │
│  👤 Alice│ │                         │ │
│  👤 Bob  │ ├────────┬────────────────┤ │
│  👤 You  │ │ You 🎥 │   Bob 🎥      │ │
│          │ └────────┴────────────────┘ │
│          │ [📷] [🖥️]  [⊟ collapse]   │
└──────────┴─────────────────────────────┘
```

- One tile is "focused" (large), others are thumbnails below.
- The active speaker auto-focuses (using existing speaking detection).
- Clicking a thumbnail focuses that tile.
- Discourse content is fully covered — user is in "video call mode."
- A collapse button returns to Mode 2.

**Mode 4: Popout window**

Click a popout button to detach the video panel into a separate browser
window:

```
Main window:                    Popout window:
┌──────────┬───────────────┐   ┌─────────────────┐
│ Sidebar  │               │   │ ┌─────────────┐ │
│          │   Discourse   │   │ │  Alice 🎥    │ │
│ 🎙 Room  │   content     │   │ ├─────────────┤ │
│  👤 Alice│   (full width)│   │ │  You 🎥     │ │
│  👤 Bob  │               │   │ └─────────────┘ │
│  👤 You  │               │   │ [📷] [🖥️]      │
└──────────┴───────────────┘   └─────────────────┘
```

- Uses `window.open()` with the video panel content.
- Main window regains full content width.
- Communication between windows via `BroadcastChannel`.
- If popout is closed, panel returns to inline Mode 2.

### Video tile anatomy

Each video tile contains:

```
┌─────────────────────────────┐
│                             │
│         Video feed          │
│                             │
│                             │
├─────────────────────────────┤
│ 👤 Alice  🔇 🎥            │
└─────────────────────────────┘
```

- Video element filling the tile with `object-fit: cover`.
- Bottom bar overlay (semi-transparent): username, mute icon, camera icon.
- Speaking indicator: colored border glow (green) when speaking.
- Right-click: existing participant context menu (volume, mute, kick).

**Self-view tile:**
- Mirrored horizontally (CSS `transform: scaleX(-1)`) for camera (not for
  screen share).
- Small "preview" badge in the corner.

**Camera-off tile:**
- Show the user's avatar centered on a dark background.
- Still shows the bottom bar with name and icons.

**Screen share tile:**
- Uses `object-fit: contain` instead of `cover` (don't crop screen content).
- No horizontal mirror.
- A "🖥️ Screen" badge in the corner.

### Tile layout algorithm

The panel must arrange 1-3 video tiles responsively:

**1 tile:** Full panel width and height.

**2 tiles:** Stacked vertically, each 50% height.

**3 tiles:** One large (top, 60% height) + two small (bottom row, 50% width
each, 40% height). Active speaker gets the large tile.

In expanded mode (Mode 3), same logic but the focused tile takes ~70% of the
space.

### Controls bar

Fixed at the bottom of the video panel:

```
┌─────────────────────────────────────┐
│  [🎤] [📷 Camera] [🖥️ Share] [⊞]  │
└─────────────────────────────────────┘
```

- **Mic toggle** — existing mute, included here for convenience.
- **Camera toggle** — start/stop camera. Grey when off, highlighted when on.
- **Screen share** — start/stop screen sharing. Opens browser's native screen
  picker.
- **Layout toggle** — cycle: panel (Mode 2) → expanded (Mode 3) → panel.
- **Popout button** — detach to separate window (small icon in the corner).

## Implementation plan

### 1. Video Panel component

**New file:** `assets/javascripts/discourse/components/audioroom-video-panel.gjs`

A Glimmer component that:
- Renders as a sibling of the sidebar, positioned via CSS grid/flexbox.
- Contains `<video>` elements for each video stream.
- Manages layout modes (panel, expanded, popout) as tracked state.
- Renders the controls bar.
- Handles resize dragging (pointer events on the right edge).

**Mounting:** Registered via an initializer (like `audioroom-voice-canvas`),
rendered into the Discourse layout when any video stream is active.

**Visibility:** The panel only appears when at least one participant (including
self) has video or screen share active. When all video stops, the panel
collapses back to sidebar-only with a CSS transition.

### 2. Extend `audioroom-webrtc` service for video tracks

**File:** `assets/javascripts/discourse/app/services/audioroom-webrtc.js`

New tracked properties:
- `localVideoStream` — camera `MediaStream` or `null`.
- `localScreenStream` — screen share `MediaStream` or `null`.
- `remoteVideoStreams` — `Map<userId, { stream, type: "camera"|"screen" }>`.

New methods:

```javascript
async toggleCamera() {
  if (this.localVideoStream) {
    this.localVideoStream.getTracks().forEach(t => t.stop());
    this.localVideoStream = null;
    this._removeVideoTrackFromPeers();
    this._broadcastVideoState({ camera: false });
  } else {
    this.localVideoStream = await navigator.mediaDevices.getUserMedia({
      video: { width: { ideal: 640 }, height: { ideal: 480 }, frameRate: { max: 24 } }
    });
    this._addVideoTrackToPeers(this.localVideoStream);
    this._broadcastVideoState({ camera: true });
  }
}

async toggleScreenShare() {
  if (this.localScreenStream) {
    this.localScreenStream.getTracks().forEach(t => t.stop());
    this.localScreenStream = null;
    this._removeVideoTrackFromPeers();
    this._broadcastVideoState({ screen: false });
  } else {
    this.localScreenStream = await navigator.mediaDevices.getDisplayMedia({
      video: { frameRate: { max: 15 } },
      audio: false
    });
    // Handle native "Stop sharing" button
    this.localScreenStream.getVideoTracks()[0].onended = () => {
      this.toggleScreenShare();
    };
    this._addVideoTrackToPeers(this.localScreenStream);
    this._broadcastVideoState({ screen: true });
  }
}
```

**Camera vs. screen share exclusivity:** Starting screen share stops camera
and vice versa. Only one video track per user at a time.

### 3. WebRTC track management

**Adding a video track to existing connections:**

When the user enables camera or screen share, add the video track to every
existing `RTCPeerConnection` via `addTrack()`, then renegotiate:

```javascript
_addVideoTrackToPeers(stream) {
  const videoTrack = stream.getVideoTracks()[0];
  for (const [peerId, pc] of this._peerConnections) {
    pc.addTrack(videoTrack, stream);
    // Renegotiation happens automatically via onnegotiationneeded
  }
}
```

`onnegotiationneeded` fires on the connection, triggering a new offer/answer
exchange. The existing signaling infrastructure handles this — the signal
endpoint already relays arbitrary SDP.

**Removing a video track:**

```javascript
_removeVideoTrackFromPeers() {
  for (const [peerId, pc] of this._peerConnections) {
    const senders = pc.getSenders();
    const videoSender = senders.find(s => s.track?.kind === "video");
    if (videoSender) {
      pc.removeTrack(videoSender);
      // Triggers renegotiation
    }
  }
}
```

**Receiving remote video:**

The existing `ontrack` handler receives new tracks. Extend it to distinguish
audio and video:

```javascript
pc.ontrack = (event) => {
  const track = event.track;
  if (track.kind === "audio") {
    // Existing audio handling
  } else if (track.kind === "video") {
    this.remoteVideoStreams.set(peerId, {
      stream: event.streams[0],
      type: metadata.screen ? "screen" : "camera"
    });
    // Trigger panel re-render
  }
};
```

### 4. Video state metadata

**File:** `app/services/audioroom/participant_tracker.rb`

Add `has_camera` and `has_screen` booleans to participant metadata. Broadcast
via the existing participant metadata system so the sidebar and panel know
who has video active without waiting for WebRTC negotiation.

Frontend broadcasts video state changes:

```javascript
_broadcastVideoState(state) {
  // POST to toggle_mute endpoint (or a new toggle_video endpoint)
  // with { has_camera: bool, has_screen: bool }
}
```

### 5. Backend: video toggle endpoint

**File:** `app/controllers/audioroom/rooms_controller.rb`

New action (or extend `toggle_mute`):

```ruby
def toggle_video
  participant = find_participant!
  metadata = params.permit(:has_camera, :has_screen)
  ParticipantTracker.update_metadata(room.id, current_user.id, metadata)
  RoomBroadcaster.publish_participants(room)
  head :ok
end
```

**Route:** `POST /audioroom/rooms/:id/toggle_video`

### 6. Sidebar indicators

**File:** Sidebar initializer

When a participant has video active, show a small camera icon (📷) or screen
icon (🖥️) next to their avatar in the sidebar, alongside the existing
mute/speaking indicators.

When any participant in a room has video, show a video badge on the room
link itself (so users browsing rooms can see "there's a video call happening").

### 7. Popout window

**New file:** `assets/javascripts/discourse/components/audioroom-video-popout.gjs`

The popout uses `window.open()` to create a minimal page containing only the
video panel. Communication with the main window:

```javascript
// Main window → popout: stream updates, participant changes
const channel = new BroadcastChannel("audioroom-video");
channel.postMessage({ type: "streams-updated", streams: [...] });

// Popout → main window: control actions (mute, camera toggle, etc.)
channel.postMessage({ type: "toggle-camera" });
```

The popout window receives `MediaStream` objects — but `MediaStream` is not
transferable via `BroadcastChannel`. Instead:

**Approach:** The popout page loads the same Ember app and injects the
`audioroom-webrtc` service. Since the service holds the WebRTC connections, the
video elements in the popout can attach to the same streams.

**Simpler approach:** Don't share streams. The popout is a stripped-down page
(`/audioroom/popout`) that connects to the same MessageBus channels and renders
video from stream data received via the WebRTC connections that live in the
main window.

**Simplest approach (recommended):** Use `window.open` with `about:blank`,
then move the video DOM elements from the inline panel to the popout window
using `popoutWindow.document.adoptNode(videoContainer)`. This moves the
actual DOM nodes (including live `<video>` elements with `srcObject` intact)
into the new window. On popout close, move them back. This avoids duplicating
any WebRTC logic.

```javascript
openPopout() {
  this.popout = window.open("", "audioroom-video", "width=480,height=640");
  this.popout.document.title = "Audioroom Video";

  // Inject stylesheet
  const link = this.popout.document.createElement("link");
  link.rel = "stylesheet";
  link.href = "/plugins/audioroom/stylesheets/video-popout.css";
  this.popout.document.head.appendChild(link);

  // Move video container DOM node
  const container = document.getElementById("audioroom-video-container");
  this.popout.document.body.appendChild(
    this.popout.document.adoptNode(container)
  );

  this.popout.onbeforeunload = () => this.closePopout();
}

closePopout() {
  const container = this.popout.document.getElementById("audioroom-video-container");
  document.getElementById("audioroom-video-panel").appendChild(
    document.adoptNode(container)
  );
  this.popout = null;
}
```

### 8. Styles

**File:** `assets/stylesheets/common/audioroom-video.scss`

```scss
.audioroom-video-panel {
  display: flex;
  flex-direction: column;
  background: var(--secondary);
  border-right: 1px solid var(--primary-low);
  min-width: 280px;
  max-width: 50vw;
  transition: width 0.2s ease;
  resize: horizontal;
  overflow: hidden;

  &.expanded {
    flex: 1;
    max-width: none;
  }
}

.audioroom-video-tile {
  position: relative;
  background: var(--primary-very-low);
  border-radius: 8px;
  overflow: hidden;

  video {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  &.screen-share video {
    object-fit: contain;
    background: #000;
  }

  &.self video {
    transform: scaleX(-1);
  }

  &.self.screen-share video {
    transform: none;
  }

  &.speaking {
    box-shadow: 0 0 0 3px var(--success);
    transition: box-shadow 0.2s ease;
  }
}

.audioroom-video-tile__overlay {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 4px 8px;
  background: linear-gradient(transparent, rgba(0, 0, 0, 0.6));
  color: #fff;
  font-size: var(--font-down-1);
  display: flex;
  align-items: center;
  gap: 6px;
}

.audioroom-video-tile__avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  background: var(--primary-very-low);

  img {
    border-radius: 50%;
    width: 64px;
    height: 64px;
  }
}

.audioroom-video-controls {
  display: flex;
  justify-content: center;
  gap: 12px;
  padding: 8px;
  border-top: 1px solid var(--primary-low);

  button {
    border-radius: 50%;
    width: 40px;
    height: 40px;

    &.active {
      background: var(--tertiary);
      color: var(--secondary);
    }

    &.screen-share.active {
      background: var(--success);
    }
  }
}

// Tile layouts
.audioroom-video-tiles {
  flex: 1;
  display: grid;
  gap: 4px;
  padding: 4px;

  &[data-count="1"] {
    grid-template: 1fr / 1fr;
  }

  &[data-count="2"] {
    grid-template: 1fr 1fr / 1fr;
  }

  &[data-count="3"] {
    grid-template: 3fr 2fr / 1fr 1fr;

    .audioroom-video-tile:first-child {
      grid-column: 1 / -1;
    }
  }
}
```

### 9. Quality profiles

Bandwidth is not the constraint — even cheap broadband in developing countries
exceeds 100 Mbps. The real limits are CPU (encoding/decoding multiple streams)
and browser peer connection overhead. Quality profiles let users on weaker
hardware opt down.

**Profiles:**

| Profile | Camera | Screen share | Use case |
|---------|--------|-------------|----------|
| **High** (default) | 1280×720, 30 fps, 1.5 Mbps | 1920×1080, 30 fps, 3 Mbps | Modern laptop/desktop |
| **Medium** | 640×480, 24 fps, 800 kbps | 1280×720, 24 fps, 1.5 Mbps | Older hardware, many participants |
| **Low** | 320×240, 15 fps, 300 kbps | 640×480, 15 fps, 500 kbps | Low-end devices |

User selects via the video panel settings (gear icon in controls bar).
Persisted in localStorage (`audioroom_video_quality`). Default is High.

Applied via `RTCRtpSender.setParameters()`:

```javascript
const sender = pc.getSenders().find(s => s.track?.kind === "video");
const params = sender.getParameters();
const profile = this._getQualityProfile();
params.encodings[0].maxBitrate = isScreen ? profile.screenBitrate : profile.cameraBitrate;
params.encodings[0].maxFramerate = profile.frameRate;
await sender.setParameters(params);
```

And via `getUserMedia` constraints:

```javascript
const constraints = {
  video: {
    width: { ideal: profile.width },
    height: { ideal: profile.height },
    frameRate: { max: profile.frameRate },
  }
};
```

### 10. Site settings

**File:** `config/settings.yml`

```yaml
audioroom_video_enabled:
  default: false
  client: true
  description: "Enable camera and screen sharing in voice rooms"

audioroom_video_max_participants:
  default: 5
  min: 2
  max: 8
  client: true
  description: "Maximum number of participants who can share video simultaneously"
```

Video is off by default — admin opt-in. Separate from the core voice feature.

## Edge cases

- **User enables camera when video participant limit is reached:** The camera
  button is disabled with a tooltip: "Maximum video participants reached."
  Check the count before calling `getUserMedia`.
- **Screen share ended by OS/browser (e.g., "Stop sharing" button):**
  Handled by the `track.onended` event which calls `toggleScreenShare()`.
- **Renegotiation storms:** Multiple users enabling video simultaneously
  triggers multiple renegotiations. The existing ICE candidate batching
  (75ms) helps. Add a renegotiation debounce: if `onnegotiationneeded` fires
  within 200ms of the last negotiation, delay it.
- **User joins mid-video:** New user joins, existing video participants'
  `onnegotiationneeded` fires for the new peer connection, which includes
  the video track. The new user receives video automatically.
- **Mobile browsers:** `getDisplayMedia` is not supported on iOS Safari or
  most Android browsers. Hide the screen share button when
  `navigator.mediaDevices.getDisplayMedia` is undefined. Camera works on
  mobile but the panel should be fullscreen (Mode 3) on small viewports
  since Mode 2 is too narrow.
- **Popout blocked by popup blocker:** `window.open` returns `null`. Show a
  toast: "Popup blocked. Allow popups for this site to use the detached
  video view."
- **Panel resize vs. Discourse layout:** The panel width change must trigger
  a reflow of the main content area. Use CSS `flex` so the content area
  automatically fills remaining space. Avoid fixed widths on the content
  area.
- **Video + PTT:** Works fine — PTT controls audio, video is independent.
- **Video + Stage rooms:** Disabled for now. The UI complexity of
  speaker/listener sections + video tiles is too much for a first version.

## Future enhancements (out of scope)

- **Video in Stage rooms** — speakers can share camera, listeners are
  view-only.
- **SFU integration** — for rooms with more than 3-5 video participants.
- **Virtual backgrounds** — WebGL/Canvas-based background blur or
  replacement using a segmentation model (like TensorFlow BodyPix).
- **Recording** — capture the composite video layout to a file.
- **Reactions overlay** — floating emoji reactions on the video tiles.
- **Picture-in-picture** — use the browser's native PiP API for a single
  video tile that floats over other tabs.
- **Simulcast** — send multiple quality layers so receivers can adapt to
  their bandwidth. Requires SFU to be effective.
