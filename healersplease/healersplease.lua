-- Healers Please addon for Windower4. Track healing done by party/alliance members.

_addon.name = 'HealersPlease'
_addon.author = 'Kabitokaii, Based on Scoreboard by Suji'
_addon.version = '1.0'
_addon.commands = {'hps', 'healersplease'}

require('tables')
require('strings')
require('maths')
require('logger')
require('actions')
local file = require('files')
config = require('config')

local Display = require('display')
local display
hps_clock = require('hpsclock'):new() -- global for now
heal_db   = require('healdb'):new() -- global for now

-------------------------------------------------------

-- Conventional settings layout
local default_settings = {}
default_settings.numplayers = 8
default_settings.hpcolor = 158  -- light green color for healing
default_settings.showallihealing = true
default_settings.resetfilters = true
default_settings.visible = true
default_settings.showfellow = true
default_settings.UpdateFrequency = 0.5
default_settings.combinepets = true
default_settings.oneperline = false
default_settings.compactsc = false
default_settings.creditpethealingtoowner = false
default_settings.debug_healing = false

default_settings.display = {}
default_settings.display.pos = {}
default_settings.display.pos.x = 500
default_settings.display.pos.y = 100

default_settings.display.bg = {}
default_settings.display.bg.alpha = 200
default_settings.display.bg.red = 0
default_settings.display.bg.green = 0
default_settings.display.bg.blue = 0

default_settings.display.text = {}
default_settings.display.text.size = 10
default_settings.display.text.font = 'Courier New'
default_settings.display.text.fonts = {}
default_settings.display.text.alpha = 255
default_settings.display.text.red = 255
default_settings.display.text.green = 255
default_settings.display.text.blue = 255

settings = config.load(default_settings)

-- Accepts msg as a string or a table
function hps_output(msg)
    local prefix = 'HPS: '
    local color  = settings['hpcolor']
    
    if type(msg) == 'table' then
        for _, line in ipairs(msg) do
            windower.add_to_chat(color, prefix .. line)
        end
    else
        windower.add_to_chat(color, prefix .. msg)
    end
end

-- Debug logging function
function debug_log(msg)
    if not settings.debug_healing then
        return
    end
    
    local debug_file = file.new('data/debug_healing.log')
    local timestamp = os.date('[%Y-%m-%d %H:%M:%S] ')
    
    if not debug_file:exists() then
        debug_file:create()
    end
    
    debug_file:append(timestamp .. msg .. '\n')
end

