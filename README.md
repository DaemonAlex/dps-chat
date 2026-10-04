# dps-chat

A commands-only box for voice-only FiveM servers. It replaces the default chat and okokChat, and adds `/me`, `/do` and `/try` as bubbles over the head.

## Features

- Press **T** to open a small box. Type a `/command` and press Enter. There is no chat feed and no text messages.
- Suggestions appear above the box and grow upward. The box never moves or changes size while you type.
- `/me`, `/do` and `/try` show as short bubbles over the player's head, not in a chat log.
- Two exports let other scripts draw the same bubbles over NPCs, vehicles, objects or a spot (`ShowBubble`, `ClearBubble`).
- Admins place the box for every player with `/chatbox`.
- Admins place a white ring around the round minimap with `/mapring`.
- Every server event is checked on the server and rate limited per player.

### The command box

- **T** opens it. Players can rebind the key under Settings > Key Bindings > FiveM ("Open the command box"). It does not open while the pause menu is active.
- The box starts with `/` in it. Suggestions match the first word and show up to 8 entries, with parameter names and help text.
- **Enter** runs the command. **Esc** closes the box. **Tab** completes the first (or selected) suggestion. **Up / Down** move through suggestions, or through your last 30 commands when no suggestion list applies. History is kept in the player's own browser storage.
- A player only sees commands they may run: the server offers a command when the player passes the ace `command.<name>`. Commands registered on the client and suggestions added by other scripts are listed too. Names starting with `+`, `-` or `_` are hidden.
- The command list is asked from the server when the box opens, at most once a minute.
- Default place: bottom right, 6% of the screen height above the bottom edge, 20% of the screen width (at least 300 px).

### /me, /do, /try

| Command | Bubble |
|---|---|
| `/me <action>` | Italic text with a blue **ME** badge. |
| `/do <description>` | Square caption with an orange **DO** badge. |
| `/try <action>` | The server rolls a 50/50 result. The bubble shows a green **SUCCESS** or red **FAIL** badge. |

- A bubble stays on screen for 7 seconds and fades out over the last 0.6 seconds.
- It is sent only to players within 25 m of the sender, and only to players in the same routing bucket.
- Up to 3 bubbles stack over one head.
- The `/try` roll happens on the server (`math.random(2) == 1`), so the player cannot choose the result.
- Text is cleaned on the server and again on every client: GTA codes (`~r~`, `~h~`, `~n~`), control characters and `<` `>` are removed, spaces are collapsed, and the text is cut to 120 characters (never in the middle of a character).
- A player may send one line every 3 seconds. The same line within 10 seconds is dropped.

### /chatbox (admin)

Needs the `admin` ace. Opens move mode: drag the box where you want it.

- **Enter** saves the spot for every player (at once, for everyone online, and for later joins).
- **Esc** cancels.
- **R** resets to the default corner.

The spot is stored as percent of the screen (x and y, 0 to 100) in this resource's server KVP, so it survives restarts.

### /mapring (admin)

Needs the `admin` ace. The ring is a white circle drawn on top of the round minimap. It is shown only while the GTA radar is on screen (not hidden, pause menu closed). Drag the ring onto the minimap. The ring is only a screen overlay and does not change the minimap.

- **Arrow keys** nudge it by one pixel.
- **Enter** saves for everyone. **Esc** cancels. **R** resets to the default spot.

The default spot is set in `html/style.css` (`.mapring`) and fits a 16:9 screen. It is stored like the box spot, under its own KVP key.

### Rate limits

All limits are per player and checked on the server.

| Action | Limit |
|---|---|
| `/me`, `/do`, `/try` | 1 per 3 s, same line dropped for 10 s |
| Command list request | 1 per 10 s |
| Box spot and ring spot read | 1 per 5 s |
| `/chatbox` and `/mapring` open, save, reset | 1 per 2 s each |

## Prerequisites

- FiveM server artifact with Lua 5.4 (`lua54 'yes'`).
- Nothing else. The code uses no framework and no other resource.
- The `admin` ace for anyone who should use `/chatbox` and `/mapring`.
- The page loads Orbitron and Roboto from Google Fonts. Players without internet access to it get fallback fonts.

