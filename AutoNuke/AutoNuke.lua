local version = '0.9'
local nukestr = 'Stone'
local delay = 0
local retrn = 0
local nuke_delay = 3
local halt_on_tp = false
local auto = 0

windower.register_event('load',function ()
    windower.send_command('unbind ^n')
    windower.send_command('unbind !n')
    windower.send_command('bind ^n ank start')
    windower.send_command('bind !n ank stop')
    windower.send_command('alias ank lua c AutoNuke')
end)
    
function start()
    windower.add_to_chat(17, 'AutoNuke '..nukestr..' STARTING~~~~~~~~~~~~~~')    
    local player = windower.ffxi.get_player()
    if player.status == 1 then
        auto = 1
    elseif player.status == 0 then
        auto = 0
    end
    shoot()
end

function stop()
    windower.add_to_chat(17, 'AutoNuke  STOPPING ~~~~~~~~~~~~~~')    
    auto = 0
end

function shoot()
    windower.send_command('input /ma "'..nukestr..' II" <t>')
end

function shootOnce()
    windower.send_command('input /ma "'..nukestr..' II" <t>')
end

function setNuke(nuke)
    nukestr = nuke
end

--Function Author:  Byrth
function split(msg, match)
    local length = msg:len()
    local splitarr = {}
    local u = 1
    while u <= length do
        local nextanch = msg:find(match,u)
        if nextanch ~= nil then
            splitarr[#splitarr+1] = msg:sub(u,nextanch-match:len())
            if nextanch~=length then
                u = nextanch+match:len()
            else
                u = length
            end
        else
            splitarr[#splitarr+1] = msg:sub(u,length)
            u = length+1
        end
    end
    return splitarr
end

function haltontp()
    if halt_on_tp == true then
        windower.add_to_chat(17, 'AutoNuke will no longer halt upon reaching 1000 TP')
        halt_on_tp = false
    elseif halt_on_tp == false then
        windower.add_to_chat(17, 'AutoNuke will halt upon reaching 1000 TP')
        halt_on_tp = true
    end
end

windower.register_event('action',function (act)
    if not act then return end
    
    local actor = act.actor_id
    local category = act.category
    
    local player = windower.ffxi.get_player()
    if not player then return end
    
    if ((actor == (player.id or player.index))) and category == 4 then
        if player.vitals and player.vitals['tp'] >= 1000 and halt_on_tp then
            windower.add_to_chat(17, 'AutoNuke  HALTING AT 1000 TP ~~~~~~~~~~~~~~')
            return
        end
        
        if auto == 1 then
            if player.status == 1 then
                windower.send_command('@wait '..nuke_delay..';input /ma "'..nukestr..' II" <t>')
            elseif player.status == 0 then
                auto = 0
            end
        end
    end
end)

--Function Designer:  Byrth
windower.register_event('addon command',function (...)
    local term = table.concat({...}, ' ')
    local splitarr = split(term,' ')
    
    local cmd = splitarr[1] and splitarr[1]:lower() or ''
    
    if cmd == 'start' then
        start()
    elseif cmd == 'stop' then
        stop()
    elseif cmd == 'haltontp' then
        haltontp()
    elseif cmd == 'setnuke' then
        setNuke(splitarr[2])
    elseif cmd == 'help' then
        windower.add_to_chat(17, 'AutoNuke  v'..version..'commands:')
        windower.add_to_chat(17, '//ank [options]')
        windower.add_to_chat(17, '  start              - Starts auto nuke')
        windower.add_to_chat(17, '  stop               - Stops auto nuke')
        windower.add_to_chat(17, '  haltontp           - Toggles automatic halt upon reaching 1000 TP')
        windower.add_to_chat(17, '  setnuke <nuke>     - Sets the nuke element')
        windower.add_to_chat(17, '  help               - Displays this help text')
        windower.add_to_chat(17, ' ')
        windower.add_to_chat(17, 'AutoNuke will only automate nukes if your status is "Engaged".  Otherwise it will always fire a single nuke.')
        windower.add_to_chat(17, 'To start auto nukes without commands use the key:  Ctrl+n')
        windower.add_to_chat(17, 'To stop auto nukes in the same manner:  Alt+n')
    end
end)
