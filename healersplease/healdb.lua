local Player = require 'player'
local MergedPlayer = require 'mergedplayer'

local HealDB = {
    db = T{},
    filter = T{}
}

HealDB.player_stat_fields = T{
    'havg', 'hrange', 'healcritavg', 'healcritrange',
    'totalheal', 'hps', 'percent', 'heals', 'healcrits',
    'healcrit', 'maxheal', 'minheal'
}

function HealDB:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    
    return o
end


function HealDB:iter()
    local k, v
    return function ()
        k, v = next(self.db, k)
        while k and not self:_filter_contains_mob(k) do
            k, v = next(self.db, k)
        end
        
        if k then
            return k, v
        end
    end
end


function HealDB:get_filters()
    return self.filter
end


function HealDB:add_filter(pattern)
    self.filter:append(pattern)
end


function HealDB:clear_filters()
    self.filter:clear()
end


function HealDB:_filter_contains_mob(mob_name)
    -- true = show, false = filter out
    if self.filter:length() == 0 then
        return true
    end
    
    for _, filter in ipairs(self.filter) do
        if string.find(mob_name:lower(), filter:lower()) then
            return true
        end
    end

    return false
end


function HealDB:get_mob_names()
    local result = T{}
    for k, v in pairs(self.db) do
        if self:_filter_contains_mob(k) then
            result:append(k)
        end
    end
    
    return result
end


function HealDB:get_player_names(mob_name)
    assert(mob_name, "mob name required")
    
    if not self.db[mob_name] then
        return T{}
    end
    
    local result = T{}
    for k, v in pairs(self.db[mob_name]) do
        result:append(k)
    end
    
    return result
end


function HealDB:get_player(mob_name, player_name)
    assert(mob_name, "mob name required")
    assert(player_name, "player name required")
    
    if not self.db[mob_name] then
        return nil
    end
    
    return self.db[mob_name][player_name]
end


function HealDB:get_merged_player(player_name)
    assert(player_name, "player name required")
    
    local result = MergedPlayer:new(player_name)
    for mob_name in self:iter() do
        local player = self:get_player(mob_name, player_name)
        if player then
            result:combine(player)
        end
    end
    
    return result
end


function HealDB:_get_or_create_player(mob_name, player_name)
    if not self.db[mob_name] then
        self.db[mob_name] = {}
    end
    
    if not self.db[mob_name][player_name] then
        self.db[mob_name][player_name] = Player:new({name=player_name})
        self.db[mob_name][player_name].clock = hps_clock
    end
    
    return self.db[mob_name][player_name]
end


function HealDB:add_healing(target_name, healer_name, healing)
    local player = self:_get_or_create_player(target_name, healer_name)
    player:add_healing(healing)
end


function HealDB:add_healing_crit(target_name, healer_name, healing)
    local player = self:_get_or_create_player(target_name, healer_name)
    player:add_healing_crit(healing)
end


function HealDB:get_total_healing()
    local total = 0
    for mob_name in self:iter() do
        total = total + self:get_total_healing_on_mob(mob_name)
    end
    return total
end


function HealDB:get_total_healing_on_mob(mob_name)
    local total = 0
    for _, player_name in ipairs(self:get_player_names(mob_name)) do
        total = total + self:get_player(mob_name, player_name).healing
    end
    return total
end


function HealDB:get_dps(clock)
    assert(clock, "clock required")
    
    local total = self:get_total_healing()
    local duration = clock:duration()
    
    if duration > 0 then
        return total / duration
    else
        return 0
    end
end


function HealDB:get_player_hps(mob_name, player_name, clock)
    assert(mob_name, "mob name required")
    assert(player_name, "player name required")
    assert(clock, "clock required")
    
    local player = self:get_player(mob_name, player_name)
    if not player then
        return 0
    end
    
    local duration = clock:duration()
    if duration > 0 then
        return player.healing / duration
    else
        return 0
    end
end


function HealDB:get_merged_player_hps(player_name, clock)
    assert(player_name, "player name required")
    assert(clock, "clock required")
    
    local player = self:get_merged_player(player_name)
    local duration = clock:duration()
    
    if duration > 0 then
        return player.healing / duration
    else
        return 0
    end
end


function HealDB:reset()
    self.db:clear()
end


function HealDB:empty()
    return self.db:empty()
end


function HealDB:query_stat(stat, player_filter)
    local result = T{}
    
    for target_name in self:iter() do
        local player_names = self:get_player_names(target_name)
        
        for _, player_name in ipairs(player_names) do
            if not player_filter or player_name == player_filter then
                local player = self:get_player(target_name, player_name)
                if player and player[stat] then
                    if not result[player_name] then
                        result[player_name] = {0, 0} -- {stat_value, count}
                    end
                    
                    local stat_value = 0
                    if type(player[stat]) == 'function' then
                        stat_value = player[stat](player)
                    else
                        stat_value = player[stat]
                    end
                    
                    result[player_name][1] = result[player_name][1] + stat_value
                    result[player_name][2] = result[player_name][2] + 1
                end
            end
        end
    end
    
    return result
end

return HealDB
