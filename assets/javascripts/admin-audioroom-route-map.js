export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("audioroom-dashboard");
    this.route(
      "audioroom-rooms",

      function () {
        this.route("new");
        this.route("edit", { path: "/:id" });
      }
    );
    this.route("audioroom-kicked");
    this.route("audioroom-banned");
    this.route("audioroom-danger-zone");
  },
};
