--[[
Object to encapsulate combined Player healing data across all targets

This merges healing data from a single player across all targets they've healed.
]]

local MergedPlayer = {}

function MergedPlayer:new (name)
    local o = {}
    
    assert(name, "Must pass a name to merged player constructor")
    
    o.name = name
    o.healing = 0
    o.heals = 0
    o.h_min = math.huge
    o.h_max = 0
    o.h_avg = 0
    o.h_crits = 0
    o.h_crit_min = math.huge
    o.h_crit_max = 0
    o.h_crit_avg = 0
    o.spell_heals = T{}
    o.ability_heals = T{}
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end


function MergedPlayer:combine(player)
    -- Combine total healing
    self.healing = self.healing + player.healing
    
    -- Combine heal counts
    local old_heals = self.heals
    self.heals = self.heals + player.heals
    
    -- Update min/max values
    if player.h_min ~= math.huge then
        self.h_min = math.min(self.h_min, player.h_min)
    end
    self.h_max = math.max(self.h_max, player.h_max)
    
    -- Recalculate average healing
    if self.heals > 0 then
        self.h_avg = (self.h_avg * old_heals + player.h_avg * player.heals) / self.heals
    end
    
    -- Combine crit data
    local old_crits = self.h_crits
    self.h_crits = self.h_crits + player.h_crits
    
    -- Update crit min/max values
    if player.h_crit_min ~= math.huge then
        self.h_crit_min = math.min(self.h_crit_min, player.h_crit_min)
    end
    self.h_crit_max = math.max(self.h_crit_max, player.h_crit_max)
    
    -- Recalculate average crit healing
    if self.h_crits > 0 then
        self.h_crit_avg = (self.h_crit_avg * old_crits + player.h_crit_avg * player.h_crits) / self.h_crits
    end
    
    -- Combine spell healing data
    for spell_name, healing in pairs(player.spell_heals) do
        if not self.spell_heals[spell_name] then
            self.spell_heals[spell_name] = 0
        end
        self.spell_heals[spell_name] = self.spell_heals[spell_name] + healing
    end
    
    -- Combine ability healing data
    for ability_name, healing in pairs(player.ability_heals) do
        if not self.ability_heals[ability_name] then
            self.ability_heals[ability_name] = 0
        end
        self.ability_heals[ability_name] = self.ability_heals[ability_name] + healing
    end
end


function MergedPlayer:get_dps()
    if hps_clock then
        local duration = hps_clock:duration()
        if duration > 0 then
            return self.healing / duration
        end
    end
    return 0
end

-- Alias for consistency
function MergedPlayer:get_hps()
    return self:get_dps()
end


function MergedPlayer:get_percent(total_healing)
    if total_healing > 0 then
        return 100 * self.healing / total_healing
    else
        return 0
    end
end


-- Statistical functions for compatibility with original scoreboard
function MergedPlayer:havg()
    return self.h_avg
end

function MergedPlayer:hrange()
    if self.h_min == math.huge then
        return "0-0"
    else
        return string.format("%d-%d", self.h_min, self.h_max)
    end
end

function MergedPlayer:healcritavg()
    return self.h_crit_avg
end

function MergedPlayer:healcritrange()
    if self.h_crit_min == math.huge then
        return "0-0"
    else
        return string.format("%d-%d", self.h_crit_min, self.h_crit_max)
    end
end

function MergedPlayer:totalheal()
    return self.healing
end

function MergedPlayer:hps()
    return self:get_hps()
end

function MergedPlayer:percent(total_healing)
    return self:get_percent(total_healing)
end

function MergedPlayer:healcrits()
    return self.h_crits
end

function MergedPlayer:healcrit()
    if self.heals > 0 then
        return 100 * self.h_crits / self.heals
    else
        return 0
    end
end

function MergedPlayer:maxheal()
    return self.h_max == 0 and 0 or self.h_max
end

function MergedPlayer:minheal()
    return self.h_min == math.huge and 0 or self.h_min
end

return MergedPlayer
