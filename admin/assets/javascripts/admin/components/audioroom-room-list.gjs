import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class AudioroomRoomList extends Component {
  @service dialog;

  @action
  async destroyRoom(room) {
    room.set("isDeleting", true);
    try {
      await this.dialog.deleteConfirm({
        message: i18n("audioroom.admin.destroy_room.confirm", {
          name: escapeExpression(room.name),
        }),
        didConfirm: async () => {
          try {
            await room.destroyRecord();
            this.args.onDestroy?.(room);
          } catch (e) {
            popupAjaxError(e);
          }
        },
      });
    } finally {
      room?.set("isDeleting", false);
    }
  }

  @action
  async archiveRoom(room) {
    try {
      await ajax(`/admin/plugins/audioroom/rooms/${room.id}/archive.json`, {
        type: "PATCH",
      });
      room.set("archived", true);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async unarchiveRoom(room) {
    try {
      await ajax(`/admin/plugins/audioroom/rooms/${room.id}/unarchive.json`, {
        type: "PATCH",
      });
      room.set("archived", false);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <section class="audioroom-rooms-table">
      <DPageSubheader @titleLabel={{i18n "audioroom.admin.rooms_title"}}>
        <:actions as |actions|>
          <actions.Primary
            @label="audioroom.admin.create_room"
            @route="adminPlugins.show.audioroom-rooms.new"
            @icon="plus"
            class="audioroom-admin__create-btn"
          />
        </:actions>
      </DPageSubheader>

      {{#if @rooms.length}}
        <table class="d-admin-table audioroom-rooms">
          <thead>
            <tr>
              <th>{{i18n "audioroom.admin.room.name"}}</th>
              <th>{{i18n "audioroom.admin.room.public"}}</th>
              <th>{{i18n "audioroom.admin.room.max_participants"}}</th>
              <th>{{i18n "audioroom.admin.room.member_count"}}</th>
              <th>{{i18n "audioroom.admin.room.creator"}}</th>
              <th>{{i18n "audioroom.admin.room.created_at"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @rooms as |room|}}
              <tr
                class="d-admin-row__content
                  {{if room.archived 'audioroom-rooms__row--archived'}}"
              >
                <td class="d-admin-row__overview audioroom-rooms__name">
                  {{room.name}}
                  {{#if room.archived}}
                    <span class="audioroom-rooms__archived-badge">
                      {{i18n "audioroom.admin.room.archived_badge"}}
                    </span>
                  {{/if}}
                </td>
                <td class="d-admin-row__detail audioroom-rooms__public">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "audioroom.admin.room.public"}}
                  </div>
                  {{#if room.public}}
                    {{i18n "yes_value"}}
                  {{else}}
                    {{i18n "no_value"}}
                  {{/if}}
                </td>
                <td class="d-admin-row__detail audioroom-rooms__max-participants">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "audioroom.admin.room.max_participants"}}
                  </div>
                  {{#if room.max_participants}}
                    {{room.max_participants}}
                  {{else}}
                    -
                  {{/if}}
                </td>
                <td class="d-admin-row__detail audioroom-rooms__member-count">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "audioroom.admin.room.member_count"}}
                  </div>
                  {{room.member_count}}
                </td>
                <td class="d-admin-row__detail audioroom-rooms__creator">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "audioroom.admin.room.creator"}}
                  </div>
                  {{#if room.creator}}
                    <a
                      href={{room.creator.userPath}}
                      data-user-card={{room.creator.username}}
                    >
                      {{avatar room.creator imageSize="small"}}
                    </a>
                  {{/if}}
                </td>
                <td class="d-admin-row__detail audioroom-rooms__created-at">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "audioroom.admin.room.created_at"}}
                  </div>
                  {{formatDate room.created_at leaveAgo="true"}}
                </td>
                <td class="d-admin-row__controls audioroom-rooms__controls">
                  {{#if room.archived}}
                    <DButton
                      @label="audioroom.admin.unarchive"
                      @icon="box-open"
                      {{on "click" (fn this.unarchiveRoom room)}}
                      class="btn-small btn-default audioroom-rooms__unarchive"
                    />
                  {{else}}
                    <LinkTo
                      @route="adminPlugins.show.audioroom-rooms.edit"
                      @model={{room.id}}
                      class="btn btn-default btn-text btn-small"
                    >
                      {{i18n "audioroom.admin.edit"}}
                    </LinkTo>

                    <DButton
                      @label="audioroom.admin.archive"
                      @icon="box-archive"
                      {{on "click" (fn this.archiveRoom room)}}
                      class="btn-small btn-default audioroom-rooms__archive"
                    />

                    <DButton
                      @icon="trash-can"
                      @disabled={{room.isDeleting}}
                      {{on "click" (fn this.destroyRoom room)}}
                      class="btn-small btn-danger audioroom-rooms__delete"
                    />
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="audioroom.admin.create_room"
          @ctaRoute="adminPlugins.show.audioroom-rooms.new"
          @ctaClass="audioroom-admin__create-btn"
          @emptyLabel="audioroom.admin.no_rooms_yet"
        />
      {{/if}}
    </section>
  </template>
}
