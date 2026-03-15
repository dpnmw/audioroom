// Developed by DPN Media Works — https://dpnmediaworks.com

import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import IdleTracker from "../../lib/audioroom/idle-tracker";
import PttManager from "../../lib/audioroom/ptt-manager";
import {
  playConnectedSound,
  playDeafenSound,
  playDisconnectedSound,
  playMuteSound,
  playUndeafenSound,
  playUnmuteSound,
  playUserJoinedSound,
  playUserLeftSound,
  schedulePlaybackResume,
} from "../../lib/audioroom/sound-effects";

export default class AudioroomWebrtcService extends Service {
  @service currentUser;
  @service siteSettings;
  @service("audioroom-rooms") audioroomRooms;
  @service toasts;
  @service dialog;

  @tracked audioEnabled = true;
  @tracked deafened = false;
  @tracked idleState = "active";
  @tracked pttEnabled = false;
  @tracked pttKey = "Space";
  @tracked pttActive = false;
  @tracked connectionRevision = 0;
  // Noise suppression is handled natively by LiveKit via audioCaptureDefaults.
  // Kept as a tracked stub so UI components don't error.
  @tracked noiseSuppressionEnabled = true;
  @tracked autoStatusEnabled = true;
  @tracked pinnedSpeakerId = null;

  #activeRoomIds = new Set();
  #livekitRooms = new Map(); // roomId -> LiveKit.Room instance
  #heartbeatTimers = new Map();
  #heartbeatInFlight = new Set();
  #audioElements = new Map(); // `${roomId}:${participantIdentity}` -> <audio>
  #participantVolumes = new Map(); // userId -> 0-1
  #participantMuted = new Map(); // userId -> bool
  #pttManager;
  #idleTracker;
  #speakerDebounceTimer = null;

