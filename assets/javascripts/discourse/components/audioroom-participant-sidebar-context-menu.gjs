import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { humanKeyName } from "../lib/audioroom/ptt-utils";
import AudioroomPttKeyCapture from "./audioroom-ptt-key-capture";

export default class AudioroomParticipantSidebarContextMenu extends Component {
  @service audioroomWebrtc;
  @service siteSettings;
  @service dialog;
  @service currentUser;

  @tracked volume = 100;
  @tracked isMuted = false;
  @tracked showKeyCapture = false;
  @tracked handRaised = false;

  constructor() {
    super(...arguments);
    const { room, participant } = this.args.data;
    this.volume = Math.round(
      this.audioroomWebrtc.getParticipantVolume(room.id, participant.id) * 100
    );
    this.isMuted = this.audioroomWebrtc.isParticipantMuted(
      room.id,
      participant.id
    );
    this.handRaised = !!participant.hand_raised;
  }

  get room() {
    return this.args.data.room;
  }

  get participant() {
    return this.args.data.participant;
  }

  get isCurrentUser() {
    return this.args.data.isCurrentUser;
  }

  get canManageRoom() {
    return this.args.data.canManageRoom;
  }

  // True if the current user has room management rights — either via room membership
  // (can_manage) or as a Discourse admin, who has full moderation access to all rooms.
  get isRoomModerator() {
    return this.canManageRoom || !!this.currentUser?.admin;
  }

  get isHardMuted() {
    return !!this.participant.hard_muted;
  }

  get canKick() {
    return this.isRoomModerator && this.participant.id !== this.room.creator_id;
  }

  get canBan() {
    return this.isRoomModerator && this.participant.id !== this.room.creator_id;
  }

  get canHardMute() {
    return (
      this.isRoomModerator &&
      !this.isStageRoom &&
      this.participant.role !== "moderator"
    );
  }

  get canForceMute() {
    return this.isRoomModerator && this.participant.role !== "moderator";
  }

  get isStageRoom() {
    return this.room.room_type === "stage";
  }

  get isListenerInStage() {
    if (!this.isStageRoom || !this.isCurrentUser) {
      return false;
    }
    const role = this.participant.role;
    return role !== "moderator" && role !== "speaker";
  }

  get participantIsSpeakerOrMod() {
    const role = this.participant.role;
    return role === "moderator" || role === "speaker";
  }

  get hasRaisedHand() {
    return !!this.participant.hand_raised;
  }

  get canInviteToSpeak() {
    return (
      this.isRoomModerator &&
      this.isStageRoom &&
      !this.isCurrentUser &&
      !this.participantIsSpeakerOrMod &&
      this.hasRaisedHand
    );
  }

  get canPromoteToSpeaker() {
    return (
      this.isRoomModerator &&
      this.isStageRoom &&
      !this.isCurrentUser &&
      !this.participantIsSpeakerOrMod
    );
  }

  get canDemoteToListener() {
    return (
      this.isRoomModerator &&
      this.isStageRoom &&
      !this.isCurrentUser &&
      this.participant.role === "speaker"
    );
  }

  get canPin() {
    return this.isRoomModerator && !this.isCurrentUser;
  }

  get isPinned() {
    return this.audioroomWebrtc.pinnedSpeakerId === String(this.participant.id);
  }

  get muteLabel() {
    return this.isMuted
      ? i18n("audioroom.participant.unmute")
      : i18n("audioroom.participant.mute");
  }

  get muteIcon() {
    return this.isMuted ? "volume-xmark" : "volume-high";
  }

  get micIcon() {
    return this.audioroomWebrtc.audioEnabled ? "microphone" : "microphone-slash";
  }

  get micLabel() {
    return this.audioroomWebrtc.audioEnabled
      ? i18n("audioroom.room.mic_on")
      : i18n("audioroom.room.mic_off");
  }

  get deafenIcon() {
    return this.audioroomWebrtc.deafened ? "volume-xmark" : "volume-high";
  }

  get deafenLabel() {
    return this.audioroomWebrtc.deafened
      ? i18n("audioroom.room.deafen_off")
      : i18n("audioroom.room.deafen_on");
  }

  get isPttEnabled() {
    return this.audioroomWebrtc.pttEnabled;
  }

