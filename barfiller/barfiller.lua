--[[    BSD License Disclaimer
        Copyright © 2015, Morath86
        All rights reserved.

        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are met:

            * Redistributions of source code must retain the above copyright
              notice, this list of conditions and the following disclaimer.
            * Redistributions in binary form must reproduce the above copyright
              notice, this list of conditions and the following disclaimer in the
              documentation and/or other materials provided with the distribution.
            * Neither the name of BarFiller nor the
              names of its contributors may be used to endorse or promote products
              derived from this software without specific prior written permission.

        THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
        ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
        WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
        DISCLAIMED. IN NO EVENT SHALL Morath86 BE LIABLE FOR ANY
        DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
        (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
        LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
        ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
        (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
        SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'BarFiller'
_addon.author = 'Morath'
_addon.version = '0.2.5'
_addon.commands = {'bf','barfiller'}
_addon.language = 'english'


-- Windower Libs
local config = require('config')
local file = require('files')
local packets = require('packets')
local texts = require('texts')
local images = require('images')

-- BarFiller Libs
require('statics')

-- Load settings
local settings
local function load_settings()
    local status, err = pcall(function()
        settings = config.load(defaults)
        config.save(settings)
    end)
    if not status then
        windower.add_to_chat(167, 'BarFiller: Error loading settings - ' .. err)
        return false
    end
    return true
end

if not load_settings() then return end

-- Create UI elements
local background_image, foreground_image, rested_bonus_image, exp_text
local function create_ui_elements()
    local status, err = pcall(function()
        background_image = images.new(settings.Images.Background)
        foreground_image = images.new(settings.Images.Foreground)
        rested_bonus_image = images.new(settings.Images.RestedBonus)
        exp_text = texts.new(settings.Texts.Exp)
    end)
    if not status then
        windower.add_to_chat(167, 'BarFiller: Error creating UI elements - ' .. err)
        return false
    end
    return true
end

if not create_ui_elements() then return end

-- Make important variables local to prevent global namespace pollution
local debug = false
local ready = false
local chunk_update = false
local xp = {current = 0, total = 0, tnl = 0}
local last_update = 0 -- Move this outside the event to persist between frames

-- These functions should be defined in statics.lua or elsewhere
-- Provided here as stubs with documentation in case they're not defined

--[[
    initialize() - Sets up the addon's initial state when loading or after clearing
    Ensures the addon is properly configured and ready to display
]]
if not initialize then
    function initialize()
        windower.add_to_chat(8, 'BarFiller: initialize() function not properly defined')
    end
end

--[[
    hide() - Hides the UI elements
    Called on logout or when toggling visibility
]]
if not hide then
    function hide()
        windower.add_to_chat(8, 'BarFiller: hide() function not properly defined')
    end
end

--[[
    show() - Shows the UI elements
    Called when toggling visibility
]]
if not show then
    function show()
        windower.add_to_chat(8, 'BarFiller: show() function not properly defined')
    end
end

--[[
    exp_msg(param, message_id) - Processes experience messages
    param: The experience value
    message_id: The message type identifier
]]
if not exp_msg then
    function exp_msg(param, message_id)
        windower.add_to_chat(8, 'BarFiller: exp_msg() function not properly defined')
    end
end

--[[
    calc_new_width() - Calculates the new width for the foreground bar
    Returns: The calculated width based on current experience proportion
]]
if not calc_new_width then
    function calc_new_width()
        windower.add_to_chat(8, 'BarFiller: calc_new_width() function not properly defined')
        return 0
    end
end

--[[
    update_strings() - Updates the displayed text values
    Updates experience text based on current values
]]
if not update_strings then
    function update_strings()
        windower.add_to_chat(8, 'BarFiller: update_strings() function not properly defined')
    end
end

--[[
    mog_house() - Handles zone change events
    Adjusts display when entering/leaving Mog House
]]
if not mog_house then
    function mog_house()
        windower.add_to_chat(8, 'BarFiller: mog_house() function not properly defined')
    end
end

--[[
    display_help() - Displays help information for the addon
    Lists available commands and their usage
]]
if not display_help then
    function display_help()
        windower.add_to_chat(8, 'BarFiller: Available commands:')
        windower.add_to_chat(8, '//bf help (h) - Display this help message')
        windower.add_to_chat(8, '//bf clear (c) - Reset the addon')
        windower.add_to_chat(8, '//bf visible (v) - Toggle visibility')
        windower.add_to_chat(8, '//bf reload (r) - Reload the addon')
        windower.add_to_chat(8, '//bf unload (u) - Unload the addon')
    end
end

windower.register_event('load',function()
    if windower.ffxi.get_info().logged_in then
        local status, err = pcall(initialize)
        if not status then
            windower.add_to_chat(167, 'BarFiller: Error during initialization - ' .. err)
        end
    end
end)

windower.register_event('login',function()
    local status, err = pcall(initialize)
    if not status then
        windower.add_to_chat(167, 'BarFiller: Error during initialization - ' .. err)
    end
end)

windower.register_event('logout',function()
    local status, err = pcall(hide)
    if not status then
        windower.add_to_chat(167, 'BarFiller: Error hiding UI - ' .. err)
    end
end)

--[[
    Command handler for the addon
    Available commands:
    - clear/c: Reinitializes the addon
    - visible/v: Toggles UI visibility
    - reload/r: Reloads the addon
    - unload/u: Unloads the addon
    - help/h: Displays help information
]]
windower.register_event('addon command',function(command, ...)
    local commands = {...}
    local first_cmd = (command or 'help'):lower()
    
    local status, err = pcall(function()
        if approved_commands[first_cmd] and #commands >= approved_commands[first_cmd].n then
            if first_cmd == 'clear' or first_cmd == 'c' then
                initialize()
            elseif first_cmd == 'visible' or first_cmd == 'v' then
                if ready then hide() else show() end
            elseif first_cmd == 'reload' or first_cmd == 'r' then
                windower.add_to_chat(8,'BarFiller successfully reloaded.')
                windower.send_command('lua r barfiller;')
            elseif first_cmd == 'unload' or first_cmd == 'u' then
                windower.send_command('lua u barfiller;')
                windower.add_to_chat(8,'BarFiller successfully unloaded.')
            elseif first_cmd == 'help' or first_cmd == 'h' then
                display_help()
            end
        else
            display_help()
        end
    end)
    
    if not status then
        windower.add_to_chat(167, 'BarFiller: Error processing command - ' .. err)
    end
end)

--[[
    Packet handling for experience updates
    Packet 0x2D: Contains experience gain/loss messages
    Packet 0x61: Contains character status update including current/total experience
]]
windower.register_event('incoming chunk',function(id,org,modi,is_injected,is_blocked)
    if is_injected then return end
    if ready then
        -- Wrap packet parsing in pcall for error handling
        local status, packet_table = pcall(function()
            return packets.parse('incoming', org)
        end)
        
        if not status then
            if debug then
                windower.add_to_chat(167, 'BarFiller: Error parsing packet - ' .. tostring(packet_table))
            end
            return
        end
        
        if id == 0x2D then
            -- Packet 0x2D: Experience point message packet
            -- Contains information about gained/lost XP and related messages
            local status_exp, err_exp = pcall(function()
                exp_msg(packet_table['Param 1'], packet_table['Message'])
            end)
            if not status_exp and debug then
                windower.add_to_chat(167, 'BarFiller: Error processing XP message - ' .. err_exp)
            end
        elseif id == 0x61 then
            -- Packet 0x61: Character update packet
            -- Contains current character status including XP values
            xp.current = packet_table['Current EXP']
            xp.total = packet_table['Required EXP']
            xp.tnl = xp.total - xp.current
            chunk_update = true
        end
    end
end)

windower.register_event('prerender',function()
    if ready and chunk_update then
        local old_width = foreground_image:width()
        local new_width
        
        -- Get new bar width with error handling
        local status, result = pcall(calc_new_width)
        if status then
            new_width = result
        else
            if debug then
                windower.add_to_chat(167, 'BarFiller: Error calculating width - ' .. result)
            end
            return
        end

        -- Thanks to Iryoku for the logic on smooth animations
        if new_width ~= nil and new_width > 0 then
            if old_width < new_width then
                -- Use os.clock() for smoother timing (returns fractional seconds)
                local x = old_width + math.ceil(((new_width - old_width) * 0.1))
                
                -- Add error handling for size change
                local status_size, err_size = pcall(function()
                    foreground_image:size(x, settings.Images.Foreground.Size.Height)
                end)
                
                if not status_size and debug then
                    windower.add_to_chat(167, 'BarFiller: Error resizing bar - ' .. err_size)
                    return
                end
                
                if debug then print(old_width, x, new_width) end

                local now = os.clock()
                if now - last_update > 0.5 then
                    -- Update strings with error handling
                    local status_update, err_update = pcall(update_strings)
                    if not status_update and debug then
                        windower.add_to_chat(167, 'BarFiller: Error updating strings - ' .. err_update)
                    end
                    last_update = now
                end
            elseif old_width >= new_width then
                -- Add error handling for final size change
                local status_final, err_final = pcall(function()
                    foreground_image:size(new_width, settings.Images.Foreground.Size.Height)
                end)
                
                if not status_final and debug then
                    windower.add_to_chat(167, 'BarFiller: Error setting final size - ' .. err_final)
                    return
                end
                
                chunk_update = false
                if debug then print(chunk_update) end
            end
        end
    end
end)

windower.register_event('level up', function(level)
    local status, err = pcall(update_strings)
    if not status and debug then
        windower.add_to_chat(167, 'BarFiller: Error updating strings on level up - ' .. err)
    end
end)

windower.register_event('level down', function(level)
    local status, err = pcall(update_strings)
    if not status and debug then
        windower.add_to_chat(167, 'BarFiller: Error updating strings on level down - ' .. err)
    end
end)

windower.register_event('zone change', function(new_id,old_id)
    local status, err = pcall(mog_house)
    if not status and debug then
        windower.add_to_chat(167, 'BarFiller: Error processing zone change - ' .. err)
    end
end)
