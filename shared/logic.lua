-- SHARED. Pure helpers (no game natives) so the tests can run them outside the game.

Logic = {}

Logic.MAX_TEXT = 120        -- longest /me or /do line
Logic.BUBBLE_GAP_MS = 3000  -- one /me or /do per player every 3 seconds
Logic.REPEAT_MS = 10000     -- the same line again inside 10 seconds is dropped

---Makes a /me or /do line safe to draw: no GTA text codes (~r~, ~h~, ~n~ ...), no control
---characters, single spaces, capped length. Returns nil when nothing is left.
function Logic.cleanText(s, max)
    if type(s) ~= 'string' then return nil end
    max = max or Logic.MAX_TEXT
    s = s:gsub('~[^~]*~', '')      -- GTA formatting codes
    s = s:gsub('~', '')            -- any stray tilde left over
    s = s:gsub('[%c]', ' ')        -- newlines, tabs, other control characters
    s = s:gsub('[<>]', '')         -- no markup if this text ever reaches a web page
    s = s:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
    if #s > max then s = s:sub(1, max) end
    while #s > 0 and not utf8.len(s) do s = s:sub(1, -2) end   -- never end on half a character
    return s ~= '' and s or nil
end

---A per-key rate gate. store: table kept by the caller; returns true when the action may run
---now (and records it), false when it came too soon after the last one.
function Logic.rateOk(store, key, now, gap)
    local last = store[key]
    if last and now - last < gap then return false end
    store[key] = now
    return true
end

---True when the same player sent the same line within REPEAT_MS. Records the line otherwise.
function Logic.isRepeat(store, key, text, now)
    local last = store[key]
    if last and last.text == text and now - last.at < Logic.REPEAT_MS then return true end
    store[key] = { text = text, at = now }
    return false
end

---A saved box spot: x and y as percent of the screen, both 0 to 100. Returns a clean copy or nil.
function Logic.validPos(pos)
    if type(pos) ~= 'table' then return nil end
    local x, y = tonumber(pos.x), tonumber(pos.y)
    if not x or not y or x ~= x or y ~= y or x < 0 or x > 100 or y < 0 or y > 100 then return nil end
    return { x = math.floor(x * 100 + 0.5) / 100, y = math.floor(y * 100 + 0.5) / 100 }
end

---A command name worth offering: a string, not a key-mapping half (+x / -x) or internal (_x).
function Logic.listable(name)
    return type(name) == 'string' and name ~= '' and not name:find('^[%+%-_]') and #name <= 64
end

---Badge text for a shared bubble: short, upper case, no codes. nil when nothing usable.
function Logic.cleanTag(s)
    s = Logic.cleanText(s, 16)
    return s and s:upper() or nil
end

---The bubble kinds other scripts may ask for; anything else becomes 'npc'.
local KINDS = { npc = true, info = true, me = true, ['do'] = true }
function Logic.bubbleKind(k)
    return KINDS[k] and k or 'npc'
end

return Logic
