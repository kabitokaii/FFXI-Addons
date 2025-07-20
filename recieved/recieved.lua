--[[
Recieved Addon for Windower4
This addon receives tells from whitelisted players and executes console commands
Author: kabitokaii
--]]

_addon.name = 'Recieved'
_addon.author = 'kabitokaii'
_addon.version = '1.0.0'
_addon.commands = {'recieved'}

require('logger')
require('strings')
local config = require('config')

-- Default settings
local defaults = {
    whitelist = {
        'Dworkkin',
        'kabitokaii',
        -- Add more player names here (case-sensitive)
    },
    respond_on_success = true,
    respond_on_failure = true,
    log_commands = true,
    case_sensitive = false
}

-- Load settings
local settings = config.load(defaults)

-- Command mappings (tell command -> console command)
local command_mappings = {
    ['sm on'] = 'sm on',
    ['sm off'] = 'sm off',
    ['sm follow'] = 'sm follow %s',
    ['SW EA2'] = 'hp all easta 2',
    ['SG MMS'] = 'sg all meri mountains s',
    ['teleholla'] = '/ma "Teleport-Holla" <me>',
    ['teledem'] = '/ma "Teleport-Dem" <me>',
    ['telealtep'] = '/ma "Teleport-Altep" <me>',
    ['telemea'] = '/ma "Teleport-Mea" <me>'


    -- Add more command mappings as needed
}

-- Function to check if player is whitelisted
local function is_whitelisted(player_name)
    for _, whitelisted_player in ipairs(settings.whitelist) do
        if settings.case_sensitive then
            if player_name == whitelisted_player then
                return true
            end
        else
            if player_name:lower() == whitelisted_player:lower() then
                return true
            end
        end
    end
    return false
end

-- Function to parse and execute command
local function execute_command(player_name, message)
    local command_parts = message:split(' ')
    local base_command = command_parts[1] and command_parts[1]:lower() or ''
    local full_command = message:lower()
    
    -- Debug logging
    if settings.log_commands then
        log(('Attempting to execute command: "%s" from %s'):format(message, player_name))
        log(('Command parts: %s'):format(table.concat(command_parts, ', ')))
        log(('Full command (lowercase): "%s"'):format(full_command))
    end
    
    -- Check for direct command mappings first
    if command_mappings[full_command] then
        local console_command = command_mappings[full_command]
        windower.send_command(console_command)
        
        if settings.log_commands then
            log(('Executed command: %s (from %s)'):format(console_command, player_name))
        end
        
        if settings.respond_on_success then
            windower.send_command(('input /tell %s Command executed: %s'):format(player_name, console_command))
        end
        return true
    end
    
    -- Check for commands with parameters (like "sm follow playername")
    if base_command == 'sm' and command_parts[2] then
        local subcommand = command_parts[2]:lower()
        local param_command = base_command .. ' ' .. subcommand
        
        if settings.log_commands then
            log(('Checking parameter command: "%s"'):format(param_command))
        end
        
        if command_mappings[param_command] then
            local console_command
            if command_parts[3] then
                -- Command has additional parameter
                console_command = command_mappings[param_command]:format(command_parts[3])
            else
                console_command = command_mappings[param_command]
            end
            
            windower.send_command(console_command)
            
            if settings.log_commands then
                log(('Executed command: %s (from %s)'):format(console_command, player_name))
            end
            
            if settings.respond_on_success then
                windower.send_command(('input /tell %s Command executed: %s'):format(player_name, console_command))
            end
            return true
        end
    end
    
    -- Command not found
    if settings.log_commands then
        log(('Command not found in mappings: "%s"'):format(full_command))
    end
    
    return false
end

-- Event handler for incoming tells
function handle_chat_message(message, player, mode, is_gm)
    -- Check if this is a tell (mode 3)
    if mode == 3 then
        -- Clean up player name and message (they should already be clean)
        local player_name = player:trim()
        local tell_message = message:trim()
        
        -- Check if player is whitelisted
        if is_whitelisted(player_name) then
            if settings.log_commands then
                log(('Received tell from whitelisted player %s: %s'):format(player_name, tell_message))
            end
            
            -- Try to execute the command
            local success = execute_command(player_name, tell_message)
            
            if not success and settings.respond_on_failure then
                windower.send_command(('input /tell %s Unknown command: %s'):format(player_name, tell_message))
            end
        else
            -- Player not whitelisted
            if settings.log_commands then
                log(('Received tell from non-whitelisted player %s: %s'):format(player_name, tell_message))
            end
            
            if settings.respond_on_failure then
                windower.send_command(('input /tell %s You are not authorized to use this feature.'):format(player_name))
            end
        end
    end
end

windower.register_event('chat message', handle_chat_message)

-- Addon command handler for managing the whitelist
function handle_addon_command(command, ...)
    local args = {...}
    command = command and command:lower() or ''
    
    if command == 'add' and args[1] then
        local player_name = args[1]
        if not is_whitelisted(player_name) then
            table.insert(settings.whitelist, player_name)
            config.save(settings)
            log(('Added %s to whitelist'):format(player_name))
        else
            log(('%s is already in the whitelist'):format(player_name))
        end
    elseif command == 'remove' and args[1] then
        local player_name = args[1]
        for i, whitelisted_player in ipairs(settings.whitelist) do
            local match = settings.case_sensitive and 
                         (player_name == whitelisted_player) or
                         (player_name:lower() == whitelisted_player:lower())
            if match then
                table.remove(settings.whitelist, i)
                config.save(settings)
                log(('Removed %s from whitelist'):format(player_name))
                return
            end
        end
        log(('%s not found in whitelist'):format(player_name))
    elseif command == 'list' then
        log('Whitelisted players:')
        for _, player in ipairs(settings.whitelist) do
            log(('  - %s'):format(player))
        end
    elseif command == 'reload' then
        settings = config.load(defaults)
        log('Settings reloaded')
    else
        log('Usage:')
        log('  //recieved add <playername> - Add player to whitelist')
        log('  //recieved remove <playername> - Remove player from whitelist')
        log('  //recieved list - Show whitelisted players')
        log('  //recieved reload - Reload settings')
    end
end

windower.register_event('addon command', handle_addon_command)

log('Recieved addon loaded. Use //recieved list to see current whitelist.')
