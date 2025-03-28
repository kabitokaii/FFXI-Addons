--[[
Copyright © 2019, Arusia von Sotto
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Rune Mater nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Arusia von Sotto BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'Rune Master'
_addon.author = 'Arusia von Sotto'
_addon.version = '0.1'
_addon.language = 'english'
_addon.command = 'ar'

-- Required libraries
local res = require('resources')
local packets = require('packets')
require('sets')
require('strings')
require('actions')
require('pack')

-- Global state variables
local setRunes = {}
local activeRunes = {}
local buffs = {}
local incapacitated = false
local enableAddon = false
local acting = false
local player_id

-- Rune ID mappings for reference (buff IDs in FFXI)
local RUNE_BUFF_IDS = {
    ignis = 523,    -- Fire rune
    gelus = 524,    -- Ice rune
    flabra = 525,   -- Wind rune
    tellus = 526,   -- Earth rune
    sulpor = 527,   -- Lightning rune
    unda = 528,     -- Water rune
    lux = 529,      -- Light rune
    tenebrae = 530  -- Dark rune
}

local RUNE_NAMES = {'ignis', 'gelus', 'flabra', 'tellus', 'sulpor', 'unda', 'lux', 'tenebrae'}

----------------------------------------------------------------------------------------------
-- Function : inRunes
--
-- Checks if the entered value is a rune. Returns boolean.
----------------------------------------------------------------------------------------------
local function inRunes(val)
    for _, value in ipairs(RUNE_NAMES) do
        if value == val then
            return true
        end
    end
    return false
end

----------------------------------------------------------------------------------------------
-- Function : set_runes
--
-- Set desired runes.
----------------------------------------------------------------------------------------------
local function set_runes(arg1, arg2, arg3)
    setRunes = {}

    local function process_arg(arg)
        if arg then
            if inRunes(arg:lower()) then
                local rune = arg:lower()
                if setRunes[rune] == nil then
                    setRunes[rune] = 1
                else
                    setRunes[rune] = setRunes[rune] + 1
                end
            else
                windower.add_to_chat(2, arg .. ' is not a valid rune.')
            end
        end
    end

    process_arg(arg1)
    process_arg(arg2)
    process_arg(arg3)
end

----------------------------------------------------------------------------------------------
-- Function : activeBuffs
--
-- Gets all active buffs and updates the activeRunes table
----------------------------------------------------------------------------------------------
local function activeBuffs()
    buffs = {}
    activeRunes = {}
    
    -- Get player's buff list
    local player_buffs = windower.ffxi.get_player().buffs
    if not player_buffs then return end
    
    for _, buff_id in ipairs(player_buffs) do
        -- Check for rune buffs
        if buff_id == RUNE_BUFF_IDS.ignis then
            activeRunes.ignis = (activeRunes.ignis or 0) + 1
        elseif buff_id == RUNE_BUFF_IDS.gelus then
            activeRunes.gelus = (activeRunes.gelus or 0) + 1
        elseif buff_id == RUNE_BUFF_IDS.flabra then
            activeRunes.flabra = (activeRunes.flabra or 0) + 1
        elseif buff_id == RUNE_BUFF_IDS.tellus then
            activeRunes.tellus = (activeRunes.tellus or 0) + 1
        elseif buff_id == RUNE_BUFF_IDS.sulpor then
            activeRunes.sulpor = (activeRunes.sulpor or 0) + 1
        elseif buff_id == RUNE_BUFF_IDS.unda then
            activeRunes.unda = (activeRunes.unda or 0) + 1
        elseif buff_id == RUNE_BUFF_IDS.lux then
            activeRunes.lux = (activeRunes.lux or 0) + 1
        elseif buff_id == RUNE_BUFF_IDS.tenebrae then
            activeRunes.tenebrae = (activeRunes.tenebrae or 0) + 1
        else
            -- Check if buff id exists in resources
            if res.buffs[buff_id] and res.buffs[buff_id].english then
                local buff_name = res.buffs[buff_id].english:lower()
                buffs[buff_name] = (buffs[buff_name] or 0) + 1
            end
        end
    end

    -- Check for incapacitating debuffs
    incapacitated = buffs.sleep or buffs.petrification or buffs.stun or 
        buffs.charm or buffs.amnesia or buffs.terror or 
        buffs.lullaby or buffs.impairment or false
end

----------------------------------------------------------------------------------------------
-- Function : compare_buffs
--
-- Compares active runes with the desired runes and casts the missing ones
----------------------------------------------------------------------------------------------
local function compare_buffs()
    for _, rune in ipairs(RUNE_NAMES) do
        if setRunes[rune] then
            local active_count = activeRunes[rune] or 0
            if active_count < setRunes[rune] then
                autoJA(rune, '<me>')
                return -- Only cast one rune at a time to avoid spamming
            end
        end
    end
end

----------------------------------------------------------------------------------------------
-- Function : autoJA
--
-- Sends a command to use a job ability
----------------------------------------------------------------------------------------------
local function autoJA(str, ta)
    windower.send_command(('input /ja "%s" %s'):format(str, ta))
end 

-- Register event handlers
windower.register_event('load', function()
    incapacitated = false
    setRunes = {}
    enableAddon = false
    acting = false
    player_id = windower.ffxi.get_player().id
end)

windower.register_event('prerender', function()
    if enableAddon then
        local recast = windower.ffxi.get_ability_recasts()
        -- Check if the player data is available
        if not recast then return end
        
        activeBuffs()
        
        -- Rune ability ID is 92
        if not incapacitated and recast[92] == 0 and not acting then
            compare_buffs()
        end
    end
end)

windower.register_event('hp change', function(hp1, hp2)
    if hp1 == 0 then 
        enableAddon = false
        windower.add_to_chat(2, 'He is dead Jim, Stopping')
    end
end)

windower.register_event('addon command', function(command, arg1, arg2, arg3)
    command = command and command:lower() or ""
    
    if command == 'start' then
        windower.add_to_chat(2, 'AutoRUN: Started')
        enableAddon = true
    elseif command == 'set' then
        set_runes(arg1, arg2, arg3)
    elseif command == 'stop' then
        windower.add_to_chat(2, 'AutoRUN: Stopped')
        enableAddon = false
    elseif command == 'help' then
        windower.add_to_chat(2, 'AutoRUN Commands:')
        windower.add_to_chat(2, '//ar start - Start the addon')
        windower.add_to_chat(2, '//ar stop - Stop the addon')
        windower.add_to_chat(2, '//ar set rune1 rune2 rune3 - Set desired runes')
    end    
end)

windower.register_event('action', function(act)
    if act.actor_id == player_id then
        if (act.category > 5 and act.category < 10) or (act.category > 11) then
            if act.category == 6 then
                acting = true
                -- Note: coroutine.sleep is not standard in Lua 5.1, but is provided by Windower
                windower.send_command('wait 1; lua i AutoRUN reset_acting')
            else 
                acting = true
            end
        end
        if act.category > 1 and act.category < 6 then
            acting = false
        end    
    end
end)

-- Custom command to reset acting flag safely
windower.register_event('unhandled command', function(command, ...)
    if command == 'reset_acting' then
        acting = false
    end
end)