-- Handle addon args
function handle_command(...)
    local args = {...}
    local command = args[1] or 'help'
    local params = {}
    for i = 2, #args do
        params[i-1] = args[i]
    end
    
    local chatmodes = S{'s', 'l', 'l2', 'p', 't', 'say', 'linkshell', 'linkshell2', 'party', 'tell', 'echo'}

    if command == 'e' then
        assert(loadstring(table.concat(params, ' ')))()
        return
    end

    command = command:lower()

        if command == 'help' then
            hps_output('HealersPlease v' .. _addon.version .. '. Author: Based on Scoreboard by Suji')
            hps_output('hps help : Shows help message')
            hps_output('hps pos <x> <y> : Positions the healing tracker')
            hps_output('hps reset : Resets healing data')
            hps_output('hps report [<target>] : Reports healing. Can take standard chatmode target options.')
            hps_output('hps reportstat <stat> [<player>] [<target>] : Reports the given stat. Can take standard chatmode target options. Ex: //hps rs avg p')
            hps_output('  Valid chatmode targets are: ' .. chatmodes:concat(', '))
            hps_output('hps filter show : Shows current filter settings')
            hps_output('hps filter add <target1> <target2> ... : Adds healing target patterns to the filter (substrings ok)')
            hps_output('hps filter clear : Clears target filter')
            hps_output('hps visible : Toggles healing tracker visibility')
            hps_output('hps stat <stat> [<player>] : Shows specific healing stats. Respects filters. If player isn\'t specified, stats for everyone are displayed.')
            hps_output('  Valid stats are: '..heal_db.player_stat_fields:tostring():stripchars('{}"'))
            hps_output('hps set <flag> <value> : Sets configuration variables')
            hps_output('  Valid flags are: CombinePets, NumPlayers, BGTransparency, Font, HPColor, ShowAlliHealing, ResetFilters, ShowFellow, OnePerLine, CompactSC, CreditPetHealingToOwner')
            hps_output('hps debug : Shows alliance member detection debug info')
            hps_output('hps debughealing : Toggles healing action debug output (logs to file)')
            hps_output('hps viewlog : Shows last 10 debug log entries')
            hps_output('hps clearlog : Clears the debug log file')
        elseif command == 'pos' then
            if params[2] then
                local posx, posy = tonumber(params[1]), tonumber(params[2])
                settings.display.pos.x = posx
                settings.display.pos.y = posy
                config.save(settings)
                display:set_position(posx, posy)
            end
        elseif command == 'set' then
            if not params[2] then
                return
            end

            local setting = params[1]
            if setting:lower() == 'combinepets' then
                if params[2]:lower() == 'true' then
                    settings.combinepets = true
                elseif params[2]:lower() == 'false' then
                    settings.combinepets = false
                else
                    error("Invalid value for 'CombinePets'. Must be true or false.")
                    return
                end
                settings:save()
                hps_output("Setting 'CombinePets' set to " .. tostring(settings.combinepets))
            elseif setting:lower() == 'numplayers' then
                settings.numplayers = tonumber(params[2])
                settings:save()
                display:update()
                hps_output("Setting 'NumPlayers' set to " .. settings.numplayers)
            elseif setting:lower() == 'bgtransparency' then
                settings.display.bg.alpha  = tonumber(params[2])
                settings:save()
                display:update()
                hps_output("Setting 'BGTransparency' set to " .. settings.display.bg.alpha)
            elseif setting:lower() == 'font' then
                settings.display.text.font = params[2]
                settings:save()
                display:update()
                hps_output("Setting 'Font' set to " .. settings.display.text.font)
            elseif setting:lower() == 'hpcolor' then
                settings.hpcolor = tonumber(params[2])
                settings:save()
                hps_output("Setting 'HPColor' set to " .. settings.hpcolor)
            elseif setting:lower() == 'showallihealing' then
                if params[2]:lower() == 'true' then
                    settings.showallihealing = true
                elseif params[2]:lower() == 'false' then
                    settings.showallihealing = false
                else
                    error("Invalid value for 'ShowAlliHealing'. Must be true or false.")
                    return
                end
                settings:save()
                hps_output("Setting 'ShowAlliHealing' set to " .. tostring(settings.showallihealing))
            elseif setting:lower() == 'resetfilters' then
                if params[2]:lower() == 'true' then
                    settings.resetfilters = true
                elseif params[2]:lower() == 'false' then
                    settings.resetfilters = false
                else
                    error("Invalid value for 'ResetFilters'. Must be true or false.")
                    return
                end
                settings:save()
                hps_output("Setting 'ResetFilters' set to " .. tostring(settings.resetfilters))
            elseif setting:lower() == 'showfellow' then
                if params[2]:lower() == 'true' then
                    settings.showfellow = true
                elseif params[2]:lower() == 'false' then
                    settings.showfellow = false
                else
                    error("Invalid value for 'ShowFellow'. Must be true or false.")
                    return
                end
                settings:save()
                hps_output("Setting 'ShowFellow' set to " .. tostring(settings.showfellow))
            elseif setting:lower() == 'oneperline' then
                if params[2]:lower() == 'true' then
                    settings.oneperline = true
                elseif params[2]:lower() == 'false' then
                    settings.oneperline = false
                else
                    error("Invalid value for 'OnePerLine'. Must be true or false.")
                    return
                end
                settings:save()
                hps_output("Setting 'OnePerLine' set to " .. tostring(settings.oneperline))
            elseif setting:lower() == 'compactsc' then
                if params[2]:lower() == 'true' then
                    settings.compactsc = true
                elseif params[2]:lower() == 'false' then
                    settings.compactsc = false
                else
                    error("Invalid value for 'CompactSC'. Must be true or false.")
                    return
                end
                settings:save()
                hps_output("Setting 'CompactSC' set to " .. tostring(settings.compactsc))
            elseif setting:lower() == 'creditpethealingtoowner' then
                if params[2]:lower() == 'true' then
                    settings.creditpethealingtoowner = true
                elseif params[2]:lower() == 'false' then
                    settings.creditpethealingtoowner = false
                else
                    error("Invalid value for 'CreditPetHealingToOwner'. Must be true or false.")
                    return
                end
                settings:save()
                hps_output("Setting 'CreditPetHealingToOwner' set to " .. tostring(settings.creditpethealingtoowner))
            end
        elseif command == 'reset' then
            reset()
        elseif command == 'report' then
            local arg = params[1]
            local arg2 = params[2]

            if arg then
                if chatmodes:contains(arg) then
                    if arg == 't' or arg == 'tell' then
                        if not arg2 then
                            -- should be a valid player name
                            error('Invalid argument for report t: Please include player target name.')
                            return
                        elseif not arg2:match('^[a-zA-Z]+$') then
                            error('Invalid argument for report t: ' .. arg2)
                        end
                    end
                else
                    error('Invalid parameter passed to report: ' .. arg)
                    return
                end
            end

            display:report_summary(arg, arg2)

        elseif command == 'visible' then
            display:update()
            display:visibility(not settings.visible)

        elseif command == 'filter' then
            local subcmd
            if params[1] then
                subcmd = params[1]:lower()
            else
                error('Invalid option to //hps filter. See //hps help')
                return
            end
            
            if subcmd == 'add' then
                for i=2, #params do
                    heal_db:add_filter(params[i])
                end
                display:update()
            elseif subcmd == 'clear' then
                heal_db:clear_filters()
                display:update()
            elseif subcmd == 'show' then
                display:report_filters()
            else
                error('Invalid argument to //hp filter')
            end
        elseif command == 'stat' then
            if not params[1] or not heal_db.player_stat_fields:contains(params[1]:lower()) then
                error('Must pass a stat specifier to //hps stat. Valid arguments: ' ..
                      heal_db.player_stat_fields:tostring():stripchars('{}"'))
            else
                local stat = params[1]:lower()
                local player = params[2]
                display:show_stat(stat, player)
            end
        elseif command == 'reportstat' or command == 'rs' then
            if not params[1] or not heal_db.player_stat_fields:contains(params[1]:lower()) then
                error('Must pass a stat specifier to //hps reportstat. Valid arguments: ' ..
                      heal_db.player_stat_fields:tostring():stripchars('{}"'))
                return
            end
            
            local stat = params[1]:lower()
            local arg2 = params[2] -- either a player name or a chatmode
            local arg3 = params[3] -- can only be a chatmode

            -- The below logic is obviously bugged if there happens to be a player named "say",
            -- "party", "linkshell" etc but I don't care enough to account for those people!
            
            if chatmodes:contains(arg2) then
                -- Arg2 is a chatmode so we assume this is a 3-arg version (no player specified)
                display:report_stat(stat, {chatmode = arg2, telltarget = arg3})
            else
                -- Arg2 is not a chatmode, so we assume it's a player name and then see
                -- if arg3 looks like an optional chatmode.
                if arg2 and not arg2:match('^[a-zA-Z]+$') then
                    -- should be a valid player name
                    error('Invalid argument for reportstat t ' .. arg2)
                    return
                end
                
                if arg3 and not chatmodes:contains(arg3) then
                    error('Invalid argument for reportstat t ' .. arg2 .. ', must be a valid chatmode.')
                    return
                end
                
                display:report_stat(stat, {player = arg2, chatmode = arg3, telltarget = params[4]})
            end
        elseif command == 'fields' then
            error("Not implemented yet.")
            return
        elseif command == 'save' then
            if params[1] then
                if not params[1]:match('^[a-ZA-Z0-9_-,.:]+$') then
                    error("Invalid filename: " .. params[1])
                    return
                end
                save(params[1])
            else
                save()
            end
        elseif command == 'debug' then
            local allies = get_ally_mob_ids()
            hps_output('Alliance member IDs detected: ' .. allies:length())
            local party = windower.ffxi.get_party()
            
            -- Show party members
            for i = 0, 5 do
                local member = party['p' .. i]
                if member and member.mob then
                    hps_output('Party ' .. i .. ': ' .. member.mob.name .. ' (ID: ' .. member.mob.id .. ')')
                end
            end
            
            -- Show alliance members
            for i = 10, 15 do
                local member = party['a' .. i]
                if member and member.mob then
                    hps_output('Alliance Party 2 ' .. (i-10) .. ': ' .. member.mob.name .. ' (ID: ' .. member.mob.id .. ')')
                end
            end
            
            for i = 20, 25 do
                local member = party['a' .. i]
                if member and member.mob then
                    hps_output('Alliance Party 3 ' .. (i-20) .. ': ' .. member.mob.name .. ' (ID: ' .. member.mob.id .. ')')
                end
            end
        elseif command == 'debughealing' then
            settings.debug_healing = not settings.debug_healing
            settings:save()
            hps_output('Healing debug mode: ' .. (settings.debug_healing and 'ON' or 'OFF'))
            if settings.debug_healing then
                hps_output('Debug output will be logged to: addons/healersplease/data/debug_healing.log')
            end
        elseif command == 'clearlog' then
            local debug_file = file.new('data/debug_healing.log')
            if debug_file:exists() then
                debug_file:delete()
            end
            hps_output('Debug log cleared.')
        elseif command == 'viewlog' then
            local debug_file = file.new('data/debug_healing.log')
            if debug_file:exists() then
                local lines = debug_file:read():split('\n')
                local start = math.max(1, #lines - 10)  -- Show last 10 lines
                hps_output('Last ' .. math.min(10, #lines) .. ' debug log entries:')
                for i = start, #lines do
                    if lines[i] and lines[i] ~= '' then
                        hps_output(lines[i])
                    end
                end
            else
                hps_output('No debug log file found.')
            end
        else
            error('Unrecognized command. See //hp help')
        end
end

windower.register_event('addon command', handle_command)

-- Set up event handlers
windower.register_event('prerender', function()
    update_hps_clock()
end)

local months = {
    'jan', 'feb', 'mar', 'apr',
    'may', 'jun', 'jul', 'aug',
    'sep', 'oct', 'nov', 'dec'
}


function save(filename)
    if not filename then
        local date = os.date("*t", os.time())
        filename = string.format("hp_%s-%d-%d-%d-%d.txt",
                                  months[date.month],
                                  date.day,
                                  date.year,
                                  date.hour,
                                  date.min)
    end
    local parse = file.new('data/parses/' .. filename)

    if parse:exists() then
        local dup_path = file.new(parse.path)
        local dup = 0

        while dup_path:exists() do
            dup_path = file.new(parse.path .. '.' .. dup)
            dup = dup + 1
        end
        parse = dup_path
    end

    parse:create()
end


-- Resets application state
function reset()
    if settings.resetfilters then
        heal_db:clear_filters()
    end
    display:reset()
    hps_clock:reset()
    heal_db:reset()
end


-- Initialize the display
display = Display:new(settings, heal_db)

-- Keep updates flowing
function update_hps_clock()
    local player = windower.ffxi.get_player()
    local pet
    if player ~= nil then
        local player_mob = windower.ffxi.get_mob_by_id(player.id)
        if player_mob ~= nil then
            local pet_index = player_mob.pet_index
            if pet_index ~= nil then
                pet = windower.ffxi.get_mob_by_index(pet_index)
            end
        end
    end
    if player and (player.in_combat or (pet ~= nil and pet.status == 1)) then
        hps_clock:advance()
    else
        hps_clock:pause()
    end

    display:update()
end

-- Returns all mob IDs for anyone in your alliance, including their pets.
function get_ally_mob_ids()
    local allies = T{}
    local party = windower.ffxi.get_party()

    -- Handle regular party members (p0-p5)
    for i = 0, 5 do
        local member = party['p' .. i]
        if member and member.mob then
            allies:append(member.mob.id)
            if member.mob.pet_index and member.mob.pet_index > 0 then
                local pet = windower.ffxi.get_mob_by_index(member.mob.pet_index)
                if pet then
                    allies:append(pet.id)
                end
            end
        end
    end

    -- Handle alliance members (a10-a15 for party 2, a20-a25 for party 3)
    for i = 10, 15 do
        local member = party['a' .. i]
        if member and member.mob then
            allies:append(member.mob.id)
            if member.mob.pet_index and member.mob.pet_index > 0 then
                local pet = windower.ffxi.get_mob_by_index(member.mob.pet_index)
                if pet then
                    allies:append(pet.id)
                end
            end
        end
    end

    for i = 20, 25 do
        local member = party['a' .. i]
        if member and member.mob then
            allies:append(member.mob.id)
            if member.mob.pet_index and member.mob.pet_index > 0 then
                local pet = windower.ffxi.get_mob_by_index(member.mob.pet_index)
                if pet then
                    allies:append(pet.id)
                end
            end
        end
    end

    if settings.showfellow then
        local fellow = windower.ffxi.get_mob_by_target("ft")
        if fellow ~= nil then
            allies:append(fellow.id)
        end
    end
    
    return allies
end

-- Returns true if is someone (or a pet of someone) in your alliance.
function mob_is_ally(mob_id)
    -- get zone-local ids of all allies and their pets
    return get_ally_mob_ids():contains(mob_id)
end

function action_handler(raw_actionpacket)
    local actionpacket = ActionPacket.new(raw_actionpacket)
    
    local player = windower.ffxi.get_player()
    local pet
    if player ~= nil then
        local player_mob = windower.ffxi.get_mob_by_id(player.id)
        if player_mob ~= nil then
            local pet_index = player_mob.pet_index
            if pet_index ~= nil then
                pet = windower.ffxi.get_mob_by_index(pet_index)
            end
        end
    end
    -- Only skip if player is not logged in
    if not player then
        return
    end
    
    if actionpacket and actionpacket.get_targets then
        for target in actionpacket:get_targets() do
            for subactionpacket in target:get_actions() do
                if (actionpacket.raw and target.raw and mob_is_ally(actionpacket.raw.actor_id) and mob_is_ally(target.raw.id)) then
                    -- Parse healing actions within the alliance
                    local main  = subactionpacket:get_basic_info()
                    local add   = subactionpacket:get_add_effect()
                    
                    -- Debug output for missed healing (enable with debug setting)
                    if settings.debug_healing then
                        debug_log('Action: ' .. actionpacket:get_actor_name() .. ' -> ' .. target:get_name() .. 
                                 ' | MsgID: ' .. (main.message_id or 'nil') .. 
                                 ' | Param: ' .. (main.param or 'nil') .. 
                                 ' | Category: ' .. (actionpacket.raw.category or 'nil'))
                    end
                    
                    local healing_detected = false
                    
                    -- Check for healing spell effects (message IDs for healing)
                    if main.message_id == 7 then  -- Standard healing spell
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 24 then  -- Cure critical
                        heal_db:add_healing_crit(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 103 then  -- Healing magic effect
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 102 then  -- Blue magic healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 238 then  -- Status recovery spell
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 306 then  -- Divine magic healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 367 then  -- Job ability healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 375 then  -- Additional healing effect
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 384 then  -- Drain/Aspir heal
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 385 then  -- Drain/Aspir critical heal
                        heal_db:add_healing_crit(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 370 then  -- Additional healing type
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 75 then  -- Regen/DoT healing effect
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 6 then  -- Magic recovery
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 263 then  -- Job ability recovery
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 266 then  -- AoE healing effect
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 42 then  -- Status removal with healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 341 then  -- Additional healing type
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 570 then  -- Special healing effect
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 230 then  -- Self-healing magic
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 420 then  -- Job ability self-healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 421 then  -- Job ability healing others
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 424 then  -- Job ability enhanced healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 100 then  -- Self job ability healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 115 then  -- Job ability healing type 1
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    elseif main.message_id == 118 then  -- Job ability healing type 2
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    -- Broad category check for magic actions with positive HP changes
                    elseif actionpacket.raw.category == 4 and main.param and main.param > 0 then  -- Magic category
                        -- For magic category with positive HP effects, assume it's healing
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    -- Job ability category with HP gain
                    elseif actionpacket.raw.category == 6 and main.param and main.param > 0 then  -- Job ability category
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    -- Item usage with HP gain
                    elseif actionpacket.raw.category == 9 and main.param and main.param > 0 then  -- Item category
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    -- Weapon skill with healing component
                    elseif actionpacket.raw.category == 3 and main.param and main.param > 0 then  -- WS category
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    -- Blue Magic healing (different category)
                    elseif actionpacket.raw.category == 14 and main.param and main.param > 0 then  -- Blue Magic category
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    -- General HP gain fallback
                    elseif main.conclusion and main.conclusion.subject == 'target' and T(main.conclusion.objects):contains('HP') and main.param > 0 then
                        heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), main.param)
                        healing_detected = true
                    end
                    
                    -- Check for additional healing effects
                    if add and add.param and add.param > 0 then
                        if add.conclusion and add.conclusion.subject == 'target' and T(add.conclusion.objects):contains('HP') then
                            heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), add.param)
                            healing_detected = true
                        elseif add.message_id and (add.message_id == 7 or add.message_id == 24 or add.message_id == 103 or add.message_id == 102 or add.message_id == 263 or add.message_id == 266 or add.message_id == 42) then
                            heal_db:add_healing(target:get_name(), create_mob_name(actionpacket), add.param)
                            healing_detected = true
                        end
                    end
                    
                    -- Debug output for missed potential healing
                    if settings.debug_healing and not healing_detected and main.param and main.param > 0 then
                        debug_log('MISSED?: ' .. actionpacket:get_actor_name() .. ' -> ' .. target:get_name() .. 
                                 ' | MsgID: ' .. (main.message_id or 'nil') .. 
                                 ' | Param: ' .. main.param .. 
                                 ' | Category: ' .. (actionpacket.raw.category or 'nil') ..
                                 ' | SpellID: ' .. (actionpacket.raw.param or 'unknown'))
                    end
                end
            end
        end
    end
end

ActionPacket.open_listener(action_handler)

function find_pet_owner_name(actionpacket)
    if not actionpacket or not actionpacket.get_id then
        return nil, nil
    end
    
    local pet = windower.ffxi.get_mob_by_id(actionpacket:get_id())
    if not pet then
        return nil, nil
    end
    
    local party = windower.ffxi.get_party()
    local name = nil
    
    -- Check regular party members (p0-p5)
    for i = 0, 5 do
        local member = party['p' .. i]
        if member and member.mob then
            if member.mob.pet_index and member.mob.pet_index > 0 and pet.index == member.mob.pet_index then
                name = member.mob.name
                break
            end
        end
    end
    
    -- Check alliance members (a10-a15 for party 2, a20-a25 for party 3)
    if not name then
        for i = 10, 15 do
            local member = party['a' .. i]
            if member and member.mob then
                if member.mob.pet_index and member.mob.pet_index > 0 and pet.index == member.mob.pet_index then
                    name = member.mob.name
                    break
                end
            end
        end
    end
    
    if not name then
        for i = 20, 25 do
            local member = party['a' .. i]
            if member and member.mob then
                if member.mob.pet_index and member.mob.pet_index > 0 and pet.index == member.mob.pet_index then
                    name = member.mob.name
                    break
                end
            end
        end
    end
    
    return name, pet.name
end

function create_mob_name(actionpacket)
    local actor = actionpacket:get_actor_name()
    local result = ''
    local owner, pet = find_pet_owner_name(actionpacket)
    if owner ~= nil then
        if pet == nil then
            return actor
        elseif settings.combinepets then
            result = "Pets"
        elseif settings.creditpethealingtoowner then
            result = owner
        else
            result = string.sub(pet, 1, 8) .. " (" .. string.sub(owner, 1, 3) .. ")"
        end
        return result
    else
        return actor
    end
end

config.register(settings, function()
    display:visibility(settings.visible and windower.ffxi.get_info().logged_in)
end)
--[[
Copyright (c) 2013-2014, Jerry Hebert
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of HealersPlease nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