### What `provide 'chat'` means

`fxmanifest.lua` declares `provide 'chat'`. Resources that list `chat` as a dependency are satisfied by this resource, so you can stop the default chat. It also means you must not run another resource that provides `chat` at the same time.

What other resources can still do:

- `chat:addSuggestion`, `chat:addSuggestions` and `chat:removeSuggestion` work. Suggestions are kept and shown in the box.
- `chat:addMessage`, `chatMessage`, `chat:clear`, `chat:addTemplate`, `chat:addMode` and `chat:removeMode` are accepted and ignored. No message is shown. The server also cancels `chatMessage`.

What they cannot do: this resource defines no exports other than `ShowBubble` and `ClearBubble`. A script that calls an export of the default chat resource (for example `exports.chat:...`) will fail. Scripts that register commands with `RegisterCommand` keep working.

## Installation

1. Stop and remove any other chat resource: the default `chat`, okokChat, or any resource that provides `chat`. Remove their `ensure`/`start` lines from `server.cfg`.
2. Copy the `dps-chat` folder into your resources folder (any bucket, for example `resources/[local]/dps-chat`).
3. Add `ensure dps-chat` to `server.cfg`. Start it before the resources that register command suggestions, so none are missed.
4. Give your admins the ace the code checks. In `permissions.cfg`:
   ```
   add_ace group.admin admin allow
   ```
5. Restart the server. Press **T** in game. Admins can then run `/chatbox` and `/mapring` once to place the box and ring.

## Configuration

There is no config file. Change these constants in the code, then restart the resource.

| File | Constant | Default | Meaning |
|---|---|---|---|
| `shared/logic.lua` | `Logic.MAX_TEXT` | 120 | Longest bubble text, in characters. |
| `shared/logic.lua` | `Logic.BUBBLE_GAP_MS` | 3000 | Time between two `/me` `/do` `/try` per player. |
| `shared/logic.lua` | `Logic.REPEAT_MS` | 10000 | The same line inside this time is dropped. |
| `server.lua` | `BUBBLE_RANGE` | 25.0 | Range in meters for `/me` `/do` `/try`. |
| `client.lua` | `SHOW_MS` | 7000 | Default bubble time in ms. |
| `client.lua` | `RANGE` | 25.0 | Default bubble range in m (also used for `/me` `/do` `/try`). |
| `client.lua` | `FADE_MS` | 600 | Fade-out time in ms. |
| `client.lua` | `MAX_PER_TARGET` | 3 | Most bubbles on one target. |
| `client.lua` | `MAX_TOTAL` | 40 | Most bubbles on one client at once. |
| `client.lua` | key mapping | `t` | Default key, in `RegisterKeyMapping`. |
| `html/style.css` | `.box` | bottom right | Default box place and width. |
| `html/style.css` | `.mapring` | see file | Default ring place and size. |
| `html/style.css` | `.bub` rules | see file | Bubble colors per kind. |

If you change `BUBBLE_RANGE` in `server.lua`, also change `RANGE` in `client.lua`. The server decides who gets the bubble, the client decides when it is too far to draw.

Fixed values in the code: bubble text for exports is cut to 120 characters, badge text to 16 characters (upper case), export duration is capped at 30000 ms, export range at 60 m.

## Commands

| Command | Who | What it does |
|---|---|---|
| `/me <action>` | Everyone | Bubble over your head, in italics. |
| `/do <description>` | Everyone | Caption over your head. |
| `/try <action>` | Everyone | Bubble with a 50/50 SUCCESS or FAIL rolled on the server. |
| `/chatbox` | `admin` ace | Move the command box for every player. |
| `/mapring` | `admin` ace | Move the minimap ring for every player. |

## Exports

Both exports are client side.

### `exports['dps-chat']:ShowBubble(target, text, opts)`

Shows a bubble on the local player's screen only. Other players do not see it. Call it from each client that should see it.

