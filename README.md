# Audioroom

Live voice rooms for Discourse — drop-in audio built into your community.


Developed by [DPN Media Works](https://dpnmediaworks.com) — based on [Resenha](https://github.com/xfalcox/resenha) by xfalcox

---

## Features

- Voice rooms in the Discourse sidebar and via REST API for mobile and external apps
- LiveKit SFU backend — scales to hundreds of participants
- Open rooms and Stage rooms (speaker/listener roles)
- Mute, deafen, push-to-talk, per-participant volume
- Server-side force mute — moderators can silence any participant via LiveKit's `mutePublishedTrack` API
- Idle/AFK detection with auto-mute and auto-disconnect
- Max participants enforced at both Discourse and LiveKit level
- Kick with 5-minute cooldown — kicked users cannot rejoin or heartbeat back in
- Unkick via admin panel (Kicked Users tab) or room-level endpoint
- Permanent ban — banned users cannot rejoin until manually unbanned
- Unban via admin panel (Banned Users tab) or room-level endpoint
- Hard mute / restore — revoke or restore `canPublish` for any participant in open rooms without a reconnect
- Single active room enforcement — joining a second room returns `409` with the conflicting room name; sidebar prompts to auto-leave and switch
- Raise hand / invite to speak flow for stage rooms
- LiveKit permission updates without reconnect — promoting a listener to speaker grants `canPublish` immediately
- User status integration ("In TheLounge 🎙️")
- Analytics, session tracking, co-presence metrics
- Badge system (Mic Check, Marathoner, Night Owl, etc.)
- REST API ready for external apps (React, mobile, etc.)
- YouTube livestreaming via LiveKit Egress (RoomComposite → RTMP)
- Live layout switching (Speaker ↔ Grid) while streaming
- Broadcast page for headless Chrome egress with speaker and grid layouts
- Real-time participant avatars on the broadcast page (via LiveKit token metadata)
- LiveKit Room Service integration — rooms created/deleted on LiveKit with `empty_timeout`
- Webhook endpoint for real-time participant sync from LiveKit

---

## Requirements

- Discourse (latest stable)
- Redis
- [LiveKit](https://livekit.io) server (self-hosted or cloud)
- [LiveKit Egress](https://docs.livekit.io/egress/) (optional, for YouTube livestreaming)

---

## Installation

1. Clone into your Discourse plugins directory:
   ```bash
   cd /var/discourse/plugins
   git clone https://github.com/dpnmw/audioroom.git
   ./launcher rebuild app
   ```

2. In Discourse Admin → Settings → Audioroom, configure:
   - `audioroom_livekit_url` — WebSocket URL clients connect to, e.g. `wss://livekit.yourdomain.com`
   - `audioroom_livekit_api_key` — your LiveKit API key
   - `audioroom_livekit_api_secret` — your LiveKit API secret
   - `audioroom_livekit_api_url` — internal HTTP URL of your LiveKit server for the Room Service API, e.g. `http://livekit:7880`
   - `audioroom_egress_url` — internal URL of your LiveKit Egress container, e.g. `http://egress:7788` (optional, required for livestreaming)
   - `audioroom_enabled` — set to `true`

3. A default room called **TheLounge** will be created automatically.

---

## Settings

All settings are in **Admin → Settings → Plugins** and are prefixed `audioroom_`.

| Setting | Default | Description |
|---------|---------|-------------|
| `audioroom_enabled` | `false` | Master switch — enables the plugin. |
| `audioroom_sidebar_enabled` | `true` | Show voice rooms in the Discourse sidebar. Disable to use Audioroom as an API-only backend. |
| `audioroom_allowed_groups` | `trust_level_0` (everyone) | Groups that can access voice rooms. |
| `audioroom_create_room_allowed_groups` | Admins, moderators, TL2 | Groups that can create new voice rooms. |
| `audioroom_max_rooms_per_user` | `5` | Maximum voice rooms a single user can own. |
| `audioroom_participant_ttl_seconds` | `30` | Seconds to keep participant presence in Redis without a heartbeat. Clients should heartbeat every 10s. |
| `audioroom_livekit_url` | `wss://livekit.example.com` | WebSocket URL clients connect to for audio. Sent to the client. |
| `audioroom_livekit_api_key` | _(empty)_ | LiveKit API key. Secret — not sent to client. |
| `audioroom_livekit_api_secret` | _(empty)_ | LiveKit API secret. Secret — not sent to client. |
| `audioroom_livekit_api_url` | `http://localhost:7880` | Internal HTTP URL of the LiveKit server for the Room Service API. Secret — not sent to client. |
| `audioroom_egress_url` | `http://localhost:7788` | Internal URL of the LiveKit Egress container. Required for YouTube livestreaming. Secret — not sent to client. |
| `audioroom_idle_threshold_minutes` | `5` | Minutes of inactivity before a participant is marked idle. Set to `0` to disable. |
| `audioroom_afk_auto_mute_threshold_minutes` | `15` | Minutes of inactivity before a participant is automatically muted. Set to `0` to disable. |
| `audioroom_afk_disconnect_threshold_minutes` | `30` | Minutes of inactivity before a participant is automatically disconnected. Set to `0` to disable. |
| `audioroom_auto_status_enabled` | `true` | Automatically set Discourse user status when a user joins a voice room (e.g. "🎙️ In TheLounge"). Requires the Discourse "enable user status" site setting. |
| `audioroom_badges_enabled` | `false` | Enable voice chat badges. Grants badges for milestones: time spent, rooms visited, co-presence connections made. |
| `audioroom_analytics_enabled` | `true` | Track sessions and co-presence data. Required for the contacts endpoint and admin analytics dashboard. |
| `audioroom_session_retention_days` | `400` | Days to retain session analytics records before automatic cleanup. Range: 7–3650. |
| `audioroom_room_notifications_enabled` | `true` | Send Discourse notifications to followers and members when a room goes live (first participant joins). |
| `audioroom_broadcast_customization_enabled` | `true` | Allow per-room broadcast background and watermark customization via the admin UI and API. When `false`, `broadcast_background` and `broadcast_watermark` params are ignored on create/update. |

---

## LiveKit Configuration

### Webhook

Add to your `livekit.yaml` so LiveKit notifies Discourse of participant events:

```yaml
webhook:
  urls:
    - https://yoursite.com/audioroom/webhook
  api_key: your_livekit_api_key
```

### Server-side unmute

To allow moderators to unmute participants (not just mute), add to the `room:` section of your `livekit.yaml`:

```yaml
room:
  enable_remote_unmute: true
```

---

## Room Types

### Open rooms
All participants can speak and publish audio freely.

### Stage rooms
Two-tier access:
- **Moderators / Speakers** — can publish audio, use data channel
- **Listeners** — subscribe-only by default; cannot unmute themselves

Moderators can:
- Promote a listener to speaker (grants `canPublish` server-side via LiveKit — no reconnect required)
- Demote a speaker back to listener (revokes `canPublish` server-side)
- Force-mute any participant via `mutePublishedTrack`
- Kick participants (5-minute rejoin cooldown)
- Hard mute / restore — revoke or restore `canPublish` for open-room participants without disconnecting them
- Permanently ban participants — banned users cannot rejoin until manually unbanned

Listeners in a stage room can:
- Raise their hand to request the mic
- Lower their hand
- Leave the room normally

When a listener raises their hand, a hand icon appears next to their name in the moderator's sidebar. The mod sees an "Invite to speak" button in the participant context menu, which promotes them to speaker immediately.

---

## LiveKit Room Management

Audioroom uses the LiveKit Room Service API to manage rooms at the LiveKit level:

- **Room created in Discourse** → LiveKit room is created immediately with `empty_timeout: 300` (5 minutes) and `departure_timeout: 20` seconds. LiveKit auto-closes the room after it has been empty for 5 minutes.
- **Room deleted in Discourse** → LiveKit room is deleted immediately, disconnecting all participants.
- **User joins** → `ensure_room` is called to create the LiveKit room if it doesn't exist yet (safe for rooms created before this feature).
- **`max_participants`** — enforced at both the Discourse level (join action) and the LiveKit level (passed to `create_room`).
- **Role changes** → LiveKit participant permissions (`canPublish`, `canPublishData`) are updated server-side immediately via `update_participant`, so role changes take effect without the user reconnecting.

---

## Webhooks

Audioroom includes a webhook endpoint that LiveKit can POST to for real-time participant sync. This ensures participant lists stay accurate even when users drop without a clean disconnect.

**Endpoint:** `POST /audioroom/webhook`

**Security:** Every request is verified using LiveKit's HMAC signature (`Authorization` header). Requests with invalid or missing signatures are rejected with `401`.

**Handled events:**

| Event | Action |
|---|---|
| `participant_joined` | Ensures participant is tracked in Redis |
| `participant_left` | Removes participant, closes session, clears user status |
| `room_finished` | Clears all participants when LiveKit closes an empty room |

---

## Kick Protection

When a participant is kicked from a room:

- They are removed from the participant list immediately
- A Redis blocklist entry is created (5-minute TTL) for that room
- Any further heartbeat or join requests from that user return `403` while the blocklist entry is active
- The blocklist is cleared when the room is deleted

Admins can manually unkick users via **Admin → Plugins → Audioroom → Kicked Users**, or via the API.

## Permanent Ban

When a participant is banned from a room:

- They are removed from the participant list immediately (same disconnect behavior as kick)
- A Redis ban entry is created with **no TTL** — the ban persists until manually removed
- Any further heartbeat or join requests from that user return `403`
- The ban list is cleared when the room is deleted

Admins can manually unban users via **Admin → Plugins → Audioroom → Banned Users**, or via the room-level API endpoint.

## Hard Mute / Restore

For open rooms, moderators can revoke a participant's publish permission entirely without disconnecting them:

- `POST /audioroom/rooms/:id/hard_mute` — calls `update_participant` to set `canPublish: false`. The participant's mic is silenced server-side immediately.
- `POST /audioroom/rooms/:id/hard_unmute` — restores `canPublish: true`.

This is the same LiveKit permission mechanism used by stage rooms to manage speaker roles.

---

## Admin Utilities

### Danger Zone — Reset Plugin

Available in **Admin → Plugins → Audioroom → Danger Zone**.

Permanently deletes all rooms, participants, sessions, memberships, analytics, kicked users, and banned users. Clears all Redis presence data. Recreates the default **TheLounge** room.

**This cannot be undone.** Type `RESET` in the confirmation field to activate the button.

The action is logged to the Discourse staff action log under `audioroom_plugin_reset`.

---

## Livestreaming to YouTube

Admins can stream any voice room live to YouTube directly from the sidebar.

**How it works:**

1. LiveKit Egress spins up a headless Chrome instance that loads the broadcast page (`/audioroom/broadcast/:slug`)
2. The broadcast page joins the room as a hidden subscriber and renders a visual layout (speaker or grid)
3. Egress captures the page and pushes it to YouTube via RTMP

**To go live:**

1. Right-click (or hover) a room in the sidebar → **Go Live**
2. Enter your YouTube stream key (saved per room after first use)
3. Choose a layout: **Speaker** (one featured tile + row) or **Grid** (equal tiles)
4. Click **Start Livestream**

The sidebar shows a **LIVE** badge on the room while streaming is active. You can switch layouts while live using the Speaker/Grid toggle. Click **Stop Livestream** to end it.

**Requirements:**

- LiveKit Egress running and reachable at `audioroom_egress_url`
- Your Discourse URL must be reachable by the Egress container (it loads the broadcast page over HTTP)

---

## API

The plugin exposes a REST API for external apps (React, mobile, etc.). All control-plane operations go through the Discourse API — only audio streaming connects directly to LiveKit using the token returned from the join endpoint.

### Authentication

Use a [Discourse User API Key](https://meta.discourse.org/t/user-api-keys-specification/48536) — pass it as a header:

```
User-Api-Key: <key>
```

### Endpoints

All endpoints require `User-Api-Key: <key>` unless noted otherwise.

#### Rooms

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/audioroom/rooms.json` | User API Key | List all accessible rooms |
| `GET` | `/audioroom/rooms/:id.json` | User API Key | Room details |
| `POST` | `/audioroom/rooms` | User API Key | Create a room (`name`, `description`, `public`, `room_type`, `max_participants`, `topic_id`, `schedule`, `next_session_at`, `broadcast_background`, `broadcast_watermark`) |
| `PUT` | `/audioroom/rooms/:id` | User API Key | Update a room (same params as create) |
| `DELETE` | `/audioroom/rooms/:id` | User API Key | Delete a room (creator or moderator only) |
| `POST` | `/audioroom/rooms/:id/join` | User API Key | Join room — returns `livekit_token` + `livekit_url` |
| `POST` | `/audioroom/rooms/:id/heartbeat` | User API Key | Keep presence alive (call every 10s). Accepts `skip_status` (bool), `idle_state` (`active`\|`idle`\|`afk`) |
| `DELETE` | `/audioroom/rooms/:id/leave` | User API Key | Leave room |
| `GET` | `/audioroom/rooms/:id/participants` | User API Key | List current participants with metadata |
| `POST` | `/audioroom/rooms/:id/toggle_mute` | User API Key | Update own mute/deafen state (`muted` bool, `deafened` bool) |

#### Stage room — listener actions

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/audioroom/rooms/:id/raise_hand` | User API Key | Signal request to speak |
| `DELETE` | `/audioroom/rooms/:id/raise_hand` | User API Key | Lower hand |

#### Moderator actions (all room types)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/audioroom/rooms/:id/memberships` | User API Key | List all room memberships |
| `POST` | `/audioroom/rooms/:id/memberships` | User API Key | Add/update a membership (`user_id` or `username`, `role`: `speaker`\|`participant`\|`moderator`) |
| `PUT` | `/audioroom/rooms/:id/memberships/:membership_id` | User API Key | Update a membership role (`role`) |
| `DELETE` | `/audioroom/rooms/:id/memberships/:membership_id` | User API Key | Remove a membership |
| `POST` | `/audioroom/rooms/:id/mute_participant` | User API Key | Force-mute a participant (`user_id`, `muted` bool) |
| `POST` | `/audioroom/rooms/:id/hard_mute` | User API Key | Revoke `canPublish` for a participant (`user_id`) — open rooms |
| `POST` | `/audioroom/rooms/:id/hard_unmute` | User API Key | Restore `canPublish` for a participant (`user_id`) — open rooms |
| `DELETE` | `/audioroom/rooms/:id/kick` | User API Key | Kick a participant — 5-minute rejoin cooldown (`user_id`) |
| `POST` | `/audioroom/rooms/:id/unkick` | User API Key | Remove kick ban for a user (`user_id`) |
| `POST` | `/audioroom/rooms/:id/ban` | User API Key | Permanently ban a participant (`user_id`) |
| `DELETE` | `/audioroom/rooms/:id/ban` | User API Key | Unban a participant (`user_id`) |
| `PATCH` | `/audioroom/rooms/:id/archive` | User API Key | Archive the room — hides it from the sidebar and API index |
| `PATCH` | `/audioroom/rooms/:id/unarchive` | User API Key | Unarchive the room — makes it visible again |

#### Follows and invite links

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/audioroom/rooms/:room_id/follow` | User API Key | Follow a room — notified when it goes live |
| `DELETE` | `/audioroom/rooms/:room_id/follow` | User API Key | Unfollow a room |
| `GET` | `/audioroom/invite/:token` | User API Key | Resolve invite link. Open rooms: grants membership immediately, returns `requires_confirmation: false`. Stage rooms: returns `requires_confirmation: true`, no membership granted until explicit `POST .../join` |

#### Analytics (requires `audioroom_analytics_enabled`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/audioroom/contacts` | User API Key | Top 10 co-presence contacts for the current user (last 30 days) |

#### Livestreaming (admin only, requires LiveKit Egress)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/audioroom/rooms/:room_id/livestream/start` | User API Key (admin) | Start YouTube livestream. Body: `{ "stream_key": "xxxx-xxxx-xxxx-xxxx", "layout": "speaker"\|"grid" }` |
| `DELETE` | `/audioroom/rooms/:room_id/livestream/stop` | User API Key (admin) | Stop YouTube livestream |
| `PATCH` | `/audioroom/rooms/:room_id/livestream/layout` | User API Key (admin) | Switch broadcast layout while live. Body: `{ "layout": "speaker"\|"grid" }` |

---

### Response shapes

#### Join response

```json
{
  "room": { ...room object... },
  "livekit_token": "eyJ...",
  "livekit_url": "wss://livekit.yourdomain.com"
}
```

Use the `livekit_token` with the [LiveKit client SDK](https://docs.livekit.io/realtime/client/connect/) to connect directly to audio.

#### Invite response

```json
{
  "room": { ...room object... },
  "requires_confirmation": false
}
```

`requires_confirmation: true` is returned for stage rooms — the client must show a confirmation step and then call `POST /audioroom/rooms/:id/join` explicitly.

### Room object

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Room ID |
| `slug` | string | URL-safe identifier |
| `name` | string | Display name |
| `description` | string | Markdown source (nullable) |
| `cooked_description` | string | Rendered HTML (nullable) |
| `public` | boolean | Visible to all users when `true`; members-only when `false` |
| `room_type` | string | `"open"` or `"stage"` |
| `max_participants` | integer | Cap on simultaneous participants (nullable) |
| `member_count` | integer | Total number of members |
| `active_participants` | array | Currently connected participants (see Participant object) |
| `creator_id` | integer | User ID of the room creator |
| `can_manage` | boolean | Whether the current user can manage this room |
| `live` | boolean | Whether a LiveKit Egress stream is active |
| `broadcast_layout` | string | Current egress layout: `"speaker"` or `"grid"` (nullable) |
| `invite_token` | string | Opaque token for shareable invite links — use with `GET /audioroom/invite/:token` |
| `schedule` | object | Recurring schedule: `{ "days": [0-6], "time": "HH:MM", "timezone": "TZ name" }` (nullable) |
| `next_session_at` | datetime | One-off next session override, ISO 8601 (nullable) |
| `topic_id` | integer | Linked Discourse topic ID (nullable) |
| `topic_url` | string | Full URL to the linked Discourse topic (nullable) |
| `is_following` | boolean | Whether the authenticated user follows this room |
| `broadcast_background` | string | Hex color or image URL applied to the broadcast page background (nullable) |
| `broadcast_watermark` | boolean | Whether to show the "Developed by dpnmw.com" watermark on the broadcast page (default: `true`) |
| `archived` | boolean | Whether the room is archived. Archived rooms are hidden from the sidebar and excluded from `GET /audioroom/rooms.json` by default. Admins can include them with `?include_archived=true`. |
| `created_at` | datetime | ISO 8601 |
| `updated_at` | datetime | ISO 8601 |

**`schedule` shape:**

```json
{
  "days": [1, 3, 5],
  "time": "20:00",
  "timezone": "America/New_York"
}
```

`days` uses `0 = Sunday … 6 = Saturday`.

### Participant object

```json
{
  "id": 42,
  "username": "alice",
  "name": "Alice",
  "avatar_template": "/user_avatar/...",
  "role": "speaker",
  "is_muted": false,
  "is_deafened": false,
  "hand_raised": false,
  "hard_muted": false,
  "idle_state": "active"
}
```

`role` reflects actual publish permissions at join time:
- Open rooms: always `"participant"` (or `"moderator"` for the creator)
- Stage rooms: `"moderator"`, `"speaker"`, or `"listener"` depending on membership and `canPublish`

### Error responses

| Status | Meaning |
|--------|---------|
| `401` | Missing or invalid API key |
| `403` | Kicked or banned from room, or not authorized for this action |
| `404` | Room or resource not found |
| `409` | Conflict — room already live, or user is already active in another room (`conflicting_room_id` and `conflicting_room_name` included in body) |
| `422` | Room is full, or invalid action (e.g. speaker trying to raise hand) |

---

## Admin Utilities

### Danger Zone

**Admin → Plugins → Audioroom → Danger Zone**

The Danger Zone tab exposes a destructive reset operation for development, staging, or recovery use. It is only accessible to Discourse admins.

#### Reset Plugin Data

**`POST /admin/plugins/audioroom/reset.json`** (admin only)

Performs a full wipe of all Audioroom state:

1. Flushes all `audioroom:*` Redis keys (participant presence, kick/ban lists)
2. Truncates all Audioroom database tables in dependency order:
   - `audioroom_room_follows`
   - `audioroom_co_presences`
   - `audioroom_sessions`
   - `audioroom_room_memberships`
   - `audioroom_rooms`
3. Logs a `audioroom_plugin_reset` entry to the Discourse staff action log

The UI requires typing `RESET` into a confirmation field before the button becomes active, and shows a second confirmation dialog before the request is sent. Returns `{ "success": true }` on success.

**This action cannot be undone.**

---

## License

MIT
