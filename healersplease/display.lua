-- Display object for healing tracker
local texts = require('texts')

local Display = {
    visible = true,
    settings = nil,
    tb_name = 'healersplease'
}

local valid_fonts = T{
    'fixedsys',
    'lucida console',
    'courier',
    'courier new',
    'ms mincho',
    'consolas',
    'dejavu sans mono'
}

local valid_fields = T{
    'name',
    'hps',
    'percent',
    'total',
    'havg',
    'hrange',
    'healcritavg',
    'healcritrange',
    'healcrit',
    'maxheal',
    'minheal'
}


function Display:set_position(posx, posy)
    self.text:pos(posx, posy)
end

function Display:new(settings, db)
    local repr = setmetatable({db = db}, self)
    self.settings = settings
    self.__index = self
    self.visible = settings.visible

    repr.text = texts.new(repr.settings.display.text, repr.settings.display)
    repr.text:font(repr.settings.display.text.font)
    repr.text:size(repr.settings.display.text.size)
    repr.text:color(repr.settings.display.text.red, repr.settings.display.text.green,
                    repr.settings.display.text.blue)
    repr.text:alpha(repr.settings.display.text.alpha)
    repr.text:stroke_transparency(200)
    repr.text:stroke_color(255, 255, 255)
    repr.text:stroke_width(1)
    repr.text:bg_color(repr.settings.display.bg.red, repr.settings.display.bg.green,
                       repr.settings.display.bg.blue)
    repr.text:bg_transparency(repr.settings.display.bg.alpha)
    repr.text:pos(repr.settings.display.pos.x, repr.settings.display.pos.y)
    repr.text:text('')

    return repr
end


function Display:visibility(visible)
    local prev_visible = self.visible

    if visible then
        self.visible = true
        if not prev_visible then
            self.settings.visible = true
            self.settings:save()
        end
        self.text:show()
    else
        self.visible = false
        if prev_visible then
            self.settings.visible = false
            self.settings:save()
        end
        self.text:hide()
    end
end


function Display:reset()
    local header = 'HPS: Paused' .. (' '):rep(25) .. '//hp help\nTargets: All\n'
    local labels = string.format('%32s%7s%9s\n', 'Tot', 'Pct', 'HPS')
    self.text:text(header .. labels)
end


function Display:empty()
    return self.db:get_mob_names():empty()
end


function Display:build_scoreboard_header()
    local mob_filter_str
    local filters = self.db:get_filters()

    if filters:empty() then
        mob_filter_str = 'All'
    else
        mob_filter_str = table.concat(filters, ', ')
    end

    local labels
    if self.db:empty() then
        labels = '\n'
    else
        labels = string.format('%32s%7s%9s\n', 'Tot', 'Pct', 'HPS')
    end

    local hps_status
    if hps_clock:is_active() then
        hps_status = 'Active'
    else
        hps_status = 'Paused'
    end

    local hps_clock_str = ''
    if hps_clock:is_active() or hps_clock.clock > 1 then
        hps_clock_str = string.format(' (%s)', hps_clock:to_string())
    end

    local hps_chunk = string.format('HPS: %s%s', hps_status, hps_clock_str)

    return string.format('%s%s\nTargets: %-9s\n%s', hps_chunk, (' '):rep(29 - hps_chunk:len()) .. '//hp help', mob_filter_str, labels)
end


-- Returns following two element pair:
-- 1) table of sorted 2-tuples containing {player, healing}
-- 2) integer containing the total healing done
function Display:get_sorted_player_healing()
    -- In order to sort by healing, we have to first add it all up into a table
    -- and then build a table of sortable 2-tuples and then finally we can sort...
    local target, players
    local player_total_healing = T{}

    if self.db:empty() then
        return {}, 0
    end

    for target, players in self.db:iter() do
        -- If the filter isn't active, include all targets
        for player_name, player in pairs(players) do
            if player_total_healing[player_name] then
                player_total_healing[player_name] = player_total_healing[player_name] + player.healing
            else
                player_total_healing[player_name] = player.healing
            end
        end
    end

    local sortable = T{}
    local total_healing = 0
    for player, healing in pairs(player_total_healing) do
        total_healing = total_healing + healing
        sortable:append({player, healing})
    end

    table.sort(sortable, function(a, b)
        return a[2] > b[2]
    end)

    return sortable, total_healing
