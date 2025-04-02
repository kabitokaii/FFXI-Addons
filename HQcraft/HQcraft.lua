_addon.name = 'hqcraft'
_addon.author = 'Unknown'
_addon.version = '3.0.0'
_addon.command = 'hqcraft'

require('logger')
local packets = require('packets')
local config = require('config')

-- Configuration with defaults
local defaults = {
    floor_stats = {
        [1] = {attempts = 0, breaks = 0, hqs = 0},
        [2] = {attempts = 0, breaks = 0, hqs = 0}
    },
    current_floor = 1,
    auto_switch = true,
    debug_mode = false,
    preferred_floor = 0  -- 0 = auto (use stats), 1 or 2 = specific floor
}

-- Load settings
local settings = config.load(defaults)
local moghouse_floor = settings.current_floor 
local auto_switch = settings.auto_switch
local debug_mode = settings.debug_mode
local preferred_floor = settings.preferred_floor
local active_synthesis = false
local synthesis_start_time = 0
local early_prediction_delay = 2 -- seconds after crafting starts to check for outcome indicators

-- Define craft result types
local craft_results = {
    [0] = 'NQ',
    [1] = 'Break',
    [2] = 'HQ'
}

--[[ 
FFXI Crafting Packet Reference:

Outgoing packets (client to server):
0x096 - Start Synthesis/Begin Crafting
  - Sent when player initiates crafting
  - Contains recipe information and crystal used

0x0A2 - Answer to Synthesis Support Request
  - Sent when responding to a synthesis support request from another player

Incoming packets (server to client):
0x030 - Synthesis Result
  - Final result of synthesis (NQ/HQ/Break)
  - Contains Param field with result code (0=NQ, 1=Break, 2=HQ)

0x06F - Synthesis Progress/Animation
  - Sent during synthesis to show progress
  - May contain early indicators of success/failure

0x0CA - Recipe List
  - Contains list of recipes available to player

0x0CB - Recipe Details
  - Contains details about a specific recipe

0x0DC - Synthesis Support Request
  - Request from another player for synthesis support

Additional packets that might contain relevant crafting information:
0x029, 0x02A, 0x02E - Various entity update packets
  - May contain skill updates or other character state changes during crafting
]]

-- Function to switch between Mog House floors
function switch_moghouse_floor(floor)
    if type(floor) ~= 'number' then
        error("Switch to floor 1 or 2")
        return
    end

    local hex_floors = {
        [1] = 0x7E,
        [2] = 0x7D,
    }

    if debug_mode then
        log('Switching to floor ' .. floor)
    end
    
    packets.inject(packets.new('outgoing', 0x05E, { 
        ['Zone Line'] = 1903324538,
        ['Type'] = hex_floors[floor],
    }))
    
    moghouse_floor = floor
    settings.current_floor = floor
    config.save(settings)
    
    log('Moved to floor ' .. floor)
end

-- Calculate the safest floor based on break statistics
function get_safest_floor()
    local floor1_break_rate = settings.floor_stats[1].breaks / math.max(1, settings.floor_stats[1].attempts)
    local floor2_break_rate = settings.floor_stats[2].breaks / math.max(1, settings.floor_stats[2].attempts)
    
    if debug_mode then
        log(string.format("Break rates - Floor 1: %.2f%%, Floor 2: %.2f%%", 
            floor1_break_rate * 100, floor2_break_rate * 100))
    end
    
    -- If we have meaningful statistics, use them
    if settings.floor_stats[1].attempts > 5 and settings.floor_stats[2].attempts > 5 then
        if floor1_break_rate < floor2_break_rate then
            return 1
        else
            return 2
        end
    else
        -- Not enough data, default to current floor
        return moghouse_floor
    end
end

-- Check and switch to the safest floor before crafting
function prepare_for_crafting()
    if not auto_switch then return end
    
    local target_floor
    if preferred_floor > 0 then
        target_floor = preferred_floor
    else
        target_floor = get_safest_floor()
    end
    
    if moghouse_floor ~= target_floor then
        log('Switching to safer floor ' .. target_floor .. ' before crafting')
        switch_moghouse_floor(target_floor)
    end
end

