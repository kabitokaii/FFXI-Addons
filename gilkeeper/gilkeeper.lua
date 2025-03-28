_addon.name = 'Gil Keeper'
_addon.author = 'Kabitokaii of Asura'
_addon.version = '1.1.3'
_addon.commands = {'gil','gk','gilkeeper','gkeeper'}
_addon.last_update = '2025-03-28'
_addon.description = 'A simple addon to track gil across multiple characters.'
_addon.command_help = 'Use //gil help for command list.'

-- Load required libraries
packets = require('packets')
config = require('config')
files = require('files')

-- Define packet IDs
local item_assign_packet_id = 0x020
local item_updates_packet_id = 0x01E
local gil_item_id = 0xFFFF

-- Define settings file path with simple relative paths
local settings_path = 'data/settings.xml'

-- Default settings
defaults = {
    debug = false,
    last_update = 0,
    characters = {} -- Maintain a character list for migration
}

-- Character defaults
char_defaults = {
    gil = 0,
    last_update = 0
}

-- Load global settings - config module will create directories as needed
settings = config.load(settings_path, defaults)
settings.debug = true  -- Force debug mode on for troubleshooting

-- Function to get character-specific config filename (Windower standard format)
function get_char_config_name(char_name)
    -- Sanitize character name to avoid any potential filepath issues
    local safe_name = char_name:gsub('[^%w%s_-]', '')
    return safe_name
end

-- Function to load character data using Windower config system
function load_character_data(char_name)
    local config_name = get_char_config_name(char_name)
    
    -- This uses Windower's convention for character-specific files
    local char_data = config.load('data/' .. config_name .. '.xml', char_defaults)
    
    if not char_data then
        windower.add_to_chat(167, 'Gil Keeper: Failed to load character data for ' .. char_name)
        return table.copy(char_defaults)
    end
    
    return char_data
end

-- Function to save character data using Windower config system
function save_character_data(char_name, data)
    local config_name = get_char_config_name(char_name)
    
    -- Use standard Windower config.save for character data
    local status, err = pcall(function()
        windower.add_to_chat(8, 'Gil Keeper: Saving character data for ' .. char_name)
        config.save(data, 'data/' .. config_name .. '.xml')
    end)
    
    if not status then
        windower.add_to_chat(167, 'Gil Keeper: Error saving character data: ' .. tostring(err))
    end
end

-- Function to update current character's gil amount
function update_current_character(char_name, amount)
    -- Load current character data
    local char_data = load_character_data(char_name)
    
    -- Update the character's gil amount
    char_data.gil = amount
    char_data.last_update = os.time()
    
    -- Save the updated data
    save_character_data(char_name, char_data)
    
    windower.add_to_chat(6, 'Gil Keeper: Updated ' .. uc_word(char_name) .. ' to ' .. comma_value(amount) .. 'g')
end

-- Function to get all character data
function get_all_characters()
    local characters = {}
    
    -- Try to list files with pcall
    local status, file_list = pcall(function()
        return files.get('data/', '*.xml')
    end)
    
    if not status or not file_list then
        windower.add_to_chat(167, 'Gil Keeper: Error listing character files')
        return characters
    end
    
    -- Process each XML file in the data directory
    for _, file in ipairs(file_list) do
        -- Skip the settings.xml file
        if file ~= 'settings.xml' then
            local char_name = file:gsub('%.xml$', '')
            
            if char_name and #char_name > 0 then
                -- Try to load character data
                local char_data = load_character_data(char_name)
                if char_data and char_data.gil then
                    characters[char_name] = char_data.gil
                end
            end
        end
    end
    
    return characters
end

-- Move table.copy() function to beginning of file for availability
function table.copy(t)
    local u = {}
    for k, v in pairs(t) do
        u[k] = v
    end
    return u
end

-- Initialize current player's gil if logged in
windower.register_event('load', function()
    local player = windower.ffxi.get_player()
    if player then
        initialize_character(player.name:lower())
    end
end)

windower.register_event('login', function()
    local player = windower.ffxi.get_player()
    if player then
        initialize_character(player.name:lower())
    end
end)

function initialize_character(character_name)
    -- Try to get current gil amount
    local gil = windower.ffxi.get_items().gil
    if gil then
        update_current_character(character_name, gil)
        if settings.debug then
            windower.add_to_chat(6, 'Gil Keeper: Initialized ' .. uc_word(character_name) .. ' with ' .. comma_value(gil) .. 'g')
        end
    end
end

function comma_value(n) --credit http://richard.warburton.it
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function uc_word(word)
    return word:gsub("^%l", string.upper)
end

windower.register_event('incoming chunk', function(id, packet)
    if id == item_assign_packet_id or id == item_updates_packet_id then
        local parsed = packets.parse('incoming', packet)
        if parsed.Item == gil_item_id then
            local player = windower.ffxi.get_player()
            if player then
                local character_name = player.name:lower()
                update_current_character(character_name, parsed.Count)
            end
        end
    end
end)