  get pttToggleLabel() {
    return this.isPttEnabled
      ? i18n("audioroom.ptt.disable")
      : i18n("audioroom.ptt.enable");
  }

  get pttKeyLabel() {
    return i18n("audioroom.ptt.configure_key", {
      key: humanKeyName(this.audioroomWebrtc.pttKey),
    });
  }

  get micDisabledByPtt() {
    return this.isCurrentUser && this.isPttEnabled;
  }

  get showNoiseSuppressionToggle() {
    return this.isCurrentUser && this.siteSettings.audioroom_noise_suppression;
  }

  get showAutoStatusToggle() {
    return this.isCurrentUser && this.siteSettings.audioroom_auto_status_enabled;
  }

  get autoStatusLabel() {
    return this.audioroomWebrtc.autoStatusEnabled
      ? i18n("audioroom.status.auto_update_on")
      : i18n("audioroom.status.auto_update_off");
  }

  get noiseSuppressionIcon() {
    return this.audioroomWebrtc.noiseSuppressionEnabled
      ? "ear-listen"
      : "volume-high";
  }

  get noiseSuppressionLabel() {
    return this.audioroomWebrtc.noiseSuppressionEnabled
      ? "audioroom.room.noise_suppression_on"
      : "audioroom.room.noise_suppression_off";
  }

  @action
  onVolumeChange(event) {
    this.volume = parseInt(event.target.value, 10);
    this.audioroomWebrtc.setParticipantVolume(
      this.room.id,
      this.participant.id,
      this.volume / 100
    );
  }

  @action
  async toggleMute() {
    this.isMuted = await this.audioroomWebrtc.toggleParticipantMute(
      this.room.id,
      this.participant.id
    );
  }