| Argument | Meaning |
|---|---|
| `target` | An entity handle (ped, vehicle, object) that exists, or a `vector3`. Anything else returns `nil`. Peds get the bubble above the head, other entities above their top. |
| `text` | The text. Cleaned the same way as `/me` (codes removed, 120 characters). Empty text returns `nil`. |
| `opts` | Optional table, see below. |

`opts` fields (all optional):

| Field | Default | Meaning |
|---|---|---|
| `tag` | kind name | Short name on the badge, for example `'MARCUS'`. Upper case, up to 16 characters. |
| `kind` | `'npc'` | `'npc'` round bubble with a cream badge, `'info'` square caption with a blue badge, `'me'` blue badge with italic text, `'do'` square caption with an orange badge. Any other value becomes `'npc'`. |
| `duration` | 7000 | Time in ms. Maximum 30000. |
| `range` | 25.0 | Draw distance in m from the local player. Maximum 60.0. A bubble fades out over its last 5 m. |
| `offset` | 0.0 | Extra height in m. |

Returns an id for `ClearBubble`, or `nil` when the text was empty, the target was invalid, or a limit was reached.

Limits (per client): 3 bubbles on one target, 40 bubbles in total. Over a limit, the call returns `nil` and nothing is shown. Bubbles on one target stack upward. A bubble on an entity that no longer exists is removed.

### `exports['dps-chat']:ClearBubble(idOrEntity)`

Removes the bubble with that id, or, if given an entity handle, every bubble on that entity.

### Example

```lua
local ped = npcPed -- an NPC handle from your own script

-- A named NPC line for 5 seconds, visible up to 15 m
local id = exports['dps-chat']:ShowBubble(ped, 'Welcome to the shop.', {
    tag = 'Marcus',
    kind = 'npc',
    duration = 5000,
    range = 15.0,
    offset = 0.1,
})

-- A caption on a fixed spot
exports['dps-chat']:ShowBubble(vector3(215.0, -810.0, 31.0), 'Wet floor.', { kind = 'info' })

-- Remove one bubble, or all bubbles on the ped
if id then exports['dps-chat']:ClearBubble(id) end
exports['dps-chat']:ClearBubble(ped)
```

## Tests

The shared helpers have no game natives, so they run outside the game. From the resource folder:

```
lua5.4 tests/run.lua
```

The runner prints `N checks, ALL PASS` and exits with a non-zero code if a check fails. The 37 checks in `tests/test_logic.lua` cover text cleaning, rate limits, repeat detection, spot validation, command names, badge text and bubble kinds.

## Troubleshooting

**A second box labelled "ALL:" opens on T.**
This is the base game's own text chat. The client calls `SetTextChatEnabled(false)` when it starts. If you still see it, another resource is turning it back on, or an old chat resource is still running. Stop it.

**T does nothing.**
Check that the resource started and that no other resource uses the same key. Players can rebind "Open the command box" in Settings > Key Bindings > FiveM. The box also does not open while the pause menu is active.

**Another chat resource is running and things are doubled or broken.**
Only one resource may provide `chat`. Stop the default chat and okokChat (step 1 of Installation).

**Messages from another script do not show.**
By design. Chat messages are dropped. Only command suggestions are kept.

**A command is missing from the suggestions.**
The list is built from commands the player may run (`command.<name>` ace), commands registered on the client, and suggestions from other scripts. Names starting with `+`, `-` or `_` are hidden. The list is refreshed when the box opens, at most once a minute.

**`/chatbox` or `/mapring` does nothing.**
The player lacks the `admin` ace. Check with `add_ace group.admin admin allow` and that the player is in `group.admin`. Also, only one action runs per 2 seconds.

**A bubble does not appear.**
The text became empty after cleaning, the sender repeated a line within 10 s or sent faster than every 3 s, the viewer is outside the range, or the viewer is in another routing bucket. For export bubbles, the target limit (3) or total limit (40) may be reached.

**The ring does not line up with the minimap.**
The default spot fits a 16:9 screen with the default minimap layout. Run `/mapring` and place it once. It is saved for everyone, so choose a layout that suits most players.

**Fonts look different.**
The page loads Orbitron and Roboto from Google Fonts. Without access to it the browser uses fallback fonts.
