(function () {
  "use strict";

  var config = document.getElementById("broadcast-config");
  var params = new URLSearchParams(window.location.search);
  var LIVEKIT_URL = params.get("url") || config.getAttribute("data-livekit-url");
  var LIVEKIT_TOKEN = params.get("token") || config.getAttribute("data-livekit-token");
  var LAYOUT = params.get("layout") || config.getAttribute("data-layout");
  var BACKGROUND = params.get("background") || config.getAttribute("data-background");
  var WATERMARK = config.getAttribute("data-watermark") !== "false";
  var ROOM_TYPE = config.getAttribute("data-room-type") || "open";

  var participants = new Map();
  var activeSpeakerId = null;
  var speakingClearTimer = null;
  var pinnedSpeakerId = null;

  function avatarUrl(template) {
    if (!template) return null;
    return template.replace("{size}", "288");
  }

  function initials(name) {
    return (name || "?").substring(0, 2).toUpperCase();
  }

  function participantData(participant) {
    var meta = null;
    try {
      if (participant.metadata) {
        meta = JSON.parse(participant.metadata);
      }
    } catch (_e) {}
    var fallback = participant.name || participant.identity;
    var role = (meta && meta.role) || "participant";
    return {
      username: (meta && meta.username) || fallback,
      name: (meta && meta.name) || fallback,
      avatar_template: (meta && meta.avatar_template) || null,
      role: role,
      speaking: false,
      muted: !!participant.isMuted,
    };
  }

  function makeTile(identity, large) {
    var p = participants.get(identity) || {};
    var speaking = p.speaking ? " speaking" : "";

    var avatarHtml = p.avatar_template
      ? '<img class="avatar" src="' + avatarUrl(p.avatar_template) + '" alt="' + (p.username || "") + '">'
      : '<div class="avatar-placeholder">' + initials(p.username) + "</div>";

    var displayName = "@" + (p.username || identity);

    if (large) {
      var micBadgeHtml =
        '<div class="mic-badge' + (p.muted ? " muted" : "") + '">' +
          (p.muted
            ? '<img src="/plugins/audioroom/images/muted.svg" width="20" height="20">'
            : '<img src="/plugins/audioroom/images/speaking.svg" width="20" height="20">'
          ) +
        "</div>";
      return (
        '<div class="tile main-tile' + speaking + '" data-identity="' + identity + '">' +
          micBadgeHtml +
          avatarHtml +
          '<div class="username">' + displayName + "</div>" +
          '<div class="waveform">' +
            '<div class="waveform-bar"></div>' +
            '<div class="waveform-bar"></div>' +
            '<div class="waveform-bar"></div>' +
            '<div class="waveform-bar"></div>' +
            '<div class="waveform-bar"></div>' +
          "</div>" +
        "</div>"
      );
    } else {
      var mutedClass = p.muted ? " muted" : "";
      var micBadgeSmHtml = p.muted
        ? '<div class="mic-badge-sm"><img src="/plugins/audioroom/images/muted.svg" width="20" height="20"></div>'
        : '<div class="mic-badge-sm"><img src="/plugins/audioroom/images/speaking.svg" width="20" height="20"></div>';
      return (
        '<div class="tile small-tile' + speaking + mutedClass + '" data-identity="' + identity + '">' +
          micBadgeSmHtml +
          avatarHtml +
          '<div class="username">' + displayName + "</div>" +
        "</div>"
      );
    }
  }

  function isSpeaker(p) {
    if (ROOM_TYPE === "stage") {
      return p.role === "moderator" || p.role === "speaker";
    }
    // Open room — everyone with publish permission is a speaker
    return p.role === "moderator" || p.role === "speaker" || p.role === "participant";
  }

  function speakerIds() {
    var ids = [];
    participants.forEach(function (p, id) {
      if (isSpeaker(p)) ids.push(id);
    });
    return ids;
  }

  function listenerCount() {
    var count = 0;
    participants.forEach(function (p) {
      if (p.role === "listener") count++;
    });
    return count;
  }

  function renderSpeaker() {
    var ids = speakerIds();
    if (ids.length === 0) {
      document.getElementById("empty-state").style.display = "flex";
      document.getElementById("participants-speaker").style.display = "none";
      return;
    }
    document.getElementById("empty-state").style.display = "none";
    document.getElementById("participants-speaker").style.display = "flex";

    // Active/pinned speaker must also be a speaker role
    var mainId =
      (pinnedSpeakerId && participants.has(pinnedSpeakerId) && isSpeaker(participants.get(pinnedSpeakerId)))
        ? pinnedSpeakerId
        : (activeSpeakerId && participants.has(activeSpeakerId) && isSpeaker(participants.get(activeSpeakerId)))
          ? activeSpeakerId
          : ids[0];
    var others = ids.filter(function (id) { return id !== mainId; });

    document.getElementById("speaker-main").innerHTML = makeTile(mainId, true);
    document.getElementById("speaker-row").innerHTML = others
      .map(function (id) { return makeTile(id, false); })
      .join("");
  }

  function renderGrid() {
    var ids = speakerIds();
    var grid = document.getElementById("participants-grid");

    if (ids.length === 0) {
      document.getElementById("empty-state").style.display = "flex";
      grid.style.display = "none";
      return;
    }
    document.getElementById("empty-state").style.display = "none";
    grid.style.display = "grid";

    var cols = Math.max(1, Math.ceil(Math.sqrt(ids.length)));
    grid.style.gridTemplateColumns = "repeat(" + cols + ", 1fr)";
    grid.innerHTML = ids
      .map(function (id) { return makeTile(id, false); })
      .join("");
  }

  function render() {
    if (LAYOUT === "grid") {
      renderGrid();
    } else {
      renderSpeaker();
    }
    var el = document.getElementById("listener-count");
    if (el) el.textContent = listenerCount();

    if (!window.__startSignalSent && participants.size > 0) {
      window.__startSignalSent = true;
      console.log("START_RECORDING");
    }
  }

  function loadLiveKit() {
    return new Promise(function (resolve, reject) {
      if (window.LivekitClient) {
        resolve();
        return;
      }
      var script = document.createElement("script");
      script.src = "/plugins/audioroom/javascripts/livekit-client.umd.js";
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  }

  function start() {
    loadLiveKit()
      .then(function () {
        console.log("[Broadcast] LiveKit loaded, connecting to", LIVEKIT_URL);
        var LK = window.LivekitClient;
        var room = new LK.Room({
          audioCaptureDefaults: { echoCancellation: false },
        });

        room.on(LK.RoomEvent.ParticipantConnected, function (participant) {
          participants.set(participant.identity, participantData(participant));
          render();
        });

        room.on(LK.RoomEvent.ParticipantDisconnected, function (participant) {
          participants.delete(participant.identity);
          if (activeSpeakerId === participant.identity) activeSpeakerId = null;
          render();
        });

        room.on(LK.RoomEvent.ActiveSpeakersChanged, function (speakers) {
          var newActiveSpeakerId = speakers.length > 0 ? speakers[0].identity : null;

          if (speakers.length > 0) {
            if (speakingClearTimer) {
              clearTimeout(speakingClearTimer);
              speakingClearTimer = null;
            }

            var speakerChanged = newActiveSpeakerId !== activeSpeakerId;
            activeSpeakerId = newActiveSpeakerId;

            participants.forEach(function (p) { p.speaking = false; });
            speakers.forEach(function (s) {
              if (participants.has(s.identity)) {
                participants.get(s.identity).speaking = true;
              }
            });

            if (speakerChanged) {
              render();
            } else {
              participants.forEach(function (p, identity) {
                var el = document.querySelector('[data-identity="' + identity + '"]');
                if (el) el.classList.toggle("speaking", !!p.speaking);
              });
            }
          } else {
            speakingClearTimer = setTimeout(function() {
              // Keep activeSpeakerId so the last speaker stays in the main tile.
              // Only clear the speaking visual state.
              participants.forEach(function (p) { p.speaking = false; });
              participants.forEach(function (_p, identity) {
                var el = document.querySelector('[data-identity="' + identity + '"]');
                if (el) el.classList.remove("speaking");
              });
              speakingClearTimer = null;
            }, 800);
          }
        });

        room.on(LK.RoomEvent.TrackMuted, function (_publication, participant) {
          var p = participants.get(participant.identity);
          if (p) { p.muted = true; render(); }
        });

        room.on(LK.RoomEvent.TrackUnmuted, function (_publication, participant) {
          var p = participants.get(participant.identity);
          if (p) { p.muted = false; render(); }
        });

        // Hard mute: moderator revokes canPublish via update_participant_permissions.
        // When publish permission is removed the participant can no longer send audio,
        // so mark them as muted in the broadcast view immediately.
        room.on(LK.RoomEvent.ParticipantPermissionsChanged, function (_prevPermissions, participant) {
          var p = participants.get(participant.identity);
          if (!p) return;
          var canPublish = participant.permissions && participant.permissions.canPublish;
          if (!canPublish) {
            p.muted = true;
          }
          // When canPublish is restored, leave muted state to TrackUnmuted to update —
          // the participant must physically unmute before their track goes live.
          render();
        });

        room.on(LK.RoomEvent.TrackSubscribed, function(track, _publication, _participant) {
          if (track.kind === "audio") {
            var el = document.createElement("audio");
            el.autoplay = true;
            el.muted = false;
            el.style.display = "none";
            track.mediaStream = track.mediaStream || new MediaStream([track.mediaStreamTrack]);
            el.srcObject = track.mediaStream;
            document.body.appendChild(el);
            el.play().catch(function() {});
          }
        });

        room.on(LK.RoomEvent.ParticipantMetadataChanged, function (_prevMetadata, participant) {
          var existing = participants.get(participant.identity);
          if (existing) {
            var updated = participantData(participant);
            updated.speaking = existing.speaking;
            updated.muted = existing.muted;
            participants.set(participant.identity, updated);
            render();
          }
        });

        room.on(LK.RoomEvent.DataReceived, function(data) {
          try {
            var msg = JSON.parse(new TextDecoder().decode(data));
            if (msg.type === "pin_speaker") {
              pinnedSpeakerId = msg.userId ? String(msg.userId) : null;
              render();
            } else if (msg.type === "mute_participant") {
              var identity = msg.userId ? String(msg.userId) : null;
              var p = identity && participants.get(identity);
              if (p) { p.muted = !!msg.muted; render(); }
            }
          } catch(_e) {}
        });

        room.on(LK.RoomEvent.Disconnected, function (reason) {
          console.log("[Broadcast] Disconnected:", reason);
        });

        room.on(LK.RoomEvent.ConnectionStateChanged, function (state) {
          console.log("[Broadcast] Connection state:", state);
        });

        room.on(LK.RoomEvent.Connected, function () {
          console.log("[Broadcast] Connected, remote participants:", room.remoteParticipants.size);
          room.remoteParticipants.forEach(function (p) {
            console.log("[Broadcast] existing participant:", p.identity, "metadata:", p.metadata);
          });
          var attempts = 0;
          var maxAttempts = 20; // 10 seconds max

          function tryLoad() {
            room.remoteParticipants.forEach(function (participant) {
              console.log("[Broadcast] metadata:", participant.identity, participant.metadata);
              participants.set(participant.identity, participantData(participant));
            });

            if (participants.size > 0 || attempts >= maxAttempts) {
              render();
              if (!window.__startSignalSent) {
                window.__startSignalSent = true;
                console.log("START_RECORDING");
              }
            } else {
              attempts++;
              setTimeout(tryLoad, 500);
            }
          }

          setTimeout(tryLoad, 500);
        });

        return room.connect(LIVEKIT_URL, LIVEKIT_TOKEN, { autoSubscribe: true });
      })
      .catch(function (e) {
        console.error("[Broadcast] failed:", e);
        var el = document.getElementById("empty-state");
        if (el) {
          el.textContent = "LiveKit client not loaded.";
          el.style.display = "flex";
        }
      });
  }

  // Apply background
  if (BACKGROUND && BACKGROUND !== "null" && BACKGROUND !== "") {
    if (BACKGROUND.startsWith("#") || BACKGROUND.startsWith("rgb")) {
      document.body.style.background = BACKGROUND;
    } else {
      document.body.style.background = "url('" + BACKGROUND + "') center/cover no-repeat";
    }
  }

  // Inject watermark
  if (WATERMARK) {
    var wm = document.createElement("div");
    wm.className = "broadcast-watermark";
    wm.innerHTML = 'Developed by <a href="https://dpnmw.com" target="_blank">dpnmw.com</a>';
    document.body.appendChild(wm);
  }

  start();
})();
