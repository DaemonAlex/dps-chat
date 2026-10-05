-- SERVER. Every event checks its input and is rate limited per player; admin actions are
-- checked here, never trusted from the player. Built for a full server: nothing loops per frame.

local gate = {}      -- rate gates: gate['<event>:<src>'] = last time (ms)
local lastLine = {}  -- last /me or /do per player, to drop repeats
local function now() return GetGameTimer() end
local function allowed(src, name, gap) return Logic.rateOk(gate, name .. ':' .. src, now(), gap) end

AddEventHandler('playerDropped', function()
    local src = source
    for _, k in ipairs({ 'cmds', 'bubble', 'pos', 'edit', 'setpos', 'ringget', 'ringedit', 'ringset' }) do gate[k .. ':' .. src] = nil end
    lastLine[src] = nil
end)

-- The commands this player may run, for the suggestion list (a command is offered when the
-- player passes its command.<name> ace, the same rule the default chat used).
RegisterNetEvent('dps-chat:requestCommands', function()
    local src = source
    if not allowed(src, 'cmds', 10000) then return end
    local list = {}
    for _, c in ipairs(GetRegisteredCommands()) do
        if Logic.listable(c.name) and IsPlayerAceAllowed(src, ('command.%s'):format(c.name)) then list[#list + 1] = c.name end
    end
    TriggerClientEvent('dps-chat:serverCommands', src, list)
end)

-- Scripts that still send chat to everyone: nothing to show on a voice-only server.
AddEventHandler('chatMessage', function() CancelEvent() end)

-- /me, /do and /try: a short line over the player's head, sent only to players close enough to see it.
local BUBBLE_RANGE = 25.0
local function bubble(kind)
    return function(src, args)
        if type(src) ~= 'number' or src <= 0 then return end
        local text = Logic.cleanText(table.concat(type(args) == 'table' and args or {}, ' '))
        if not text then return end
        if not allowed(src, 'bubble', Logic.BUBBLE_GAP_MS) then return end
        if Logic.isRepeat(lastLine, src, text, now()) then return end
        local ok = nil
        if kind == 'try' then ok = math.random(2) == 1 end   -- 50/50, rolled here so nobody can pick the result
        local ped = GetPlayerPed(src)
        if ped == 0 then return end
        local here, bucket = GetEntityCoords(ped), GetPlayerRoutingBucket(src)
        for _, id in ipairs(GetPlayers()) do
            local other = GetPlayerPed(id)
            if other ~= 0 and GetPlayerRoutingBucket(id) == bucket and #(GetEntityCoords(other) - here) <= BUBBLE_RANGE then
                TriggerClientEvent('dps-chat:bubble', tonumber(id), src, kind, text, ok)
            end
        end
    end
end
RegisterCommand('me', bubble('me'), false)
RegisterCommand('do', bubble('do'), false)
RegisterCommand('try', bubble('try'), false)

-- The box's spot on screen: one for everyone, kept in this resource's server storage.
-- Only admins (the 'admin' ace, group.admin) may change it with /chatbox.
local POS_KEY = 'pos'
local cachedPos, posRead = nil, false
local function readPos()
    if posRead then return cachedPos end
    posRead = true
    local raw = GetResourceKvpString(POS_KEY)
    if raw and raw ~= '' then
        local ok, pos = pcall(json.decode, raw)
        cachedPos = ok and Logic.validPos(pos) or nil
    end
    return cachedPos
end
local function isAdmin(src)
    local ok = IsPlayerAceAllowed(src, 'admin')
    return ok == true or ok == 1
end

RegisterNetEvent('dps-chat:getPos', function()
    local src = source
    if not allowed(src, 'pos', 5000) then return end
    TriggerClientEvent('dps-chat:pos', src, readPos())
end)

RegisterNetEvent('dps-chat:editRequest', function()
    local src = source
    if not allowed(src, 'edit', 2000) or not isAdmin(src) then return end
    TriggerClientEvent('dps-chat:editAllowed', src)
end)

RegisterNetEvent('dps-chat:setPos', function(pos)
    local src = source
    if not allowed(src, 'setpos', 2000) or not isAdmin(src) then return end
    if pos == false then
        DeleteResourceKvp(POS_KEY)
        cachedPos = nil
    else
        local p = Logic.validPos(pos)
        if not p then return end
        SetResourceKvp(POS_KEY, json.encode(p))
        cachedPos = p
    end
    posRead = true
    TriggerClientEvent('dps-chat:pos', -1, cachedPos)
end)

-- The minimap ring's spot: one for everyone, server KVP, set by admins with /mapring.
local RING_KEY = 'ring'
local function readRing()
    local raw = GetResourceKvpString(RING_KEY)
    if not raw or raw == '' then return nil end
    local ok, pos = pcall(json.decode, raw)
    return ok and Logic.validPos(pos) or nil
end
RegisterNetEvent('dps-chat:getRingPos', function()
    local src = source
    if not allowed(src, 'ringget', 5000) then return end
    TriggerClientEvent('dps-chat:ringpos', src, readRing())
end)
RegisterNetEvent('dps-chat:ringEditRequest', function()
    local src = source
    if not allowed(src, 'ringedit', 2000) or not isAdmin(src) then return end
    TriggerClientEvent('dps-chat:ringEditAllowed', src)
end)
RegisterNetEvent('dps-chat:setRingPos', function(pos)
    local src = source
    if not allowed(src, 'ringset', 2000) or not isAdmin(src) then return end
    if pos == false then DeleteResourceKvp(RING_KEY)
    else
        local p = Logic.validPos(pos)
        if not p then return end
        SetResourceKvp(RING_KEY, json.encode(p))
    end
    TriggerClientEvent('dps-chat:ringpos', -1, readRing())
end)
