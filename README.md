# dps-chat

The **command box** for Del Perro Sands, a voice-only Qbox FiveM server.

Press **T** and a small box opens. Type a `/command`, press **Enter**, and it runs. There is **no chat feed and no messages**: players talk by voice. The only text other players ever see is the short role-play line over a head from `/me`, `/do` and `/try`.

It replaces the default `chat` resource and okokChat. It `provide`s `chat`, so every script that registers command suggestions keeps working.

## What players get

| Key / command | What it does |
|---|---|
| **T** | Opens the command box. It suggests matching commands as you type, with their help text. |
| **Enter / Tab / ↑ ↓ / Esc** | Run, complete, pick a suggestion or recall recent commands, close. |
| `/me <action>` | Blue line over your head for 7 s, *in italics*: what your character does. |
| `/do <description>` | Orange line over your head for 7 s: what others can see in the scene. |
| `/try <action>` | The server rolls 50/50: green **SUCCESS** or red **FAIL** next to what you tried. |

Lines are seen by players within 25 m in the same routing bucket. Up to three lines stack over one head.

## What admins get

| Command | What it does |
|---|---|
| `/chatbox` | Drag the box to a new spot. **Enter** saves it for **every player**, **Esc** cancels, **R** puts it back in the bottom-right corner. Needs the `admin` ace (`group.admin`). The spot is kept in the resource's server KVP and survives reboots. |

## Built to hold up on a full server

- **Rate limits per player (server-side):** one `/me` `/do` `/try` every 3 s; the same line again inside 10 s is dropped; command list once per 10 s; box spot reads once per 5 s; admin actions once per 2 s.
- **Clean text:** GTA formatting codes (`~r~`, `~h~`, `~n~`…), control characters and `<` `>` are removed, length capped at 120 characters, never cut mid-character. Cleaned on the server **and** again on each client before drawing.
- **Server-side checks:** every event validates its input; admin rights are checked on the server, never trusted from the player. The `/try` roll happens on the server.
- **No per-frame cost when idle:** the bubble loop runs only while a bubble is on screen.
- **Messages from other scripts** (`chat:addMessage`, `chatMessage`, …) are dropped on purpose, and GTA's own online text chat (the "ALL:" box) is switched off.

## Requirements

- FiveM server with `lua54`. No framework dependency: it works on Qbox, QBCore or standalone.
- **Remove or stop** any other chat resource: the default `chat` and okokChat (or any other resource that `provide`s `chat`).
- The `admin` ace for whoever should place the box, e.g. in `permissions.cfg`:
  ```
  add_ace group.admin admin allow
  ```

## Install

1. Put the `dps-chat` folder in your resources (we use `resources/[dps]/dps-chat`).
2. In `server.cfg`, comment out the old chat and start this one:
   ```
   # ensure chat
   # ensure okokChatV2
   ensure dps-chat
   ```
   If your resources are started by bucket (`ensure [dps]`), the folder line is enough.
3. Restart the server. In game, press **T** to check, then use `/chatbox` once to place the box where you want it.

## Settings

All in code, short and commented:

| Where | What |
|---|---|
| `shared/logic.lua` | `MAX_TEXT` (120), `BUBBLE_GAP_MS` (3000), `REPEAT_MS` (10000) |
| `server.lua` | `BUBBLE_RANGE` (25 m) |
| `client.lua` | `SHOW_MS` (7000), key mapping (`t`, players can rebind it under Settings → Key Bindings → FiveM) |
| `html/style.css` | Colours (DPS palette: navy, #ff7a45), default corner, bubble colours per kind |

## Tests

From the resource folder:

```
lua5.4 tests/run.lua
```

31 checks cover text cleaning, rate limits, repeats, box position and command names. Run them before every restart.

## Files

```
fxmanifest.lua       provide 'chat', shared/client/server scripts, NUI
shared/logic.lua     pure helpers (no natives), used by both sides and the tests
server.lua           command list, /me /do /try, box spot, rate limits
client.lua           T key, suggestions, NUI focus, bubble positions
html/                the box and the bubbles (index.html, style.css, app.js)
tests/               run.lua, stubs.lua, test_logic.lua
```
