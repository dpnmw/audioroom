import noop from "discourse/helpers/noop";
import { avatarUrl } from "discourse/lib/avatar-utils";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import AudioroomCreateRoomModal from "discourse/plugins/audioroom/discourse/components/modal/audioroom-create-room";
import AudioroomParticipantSidebarContextMenu from "discourse/plugins/audioroom/discourse/components/audioroom-participant-sidebar-context-menu";
import AudioroomRoomSidebarContextMenu from "discourse/plugins/audioroom/discourse/components/audioroom-room-sidebar-context-menu";
import { humanKeyName } from "../lib/audioroom/ptt-utils";

const LINK_NAME_PREFIX = "audioroom-room-";
let sidebarClickHandler;
let sidebarContextMenuHandler;

export default {
  name: "audioroom-sidebar",
  initialize(owner) {
    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();
      const siteSettings = owner.lookup("service:site-settings");

      if (!currentUser || !siteSettings.audioroom_enabled || !siteSettings.audioroom_sidebar_enabled) {
        return;
      }

      const roomsService = owner.lookup("service:audioroom-rooms");
      const audioroomWebrtc = owner.lookup("service:audioroom-webrtc");
      const menuService = owner.lookup("service:menu");
      const modalService = owner.lookup("service:modal");
      const capabilities = owner.lookup("service:capabilities");

      api.addSidebarSection((BaseSection, BaseLink) => {
        const RoomsLink = class extends BaseLink {
          constructor({ room, webrtcService, user, menu }) {
            super(...arguments);
            this.room = room;
            this.audioroomWebrtc = webrtcService;
            this.currentUser = user;
            this.menuService = menu;
          }

          get hoverType() {
            return "icon";
          }

          get hoverValue() {
            return capabilities.isIpadOS ? null : "ellipsis-vertical";
          }

          get hoverTitle() {
            return i18n("audioroom.room.menu_title");
          }

          get hoverAction() {
            if (capabilities.isIpadOS) {
              return noop;
            }

            return (event, onMenuClose) => {
              event.stopPropagation();
              event.preventDefault();

              const anchor =
                event.target.closest(".sidebar-section-link") || event.target;

              this.menuService.show(anchor, {
                identifier: "audioroom-room-menu",
                component: AudioroomRoomSidebarContextMenu,
                placement: "right",
                data: { room: this.room },
                onClose: onMenuClose,
              });
            };
          }

          get name() {
            return `audioroom-room-${this.room.id}`;
          }

          get classNames() {
            const classes = ["audioroom-sidebar-link"];
            const state = this.audioroomWebrtc.connectionStateFor(this.room.id);

            if (state === "connected") {
              classes.push("sidebar-section-link--active");
            } else if (state === "connecting") {
              classes.push("audioroom-sidebar-link--connecting");
            }

            return classes.join(" ");
          }

          get href() {
            return "#";
          }

          get title() {
            const state = this.audioroomWebrtc.connectionStateFor(this.room.id);

            if (state === "connecting") {
              return i18n("audioroom.room.connecting");
            }

            if (state === "connected") {
              return i18n("audioroom.room.leave");
            }

            return (
              this.room.description_excerpt ||
              this.room.name ||
              i18n("audioroom.room.join")
            );
          }

          get text() {
            return this.room.name;
          }

          get prefixType() {
            return "icon";
          }

          get prefixValue() {
            return this.room.room_type === "stage"
              ? "podcast"
              : "microphone-lines";
          }

          get suffixType() {
            if (this.room.live) {
              return "text";
            }
            if (
              this.audioroomWebrtc.connectionStateFor(this.room.id) ===
              "connecting"
            ) {
              return "icon";
            }
            return null;
          }

          get suffixValue() {
            if (this.room.live) {
              return i18n("audioroom.livestream.live_badge");
            }
            if (
              this.audioroomWebrtc.connectionStateFor(this.room.id) ===
              "connecting"
            ) {
              return "spinner";
            }
            return null;
          }

          get suffixCSSClass() {
            if (this.room.live) {
              return "audioroom-sidebar-live-badge";
            }
            return null;
          }

          getParticipantsForSummary() {
            const participants = this.room.active_participants || [];

            if (!this.currentUser) {
              return participants;
            }

            if (
              this.audioroomWebrtc.connectionStateFor(this.room.id) !==
              "connected"
            ) {
              return participants;
            }

            if (
              participants.some(
                (participant) => participant?.id === this.currentUser.id
              )
            ) {
              return participants;
            }

            return [
              ...participants,
              {
                id: this.currentUser.id,
                username: this.currentUser.username,
                name: this.currentUser.name,
                avatar_template: this.currentUser.avatar_template,
              },
            ];
          }
        };

        const ParticipantLink = class extends BaseLink {
          constructor({
            room,
            participant,
            webrtcService,
            user,
            menu,
            canManageRoom,
            isListener,
            isFirstListener,
          }) {
            super(...arguments);
            this.room = room;
            this.participant = participant;
            this.audioroomWebrtc = webrtcService;
            this.currentUser = user;
            this.menuService = menu;
            this.canManageRoom = canManageRoom;
            this.isStageListener = isListener || false;
            this.isFirstListener = isFirstListener || false;
          }

          get #isCurrentUser() {
            return this.participant.id === this.currentUser?.id;
          }

          get #showMenu() {
            return !capabilities.isIpadOS;
          }

          get hoverType() {
            return this.#showMenu ? "icon" : null;
          }

          get hoverValue() {
            return this.#showMenu ? "ellipsis-vertical" : null;
          }

          get hoverTitle() {
            return i18n("audioroom.participant.menu_title");
          }

          get hoverAction() {
            if (!this.#showMenu) {
              return noop;
            }

            return (event, onMenuClose) => {
              event.stopPropagation();
              event.preventDefault();

              const anchor =
                event.target.closest(".sidebar-section-link") || event.target;

              this.menuService.show(anchor, {
                identifier: "audioroom-participant-menu",
                component: AudioroomParticipantSidebarContextMenu,
                placement: "right",
                data: {
                  room: this.room,
                  participant: this.participant,
                  canManageRoom: this.canManageRoom,
                  isCurrentUser: this.#isCurrentUser,
                },
                onClose: onMenuClose,
              });
            };
          }

          get name() {
            return `audioroom-participant-${this.room.id}-${this.participant.id}`;
          }

          get classNames() {
            const classes = ["audioroom-sidebar-participant"];

            if (this.isStageListener) {
              classes.push("audioroom-sidebar-participant--listener");
            }

            if (this.isFirstListener) {
              classes.push("audioroom-sidebar-participant--listeners-start");
            }

            if (this.participant.is_speaking) {
              classes.push("audioroom-sidebar-participant--speaking");
            }

            if (this.participant.is_muted) {
              classes.push("audioroom-sidebar-participant--muted");
            }

            if (this.participant.is_deafened) {
              classes.push("audioroom-sidebar-participant--deafened");
            }

            if (this.participant.idle_state === "idle") {
              classes.push("audioroom-sidebar-participant--idle");
            } else if (this.participant.idle_state === "afk") {
              classes.push("audioroom-sidebar-participant--afk");
            }

            return classes.join(" ");
          }

          get href() {
            return "#";
          }

          get title() {
            const name = this.participant.name || this.participant.username;
            if (this.#isCurrentUser && this.audioroomWebrtc.pttEnabled) {
              return `${name} — ${i18n("audioroom.ptt.badge", { key: humanKeyName(this.audioroomWebrtc.pttKey) })}`;
            }
            return name;
          }

          get text() {
            return this.participant.name || this.participant.username;
          }

          get suffixType() {
            if (this.#isCurrentUser && this.audioroomWebrtc.pttEnabled) {
              return "icon";
            }
            if (this.participant.hand_raised) {
              return "icon";
            }
            return null;
          }

          get suffixValue() {
            if (this.#isCurrentUser && this.audioroomWebrtc.pttEnabled) {
              return "walkie-talkie";
            }
            if (this.participant.hand_raised) {
              return "hand";
            }
            return null;
          }

          get suffixCSSClass() {
            if (this.participant.hand_raised) {
              return "audioroom-sidebar-participant__hand-raised";
            }
            return null;
          }

          get prefixType() {
            return "image";
          }

          get prefixValue() {
            return avatarUrl(this.participant.avatar_template, "small");
          }
        };

        const ListenerCountLink = class extends BaseLink {
          constructor({ room, count }) {
            super(...arguments);
            this.room = room;
            this.count = count;
          }

          get name() {
            return `audioroom-listener-count-${this.room.id}`;
          }

          get classNames() {
            return "audioroom-sidebar-participant audioroom-sidebar-participant--listener-count";
          }

          get href() {
            return "#";
          }

          get text() {
            return i18n("audioroom.stage.more_listeners", {
              count: this.count,
            });
          }

          get prefixType() {
            return "icon";
          }

          get prefixValue() {
            return "users";
          }
        };

        const RoomsSection = class extends BaseSection {
          name = "audioroom-rooms";
          text = i18n("audioroom.sidebar.title");
          title = i18n("audioroom.sidebar.title");

          constructor() {
            super(...arguments);
            this.audioroomRooms = roomsService;
          }

          get actions() {
            if (this.audioroomRooms?.canCreateRoom) {
              return [
                {
                  id: "createAudioroomRoom",
                  title: i18n("audioroom.sidebar.create"),
                  action: () => modalService.show(AudioroomCreateRoomModal),
                },
              ];
            }
            return [];
          }

          get actionsIcon() {
            return "plus";
          }

          get displaySection() {
            return (
              (this.audioroomRooms?.rooms?.length || 0) > 0 ||
              this.audioroomRooms?.canCreateRoom
            );
          }

          get links() {
            const result = [];

            for (const room of this.audioroomRooms?.rooms || []) {
              const roomLink = new RoomsLink({
                room,
                webrtcService: audioroomWebrtc,
                user: currentUser,
                menu: menuService,
              });
              result.push(roomLink);

              const canManageRoom = room.can_manage;
              const participants = roomLink.getParticipantsForSummary();

              if (room.room_type === "stage" && participants.length > 0) {
                const speakers = participants.filter((p) => {
                  const role = p.role;
                  return role === "moderator" || role === "speaker";
                });
                const listeners = participants.filter((p) => {
                  const role = p.role;
                  return role !== "moderator" && role !== "speaker";
                });

                for (const participant of speakers) {
                  result.push(
                    new ParticipantLink({
                      room,
                      participant,
                      webrtcService: audioroomWebrtc,
                      user: currentUser,
                      menu: menuService,
                      canManageRoom,
                    })
                  );
                }

                const maxVisibleListeners = 5;
                const visibleListeners = listeners.slice(
                  0,
                  maxVisibleListeners
                );

                visibleListeners.forEach((participant, index) => {
                  result.push(
                    new ParticipantLink({
                      room,
                      participant,
                      webrtcService: audioroomWebrtc,
                      user: currentUser,
                      menu: menuService,
                      canManageRoom,
                      isListener: true,
                      isFirstListener: index === 0,
                    })
                  );
                });

                if (listeners.length > maxVisibleListeners) {
                  result.push(
                    new ListenerCountLink({
                      room,
                      count: listeners.length - maxVisibleListeners,
                    })
                  );
                }
              } else {
                for (const participant of participants) {
                  result.push(
                    new ParticipantLink({
                      room,
                      participant,
                      webrtcService: audioroomWebrtc,
                      user: currentUser,
                      menu: menuService,
                      canManageRoom,
                    })
                  );
                }
              }
            }

            return result;
          }
        };

        return RoomsSection;
      });

      if (sidebarClickHandler) {
        document.removeEventListener("click", sidebarClickHandler);
      }

      sidebarClickHandler = async (event) => {
        const findAnchor = (selector) =>
          event
            .composedPath?.()
            ?.find?.(
              (node) => node instanceof HTMLElement && node.matches?.(selector)
            ) || event.target?.closest?.(selector);

        const participantAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='audioroom-participant-']"
        );

        if (participantAnchor) {
          event.preventDefault();
          event.stopPropagation();
          return;
        }

        const roomAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='audioroom-room-']"
        );

        if (!roomAnchor) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();

        const linkName = roomAnchor.dataset?.linkName;
        if (!linkName?.startsWith(LINK_NAME_PREFIX)) {
          return;
        }

        const roomId = parseInt(
          linkName.substring(LINK_NAME_PREFIX.length),
          10
        );
        const room = Number.isNaN(roomId)
          ? null
          : roomsService.roomById(roomId);

        if (!room) {
          return;
        }

        const connectionState = audioroomWebrtc.connectionStateFor(room.id);

        if (connectionState === "connecting") {
          return;
        }

        if (connectionState === "connected") {
          audioroomWebrtc.leave(room);
        } else {
          await audioroomWebrtc.join(room);
        }
      };

      document.addEventListener("click", sidebarClickHandler);

      if (sidebarContextMenuHandler) {
        document.removeEventListener("contextmenu", sidebarContextMenuHandler);
      }

      sidebarContextMenuHandler = (event) => {
        const findAnchor = (selector) =>
          event
            .composedPath?.()
            ?.find?.(
              (node) => node instanceof HTMLElement && node.matches?.(selector)
            ) || event.target?.closest?.(selector);

        const participantAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='audioroom-participant-']"
        );

        if (participantAnchor) {
          event.preventDefault();
          event.stopPropagation();

          const linkName = participantAnchor.dataset?.linkName;
          const suffix = linkName?.replace("audioroom-participant-", "");
          const dashIdx = suffix?.indexOf("-");
          if (!suffix || dashIdx < 1) {
            return;
          }

          const roomId = parseInt(suffix.substring(0, dashIdx), 10);
          const participantId = parseInt(suffix.substring(dashIdx + 1), 10);
          const room = roomsService.roomById(roomId);
          if (!room) {
            return;
          }

          const participant = (room.active_participants || []).find(
            (p) => p.id === participantId
          );
          if (!participant) {
            return;
          }

          menuService.show(participantAnchor, {
            identifier: "audioroom-participant-menu",
            component: AudioroomParticipantSidebarContextMenu,
            placement: "right",
            data: {
              room,
              participant,
              canManageRoom: room.can_manage,
              isCurrentUser: participant.id === currentUser?.id,
            },
          });
          return;
        }

        const roomAnchor = findAnchor(
          ".sidebar-section-link[data-link-name^='audioroom-room-']"
        );

        if (!roomAnchor) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();

        const linkName = roomAnchor.dataset?.linkName;
        if (!linkName?.startsWith(LINK_NAME_PREFIX)) {
          return;
        }

        const roomId = parseInt(
          linkName.substring(LINK_NAME_PREFIX.length),
          10
        );
        const room = Number.isNaN(roomId)
          ? null
          : roomsService.roomById(roomId);

        if (!room) {
          return;
        }

        menuService.show(roomAnchor, {
          identifier: "audioroom-room-menu",
          component: AudioroomRoomSidebarContextMenu,
          placement: "right",
          data: { room },
        });
      };

      document.addEventListener("contextmenu", sidebarContextMenuHandler);
    });
  },
};