  @action
  async kick() {
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/kick`, {
        type: "DELETE",
        data: { user_id: this.participant.id },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async hardMute() {
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/hard_mute`, {
        type: "POST",
        data: { user_id: this.participant.id },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async hardUnmute() {
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/hard_unmute`, {
        type: "POST",
        data: { user_id: this.participant.id },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  banParticipant() {
    this.dialog.confirm({
      message: i18n("audioroom.participant.ban_confirm", {
        username: this.participant.username,
      }),
      didConfirm: async () => {
        try {
          await ajax(`/audioroom/rooms/${this.room.id}/ban`, {
            type: "POST",
            data: { user_id: this.participant.id },
          });
          this.args.close();
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  toggleMic() {
    this.audioroomWebrtc.toggleMute();
  }

  @action
  toggleDeafen() {
    this.audioroomWebrtc.toggleDeafen();
  }

  @action
  async toggleNoiseSuppression() {
    await this.audioroomWebrtc.toggleNoiseSuppression();
  }

  @action
  toggleAutoStatus() {
    this.audioroomWebrtc.toggleAutoStatus();
  }

  @action
  togglePtt() {
    if (this.isPttEnabled) {
      this.audioroomWebrtc.disablePtt();
    } else {
      this.audioroomWebrtc.enablePtt();
    }
  }

  @action
  openKeyCapture() {
    this.showKeyCapture = true;
  }

  @action
  onKeyCaptureConfirm(keyCode) {
    this.audioroomWebrtc.setPttKey(keyCode);
    this.showKeyCapture = false;
  }

  @action
  onKeyCaptureCancel() {
    this.showKeyCapture = false;
  }

  @action
  async togglePin() {
    if (this.isPinned) {
      await this.audioroomWebrtc.unpinSpeaker(this.room.id);
    } else {
      await this.audioroomWebrtc.pinSpeaker(this.room.id, this.participant.id);
    }
    this.args.close();
  }

  @action
  leaveRoom() {
    this.audioroomWebrtc.leave(this.room);
    this.args.close();
  }

  @action
  async raiseHand() {
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/raise_hand`, {
        type: "POST",
      });
      this.handRaised = true;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async lowerHand() {
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/raise_hand`, {
        type: "DELETE",
      });
      this.handRaised = false;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async inviteToSpeak() {
    await this.#changeParticipantRole("speaker");
  }

  @action
  async promoteToSpeaker() {
    await this.#changeParticipantRole("speaker");
  }

  @action
  async demoteToListener() {
    await this.#changeParticipantRole("participant");
  }

  async #changeParticipantRole(newRole) {
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/memberships`, {
        type: "POST",
        data: { user_id: this.participant.id, role: newRole },
      });
      this.args.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DropdownMenu
      class="audioroom-participant-sidebar-context-menu"
      as |dropdown|
    >
      {{#if this.isCurrentUser}}
        {{#unless this.isListenerInStage}}
          <dropdown.item>
            <DButton
              @action={{this.toggleMic}}
              @icon={{this.micIcon}}
              @translatedLabel={{this.micLabel}}
              @translatedTitle={{if
                this.micDisabledByPtt
                (i18n "audioroom.ptt.controlled_by_ptt")
                this.micLabel
              }}
              @disabled={{this.micDisabledByPtt}}
              class="audioroom-participant-sidebar-context-menu__mic-btn
                {{if this.micDisabledByPtt '--disabled-by-ptt'}}"
            />
            {{#if this.micDisabledByPtt}}
              <span
                class="audioroom-participant-sidebar-context-menu__ptt-hint"
              >{{i18n "audioroom.ptt.controlled_by_ptt"}}</span>
            {{/if}}
          </dropdown.item>
        {{/unless}}
        <dropdown.item>
          <DButton
            @action={{this.toggleDeafen}}
            @icon={{this.deafenIcon}}
            @translatedLabel={{this.deafenLabel}}
            @translatedTitle={{this.deafenLabel}}
            class="audioroom-participant-sidebar-context-menu__deafen-btn"
          />
        </dropdown.item>
        {{#unless this.isListenerInStage}}
          {{#if this.showNoiseSuppressionToggle}}
            <dropdown.item>
              <DButton
                @action={{this.toggleNoiseSuppression}}
                @icon={{this.noiseSuppressionIcon}}
                @label={{this.noiseSuppressionLabel}}
                @title={{this.noiseSuppressionLabel}}
                class="audioroom-participant-sidebar-context-menu__noise-suppression"
              />
            </dropdown.item>
          {{/if}}
          <dropdown.item>
            <DButton
              @action={{this.togglePtt}}
              @icon={{if this.isPttEnabled "walkie-talkie" "walkie-talkie"}}
              @translatedLabel={{this.pttToggleLabel}}
              @translatedTitle={{this.pttToggleLabel}}
              class="audioroom-participant-sidebar-context-menu__ptt-btn
                {{if this.isPttEnabled '--active'}}"
            />
          </dropdown.item>
          {{#if this.isPttEnabled}}
            <dropdown.item>
              {{#if this.showKeyCapture}}
                <AudioroomPttKeyCapture
                  @onConfirm={{this.onKeyCaptureConfirm}}
                  @onCancel={{this.onKeyCaptureCancel}}
                />
              {{else}}
                <DButton
                  @action={{this.openKeyCapture}}
                  @icon="keyboard"
                  @translatedLabel={{this.pttKeyLabel}}
                  @translatedTitle={{this.pttKeyLabel}}
                  class="audioroom-participant-sidebar-context-menu__ptt-key-btn"
                />
              {{/if}}
            </dropdown.item>
          {{/if}}
        {{/unless}}
        {{#if this.showAutoStatusToggle}}
          <dropdown.item>
            <DButton
              @action={{this.toggleAutoStatus}}
              @icon={{if
                this.audioroomWebrtc.autoStatusEnabled
                "square-check"
                "far-square"
              }}
              @translatedLabel={{this.autoStatusLabel}}
              @translatedTitle={{this.autoStatusLabel}}
              class="audioroom-participant-sidebar-context-menu__auto-status-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.isListenerInStage}}
          <dropdown.item>
            <span
              class="audioroom-participant-sidebar-context-menu__stage-hint"
            >{{i18n "audioroom.room.listeners_cannot_unmute"}}</span>
          </dropdown.item>
          <dropdown.item>
            <DButton
              @action={{if this.handRaised this.lowerHand this.raiseHand}}
              @icon={{if this.handRaised "hand" "hand"}}
              @translatedLabel={{if
                this.handRaised
                (i18n "audioroom.stage.lower_hand")
                (i18n "audioroom.stage.raise_hand")
              }}
              class="audioroom-participant-sidebar-context-menu__raise-hand-btn
                {{if this.handRaised '--active'}}"
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              @action={{this.leaveRoom}}
              @icon="phone-slash"
              @label="audioroom.room.leave"
              @title="audioroom.room.leave"
              class="audioroom-participant-sidebar-context-menu__leave-btn --danger"
            />
          </dropdown.item>
        {{/if}}
      {{else}}
        {{! Volume slider — client-side only, always visible for other participants }}
        <dropdown.item
          class="audioroom-participant-sidebar-context-menu__volume"
        >
          <label
            class="audioroom-participant-sidebar-context-menu__volume-label"
          >
            {{i18n "audioroom.participant.volume"}}
          </label>
          <input
            type="range"
            min="0"
            max="100"
            value={{this.volume}}
            class="audioroom-participant-sidebar-context-menu__volume-slider"
            {{on "input" this.onVolumeChange}}
          />
        </dropdown.item>
        {{! Force-mute — server-side via mute_participant; only for managers and never on moderators }}
        {{#if this.canForceMute}}
          <dropdown.item>
            <DButton
              @action={{this.toggleMute}}
              @icon={{this.muteIcon}}
              @translatedLabel={{this.muteLabel}}
              @translatedTitle={{this.muteLabel}}
              class="audioroom-participant-sidebar-context-menu__mute-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canInviteToSpeak}}
          <dropdown.item>
            <DButton
              @action={{this.inviteToSpeak}}
              @icon="hand"
              @label="audioroom.stage.invite_to_speak"
              @title="audioroom.stage.invite_to_speak"
              class="audioroom-participant-sidebar-context-menu__invite-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canPromoteToSpeaker}}
          <dropdown.item>
            <DButton
              @action={{this.promoteToSpeaker}}
              @icon="microphone"
              @label="audioroom.stage.make_speaker"
              @title="audioroom.stage.make_speaker"
              class="audioroom-participant-sidebar-context-menu__promote-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canDemoteToListener}}
          <dropdown.item>
            <DButton
              @action={{this.demoteToListener}}
              @icon="volume-xmark"
              @label="audioroom.stage.move_to_listeners"
              @title="audioroom.stage.move_to_listeners"
              class="audioroom-participant-sidebar-context-menu__demote-btn"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canPin}}
          <dropdown.item>
            <DButton
              @action={{this.togglePin}}
              @icon="thumbtack"
              @translatedLabel={{if this.isPinned (i18n "audioroom.participant.unpin") (i18n "audioroom.participant.pin")}}
              @translatedTitle={{if this.isPinned (i18n "audioroom.participant.unpin") (i18n "audioroom.participant.pin")}}
              class="audioroom-participant-sidebar-context-menu__pin-btn
                {{if this.isPinned '--active'}}"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canHardMute}}
          {{#if this.isHardMuted}}
            <dropdown.item>
              <DButton
                @action={{this.hardUnmute}}
                @icon="microphone"
                @label="audioroom.participant.hard_unmute"
                @title="audioroom.participant.hard_unmute"
                class="audioroom-participant-sidebar-context-menu__hard-unmute-btn"
              />
            </dropdown.item>
          {{else}}
            <dropdown.item>
              <DButton
                @action={{this.hardMute}}
                @icon="microphone-slash"
                @label="audioroom.participant.hard_mute"
                @title="audioroom.participant.hard_mute"
                class="audioroom-participant-sidebar-context-menu__hard-mute-btn"
              />
            </dropdown.item>
          {{/if}}
        {{/if}}
        {{#if this.canKick}}
          <dropdown.item>
            <DButton
              @action={{this.kick}}
              @icon="right-from-bracket"
              @label="audioroom.participant.kick"
              @title="audioroom.participant.kick"
              class="audioroom-participant-sidebar-context-menu__kick-btn btn-danger"
            />
          </dropdown.item>
        {{/if}}
        {{#if this.canBan}}
          <dropdown.item>
            <DButton
              @action={{this.banParticipant}}
              @icon="ban"
              @label="audioroom.participant.ban"
              @title="audioroom.participant.ban"
              class="audioroom-participant-sidebar-context-menu__ban-btn btn-danger"
            />
          </dropdown.item>
        {{/if}}
      {{/if}}
    </DropdownMenu>
  </template>
}
