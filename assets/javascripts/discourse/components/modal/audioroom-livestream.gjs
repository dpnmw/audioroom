import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { and, eq, not, or } from "truth-helpers";
import { i18n } from "discourse-i18n";

export default class AudioroomLivestreamModal extends Component {
  @service audioroomRooms;

  @tracked streamKey = "";
  @tracked layout = this.args.model.room.broadcast_layout || "speaker";
  @tracked isSaving = false;

  get hasSavedKey() {
    return !!this.args.model.room.has_youtube_stream_key;
  }

  get room() {
    return this.args.model.room;
  }

  get isLive() {
    return this.room.live;
  }

  get title() {
    return this.isLive
      ? i18n("audioroom.livestream.title_live")
      : i18n("audioroom.livestream.title");
  }

  @action
  setLayout(value) {
    this.layout = value;
  }

  @action
  setLayoutSpeaker() {
    this.setLayout("speaker");
  }

  @action
  setLayoutGrid() {
    this.setLayout("grid");
  }

  @action
  onStreamKeyInput(event) {
    this.streamKey = event.target.value;
  }

  @action
  async startStream() {
    if (!this.streamKey.trim() && !this.hasSavedKey) {
      return;
    }
    this.isSaving = true;
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/livestream/start`, {
        type: "POST",
        data: { stream_key: this.streamKey, layout: this.layout },
      });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  @action
  async stopStream() {
    this.isSaving = true;
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/livestream/stop`, {
        type: "DELETE",
      });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  @action
  switchLayoutSpeaker() {
    this.switchLayout("speaker");
  }

  @action
  switchLayoutGrid() {
    this.switchLayout("grid");
  }

  @action
  async switchLayout(newLayout) {
    this.layout = newLayout;
    if (!this.isLive) return;
    try {
      await ajax(`/audioroom/rooms/${this.room.id}/livestream/layout`, {
        type: "PATCH",
        data: { layout: newLayout },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class="audioroom-livestream-modal"
    >
      <:body>
        {{#if this.isLive}}
          <div class="audioroom-livestream-modal__live-indicator">
            <span class="audioroom-livestream-modal__live-dot"></span>
            {{i18n "audioroom.livestream.currently_live"}}
          </div>

          <div class="audioroom-livestream-modal__section">
            <label class="audioroom-livestream-modal__label">
              {{i18n "audioroom.livestream.layout"}}
            </label>
            <div class="audioroom-livestream-modal__layout-toggle">
              <DButton
                @action={{this.switchLayoutSpeaker}}
                @translatedLabel={{i18n "audioroom.livestream.layout_speaker"}}
                class="btn {{if (eq this.layout 'speaker') 'btn-primary' 'btn-flat'}}"
              />
              <DButton
                @action={{this.switchLayoutGrid}}
                @translatedLabel={{i18n "audioroom.livestream.layout_grid"}}
                class="btn {{if (eq this.layout 'grid') 'btn-primary' 'btn-flat'}}"
              />
            </div>
          </div>
        {{else}}
          <div class="audioroom-livestream-modal__section">
            <label class="audioroom-livestream-modal__label" for="stream-key-input">
              {{i18n "audioroom.livestream.stream_key"}}
            </label>
            <input
              id="stream-key-input"
              type="password"
              class="input-large"
              value={{this.streamKey}}
              placeholder={{if
                this.hasSavedKey
                (i18n "audioroom.livestream.stream_key_placeholder_saved")
                (i18n "audioroom.livestream.stream_key_placeholder")
              }}
              {{on "input" this.onStreamKeyInput}}
              autocomplete="off"
            />
            <p class="audioroom-livestream-modal__help">
              {{i18n "audioroom.livestream.stream_key_help"}}
            </p>
          </div>

          <div class="audioroom-livestream-modal__section">
            <label class="audioroom-livestream-modal__label">
              {{i18n "audioroom.livestream.layout"}}
            </label>
            <div class="audioroom-livestream-modal__layout-toggle">
              <DButton
                @action={{this.setLayoutSpeaker}}
                @translatedLabel={{i18n "audioroom.livestream.layout_speaker"}}
                class="btn {{if (eq this.layout 'speaker') 'btn-primary' 'btn-flat'}}"
              />
              <DButton
                @action={{this.setLayoutGrid}}
                @translatedLabel={{i18n "audioroom.livestream.layout_grid"}}
                class="btn {{if (eq this.layout 'grid') 'btn-primary' 'btn-flat'}}"
              />
            </div>
          </div>
        {{/if}}
      </:body>

      <:footer>
        {{#if this.isLive}}
          <DButton
            @action={{this.stopStream}}
            @label="audioroom.livestream.stop"
            @icon="circle-stop"
            @disabled={{this.isSaving}}
            class="btn-danger"
          />
        {{else}}
          <DButton
            @action={{this.startStream}}
            @label="audioroom.livestream.start"
            @icon="circle-play"
            @disabled={{(or this.isSaving (and (not this.hasSavedKey) (not this.streamKey)))}}
            class="btn-primary"
          />
        {{/if}}
        <DButton
          @action={{@closeModal}}
          @label="cancel"
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
