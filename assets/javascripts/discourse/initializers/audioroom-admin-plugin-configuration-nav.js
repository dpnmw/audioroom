import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "audioroom";

export default {
  name: "audioroom-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "microphone-lines");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "audioroom.admin.dashboard_title",
          route: "adminPlugins.show.audioroom-dashboard",
        },
        {
          label: "audioroom.admin.rooms_title",
          route: "adminPlugins.show.audioroom-rooms",
        },
        {
          label: "audioroom.admin.kicked_title",
          route: "adminPlugins.show.audioroom-kicked",
        },
        {
          label: "audioroom.admin.banned_title",
          route: "adminPlugins.show.audioroom-banned",
        },
        {
          label: "audioroom.admin.danger_zone_title",
          route: "adminPlugins.show.audioroom-danger-zone",
          className: "audioroom-admin-nav__danger-zone",
        },
      ]);
    });
  },
};
