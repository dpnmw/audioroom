import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AudioroomRoomForm extends Component {
  @tracked isSaving = false;

  get isAdminContext() {
    return !this.args.onSubmit;
  }

  get formData() {
    return {
      name: this.args.room?.name || "",
      description: this.args.room?.description || "",
      public: this.args.room?.public ?? false,
      room_type: this.args.room?.room_type || "open",
      max_participants: this.args.room?.max_participants || null,
      youtube_stream_key: this.args.room?.youtube_stream_key || "",
      broadcast_background: this.args.room?.broadcast_background || "",
      broadcast_watermark: this.args.room?.broadcast_watermark ?? true,
    };
  }

  get maxParticipantsValidation() {
    return "integer|number:2,200";
  }

  isStageType(roomType) {
    return roomType === "stage";
  }

  get roomTypeOptions() {
    return [
      {
        id: "open",
        name: i18n("audioroom.room.type_open"),
        description: i18n("audioroom.room.type_open_description"),
      },
      {
        id: "stage",
        name: i18n("audioroom.room.type_stage"),
        description: i18n("audioroom.room.type_stage_description"),
      },
    ];
  }

  get submitLabel() {
    if (this.isAdminContext) {
      return this.args.room?.id
        ? "audioroom.admin.update"
        : "audioroom.admin.create";
    }
    return "audioroom.room.save";
  }

  @action
  async handleSubmit(data) {
    this.isSaving = true;

    try {
      if (this.args.onSubmit) {
        await this.args.onSubmit(data);
      } else {
        const room = this.args.room;
        room.setProperties(data);
        await room.save();
        this.args.onSave?.(room);
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <div class="audioroom-room-form {{if this.isAdminContext 'admin-detail'}}">
      {{#if this.isAdminContext}}
        <BackButton
          @label="audioroom.admin.back"
          @route="adminPlugins.show.audioroom-rooms.index"
          class="audioroom-admin-back"
        />
      {{/if}}

      <Form
        @data={{this.formData}}
        @onSubmit={{this.handleSubmit}}
        class="audioroom-room-form__form"
        as |form|
      >
        <form.Field
          @name="name"
          @title={{i18n "audioroom.admin.room.name"}}
          @format="full"
          @validation="required|length:1,80"
          as |field|
        >
          <field.Input
            placeholder={{i18n "audioroom.admin.room.name_placeholder"}}
          />
        </form.Field>

        <form.Field
          @name="description"
          @title={{i18n "audioroom.admin.room.description"}}
          @format="full"
          as |field|
        >
          <field.Textarea />
        </form.Field>

        <form.Field
          @name="room_type"
          @title={{i18n "audioroom.admin.room.room_type"}}
          @format="full"
          as |field|
        >
          <field.RadioGroup as |radioGroup|>
            {{#each this.roomTypeOptions as |option|}}
              <radioGroup.Radio @value={{option.id}}>
                <strong>{{option.name}}</strong>
                —
                {{option.description}}
              </radioGroup.Radio>
            {{/each}}
          </field.RadioGroup>
        </form.Field>

        {{#if (this.isStageType form.data.room_type)}}
          <div class="audioroom-room-form__stage-hint">
            {{i18n "audioroom.room.type_stage_hint"}}
          </div>
        {{/if}}

        <form.Field
          @name="public"
          @title={{i18n "audioroom.admin.room.public"}}
          @helpText={{i18n "audioroom.admin.room.public_help"}}
          as |field|
        >
          <field.Toggle />
        </form.Field>

        <form.Field
          @name="max_participants"
          @title={{i18n "audioroom.admin.room.max_participants"}}
          @description={{i18n "audioroom.admin.room.max_participants_help"}}
          @validation={{this.maxParticipantsValidation}}
          as |field|
        >
          <field.Input @type="number" />
        </form.Field>

        {{#if this.isAdminContext}}
          <form.Field
            @name="youtube_stream_key"
            @title={{i18n "audioroom.admin.room.youtube_stream_key"}}
            @helpText={{i18n "audioroom.admin.room.youtube_stream_key_help"}}
            @format="full"
            as |field|
          >
            <field.Input @type="password" autocomplete="off" />
          </form.Field>

          <form.Section @title={{i18n "audioroom.admin.room.broadcast_appearance"}}>
            <form.Field
              @name="broadcast_background"
              @title={{i18n "audioroom.admin.room.broadcast_background"}}
              @helpText={{i18n "audioroom.admin.room.broadcast_background_help"}}
              @format="full"
              as |field|
            >
              <div class="audioroom-room-form__background-input-row">
                <field.Input placeholder="#1a1a2e or https://...image.jpg" />
                {{#if form.data.broadcast_background}}
                  <DButton
                    @action={{fn form.set "broadcast_background" null}}
                    @label="audioroom.admin.room.broadcast_background_clear"
                    class="btn-flat btn-small audioroom-room-form__background-clear"
                  />
                {{/if}}
              </div>
            </form.Field>

            <form.Field
              @name="broadcast_watermark"
              @title={{i18n "audioroom.admin.room.broadcast_watermark"}}
              as |field|
            >
              <field.Toggle />
            </form.Field>
          </form.Section>
        {{/if}}

        <form.Submit
          @label={{this.submitLabel}}
          @disabled={{this.isSaving}}
          class="audioroom-room-form__submit"
        />
      </Form>
    </div>
  </template>
}