function display_help()
    windower.add_to_chat(6, 'Gil Keeper commands:')
    windower.add_to_chat(6, '  /gil - Display gil for all characters')
    windower.add_to_chat(6, '  /gil show [names] - Show gil for specific characters')
    windower.add_to_chat(6, '  /gil reset [name] - Reset gil data for a character')
    windower.add_to_chat(6, '  /gil remove [name] - Remove a character from the ledger')
    windower.add_to_chat(6, '  /gil status - Show addon status and debugging info')
    windower.add_to_chat(6, '  /gil debug - Toggle debug mode')
    windower.add_to_chat(6, '  /gil help - Display this help message')
end

function show_gil(characters)
    local all_chars = get_all_characters()
    local total_gil = 0
    local displayed_count = 0
    
    for character, gil in pairs(all_chars) do
        if not characters or #characters == 0 or table.contains(characters, character) then
            windower.add_to_chat(6, uc_word(character) .. ': ' .. comma_value(gil) .. 'g')
            total_gil = total_gil + gil
            displayed_count = displayed_count + 1
        end
    end
    
    if displayed_count > 0 then
        windower.add_to_chat(6, 'Total: ' .. comma_value(total_gil) .. 'g')
    else
        windower.add_to_chat(6, 'No character data found.')
    end
end

-- Helper function to check if table contains a value
function table.contains(table, element)
    for _, value in pairs(table) do
        if value:lower() == element:lower() then
            return true
        end
    end
    return false
end

windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'show'
    local args = {...}
    
    if command == 'help' then
        display_help()
    elseif command == 'debug' then
        settings.debug = not settings.debug
        config.save(settings) -- Direct call instead of save_settings()
        windower.add_to_chat(6, 'Gil Keeper: Debug mode ' .. (settings.debug and 'enabled' or 'disabled'))
    elseif command == 'status' then
        local all_chars = get_all_characters()
        local player = windower.ffxi.get_player()
        
        windower.add_to_chat(6, 'Gil Keeper Status:')
        windower.add_to_chat(6, '  Version: ' .. _addon.version)
        windower.add_to_chat(6, '  Debug mode: ' .. (settings.debug and 'Enabled' or 'Disabled'))
        windower.add_to_chat(6, '  Characters tracked: ' .. table.count(all_chars))
        
        -- Display all characters
        windower.add_to_chat(6, '  Tracked characters:')
        for char_name, gil in pairs(all_chars) do
            windower.add_to_chat(6, '    - ' .. uc_word(char_name) .. ': ' .. comma_value(gil) .. 'g')
        end
        
        if player then
            local current = player.name:lower()
            local current_gil = windower.ffxi.get_items().gil
            local char_data = load_character_data(current)
            windower.add_to_chat(6, '  Current character: ' .. uc_word(current))
            windower.add_to_chat(6, '  Current gil (live): ' .. comma_value(current_gil) .. 'g')
            windower.add_to_chat(6, '  Current gil (tracked): ' .. (char_data.gil and comma_value(char_data.gil) or 'Not tracked') .. 'g')
            if char_data.last_update then
                windower.add_to_chat(6, '  Last updated: ' .. os.date('%Y-%m-%d %H:%M:%S', char_data.last_update))
            end
        end
    elseif command == 'reset' and args[1] then
        local char_name = args[1]:lower()
        update_current_character(char_name, 0)
        windower.add_to_chat(6, 'Reset gil data for ' .. uc_word(char_name))
    elseif command == 'remove' and args[1] then
        local char_name = args[1]:lower()
        local config_name = get_char_config_name(char_name)
        local file_path = 'data/' .. config_name .. '.xml'
        
        -- Check if file exists
        local file = files.new(file_path)
        if file:exists() then
            local success = file:delete()
            if success then
                windower.add_to_chat(6, 'Removed ' .. uc_word(char_name) .. ' from ledger')
            else
                windower.add_to_chat(167, 'Failed to remove ' .. uc_word(char_name) .. ' from ledger')
            end
        else
            windower.add_to_chat(6, 'No data found for character: ' .. uc_word(char_name))
        end
    elseif command == 'show' then
        show_gil(args)
    else
        show_gil({})
    end
end)

-- Helper function to count table elements
function table.count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Force update of current character when addon loads
local player = windower.ffxi.get_player()
if player then
    local gil = windower.ffxi.get_items().gil
    if gil then
        local character_name = player.name:lower()
        update_current_character(character_name, gil)
    end
end

-- At startup, migrate any old data to the new format if needed
function migrate_old_data()
    if settings.characters and next(settings.characters) then
        windower.add_to_chat(6, 'Gil Keeper: Migrating old character data to new format...')
        for char_name, gil in pairs(settings.characters) do
            update_current_character(char_name, gil)
        end
        settings.characters = {}
        config.save(settings) -- Direct call instead of save_settings()
        windower.add_to_chat(6, 'Gil Keeper: Migration complete')
    end
end

migrate_old_data()

-- At startup, display debug info
windower.add_to_chat(8, 'Gil Keeper '..(_addon.version or '?.?.?')..' loading...')
windower.add_to_chat(8, 'Settings path: '..settings_path)