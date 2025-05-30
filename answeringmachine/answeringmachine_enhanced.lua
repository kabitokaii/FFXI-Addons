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
local mention_recording = {} -- For party/linkshell mentions
local unseen_mention_count = 0

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

local function arrows(bool, name)
    if bool then
        return name .. '>> '
    else
        return '>>' .. name .. ' : '
    end
end

local function print_messages(tab, name)
    for p, q in ipairs(tab) do
        windower.add_to_chat(4, os.date('%H:%M:%S', q.timestamp) .. ' ' .. arrows(q.outgoing, uc_first(name)) .. q.message)
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
    
    -- Handle mentions similarly
    if unseen_mention_count > 0 then
        local temp_mention_count = 0
        for i, v in pairs(mention_recording) do
            for n, m in pairs(v) do
                if not m.seen then
                    local next_index = (text_index + 1) % 11
                    if next_index == 0 then next_index = 1 end
                    if m.timestamp < text_list[next_index] then
                        temp_mention_count = temp_mention_count + 1
                    else
                        mention_recording[i][n].seen = true
                    end
                end
            end
        end
        unseen_mention_count = temp_mention_count
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
                mention_recording = {}
                windower.add_to_chat(4, 'Answering Machine>> Blanking all recordings')
            elseif broken[2]:upper() == "MENTIONS" then
                mention_recording = {}
                windower.add_to_chat(4, 'Answering Machine>> Blanking mention recordings')
            elseif recording[broken[2]:upper()] then
                windower.add_to_chat(4, 'Answering Machine>> Deleting conversation with ' .. uc_first(broken[2]))
                recording[broken[2]:upper()] = nil
            else
                windower.add_to_chat(5, 'Cancel error: Could not find specified player in tell history')
            end
        elseif broken[1]:upper() == "LIST" then
            local trig
            for i, v in pairs(recording) do
                windower.add_to_chat(5, #v .. ' exchange' .. pl(#v) .. ' with ' .. uc_first(i))
                trig = true
            end
            for i, v in pairs(mention_recording) do
                windower.add_to_chat(6, #v .. ' mention' .. pl(#v) .. ' from ' .. uc_first(i))
                trig = true
            end
            if not trig then
                windower.add_to_chat(5, 'No exchanges recorded.')
            end
        elseif broken[1]:upper() == "PLAY" then
            if broken[2] then
                if broken[2]:upper() == "MENTIONS" then
                    if broken[3] then
                        -- Play mentions from specific user
                        if mention_recording[broken[3]:upper()] then
                            local num = #mention_recording[broken[3]:upper()]
                            windower.add_to_chat(6, num .. ' mention' .. pl(num) .. ' from ' .. uc_first(broken[3]))
                            for p, q in ipairs(mention_recording[broken[3]:upper()]) do
                                windower.add_to_chat(4, os.date('%H:%M:%S', q.timestamp) .. ' [' .. q.chat_type .. '] ' .. uc_first(broken[3]) .. ': ' .. q.message)
                                mention_recording[broken[3]:upper()][p].seen = true
                            end
                        else
                            windower.add_to_chat(5, 'No mentions recorded from ' .. uc_first(broken[3]))
                        end
                    else
                        -- Play all mentions
                        windower.add_to_chat(4, 'Answering Machine>> Playing back all mentions')
                        for i, v in pairs(mention_recording) do
                            windower.add_to_chat(6, #v .. ' mention' .. pl(#v) .. ' from ' .. uc_first(i))
                            for p, q in ipairs(v) do
                                windower.add_to_chat(4, os.date('%H:%M:%S', q.timestamp) .. ' [' .. q.chat_type .. '] ' .. uc_first(i) .. ': ' .. q.message)
                                mention_recording[i][p].seen = true
                            end
                        end
                    end
                elseif recording[broken[2]:upper()] then
                    local num = #recording[broken[2]:upper()]
                    windower.add_to_chat(5, num .. ' exchange' .. pl(num) .. ' with ' .. uc_first(broken[2]))
                    print_messages(recording[broken[2]:upper()], broken[2])
                else
                    windower.add_to_chat(5, 'No exchanges recorded with ' .. uc_first(broken[2]))
                end
            else
                windower.add_to_chat(4, 'Answering Machine>> Playing back all messages')
                for i, v in pairs(recording) do
                    windower.add_to_chat(5, #v .. ' exchange' .. pl(#v) .. ' with ' .. uc_first(i))
                    print_messages(v, i)
                end
                for i, v in pairs(mention_recording) do
                    windower.add_to_chat(6, #v .. ' mention' .. pl(#v) .. ' from ' .. uc_first(i))
                    for p, q in ipairs(v) do
                        windower.add_to_chat(4, os.date('%H:%M:%S', q.timestamp) .. ' [' .. q.chat_type .. '] ' .. uc_first(i) .. ': ' .. q.message)
                        mention_recording[i][p].seen = true
                    end
                end
            end
        elseif broken[1]:upper() == "HELP" then
            print('am clear <n> : Clears current messages, or only messages from <n> if provided')
            print('am clear mentions : Clears all mention recordings')
            print('am help : Lists these commands!')
            print('am list : Lists the names of people who have sent you tells and mentions')
            print('am msg <message> : Sets your away message, which will be sent to non-GMs only once after plugin load or message clear')
            print('am play <n> : Plays current messages, or only messages from <n> if provided')
            print('am play mentions [n] : Plays all mentions, or only mentions from <n> if provided')
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
        if recording[player:upper()] then
            recording[player:upper()][#recording[player:upper()] + 1] = {message=message, outgoing=false, timestamp=os.time(), seen=false}
        else
            recording[player:upper()] = {{message=message, outgoing=false, timestamp=os.time(), seen=false}}
            if away_msg and not isGM then
                windower.send_command('@input /tell ' .. player .. ' ' .. away_msg)
            end
        end
        unseen_message_count = unseen_message_count + 1
    elseif mode == 13 or mode == 14 then -- Party or Linkshell chat
        local current_player = windower.ffxi.get_player()
        if current_player and current_player.name then
            local player_name = current_player.name
            -- Check if the message mentions the player's name (case insensitive)
            if message:lower():find(player_name:lower()) then
                local sender_name = nil
                local chat_type = mode == 13 and "Party" or "Linkshell"
                
                if mode == 13 then -- Party chat
                    -- Party chat format: (PlayerName) message
                    sender_name = message:match('%((%a+)%) ')
                    if sender_name then
                        message = message:gsub('^%(%a+%) ', '') -- Remove sender prefix from message
                    end
                elseif mode == 14 then -- Linkshell chat
                    -- Linkshell chat format: <PlayerName> message
                    sender_name = message:match('<(%a+)> ')
                    if sender_name then
                        message = message:gsub('^<%a+> ', '') -- Remove sender prefix from message
                    end
                end
                
                -- Only record if we found a sender and it's not from the player themselves
                if sender_name and sender_name:upper() ~= player_name:upper() then
                    local mention_data = {
                        message = message,
                        timestamp = os.time(),
                        seen = false,
                        chat_type = chat_type
                    }
                    
                    if mention_recording[sender_name:upper()] then
                        mention_recording[sender_name:upper()][#mention_recording[sender_name:upper()] + 1] = mention_data
                    else
                        mention_recording[sender_name:upper()] = {mention_data}
                    end
                    unseen_mention_count = unseen_mention_count + 1
                end
            end
        end
    end
end)

windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
    if not blocked and id == 0x0B6 then
        local name = trim(original:sub(0x6, 0x14))
        local message = trim(original:sub(0x15))
        if recording[name:upper()] then
            recording[name:upper()][#recording[name:upper()] + 1] = {message=message, outgoing=true, timestamp=os.time(), seen=true}
        else
            recording[name:upper()] = {{message=message, outgoing=true, timestamp=os.time(), seen=true}}
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
    local total_count = unseen_message_count + unseen_mention_count
    AM_box:append(unseen_message_count .. ' Message' .. pl(unseen_message_count))
    if unseen_mention_count > 0 then
        AM_box:append(' + ' .. unseen_mention_count .. ' Mention' .. pl(unseen_mention_count))
    end
    local t = os.clock() % 1
    AM_box:bg_color(255, 150 + 100 * math.sin(t * math.pi), 150 + 100 * math.sin(t * math.pi))
    AM_box:color(0, 0, 0)
    if total_count > 0 then
        AM_box:show()
    else
        AM_box:hide()
    end
end)

windower.register_event('keyboard', activity)
windower.register_event('mouse', activity)
