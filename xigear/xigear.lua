--[[
xigear: saves a character's gear, storage slips, merits, job points and master levels to a file,
for importing on xi-gear.com. It never connects to the internet.

Copyright (c) 2026 xi-gear
Portions (the bag list, and reading augments and ranks with Windower's extdata library) are based on
invdump, Copyright (c) 2026 Masin-M, used under the BSD license below.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of xigear nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

What the file holds: your character's name, server and race; every item in your inventory, wardrobes
and Mog House bags with its augments and rank; the items on your storage slips; your merits; job levels,
job points spent and master levels for each job. The addon only writes this file. It has no network code and sends nothing.
]]

_addon.name = 'xigear'
_addon.author = 'xi-gear'
_addon.version = '1.0.0'
_addon.commands = {'xigear'}

require('tables')
require('strings')
local res = require('resources')
local extdata = require('extdata')
local slips = require('slips')
local packets = require('packets')

local CHAT, ERR = 207, 167
local function say(msg, color) windower.add_to_chat(color or CHAT, 'xigear: ' .. msg) end

-- Bags, by Windower's names (same list as invdump). Temporary items and the recycle bin are left out.
local BAGS = {'inventory', 'safe', 'safe2', 'storage', 'locker', 'satchel', 'sack', 'case',
              'wardrobe', 'wardrobe2', 'wardrobe3', 'wardrobe4', 'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8'}
local JOBS = {'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
              'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN'}

------------------------------------------------------------------------------------------------------------
-- Reading the game
------------------------------------------------------------------------------------------------------------

-- An item's augments and rank, read the same way invdump does: Windower's own list first, else extdata.
local function augments_and_rank(item)
    local decoded
    if item.extdata then
        local ok, d = pcall(extdata.decode, item)
        if ok then decoded = d end
    end
    local augs = {}
    local src = item.augments or (decoded and decoded.augments) or {}
    for _, a in ipairs(src) do
        if a and a ~= 'none' and a ~= '' then augs[#augs + 1] = tostring(a) end
    end
    return augs, decoded and decoded.rank or nil
end

local function read_items()
    local all = windower.ffxi.get_items()
    if not all or not all.inventory or (all.inventory.max or 0) == 0 then return nil end
    local out = {}
    for _, bag in ipairs(BAGS) do
        local b = all[bag]
        -- Mog House bags read as "not enabled" outside the Mog House, but their contents are still there
        if b then
            for slot, item in pairs(b) do
                if type(item) == 'table' and item.id and item.id > 0 then
                    local augs, rank = augments_and_rank(item)
                    out[#out + 1] = {bag = bag, id = item.id, augments = augs, rank = rank}
                end
            end
        end
    end
    return out
end

-- Gear stored with the Porter Moogle, from Windower's slips library (it reads each slip you carry or store).
local function read_slips()
    local out = {}
    local ok, stored = pcall(slips.get_player_items)
    if not ok or not stored then return out end
    for slip_id, ids in pairs(stored) do
        for _, id in ipairs(ids) do out[#out + 1] = {slip = slip_id, id = id} end
    end
    return out
end

-- Master levels come in the game's job info packet (sent at login and when you zone).
local function read_master_levels()
    local raw = windower.packets.last_incoming(0x01B)
    if not raw then return nil end
    local ok, p = pcall(packets.parse, 'incoming', raw)
    if not ok or not p then return nil end
    local out = {}
    for id = 1, 22 do
        local job = res.jobs[id]
        local ml = job and p[job.english .. ' Master Level']
        if ml then out[job.ens] = ml end
    end
    return out
end

local function read_character()
    local player = windower.ffxi.get_player()
    if not player then return nil end
    local info = windower.ffxi.get_info()
    local me = windower.ffxi.get_mob_by_target('me')
    local race = me and res.races[me.race] and res.races[me.race].en or ''
    local items = read_items()
    if not items then return nil end
    local jp, levels = {}, {}
    for _, job in ipairs(JOBS) do
        local j = player.job_points and player.job_points[job:lower()]
        if j then jp[job] = j.jp_spent or 0 end
        local lv = player.jobs and player.jobs[job]
        if lv and lv > 0 then levels[job] = lv end
    end
    local merits = {}
    for k, v in pairs(player.merits or {}) do
        if type(v) == 'number' then merits[k] = v end
    end
    return {
        addon_version = _addon.version,
        character = player.name,
        server = info and res.servers[info.server] and res.servers[info.server].en or '',
        race = race:match('^(%a+)') or '',
        items = items,
        slips = read_slips(),
        job_levels = levels,
        job_points = jp,
        master_levels = read_master_levels(),
        merits = merits,
    }
end

------------------------------------------------------------------------------------------------------------
-- JSON (Windower's json library only reads)
------------------------------------------------------------------------------------------------------------

local function esc(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        return ({['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'})[c]
            or string.format('\\u%04x', c:byte())
    end) .. '"'
end

local function to_json(v)
    local t = type(v)
    if t == 'nil' then return 'null' end
    if t == 'boolean' or t == 'number' then return tostring(v) end
    if t == 'string' then return esc(v) end
    if #v > 0 or next(v) == nil then
        local parts = {}
        for i = 1, #v do parts[i] = to_json(v[i]) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local parts, keys = {}, {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local val = v[k]; if val == nil then val = v[tonumber(k)] end
        parts[#parts + 1] = esc(k) .. ':' .. to_json(val)
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

local data_dir = windower.addon_path .. 'data/'
local function write(path, text)
    local f = io.open(path, 'wb'); if not f then return false end
    f:write(text); f:close(); return true
end

------------------------------------------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------------------------------------------

local function save_file()
    local data = read_character()
    if not data then say('Your character and bags are still loading. Try again in a few seconds.', ERR) return end
    windower.create_dir(data_dir)
    local name = ('xigear_%s_%s.json'):format(data.character, os.date('%Y%m%d_%H%M%S'))
    if write(data_dir .. name, to_json(data)) then
        say(('Saved %s: %d items, %d on storage slips.'):format(name, #data.items, #data.slips))
        say('It\'s in Windower4/addons/xigear/data. Import it on xi-gear.com > Characters > Import.')
        if not data.master_levels then say('Master levels weren\'t loaded yet: zone once and export again to include them.') end
    else
        say("Couldn't write the file.", ERR)
    end
end

windower.register_event('addon command', function(cmd)
    cmd = (cmd or 'help'):lower()
    if cmd == 'export' then
        save_file()
    else
        say('Commands:')
        say('  //xigear export - save this character to a file for xi-gear.com > Characters > Import')
        say('  //xigear help - this list')
    end
end)
