-- CLIENT. The command box: T opens it at a fixed spot, it suggests commands as you type,
-- Enter runs the command, Escape closes. There is no chat feed (voice-only server): chat
-- messages from other scripts are dropped; their command suggestions are kept.

local open = false

-- GTA's own online text chat also opens on T (the "ALL:" box); the default chat script switched it off, so we do too
SetTextChatEnabled(false)
local suggestions = {}   -- name -> { help, params }
local serverCommands = {}

local function clean(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('^/', '')
    return name ~= '' and name:lower() or nil
end

-- suggestions other scripts register (the default chat's events, kept working)
AddEventHandler('chat:addSuggestion', function(name, help, params)
    local n = clean(name); if not n then return end
    suggestions[n] = { help = type(help) == 'string' and help or '', params = type(params) == 'table' and params or {} }
end)
RegisterNetEvent('chat:addSuggestion', function(name, help, params) TriggerEvent('chat:addSuggestion', name, help, params) end)
local function addMany(list)
    if type(list) ~= 'table' then return end
    for _, s in ipairs(list) do if type(s) == 'table' then TriggerEvent('chat:addSuggestion', s.name, s.help, s.params) end end
end
AddEventHandler('chat:addSuggestions', addMany)
RegisterNetEvent('chat:addSuggestions', addMany)
local function removeOne(name) local n = clean(name); if n then suggestions[n] = nil end end
AddEventHandler('chat:removeSuggestion', removeOne)
RegisterNetEvent('chat:removeSuggestion', removeOne)

-- chat messages: voice-only server, dropped on purpose
for _, ev in ipairs({ 'chat:addMessage', 'chatMessage', 'chat:clear', 'chat:addTemplate', 'chat:addMode', 'chat:removeMode' }) do
    AddEventHandler(ev, function() end)
    RegisterNetEvent(ev, function() end)
end

local commandsAt = -60000   -- when the server's list last arrived; asked again after a minute at most
RegisterNetEvent('dps-chat:serverCommands', function(list)
    if type(list) ~= 'table' then return end
    local keep = {}
    for _, n in ipairs(list) do if Logic.listable(n) then keep[#keep + 1] = n end end
    serverCommands, commandsAt = keep, GetGameTimer()
end)

local function commandList()
    local seen, out = {}, {}
    local function add(n)
        n = clean(n)
        if not n or seen[n] or n:find('^[%+%-_]') then return end
        seen[n] = true
        local s = suggestions[n]
        out[#out + 1] = { name = n, help = s and s.help or '', params = s and s.params or {} }
    end
    for _, c in ipairs(GetRegisteredCommands()) do add(c.name) end   -- commands this client registered
    for _, n in ipairs(serverCommands) do add(n) end                  -- server commands this player may run
    for n in pairs(suggestions) do add(n) end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- where the box sits: one spot for every player, set by an admin with /chatbox and kept on
-- the server; nil = the default corner
local sharedPos = nil
local function savedPos() return sharedPos end
RegisterNetEvent('dps-chat:pos', function(pos) sharedPos = Logic.validPos(pos) end)
CreateThread(function() TriggerServerEvent('dps-chat:getPos'); TriggerServerEvent('dps-chat:requestCommands') end)
DeleteResourceKvp('dps-chat:pos')   -- the old per-player spot from the first version

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openBox()
    if open or IsPauseMenuActive() then return end
    open = true
    if GetGameTimer() - commandsAt > 60000 then TriggerServerEvent('dps-chat:requestCommands') end
    SetNuiFocus(true, true)   -- cursor on too: keyboard-only focus left the text box dead
    SendNUIMessage({ action = 'open', commands = commandList(), pos = savedPos() })
    SetTimeout(400, function() if open then SendNUIMessage({ action = 'commands', commands = commandList() }) end end)
end

RegisterCommand('+dpschat', openBox, false)
RegisterCommand('-dpschat', function() end, false)
RegisterKeyMapping('+dpschat', 'Open the command box', 'keyboard', 't')

RegisterNUICallback('run', function(d, cb)
    cb({ ok = true })
    close()
    local text = type(d.text) == 'string' and d.text:sub(1, 512):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if text == '' then return end
    if text:sub(1, 1) == '/' then text = text:sub(2) end
    if text ~= '' then ExecuteCommand(text) end
end)

RegisterNUICallback('close', function(_, cb) cb({ ok = true }); close() end)

-- /chatbox: drag the box where you want it; Enter saves, Esc cancels, R puts it back in the corner
RegisterCommand('chatbox', function()
    if open then return end
    TriggerServerEvent('dps-chat:editRequest')   -- the server answers only for admins
end, false)
RegisterNetEvent('dps-chat:editAllowed', function()
    if open then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'edit', pos = savedPos() })
end)
TriggerEvent('chat:addSuggestion', '/chatbox', 'Admins: move the command box for every player (drag, Enter saves, Esc cancels, R resets)')

RegisterNUICallback('editDone', function(d, cb)
    cb({ ok = true })
    if d.reset then TriggerServerEvent('dps-chat:setPos', false)
    elseif d.save and Logic.validPos(d.pos) then
        TriggerServerEvent('dps-chat:setPos', Logic.validPos(d.pos))
    end
    open = false
    SetNuiFocus(false, false)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and open then SetNuiFocus(false, false) end end)

-- /me, /do and /try bubbles: shown over the player's head for 7 seconds in the DPS look (html/app.js). The draw loop only runs
-- while at least one bubble is showing.
TriggerEvent('chat:addSuggestion', '/me', 'Show an action over your head', { { name = 'action', help = 'what your character does' } })
TriggerEvent('chat:addSuggestion', '/do', 'Describe something about the scene', { { name = 'description', help = 'what others can see' } })
TriggerEvent('chat:addSuggestion', '/try', 'Try something: the server rolls success or fail', { { name = 'action', help = 'what your character tries' } })

local bubbles, drawing = {}, false
local SHOW_MS, RANGE = 7000, 25.0
local FADE_MS = 600
local MAX_PER_TARGET, MAX_TOTAL = 3, 40

-- Where a bubble's target is right now: a player (server id), any entity, or a fixed spot.
-- Peds get the head bone; other entities their top; spots their own height.
local function anchorOf(b)
    local ent = 0
    if b.src then
        local player = GetPlayerFromServerId(b.src)
        ent = player ~= -1 and GetPlayerPed(player) or 0
    elseif b.entity then
        ent = b.entity
    elseif b.coords then
        return b.coords + vector3(0.0, 0.0, b.offset or 0.0)
    end
    if ent == 0 or not DoesEntityExist(ent) then return nil end
    if IsEntityAPed(ent) then
        return GetPedBoneCoords(ent, 31086, 0.0, 0.0, 0.0) + vector3(0.0, 0.0, 0.35 + (b.offset or 0.0))
    end
    local _, mx = GetModelDimensions(GetEntityModel(ent))
    return GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, mx.z + 0.2 + (b.offset or 0.0))
end

local function drawLoop()
    if drawing then return end
    drawing = true
    CreateThread(function()
        while next(bubbles) do
            local now, me = GetGameTimer(), GetEntityCoords(PlayerPedId())
            local stack, out = {}, {}
            for key, b in pairs(bubbles) do
                if now > b.untilAt then bubbles[key] = nil else
                    local at = anchorOf(b)
                    if not at and not b.src then bubbles[key] = nil   -- the NPC or object is gone
                    elseif at then
                        local dist = #(at - me)
                        if dist <= b.range then
                            local n = stack[b.target] or 0; stack[b.target] = n + 1
                            local onScreen, x, y = World3dToScreen2d(at.x, at.y, at.z + n * 0.16)
                            if onScreen then
                                local a = math.min(1.0, (b.untilAt - now) / FADE_MS) * (dist > b.range - 5.0 and (b.range - dist) / 5.0 or 1.0)
                                out[#out + 1] = { id = key, kind = b.kind, tag = b.tag, text = b.text, ok = b.ok, x = x, y = y, a = math.max(0.0, a) }
                            end
                        end
                    end
                end
            end
            SendNUIMessage({ action = 'bubbles', list = out })
            Wait(0)
        end
        SendNUIMessage({ action = 'bubbles', list = {} })
        drawing = false
    end)
end

local seq = 0
local function count(target)
    local n, total = 0, 0
    for _, b in pairs(bubbles) do total = total + 1; if b.target == target then n = n + 1 end end
    return n, total
end

local function add(b)
    local n, total = count(b.target)
    if n >= MAX_PER_TARGET or total >= MAX_TOTAL then return nil end
    seq = seq + 1
    bubbles[seq] = b
    drawLoop()
    return seq
end

RegisterNetEvent('dps-chat:bubble', function(src, kind, text, ok)
    src = tonumber(src)
    text = Logic.cleanText(text)   -- cleaned again here: never draw text as it arrived
    if not src or not text then return end
    kind = (kind == 'do' or kind == 'try') and kind or 'me'
    add({ src = src, target = 'p' .. src, kind = kind, text = text, ok = ok == true, range = RANGE, untilAt = GetGameTimer() + SHOW_MS })
end)

---Shared bubble maker for any script (client side), in the DPS floating-text look.
---target: an entity handle (NPC, object, vehicle) or a vector3 spot.
---opts (all optional): tag = short name on the badge ('MARCUS'), kind = 'npc' (round, cream badge),
---  'info' (square caption, blue badge), 'me', 'do'; duration ms (default 7000, max 30000);
---  range m (default 25, max 60); offset = extra height in m.
---Returns an id for ClearBubble, or nil when the text was empty or limits were hit.
local function showBubble(target, text, opts)
    opts = type(opts) == 'table' and opts or {}
    text = Logic.cleanText(text)
    if not text then return nil end
    local b = { kind = Logic.bubbleKind(opts.kind), tag = Logic.cleanTag(opts.tag), text = text,
        range = math.min(60.0, tonumber(opts.range) or RANGE), offset = tonumber(opts.offset) or 0.0,
        untilAt = GetGameTimer() + math.min(30000, tonumber(opts.duration) or SHOW_MS) }
    if type(target) == 'vector3' then
        b.coords, b.target = target, ('c%.1f:%.1f:%.1f'):format(target.x, target.y, target.z)
    elseif type(target) == 'number' and target ~= 0 and DoesEntityExist(target) then
        b.entity, b.target = target, 'e' .. target
    else
        return nil
    end
    return add(b)
end
exports('ShowBubble', showBubble)

---Removes one bubble (id from ShowBubble), or every bubble on an entity when given the entity.
exports('ClearBubble', function(idOrEntity)
    if bubbles[idOrEntity] then bubbles[idOrEntity] = nil return end
    for k, b in pairs(bubbles) do if b.entity == idOrEntity then bubbles[k] = nil end end
end)

-- White ring around the round minimap: shown while GTA's radar is on screen. Checked four times a second and
-- only sent to the page when it changes, so it costs nothing while nothing changes.
CreateThread(function()
    local shown = nil
    while true do
        local on = not IsRadarHidden() and not IsPauseMenuActive() and IsMinimapRendering()
        if on ~= shown then shown = on; SendNUIMessage({ action = 'ring', on = on }) end
        Wait(250)
    end
end)

-- /mapring (admins): drag the ring onto the minimap; the spot is kept on the server for everyone.
RegisterNetEvent('dps-chat:ringpos', function(pos) SendNUIMessage({ action = 'ringpos', pos = Logic.validPos(pos) }) end)
CreateThread(function() TriggerServerEvent('dps-chat:getRingPos') end)
RegisterCommand('mapring', function()
    if open then return end
    TriggerServerEvent('dps-chat:ringEditRequest')
end, false)
TriggerEvent('chat:addSuggestion', '/mapring', 'Admins: line the white ring up with the minimap for every player')
RegisterNetEvent('dps-chat:ringEditAllowed', function()
    if open then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'ringedit' })
end)
RegisterNUICallback('ringDone', function(d, cb)
    cb({ ok = true })
    if d.reset then TriggerServerEvent('dps-chat:setRingPos', false)
    elseif d.save and Logic.validPos(d.pos) then TriggerServerEvent('dps-chat:setRingPos', Logic.validPos(d.pos)) end
    open = false
    SetNuiFocus(false, false)
end)
