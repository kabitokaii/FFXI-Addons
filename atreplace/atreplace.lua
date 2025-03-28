_addon.name = 'atreplace'
_addon.author = 'Lili'
_addon.version = '1.3.1'
_addon.commands = { _addon.name, 'at' }

local res = require('resources')
local windower = require('windower')
require('pack')
require('logger')
local sets = require('sets') -- Required for S{} constructor

local validterms = { auto_translates = S{}, items = S{}, key_items = S{} }
local cache = {}
local lang = windower.ffxi.get_info().language:lower()

local at_term = function(str)
    local term = str:lower()

    if not cache[term] then
        local at
        local id = validterms.auto_translates[term] or validterms.items[term] or validterms.key_items[term]
        
        if id then
            -- arcon is the best
            local is_item = validterms.items[term] and true
            local high = math.floor(id / 0x100) ~= 0 -- Fixed floor method for Lua 5.1
            local low = (id % 0x100) ~= 0
            local any_zero = not (high and low)
            local mask = validterms.auto_translates[term] and string.char(2) or string.pack('qqqqq',
                low and 1 or 0,
                high and 1 or 0,
                (not is_item == any_zero) and 1 or 0,
                (is_item and any_zero) and 1 or 0,
                (not is_item) and 1 or 0
            )

            at = string.pack('CS1C>HC', 0xFD, mask, 2, id, 0xFD):gsub("\0", string.char(0xFF)) -- Explicit null character
        end
       
        cache[term] = at or str
    end
   
    return cache[term]
end

windower.register_event('load', function()
    local keys = { 'english', 'english_log', 'japanese', 'japanese_log' }
    for category,_ in pairs(validterms) do
        for id, t in pairs(res[category]) do
            if not (category == 'auto_translates' and id % 0x100 == 0) then
                for _,key in pairs(keys) do
                    if t[key] then
                        validterms[category][t[key]:lower()] = id
                    end
                end
            end
        end
    end
end)

windower.register_event('outgoing text', function(org, mod)
    if org == mod then
        return mod:gsub("_%((..-)%)", at_term)
    end
end)

windower.register_event('addon command', function(...)
    local args = T{...}
    local mode = args[1] and args[1]:lower() or 'help'
    
    if mode == 'r' or mode == 'reload' then
        windower.send_command('lua r '.._addon.name)
        return
        
    elseif mode == 'u' or mode == 'unload' then
        windower.send_command('lua u '.._addon.name)
        return
    
    elseif mode == 'search' or mode == 'find' then
        table.remove(args,1)
        local arg = args:concat(' ')
        -- Simplified pattern matching for better Lua 5.1 compatibility
        local pattern = arg:lower()
        log(string.format("Search results for '%s'", arg))
        for cat, t in pairs(validterms) do
            local r = ''
            local count = 0
            for name, id in pairs(t) do
                if name:lower():find(pattern, 1, true) then
                    r = string.format('%s %s,', r, res[cat][id][lang])
                    count = count + 1
                    if count >= 50 then
                        r = r .. ' (too many results, showing first 50)'
                        break
                    end
                end
            end
            if count > 0 then
                log('[' .. cat:upper() .. ']', r:sub(1,-2))
            end
        end
        
        return
        
    else
        log('ATReplace Commands:')
        log('//at search <term> - Search for auto-translate terms')
        log('//at reload - Reload the addon')
        log('//at unload - Unload the addon')
    end
end)
