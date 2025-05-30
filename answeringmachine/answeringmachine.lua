_addon.commands = {'answeringmachine','am'}
_addon.name = 'AnsweringMachine'
_addon.author = 'Byrth'
_addon.version = '1.4'

-- Require libraries
local texts = require('texts')
local AM_box = texts.new('')
AM_box:size(24)

local last_activity = os.time()
local unseen_message_count = 0
local away_msg = nil -- Properly declare away_msg variable

local textspeed = 0
local text_list = {[1]=os.time()}
text_list[2] = text_list[1]
text_list[3] = text_list[1]
text_list[4] = text_list[1]
text_list[5] = text_list[1]
text_list[6] = text_list[1]
text_list[7] = text_list[1]
text_list[8] = text_list[1]
text_list[9] = text_list[1]
text_list[10] = text_list[1]
local text_index = 1

local recording = {}

-- Utility functions
local function split(msg, match)
    local length = msg:len()
    local splitarr = {}
    local u = 1
    while u < length do
        local nextanch = msg:find(match, u)
        if nextanch ~= nil then
            splitarr[#splitarr+1] = msg:sub(u, nextanch-1)
            if nextanch ~= length then
                u = nextanch+1
            else
                u = length
            end
        else
            splitarr[#splitarr+1] = msg:sub(u, length)
            u = length
        end
    end
    return splitarr
end

local function uc_first(msg)
    if not msg or msg == "" then return "" end
    local first_char = msg:sub(1,1)
    local rest = msg:sub(2)
    return first_char:upper() .. rest:lower()
end

local function trim(msg)
    for i=2, msg:len() do
        if msg:byte(i) == 0 then
            return msg:sub(1, i-1)
        end
    end
    return msg
end

local function pl(num)
    if num > 1 then
        return 's'
    else
        return ''
    end
end

local function arrows(bool, name, msg_type)
    local type_prefix = ""
    if msg_type == 'party' then
        type_prefix = "[Party] "
    elseif msg_type == 'linkshell' then
        type_prefix = "[LS] "
    end
    
    if bool then
        return type_prefix .. name .. '>> '
    else
        return type_prefix .. '>>' .. name .. ' : '
    end
end

local function print_messages(tab, name)
    for p, q in ipairs(tab) do
        local msg_type = q.type or 'tell'
        local display_name = name
        
        -- For mentions, use the actual sender name if available
        if (msg_type == 'party' or msg_type == 'linkshell') and q.sender then
            display_name = q.sender
        end
        
        windower.add_to_chat(4, os.date('%H:%M:%S', q.timestamp) .. ' ' .. arrows(q.outgoing, uc_first(display_name), msg_type) .. q.message)
        tab[p].seen = true
    end
end

local function activity()
    last_activity = os.time()
    if unseen_message_count > 0 then
        local temp_message_count = 0
        for i, v in pairs(recording) do
            for n, m in pairs(v) do
                if not m.seen then
                    local next_index = (text_index + 1) % 11
                    if next_index == 0 then next_index = 1 end
                    if m.timestamp < text_list[next_index] then
                        temp_message_count = temp_message_count + 1
                    else
                        recording[i][n].seen = true
                    end
                end
            end
        end
        unseen_message_count = temp_message_count
    end
end

-- Event registrations
windower.register_event('addon command', function(...)
    local term = table.concat({...}, ' ')
    local broken = split(term, ' ')
    if broken[1] ~= nil then
        if broken[1]:upper() == "CLEAR" then
            if broken[2] == nil then
                recording = {}
                windower.add_to_chat(4, 'Answering Machine>> Blanking the recordings')
            else
                local player_upper = broken[2]:upper()
                local cleared = false
                
                -- Check and clear direct tell recording
                if recording[player_upper] then
                    windower.add_to_chat(4, 'Answering Machine>> Deleting tell conversation with ' .. uc_first(broken[2]))
                    recording[player_upper] = nil
                    cleared = true
                end
                
                -- Check and clear party mention recording
                local party_key = player_upper .. '_PARTY'
                if recording[party_key] then
                    windower.add_to_chat(4, 'Answering Machine>> Deleting party mentions from ' .. uc_first(broken[2]))
                    recording[party_key] = nil
                    cleared = true
                end
                
                -- Check and clear linkshell mention recording
                local ls_key = player_upper .. '_LINKSHELL'
                if recording[ls_key] then
                    windower.add_to_chat(4, 'Answering Machine>> Deleting linkshell mentions from ' .. uc_first(broken[2]))
                    recording[ls_key] = nil
                    cleared = true
                end
                
                if not cleared then
                    windower.add_to_chat(5, 'Cancel error: Could not find specified player in recording history')
                end
            end
        elseif broken[1]:upper() == "LIST" then
            local trig
            for i, v in pairs(recording) do
                local display_name = i
                local msg_type = "tells"
                
                -- Check if this is a mention recording
                if i:find('_PARTY') then
                    display_name = i:gsub('_PARTY', '')
                    msg_type = "party mentions"
                elseif i:find('_LINKSHELL') then
                    display_name = i:gsub('_LINKSHELL', '')
                    msg_type = "linkshell mentions"
                end
                
                windower.add_to_chat(5, #v .. ' ' .. msg_type .. ' with ' .. uc_first(display_name))
                trig = true
            end
            if not trig then
                windower.add_to_chat(5, 'No exchanges recorded.')
            end
        elseif broken[1]:upper() == "PLAY" then
            if broken[2] then
                local player_upper = broken[2]:upper()
                local found = false
                
                -- Check for direct tell recording
                if recording[player_upper] then
                    local num = #recording[player_upper]
                    windower.add_to_chat(5, num .. ' tell exchange' .. pl(num) .. ' with ' .. uc_first(broken[2]))
                    print_messages(recording[player_upper], broken[2])
                    found = true
                end
                
                -- Check for party mention recording
                local party_key = player_upper .. '_PARTY'
                if recording[party_key] then
                    local num = #recording[party_key]
                    windower.add_to_chat(5, num .. ' party mention' .. pl(num) .. ' from ' .. uc_first(broken[2]))
                    print_messages(recording[party_key], broken[2])
                    found = true
                end
                
                -- Check for linkshell mention recording
                local ls_key = player_upper .. '_LINKSHELL'
                if recording[ls_key] then
                    local num = #recording[ls_key]
                    windower.add_to_chat(5, num .. ' linkshell mention' .. pl(num) .. ' from ' .. uc_first(broken[2]))
                    print_messages(recording[ls_key], broken[2])
                    found = true
                end
                
                if not found then
                    windower.add_to_chat(5, 'No exchanges recorded with ' .. uc_first(broken[2]))
                end
            else
                windower.add_to_chat(4, 'Answering Machine>> Playing back all messages')
                for i, v in pairs(recording) do
                    local display_name = i
                    local msg_type = "tell exchange"
                    
                    if i:find('_PARTY') then
                        display_name = i:gsub('_PARTY', '')
                        msg_type = "party mention"
                    elseif i:find('_LINKSHELL') then
                        display_name = i:gsub('_LINKSHELL', '')
                        msg_type = "linkshell mention"
                    end
                    
                    windower.add_to_chat(5, #v .. ' ' .. msg_type .. pl(#v) .. ' with ' .. uc_first(display_name))
                    print_messages(v, display_name)
                end
            end
        elseif broken[1]:upper() == "HELP" then
            print('am clear <n> : Clears current messages, or only messages from <n> if provided')
            print('am help : Lists these commands!')
            print('am list : Lists the names of people who have sent you tells or mentioned you')
            print('am msg <message> : Sets your away message, which will be sent to non-GMs only once after plugin load or message clear')
            print('am play <n> : Plays current messages, or only messages from <n> if provided')
            print('')
            print('The addon now records:')
            print('- Tell messages (triggers away message)')
            print('- Party chat messages that mention your name')
            print('- Linkshell chat messages that mention your name')
        elseif broken[1]:upper() == "MSG" then
            table.remove(broken, 1)
            if #broken ~= 0 then
                away_msg = table.concat(broken, ' ')
                windower.add_to_chat(123, 'AnsweringMachine: Message set to: ' .. away_msg)
            end
        elseif broken[1] == 'box' and broken[2] == 'pos' and tonumber(broken[3]) and tonumber(broken[4]) then
            AM_box:pos(tonumber(broken[3]), tonumber(broken[4]))
        end
    end
end)

windower.register_event('chat message', function(message, player, mode, isGM)
    if mode == 3 then
        -- Handle tell messages (existing functionality)
        if recording[player:upper()] then
            recording[player:upper()][#recording[player:upper()] + 1] = {message=message, outgoing=false, timestamp=os.time(), seen=false, type='tell'}
        else
            recording[player:upper()] = {{message=message, outgoing=false, timestamp=os.time(), seen=false, type='tell'}}
            if away_msg and not isGM then
                windower.send_command('@input /tell ' .. player .. ' ' .. away_msg)
            end
        end
        unseen_message_count = unseen_message_count + 1
    elseif mode == 4 or mode == 5 then
        -- Handle party chat (mode 4) and linkshell chat (mode 5) mentions
        local player_info = windower.ffxi.get_player()
        if player_info and player_info.name then
            local player_name = player_info.name:lower()
            local message_lower = message:lower()
            
            -- Check if the message mentions the player's name
            if message_lower:find(player_name, 1, true) then
                local chat_type = mode == 4 and 'party' or 'linkshell'
                local record_key = player:upper() .. '_' .. chat_type:upper()
                
                if recording[record_key] then
                    recording[record_key][#recording[record_key] + 1] = {message=message, outgoing=false, timestamp=os.time(), seen=false, type=chat_type, sender=player}
                else
                    recording[record_key] = {{message=message, outgoing=false, timestamp=os.time(), seen=false, type=chat_type, sender=player}}
                end
                unseen_message_count = unseen_message_count + 1
            end
        end
    end
end)

windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
    if not blocked and id == 0x0B6 then
        local name = trim(original:sub(0x6, 0x14))
        local message = trim(original:sub(0x15))
        if recording[name:upper()] then
            recording[name:upper()][#recording[name:upper()] + 1] = {message=message, outgoing=true, timestamp=os.time(), seen=true, type='tell'}
        else
            recording[name:upper()] = {{message=message, outgoing=true, timestamp=os.time(), seen=true, type='tell'}}
        end
    end
end)

windower.register_event('incoming text', function(org, mod, org_m, mod_m, blocked)
    if not blocked then
        text_list[text_index] = os.time()
        text_index = text_index + 1
        if text_index > 10 then text_index = 1 end
    end
end)

windower.register_event('postrender', function()
    AM_box:clear()
    AM_box:append(unseen_message_count .. ' Message' .. pl(unseen_message_count))
    local t = os.clock() % 1
    AM_box:bg_color(255, 150 + 100 * math.sin(t * math.pi), 150 + 100 * math.sin(t * math.pi))
    AM_box:color(0, 0, 0)
    if unseen_message_count > 0 then
        AM_box:show()
    else
        AM_box:hide()
    end
end)

-- windower.register_event('keyboard', activity)
-- windower.register_event('mouse', activity)