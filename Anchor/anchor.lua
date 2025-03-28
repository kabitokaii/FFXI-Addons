--[[
Copyright 2014 Seth VanHeulen

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
--]]

-- addon information

_addon.name = 'anchor'
_addon.version = '1.0.3'
_addon.command = 'anchor'
_addon.author = 'Seth VanHeulen (Acacia@Odin)'

-- bit manipulation helper functions

local function bit(p)
    return 2 ^ p
end

local function checkbit(x, p)
    return x % (p + p) >= p
end

local function clearbit(x, p)
    return checkbit(x, p) and x - p or x
end

function string.clearbits(s, p, c)
    if c and c > 1 then
        s = s:clearbits(p + 1, c - 1)
    end
    local b = math.floor(p / 8)
    -- Check if we're within bounds
    if b + 1 > #s then return s end
    
    return s:sub(1, b) .. string.char(clearbit(s:byte(b + 1), bit(p % 8))) .. s:sub(b + 2)
end

function string.checkbit(s, p)
    local bytePos = math.floor(p / 8) + 1
    -- Check if we're within bounds
    if bytePos > #s then return false end
    
    return checkbit(s:byte(bytePos), bit(p % 8))
end

-- event callback functions

-- This function processes incoming packets and removes specific bits for action packets (category 11)
-- These bits are related to character animation anchoring in the game
local function check_incoming_chunk(id, original, modified, injected, blocked)
    if id == 0x28 then  -- Action packet ID
        -- Safety check for minimum packet length
        if #original < 11 then return end
        
        local category = math.floor((original:byte(11) % 64) / 4)
        if category == 11 then  -- Category 11 = Fishing
            local new = original
            local position = 150
            
            -- Check byte 10 exists and contains valid data
            if #original < 10 then return end
            local targetCount = original:byte(10)
            
            for target = 1, targetCount do
                -- Safety check: ensure we don't exceed packet bounds
                if position + 122 > #original * 8 then
                    break
                end
                
                -- Clear animation anchoring bits
                new = new:clearbits(position + 60, 3)
                
                -- Calculate position of next target data block
                local next_position = position + 123
                if original:checkbit(position + 121) then
                    next_position = next_position + 37
                end
                if original:checkbit(position + 122) then
                    next_position = next_position + 34
                end
                position = next_position
            end
            return new
        end
    end
end

-- register event callbacks

windower.register_event('incoming chunk', check_incoming_chunk)
