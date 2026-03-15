import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import avatar from "discourse/helpers/avatar";
import { i18n } from "discourse-i18n";

export default class AudioroomKickedList extends Component {
  <template>
    <section class="audioroom-kicked">
      <DPageSubheader @titleLabel={{i18n "audioroom.admin.kicked_title"}} />

      {{#if @kickedUsers.length}}
        <table class="d-admin-table audioroom-kicked__table">
          <thead>
            <tr>
              <th>{{i18n "audioroom.admin.kicked.user"}}</th>
              <th>{{i18n "audioroom.admin.kicked.room"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @kickedUsers as |entry|}}
              <tr class="d-admin-row__content">
                <td class="d-admin-row__overview">
                  <a
                    href="/admin/users/{{entry.user_id}}/{{entry.username}}"
                    data-user-card={{entry.username}}
                    class="audioroom-kicked__user-cell"
                  >
                    {{avatar entry imageSize="small"}}
                    <span>{{entry.username}}</span>
                  </a>
                </td>
                <td class="d-admin-row__detail">{{entry.room_name}}</td>
                <td class="d-admin-row__controls">
                  <DButton
                    @label="audioroom.admin.kicked.unkick"
                    @icon="rotate-left"
                    {{on "click" (fn @onUnkick entry)}}
                    class="btn-small btn-default"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="audioroom-kicked__empty">{{i18n "audioroom.admin.kicked.none"}}</p>
      {{/if}}
    </section>
  </template>
}