-- Function to attempt to cancel a craft by switching floors
function emergency_cancel_craft()
    local target_floor = (moghouse_floor % 2) + 1
    log('⚠️ Predicting non-HQ result! Attempting emergency craft cancel by switching to floor ' .. target_floor)
    switch_moghouse_floor(target_floor)
end

-- Command handler
windower.register_event('addon command', function (...)
    local args = {...}
    if #args == 0 then
        print('HQcraft: Use //hqcraft help for command options')
    elseif args[1] == 'help' then
        print('HQcraft: Intelligently switches floors to prevent breaks')
        print('Commands:')
        print('  //hqcraft floor [1|2] - Manually switch to specified floor')
        print('  //hqcraft toggle - Enable/disable automatic floor switching')
        print('  //hqcraft prefer [0|1|2] - Set preferred floor (0=auto, 1 or 2=specific floor)')
        print('  //hqcraft status - Show current settings and statistics')
        print('  //hqcraft debug - Toggle debug mode')
        print('  //hqcraft reset - Reset floor statistics')
        print('  //hqcraft cancel - Force emergency craft cancellation')
    elseif args[1] == 'floor' and args[2] and tonumber(args[2]) then
        local floor = tonumber(args[2])
        if floor == 1 or floor == 2 then
            switch_moghouse_floor(floor)
        else
            print('HQcraft: Floor must be 1 or 2')
        end
    elseif args[1] == 'toggle' then
        auto_switch = not auto_switch
        settings.auto_switch = auto_switch
        config.save(settings)
        print('HQcraft: Auto-switching ' .. (auto_switch and 'enabled' or 'disabled'))
    elseif args[1] == 'prefer' and args[2] and tonumber(args[2]) then
        local pref = tonumber(args[2])
        if pref >= 0 and pref <= 2 then
            preferred_floor = pref
            settings.preferred_floor = pref
            config.save(settings)
            if pref == 0 then
                print('HQcraft: Using automatic floor selection based on statistics')
            else
                print('HQcraft: Preferred floor set to ' .. pref)
            end
        else
            print('HQcraft: Preferred floor must be 0 (auto), 1, or 2')
        end
    elseif args[1] == 'status' then
        print('HQcraft Status:')
        print('  Current floor: ' .. moghouse_floor)
        print('  Auto-switching: ' .. (auto_switch and 'enabled' or 'disabled'))
        print('  Preferred floor: ' .. (preferred_floor == 0 and 'auto' or tostring(preferred_floor)))
        print('  Debug mode: ' .. (debug_mode and 'enabled' or 'disabled'))
        print('  Floor 1 stats: ' .. settings.floor_stats[1].attempts .. ' attempts, ' .. 
              settings.floor_stats[1].breaks .. ' breaks, ' .. 
              settings.floor_stats[1].hqs .. ' HQs')
        print('  Floor 2 stats: ' .. settings.floor_stats[2].attempts .. ' attempts, ' .. 
              settings.floor_stats[2].breaks .. ' breaks, ' .. 
              settings.floor_stats[2].hqs .. ' HQs')
        print('  Active synthesis: ' .. (active_synthesis and 'YES' or 'no'))
    elseif args[1] == 'debug' then
        debug_mode = not debug_mode
        settings.debug_mode = debug_mode
        config.save(settings)
        print('HQcraft: Debug mode ' .. (debug_mode and 'enabled' or 'disabled'))
    elseif args[1] == 'reset' then
        settings.floor_stats = {
            [1] = {attempts = 0, breaks = 0, hqs = 0},
            [2] = {attempts = 0, breaks = 0, hqs = 0}
        }
        config.save(settings)
        print('HQcraft: Floor statistics reset')
    elseif args[1] == 'cancel' then
        emergency_cancel_craft()
    end
end)

-- Monitor for synthesis start (outgoing synthesis packet)
windower.register_event('outgoing chunk', function(id, data)
    -- Packet 0x096 is sent when starting synthesis
    if id == 0x096 then
        active_synthesis = true
        synthesis_start_time = os.time()
        if debug_mode then
            log('Synthesis started')
        end
        prepare_for_crafting()
    end
end)