end


-- Updates the main display with current filter/healing/hps status
function Display:update()
    if not self.visible then
        -- no need build a display while it's hidden
        return
    end

    if self.db:empty() then
        self:reset()
        return
    end
    local healing_table, total_healing
    healing_table, total_healing = self:get_sorted_player_healing()

    local display_table = T{}
    local player_lines = 0
    local alli_healing = 0
    for k, v in pairs(healing_table) do
        if player_lines < self.settings.numplayers then
            local hps
            if hps_clock.clock == 0 then
                hps = "N/A"
            else
                hps = string.format('%.2f', v[2] / hps_clock.clock)
            end

            local percent
            if total_healing > 0 then
                percent = string.format('(%.1f%%)', 100 * v[2] / total_healing)
            else
                percent = '(0%)'
            end
            display_table:append(string.format('%-25s%7.0f%8s %7s', v[1], v[2], percent, hps))
        end
        alli_healing = alli_healing + v[2] -- gather this even for players not displayed
        player_lines = player_lines + 1
    end

    if self.settings.showallihealing and hps_clock.clock > 0 then
        display_table:append(('-'):rep(17))
        display_table:append('Alli HPS: ' .. string.format('%7.1f', alli_healing / hps_clock.clock))
    end

    self.text:text(self:build_scoreboard_header() .. table.concat(display_table, '\n'))
end


local function build_input_command(chatmode, tell_target)
    local input_cmd = 'input '
    if chatmode then
        input_cmd = input_cmd .. '/' .. chatmode .. ' '
        if tell_target then
            input_cmd = input_cmd .. tell_target .. ' '
        end
    end

    return input_cmd
end

-- Takes a table of elements to be wrapped across multiple lines and returns
-- a table of strings, each of which fits within one FFXI line.
local function wrap_elements(elements, header, alt, sep)
    local max_line_length = 120 -- game constant
    if not sep then
        sep = ', '
    end

    local lines = T{}
    local current_line = nil
    local line_length

    local i = 1
    if not alt then
        while i <= #elements do
            if not current_line then
                current_line = T{}
                line_length = header:len()
                lines:append(current_line)
            end

            local new_line_length = line_length + elements[i]:len() + sep:len()
            if new_line_length > max_line_length then
                current_line = T{}
                lines:append(current_line)
                new_line_length = elements[i]:len() + sep:len()
            end

            current_line:append(elements[i])
            line_length = new_line_length
            i = i + 1
        end
        local baked_lines = T{}
        for _, ls in ipairs(lines) do
            baked_lines:append(ls:concat(sep))
        end
        if header:len() > 0 and #baked_lines > 0 then
            baked_lines[1] = header .. baked_lines[1]
        end
        return baked_lines
    else
        local header_line = T{}
        header_line:append(header)
        lines:append(header_line)
        while i <= #elements do
            current_line = T{}
            lines:append(current_line)
            current_line:append(elements[i])
            i = i + 1
        end
        local baked_lines = T{}
        for _, ls in ipairs(lines) do
            baked_lines:append(ls:concat(' '))
        end
        return baked_lines
    end
end


local function slow_output(chatprefix, lines, limit)
    -- this is funky but if we don't wait like this, the lines will spew too fast and error
    local commands = T{}
    for _, line in ipairs(lines) do
        commands:append(chatprefix .. line)
    end
    windower.send_command(commands:concat('; wait 1.2 ; '))
end


function Display:report_summary (...)
    local args = {...}
    local chatmode, tell_target = args[1], args[2]

    local healing_table, total_healing
    healing_table, total_healing = self:get_sorted_player_healing()

    local elements = T{}
    for k, v in pairs(healing_table) do
        elements:append(string.format('%s %.0f(%.1f%%)', v[1], v[2], 100 * v[2]/total_healing))
    end

    -- Send the report to the specified chatmode
    slow_output(build_input_command(chatmode, tell_target),
                wrap_elements(elements, 'Healing: ', self.settings.oneperline),
                self.settings.numplayers)
end

-- This is a table of the line aggregators and related utilities
Display.stat_summaries = {}


