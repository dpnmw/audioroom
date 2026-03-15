import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import avatar from "discourse/helpers/avatar";
import { i18n } from "discourse-i18n";

export default class AudioroomBannedList extends Component {
  <template>
    <section class="audioroom-banned">
      <DPageSubheader @titleLabel={{i18n "audioroom.admin.banned_title"}} />

      {{#if @bannedUsers.length}}
        <table class="d-admin-table audioroom-banned__table">
          <thead>
            <tr>
              <th>{{i18n "audioroom.admin.banned.user"}}</th>
              <th>{{i18n "audioroom.admin.banned.room"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @bannedUsers as |entry|}}
              <tr class="d-admin-row__content">
                <td class="d-admin-row__overview">
                  <a
                    href="/admin/users/{{entry.user_id}}/{{entry.username}}"
                    data-user-card={{entry.username}}
                    class="audioroom-banned__user-cell"
                  >
                    {{avatar entry imageSize="small"}}
                    <span>{{entry.username}}</span>
                  </a>
                </td>
                <td class="d-admin-row__detail">{{entry.room_name}}</td>
                <td class="d-admin-row__controls">
                  <DButton
                    @label="audioroom.admin.banned.unban"
                    @icon="rotate-left"
                    {{on "click" (fn @onUnban entry)}}
                    class="btn-small btn-default"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="audioroom-banned__empty">{{i18n "audioroom.admin.banned.none"}}</p>
      {{/if}}
    </section>
  </template>
}