  constructor() {
    super(...arguments);

    this.#pttManager = new PttManager({
      onPress: () => this.#handlePttPress(),
      onReleaseImmediate: () => this.#handlePttRelease(),
      onReleaseDebounced: () => this.#broadcastMuteState(),
      isConnected: () => this.#activeRoomIds.size > 0,
    });

    this.pttEnabled = this.#pttManager.enabled;
    this.pttKey = this.#pttManager.key;
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  async join(room) {
    if (this.#activeRoomIds.has(room.id)) {
      return;
    }

    schedulePlaybackResume();

    let response;
    try {
      response = await ajax(`/audioroom/rooms/${room.id}/join`, {
        type: "POST",
        data: { skip_status: false },
      });
    } catch (e) {
      const json = e.jqXHR?.responseJSON;
      if (e.jqXHR?.status === 409 && json?.conflicting_room_id) {
        const conflictingRoomId = json.conflicting_room_id;
        const conflictingRoomName = json.conflicting_room_name || String(conflictingRoomId);
        this.dialog.confirm({
          message: i18n("audioroom.already_in_room_confirm", {
            room_name: conflictingRoomName,
          }),
          didConfirm: async () => {
            // If the conflicting room is actively connected in this client,
            // use the full leave() path which disconnects LiveKit, stops the
            // heartbeat, and clears all local state before calling the API.
            if (this.#activeRoomIds.has(conflictingRoomId)) {
              await this.leave({ id: conflictingRoomId });
            } else {
              // Stale Redis entry from a crash or another session — just clean
              // up server-side. No local LiveKit connection to tear down.
              await ajax(`/audioroom/rooms/${conflictingRoomId}/leave`, { type: "DELETE" }).catch(() => {});
            }
            await this.join(room);
          },
        });
        return;
      }
      this.toasts?.error({ data: { message: json?.errors?.[0] || "Failed to join room" } });
      return;
    }

    const { livekit_token, livekit_url } = response;

    if (!livekit_token || !livekit_url) {
      this.toasts?.error({ data: { message: "LiveKit is not configured on this server." } });
      return;
    }

    const lkRoom = await this.#createLiveKitRoom(room.id, livekit_url, livekit_token);
    if (!lkRoom) {
      return;
    }

    this.#livekitRooms.set(room.id, lkRoom);
    this.#activeRoomIds.add(room.id);
    this.connectionRevision++;

    this.#startHeartbeat(room.id);
    this.#ensureIdleTracker();

    playConnectedSound();
  }

  async leave(room, options = {}) {
    if (!this.#activeRoomIds.has(room.id)) {
      return;
    }

    this.#stopHeartbeat(room.id);
    this.#activeRoomIds.delete(room.id);

    const lkRoom = this.#livekitRooms.get(room.id);
    if (lkRoom) {
      lkRoom.removeAllListeners();
      await lkRoom.disconnect();
      this.#livekitRooms.delete(room.id);
    }

    this.#cleanupAudioElementsForRoom(room.id);

    if (this.#activeRoomIds.size === 0) {
      this.#idleTracker?.stop();
      this.#idleTracker = null;
    }

    this.connectionRevision++;

    if (!options.skipApi) {
      await ajax(`/audioroom/rooms/${room.id}/leave`, { type: "DELETE" }).catch(() => { });
    }

    playDisconnectedSound();
  }

  // Called when the current user is promoted from listener to speaker/moderator
  // in a stage room. Enables their mic (LiveKit permissions already updated
  // server-side via update_participant_permissions) and shows a toast.
  onPromotedToSpeaker(room) {
    if (!this.#activeRoomIds.has(room.id)) {
      return;
    }

    if (!this.pttEnabled) {
      this.audioEnabled = true;
      this.#setMicEnabled(true);
    }

    this.toasts?.success({
      data: { message: i18n("audioroom.stage.promoted_to_speaker") },
      duration: 4000,
    });
  }

  toggleMute() {
    if (this.pttEnabled) {
      return;
    }

    const newEnabled = !this.audioEnabled;
    this.audioEnabled = newEnabled;
    this.#setMicEnabled(newEnabled);
    this.#broadcastMuteState();

    if (newEnabled) {
      playUnmuteSound();
    } else {
      playMuteSound();
    }
  }

  toggleDeafen() {
    this.deafened = !this.deafened;
    this.#audioElements.forEach((el) => {
      el.muted = this.deafened;
    });

    if (this.deafened) {
      playDeafenSound();
    } else {
      playUndeafenSound();
    }
  }

  enablePtt() {
    this.#pttManager.enable();
    this.pttEnabled = true;
    // mute mic immediately when PTT mode is turned on
    this.audioEnabled = false;
    this.#setMicEnabled(false);
  }

  disablePtt() {
    this.#pttManager.disable();
    this.pttEnabled = false;
    this.audioEnabled = true;
    this.#setMicEnabled(true);
  }

  // Noise suppression is always on via LiveKit's audioCaptureDefaults.
  // This method is a no-op stub for UI compatibility.
  async toggleNoiseSuppression() {
    // no-op — LiveKit handles noise suppression internally
  }

  toggleAutoStatus() {
    this.autoStatusEnabled = !this.autoStatusEnabled;
  }

  setPttKey(code) {
    this.#pttManager.setKey(code);
    this.pttKey = code;
  }

  getParticipantVolume(_roomId, userId) {
    return this.#participantVolumes.get(userId) ?? 1;
  }

  isParticipantMuted(_roomId, userId) {
    return this.#participantMuted.get(userId) ?? false;
  }

  setParticipantVolume(_roomId, userId, volume) {
    this.#participantVolumes.set(userId, volume);
    const key = this.#audioKeyForUser(userId);
    if (key) {
      const el = this.#audioElements.get(key);
      if (el) {
        el.volume = volume;
      }
    }
  }

  async toggleParticipantMute(roomId, userId) {
    const current = this.#participantMuted.get(userId) ?? false;
    const next = !current;

    // Optimistically update local audio element so the moderator hears the change immediately
    this.#participantMuted.set(userId, next);
    const key = this.#audioKeyForUser(userId);
    if (key) {
      const el = this.#audioElements.get(key);
      if (el) el.muted = next || this.deafened;
    }

    // Server-side mute via LiveKit API — fires real TrackMuted/TrackUnmuted events
    // to all participants including the muted person and the broadcast page
    try {
      await ajax(`/audioroom/rooms/${roomId}/mute_participant`, {
        type: "POST",
        data: { user_id: userId, muted: next },
      });
    } catch (_e) {
      // Roll back optimistic update on failure
      this.#participantMuted.set(userId, current);
      if (key) {
        const el = this.#audioElements.get(key);
        if (el) el.muted = current || this.deafened;
      }
    }

    return next;
  }

  connectionStateFor(roomId) {
    const lkRoom = this.#livekitRooms.get(roomId);
    if (!lkRoom) {
      return "idle";
    }
    const state = lkRoom.state;
    if (state === "connected") {
      return "connected";
    }
    if (state === "connecting" || state === "reconnecting") {
      return "connecting";
    }
    return "idle";
  }

  get activeRoomIds() {
    return [...this.#activeRoomIds];
  }

  async pinSpeaker(roomId, userId) {
    const lkRoom = this.#livekitRooms.get(roomId);
    if (!lkRoom) return;

    const msg = JSON.stringify({ type: "pin_speaker", userId: userId || null });
    await lkRoom.localParticipant.publishData(
      new TextEncoder().encode(msg),
      { reliable: true }
    );
    this.pinnedSpeakerId = userId ? String(userId) : null;
  }

  async unpinSpeaker(roomId) {
    return this.pinSpeaker(roomId, null);
  }

  // ─── LiveKit Room Setup ─────────────────────────────────────────────────────

  async #createLiveKitRoom(roomId, livekitUrl, token) {
    // LiveKit client SDK is loaded as a vendored script — access via window.LivekitClient
    const LivekitClient = window.LivekitClient;
    if (!LivekitClient) {
      this.toasts?.error({ data: { message: "LiveKit client SDK not loaded." } });
      return null;
    }

    const { Room, RoomEvent, ParticipantEvent } = LivekitClient;

    const lkRoom = new Room({
      adaptiveStream: true,
      dynacast: true,
      audioCaptureDefaults: {
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: false,
      },
      publishDefaults: {
        audioPreset: {
          maxBitrate: 128000,
        },
        dtx: false,
      },
    });

    lkRoom.on(RoomEvent.ParticipantConnected, (participant) => {
      this.#onParticipantConnected(roomId, participant);
    });

    lkRoom.on(RoomEvent.ParticipantDisconnected, (participant) => {
      this.#onParticipantDisconnected(roomId, participant);
    });

    lkRoom.on(RoomEvent.TrackSubscribed, (track, _pub, participant) => {
      this.#onTrackSubscribed(roomId, track, participant);
    });

    lkRoom.on(RoomEvent.TrackUnsubscribed, (track, _pub, participant) => {
      this.#onTrackUnsubscribed(roomId, track, participant);
    });

    lkRoom.on(RoomEvent.ActiveSpeakersChanged, (speakers) => {
      this.#onActiveSpeakersChanged(roomId, speakers);
    });

    lkRoom.on(RoomEvent.Disconnected, () => {
      this.#onRoomDisconnected(roomId);
    });

    lkRoom.on(RoomEvent.Reconnecting, () => {
      schedule("afterRender", () => {
        if (!this.isDestroyed && !this.isDestroying) {
          this.connectionRevision++;
        }
      });
    });

    lkRoom.on(RoomEvent.Reconnected, () => {
      schedule("afterRender", () => {
        if (!this.isDestroyed && !this.isDestroying) {
          this.connectionRevision++;
        }
      });
    });

    lkRoom.localParticipant.on(
      ParticipantEvent.ParticipantPermissionsChanged,
      async (prevPermissions) => {
        const canPublish = lkRoom.localParticipant.permissions?.canPublish;
        if (canPublish && !prevPermissions?.canPublish) {
          // Just got promoted to speaker — enable mic
          await lkRoom.localParticipant.setMicrophoneEnabled(
            !this.pttEnabled
          );
        }
      }
    );

    try {
      await lkRoom.connect(livekitUrl, token, {
        autoSubscribe: true,
      });

      // Only publish mic if the token grants canPublish (speakers/mods).
      // Stage room listeners have canPublish: false and must not attempt to publish.
      if (lkRoom.localParticipant.permissions?.canPublish) {
        await lkRoom.localParticipant.setMicrophoneEnabled(this.audioEnabled && !this.pttEnabled);
      }

      // Optimistically add current user to the participant list
      this.audioroomRooms?.addParticipant(roomId, {
        id: this.currentUser.id,
        username: this.currentUser.username,
        name: this.currentUser.name,
        avatar_template: this.currentUser.avatar_template,
        is_speaking: false,
        is_muted: !this.audioEnabled || this.pttEnabled,
        is_deafened: false,
        role: "listener",
      });

      return lkRoom;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[Audioroom] LiveKit connect failed:", e);
      this.toasts?.error({ data: { message: "Could not connect to voice server." } });
      return null;
    }
  }

  // ─── LiveKit Event Handlers ─────────────────────────────────────────────────

  #onParticipantConnected(roomId, participant) {
    playUserJoinedSound();
    this.audioroomRooms?.addParticipant(roomId, {
      id: Number(participant.identity),
      username: participant.name || participant.identity,
      name: participant.name || participant.identity,
      avatar_template: null,
      is_speaking: false,
    });
    schedule("afterRender", () => {
      if (!this.isDestroyed && !this.isDestroying) {
        this.connectionRevision++;
      }
    });
  }

  #onParticipantDisconnected(roomId, participant) {
    playUserLeftSound();
    this.audioroomRooms?.removeParticipant(roomId, Number(participant.identity));
    const key = `${roomId}:${participant.identity}`;
    const el = this.#audioElements.get(key);
    if (el) {
      el.remove();
      this.#audioElements.delete(key);
    }
    schedule("afterRender", () => {
      if (!this.isDestroyed && !this.isDestroying) {
        this.connectionRevision++;
      }
    });
  }

  #onTrackSubscribed(roomId, track, participant) {
    const LivekitClient = window.LivekitClient;
    if (!LivekitClient || track.kind !== LivekitClient.Track.Kind.Audio) {
      return;
    }

    const key = `${roomId}:${participant.identity}`;
    const el = document.createElement("audio");
    el.autoplay = true;
    el.muted = this.deafened || (this.#participantMuted.get(Number(participant.identity)) ?? false);
    el.volume = this.#participantVolumes.get(Number(participant.identity)) ?? 1;

    track.attach(el);
    this.#audioElements.set(key, el);

    const canvas = document.getElementById("audioroom-voice-canvas");
    if (canvas) {
      canvas.appendChild(el);
    } else {
      document.body.appendChild(el);
    }
  }

  #onTrackUnsubscribed(roomId, track, participant) {
    track.detach();
    const key = `${roomId}:${participant.identity}`;
    const el = this.#audioElements.get(key);
    if (el) {
      el.remove();
      this.#audioElements.delete(key);
    }
  }

  #onActiveSpeakersChanged(roomId, speakers) {
    const speakingUserIds = new Set(
      speakers.map((s) => Number(s.identity)).filter(Boolean)
    );

    if (this.#speakerDebounceTimer) {
      clearTimeout(this.#speakerDebounceTimer);
    }

    this.#speakerDebounceTimer = setTimeout(() => {
      schedule("afterRender", () => {
        if (!this.isDestroyed && !this.isDestroying) {
          this.audioroomRooms?.updateSpeakingState(roomId, speakingUserIds);
        }
      });
    }, 400);
  }

  #onRoomDisconnected(roomId) {
    this.#activeRoomIds.delete(roomId);
    this.#livekitRooms.delete(roomId);
    this.#cleanupAudioElementsForRoom(roomId);
    this.#stopHeartbeat(roomId);

    // Defer tracked update to avoid Glimmer re-render on a torn-down component
    schedule("afterRender", () => {
      if (!this.isDestroyed && !this.isDestroying) {
        this.connectionRevision++;
      }
    });

    // Notify Discourse presence
    ajax(`/audioroom/rooms/${roomId}/leave`, { type: "DELETE" }).catch(() => { });
  }

  // ─── Mic / Mute Helpers ─────────────────────────────────────────────────────

  #setMicEnabled(enabled) {
    this.#livekitRooms.forEach((lkRoom) => {
      if (!lkRoom.localParticipant.permissions?.canPublish) {
        return;
      }
      lkRoom.localParticipant.setMicrophoneEnabled(enabled).catch(() => { });
    });
  }

  #handlePttPress() {
    this.pttActive = true;
    this.audioEnabled = true;
    this.#setMicEnabled(true);
  }

  #handlePttRelease() {
    this.pttActive = false;
    this.audioEnabled = false;
    this.#setMicEnabled(false);
  }

  async #broadcastMuteState() {
    for (const [roomId] of this.#livekitRooms) {
      try {
        await ajax(`/audioroom/rooms/${roomId}/toggle_mute`, {
          type: "POST",
          data: { muted: !this.audioEnabled },
        });
      } catch (_e) {
        // non-critical
      }
    }
  }

  // ─── Heartbeat ──────────────────────────────────────────────────────────────

  #startHeartbeat(roomId) {
    const timer = setInterval(async () => {
      if (this.#heartbeatInFlight.has(roomId)) {
        return;
      }
      this.#heartbeatInFlight.add(roomId);
      try {
        await ajax(`/audioroom/rooms/${roomId}/heartbeat`, {
          type: "POST",
          data: {
            idle_state: this.idleState,
            skip_status: !this.autoStatusEnabled || undefined,
          },
        });
      } catch (_e) {
        // non-critical
      } finally {
        this.#heartbeatInFlight.delete(roomId);
      }
    }, 10_000);

    this.#heartbeatTimers.set(roomId, timer);
  }

  #stopHeartbeat(roomId) {
    clearInterval(this.#heartbeatTimers.get(roomId));
    this.#heartbeatTimers.delete(roomId);
    this.#heartbeatInFlight.delete(roomId);
  }

  // ─── Idle Tracker ───────────────────────────────────────────────────────────

  #ensureIdleTracker() {
    if (this.#idleTracker) {
      return;
    }

    const idleMs =
      (this.siteSettings.audioroom_idle_threshold_minutes || 0) * 60 * 1000;
    const afkMs =
      (this.siteSettings.audioroom_afk_auto_mute_threshold_minutes || 0) *
      60 *
      1000;
    const disconnectMs =
      (this.siteSettings.audioroom_afk_disconnect_threshold_minutes || 0) *
      60 *
      1000;

    this.#idleTracker = new IdleTracker({
      getThresholds: () => ({ idleMs, afkMs, disconnectMs }),
      onIdleStateChange: (state) => {
        this.idleState = state;
        if (state === "idle" || state === "afk") {
          if (!this.pttEnabled && this.audioEnabled) {
            this.audioEnabled = false;
            this.#setMicEnabled(false);
          }
        }
      },
      onAutoMute: () => {
        if (!this.pttEnabled && this.audioEnabled) {
          this.audioEnabled = false;
          this.#setMicEnabled(false);
        }
      },
      onDisconnect: () => {
        this.#activeRoomIds.forEach((roomId) => {
          const room = this.audioroomRooms?.roomById(roomId);
          if (room) {
            this.leave(room);
          }
        });
      },
    });

    this.#idleTracker.start();
  }

  // ─── Cleanup ────────────────────────────────────────────────────────────────

  #cleanupAudioElementsForRoom(roomId) {
    const prefix = `${roomId}:`;
    for (const [key, el] of this.#audioElements) {
      if (key.startsWith(prefix)) {
        el.remove();
        this.#audioElements.delete(key);
      }
    }
  }

  #audioKeyForUser(userId) {
    const identity = String(userId);
    for (const key of this.#audioElements.keys()) {
      if (key.endsWith(`:${identity}`)) {
        return key;
      }
    }
    return null;
  }
}