Display.stat_summaries._format_title = function (msg)
        local line_length = 40
        local msg_length  = msg:len()
        local border_len = math.floor(line_length / 2 - msg_length / 2)

        return (' '):rep(border_len) .. msg .. (' '):rep(border_len)
    end

    
Display.stat_summaries['range'] = function (stats, filters, options)
        
        local lines = T{}
        for name, pair in pairs(stats) do
            lines:append(string.format('%-20s %d min   %d max', name, pair[1], pair[2]))
        end

        if #lines > 0 and options and options.name then
            hp_output(Display.stat_summaries._format_title('-= '..options.name..' (' .. filters .. ') =-'))
            hp_output(lines)
        end
    end

    
Display.stat_summaries['average'] = function (stats, filters, options)
        
        local lines = T{}
        for name, pair in pairs(stats) do
            if options and options.percent then
                lines:append(string.format('%-20s %.2f%% (%d sample%s)', name, 100 * pair[1], pair[2],
                                                                      pair[2] == 1 and '' or 's'))
            else
                lines:append(string.format('%-20s %d (%ds)', name, pair[1], pair[2]))
            end
        end

        if #lines > 0 and options and options.name then
            hp_output(Display.stat_summaries._format_title('-= '..options.name..' (' .. filters .. ') =-'))
            hp_output(lines)
        end
    end

    
-- This is a closure around a hash-based dispatcher. Some conveniences are
-- defined for the actual stat display functions.
function Display:show_stat(stat, player_filter)
    local stats = self.db:query_stat(stat, player_filter)
    local filters = self.db:get_filters()
    local filter_str

    if filters:empty() then
        filter_str = 'All targets'
    else
        filter_str = filters:concat(', ')
    end
    
    Display.stat_summaries[Display.stat_summaries._all_stats[stat].category](stats, filter_str, Display.stat_summaries._all_stats[stat])
end


-- Healing stats for reporting
Display.stat_summaries._all_stats = T{
    ['havg']          = {percent=false, category="average", name='Healing Average'},
    ['hrange']        = {percent=false, category="range",   name='Healing Range'},
    ['healcritavg']   = {percent=false, category="average", name='Healing Crit. Avg.'},
    ['healcritrange'] = {percent=false, category="range",   name='Healing Crit. Range'},
    ['healcrit']      = {percent=true,  category="average", name='Healing Crit. Rate'},
    ['totalheal']     = {percent=false, category="average", name='Total Healing'},
    ['hps']           = {percent=false, category="average", name='Healing Per Second'},
    ['maxheal']       = {percent=false, category="average", name='Maximum Heal'},
    ['minheal']       = {percent=false, category="average", name='Minimum Heal'}
}

function Display:report_stat(stat, args)
    if Display.stat_summaries._all_stats:containskey(stat) then
        local stats = self.db:query_stat(stat, args.player)

        local elements = T{}
        local header   = Display.stat_summaries._all_stats[stat].name .. ': '
        for name, stat_pair in pairs(stats) do
            if stat_pair[2] > 0 then
                if Display.stat_summaries._all_stats[stat].category == 'range' then
                    elements:append({stat_pair[1], string.format('%s %d~%d', name, stat_pair[1], stat_pair[2])})
                elseif Display.stat_summaries._all_stats[stat].percent then
                    elements:append({stat_pair[1], string.format('%s %.2f%% (%ds)', name, stat_pair[1] * 100, stat_pair[2])})
                else
                    elements:append({stat_pair[1], string.format('%s %d (%ds)', name, stat_pair[1], stat_pair[2])})
                end
            end
        end

        -- Sort elements by the stat value (descending)
        table.sort(elements, function(a, b) return a[1] > b[1] end)

        -- Extract just the formatted strings for reporting
        local formatted_elements = T{}
        for _, element in ipairs(elements) do
            formatted_elements:append(element[2])
        end

        -- Send the report to the specified chatmode
        slow_output(build_input_command(args.chatmode, args.telltarget),
                    wrap_elements(formatted_elements, header, self.settings.oneperline),
                    self.settings.numplayers)
    else
        error('Invalid stat: ' .. stat)
    end
end


function Display:report_filters()
    local filters = self.db:get_filters()
    if filters:empty() then
        hp_output('No target filters set.')
    else
        hp_output('Target filters: ' .. filters:concat(', '))
    end
end

return Display
