_addon.name = 'GilLedger'
_addon.author = 'Dean James (Xurion of Bismarck)'
_addon.version = '1.1.0'
_addon.commands = {'gilledger', 'ledger', 'gil'}

packets = require('packets')
config = require('config')
require('chat')
windower = require('windower')

defaults = {}
settings = config.load(defaults)
config.save(settings)

item_assign_packet_id = 0x01F
item_updates_packet_id = 0x020
gil_item_id = 65535

function comma_value(n) --credit http://richard.warburton.it
	local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
	return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

function uc_word(word)
	return word:gsub("^%l", string.upper)
end

windower.register_event('incoming chunk', function(id, packet)
	if id == item_assign_packet_id or id == item_updates_packet_id then
		local parsed = packets.parse('incoming', packet)
		if parsed.Item == gil_item_id then
			local player = windower.ffxi.get_player()
			if player then
				local character_name = player.name:lower()
				settings[character_name] = parsed.Count
				config.save(settings)
			end
		end
	end
end)

function display_help()
	windower.add_to_chat(8, 'GilLedger commands:')
	windower.add_to_chat(8, '  /gil - Display gil for all characters')
	windower.add_to_chat(8, '  /gil show [names] - Show gil for specific characters')
	windower.add_to_chat(8, '  /gil reset [name] - Reset gil data for a character')
	windower.add_to_chat(8, '  /gil remove [name] - Remove a character from the ledger')
	windower.add_to_chat(8, '  /gil help - Display this help message')
end

function show_gil(characters)
	local total_gil = 0
	local displayed_count = 0
	
	for character, gil in pairs(settings) do
		if not characters or #characters == 0 or table.contains(characters, character) then
			windower.add_to_chat(8, uc_word(character) .. ': ' .. comma_value(gil) .. 'g')
			total_gil = total_gil + gil
			displayed_count = displayed_count + 1
		end
	end
	
	if displayed_count > 0 then
		windower.add_to_chat(8, 'Total: ' .. comma_value(total_gil) .. 'g')
	else
		windower.add_to_chat(8, 'No character data found.')
	end
end

-- Helper function to check if table contains a value
function table.contains(table, element)
	for _, value in pairs(table) do
		if value:lower() == element:lower() then
			return true
		end
	end
	return false
end

windower.register_event('addon command', function(command, ...)
	command = command and command:lower() or 'show'
	local args = {...}
	
	if command == 'help' then
		display_help()
	elseif command == 'reset' and args[1] then
		local char_name = args[1]:lower()
		if settings[char_name] then
			settings[char_name] = 0
			config.save(settings)
			windower.add_to_chat(8, 'Reset gil data for ' .. uc_word(char_name))
		else
			windower.add_to_chat(8, 'No data found for character: ' .. uc_word(char_name))
		end
	elseif command == 'remove' and args[1] then
		local char_name = args[1]:lower()
		if settings[char_name] then
			settings[char_name] = nil
			config.save(settings)
			windower.add_to_chat(8, 'Removed ' .. uc_word(char_name) .. ' from ledger')
		else
			windower.add_to_chat(8, 'No data found for character: ' .. uc_word(char_name))
		end
	elseif command == 'show' then
		show_gil(args)
	else
		show_gil({})
	end
end)