-- Monitor crafting results to update statistics
windower.register_event('incoming chunk', function (id, data)
    if id == 0x30 then
        local packet = packets.parse('incoming', data)

        if packet['Player'] == windower.ffxi.get_player().id then
            -- Get and validate the crafting result
            local result_value = packet['Param']
            local result_text = craft_results[result_value]
            
            if debug_mode then
                log('Craft result: ' .. (result_text or 'Unknown (' .. tostring(result_value) .. ')'))
            end
            
            -- Update statistics for the current floor
            if result_text then
                settings.floor_stats[moghouse_floor].attempts = settings.floor_stats[moghouse_floor].attempts + 1
                
                if result_text == 'Break' then
                    settings.floor_stats[moghouse_floor].breaks = settings.floor_stats[moghouse_floor].breaks + 1
                elseif result_text == 'HQ' then
                    settings.floor_stats[moghouse_floor].hqs = settings.floor_stats[moghouse_floor].hqs + 1
                end
                
                config.save(settings)
                
                if debug_mode then
                    log(string.format('Updated floor %d stats: %d attempts, %d breaks, %d HQs', 
                        moghouse_floor, 
                        settings.floor_stats[moghouse_floor].attempts,
                        settings.floor_stats[moghouse_floor].breaks,
                        settings.floor_stats[moghouse_floor].hqs))
                end
            end
            active_synthesis = false
        end
    end

    -- Only process other packets if we're in active synthesis
    if not active_synthesis or not auto_switch then return end
    
    -- Monitor synthesis progress packet (0x06F)
    if id == 0x06F then
        local packet = packets.parse('incoming', data)
        
        if debug_mode then
            log('Synthesis progress packet received:')
            for k, v in pairs(packet) do
                if type(v) ~= 'function' then
                    log('  ' .. k .. ': ' .. tostring(v))
                end
            end
        end
        
        -- Extract potential synthesis progress indicators
        -- Parameter and Progress fields might indicate the outcome
        local param = packet['Param'] or 0
        local progress = packet['Progress'] or packet['Value'] or 0
        
        if debug_mode then
            log('Synthesis progress - Param: ' .. tostring(param) .. ', Progress: ' .. tostring(progress))
        end
        
        -- Analyze indicator values (this needs calibration with real data)
        -- These are placeholder conditions and would need refinement through testing
        if param > 0 then
            -- Higher param values might indicate risk of break
            if param > 100 then -- Threshold needs adjustment after testing
                emergency_cancel_craft()
                return
            end
        end
        
        if progress > 0 then
            -- Progress values might indicate success likelihood
            -- This is speculative and needs testing to determine actual thresholds
            if progress < 50 then -- Threshold needs adjustment after testing
                emergency_cancel_craft()
                return
            end
        end
    end
    
    -- Some packets that might contain early outcome indicators
    -- These are speculative and require testing
    if id == 0x29 or id == 0x2A or id == 0x2E then
        local packet = packets.parse('incoming', data)
        if debug_mode then
            log('Potential synthesis indicator packet ' .. id .. ' received during crafting')
            for k, v in pairs(packet) do
                if type(v) ~= 'function' then
                    log('  ' .. k .. ': ' .. tostring(v))
                end
            end
        end
        
        -- Attempt to predict outcome based on packet values
        -- This is highly experimental and would need extensive testing
        -- For now, we're just using a packet field that might indicate progress
        if packet['Param'] or packet['Value'] then
            local indicator = packet['Param'] or packet['Value']
            if debug_mode then
                log('Examining possible indicator value: ' .. tostring(indicator))
            end
            
            -- This would need proper testing to determine the actual values that indicate outcomes
            -- For now this is a placeholder implementation
            if type(indicator) == 'number' and indicator % 3 ~= 2 then -- Not HQ indication
                emergency_cancel_craft()
            end
        end
    end
end)

-- Timer to monitor crafting progress
windower.register_event('prerender', function()
    if active_synthesis and auto_switch then
        local current_time = os.time()
        
        -- Emergency timeout if synthesis somehow didn't complete
        if current_time - synthesis_start_time > 30 then -- 30 seconds max craft time
            active_synthesis = false
            if debug_mode then
                log('Synthesis timed out')
            end
        end
    end
end)

-- Display startup message
windower.register_event('load', function()
    log('HQcraft v3.0 loaded.')
    log('⚠️ EXPERIMENTAL: Attempts to cancel non-HQ crafts in progress.')
    log('This feature requires testing and may not work reliably.')
    log('Type //hqcraft status to see current statistics.')
    log('Type //hqcraft help for all commands.')
end)