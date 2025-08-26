--[[
Object to encapsulate Player healing data

For each heal target, a separate player instance will be stored. Therefore
there will be multiple Player instances for each actual player in the game.
This allows for easier target filtering. 
]]

local Player = {}

function Player:new (o)
    o = o or {}
    
    assert(o.name, "Must pass a name to player constructor")
    -- attrs should be defined in Player above but due to interpreter bug it's here for now
    local attrs = {
        clock = nil,            -- specific HPS clock for this player
        healing = 0,            -- total healing done by this player
        heals = 0,              -- total number of healing spells/abilities cast
        h_min = math.huge,      -- minimum healing amount
        h_max = 0,              -- maximum healing amount
        h_avg = 0,              -- avg healing amount
        h_crits = 0,            -- total healing crits
        h_crit_min = math.huge, -- minimum healing crit
        h_crit_max = 0,         -- maximum healing crit
        h_crit_avg = 0,         -- avg healing crit
        spell_heals = T{},      -- table of all healing spells and their amounts
        ability_heals = T{},    -- table of all healing abilities and their amounts
        
        -- These could be added later for more detailed tracking
        -- cure_potency = 0,       -- total cure potency
        -- overcure = 0,           -- total amount of overcure
        -- mp_used = 0,            -- total MP used for healing
    }
    attrs.name = o.name
    o = attrs
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end


function Player:add_healing(healing)
    self.healing = self.healing + healing
    self.heals = self.heals + 1
    
    -- update min/max/avg healing values
    self.h_min = math.min(self.h_min, healing)
    self.h_max = math.max(self.h_max, healing)
    self.h_avg = self.h_avg * (self.heals - 1)/self.heals + healing/self.heals
end


function Player:add_healing_crit(healing)
    -- increment crits
    self.h_crits = self.h_crits + 1
    
    -- update min/max/avg healing crit values
    self.h_crit_min = math.min(self.h_crit_min, healing)
    self.h_crit_max = math.max(self.h_crit_max, healing)
    self.h_crit_avg = self.h_crit_avg * (self.h_crits - 1)/self.h_crits + healing/self.h_crits
    
    -- also add to general healing stats
    self:add_healing(healing)
end


function Player:add_spell_healing(spell_name, healing)
    if not self.spell_heals[spell_name] then
        self.spell_heals[spell_name] = 0
    end
    
    self.spell_heals[spell_name] = self.spell_heals[spell_name] + healing
    self:add_healing(healing)
end


function Player:add_ability_healing(ability_name, healing)
    if not self.ability_heals[ability_name] then
        self.ability_heals[ability_name] = 0
    end
    
    self.ability_heals[ability_name] = self.ability_heals[ability_name] + healing
    self:add_healing(healing)
end


function Player:get_dps()
    if self.clock then
        local duration = self.clock:duration()
        if duration > 0 then
            return self.healing / duration
        end
    end
    return 0
end

-- Alias for consistency with original naming
function Player:get_hps()
    return self:get_dps()
end


function Player:get_percent(total_healing)
    if total_healing > 0 then
        return 100 * self.healing / total_healing
    else
        return 0
    end
end


-- Statistical functions for compatibility with original scoreboard
function Player:havg()
    return self.h_avg
end

function Player:hrange()
    if self.h_min == math.huge then
        return "0-0"
    else
        return string.format("%d-%d", self.h_min, self.h_max)
    end
end

function Player:healcritavg()
    return self.h_crit_avg
end

function Player:healcritrange()
    if self.h_crit_min == math.huge then
        return "0-0"
    else
        return string.format("%d-%d", self.h_crit_min, self.h_crit_max)
    end
end

function Player:totalheal()
    return self.healing
end

function Player:hps()
    return self:get_hps()
end

function Player:percent(total_healing)
    return self:get_percent(total_healing)
end

function Player:healcrits()
    return self.h_crits
end

function Player:healcrit()
    if self.heals > 0 then
        return 100 * self.h_crits / self.heals
    else
        return 0
    end
end

function Player:maxheal()
    return self.h_max == 0 and 0 or self.h_max
end

function Player:minheal()
    return self.h_min == math.huge and 0 or self.h_min
end

return Player
