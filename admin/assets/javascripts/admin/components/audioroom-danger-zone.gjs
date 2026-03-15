import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";

export default class AudioroomDangerZone extends Component {
  <template>
    <section class="audioroom-danger-zone">
      <DPageSubheader
        @titleLabel={{i18n "audioroom.admin.danger_zone_title"}}
      />

      <div class="audioroom-danger-zone__card">
        <h3 class="audioroom-danger-zone__card-title">
          {{i18n "audioroom.admin.danger_zone.reset_title"}}
        </h3>
        <p class="audioroom-danger-zone__card-description">
          {{i18n "audioroom.admin.danger_zone.reset_description"}}
        </p>

        <div class="audioroom-danger-zone__confirm-row">
          <label class="audioroom-danger-zone__confirm-label">
            {{i18n "audioroom.admin.danger_zone.type_to_confirm"}}
          </label>
          <input
            type="text"
            class="audioroom-danger-zone__confirm-input"
            placeholder="RESET"
            value={{@confirmText}}
            {{on "input" @onUpdateConfirmText}}
          />
        </div>

        <DButton
          @label="audioroom.admin.danger_zone.reset_button"
          @icon="triangle-exclamation"
          @disabled={{@resetDisabled}}
          {{on "click" @onReset}}
          class="btn-danger audioroom-danger-zone__reset-btn"
        />
      </div>
    </section>
  </template>
}
