--[[
Clock object to track healing time intervals
]]

local HPSClock = {}

function HPSClock:new (o)
    o = o or {}
    
    o.last_update = 0
    o.elapsed_time = 0  -- Renamed from duration to avoid conflict with duration() method
    o.paused = true
    o.clock = 0  -- For compatibility with display functions
    
    setmetatable(o, self)
    self.__index = self
    
    return o
end


function HPSClock:advance()
    local now = os.clock()
    
    if self.paused then
        self.last_update = now
        self.paused = false
    else
        local elapsed = now - self.last_update
        self.elapsed_time = self.elapsed_time + elapsed
        self.last_update = now
    end
    
    self.clock = self.elapsed_time  -- Keep clock property in sync
end


function HPSClock:pause()
    if not self.paused then
        local now = os.clock()
        local elapsed = now - self.last_update
        self.elapsed_time = self.elapsed_time + elapsed
        self.paused = true
    end
    
    self.clock = self.elapsed_time  -- Keep clock property in sync
end


function HPSClock:duration()
    if self.paused then
        return self.elapsed_time
    else
        local now = os.clock()
        local elapsed = now - self.last_update
        return self.elapsed_time + elapsed
    end
end


function HPSClock:is_active()
    return not self.paused
end


function HPSClock:to_string()
    local total_seconds = self:duration()
    local minutes = math.floor(total_seconds / 60)
    local seconds = math.floor(total_seconds % 60)
    return string.format("%02d:%02d", minutes, seconds)
end


function HPSClock:reset()
    self.last_update = 0
    self.elapsed_time = 0
    self.paused = true
    self.clock = 0
end

return HPSClock
