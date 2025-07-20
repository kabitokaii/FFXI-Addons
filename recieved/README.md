# Recieved Addon for Windower4

This addon receives tells from whitelisted players and executes console commands.

## Features

- **Whitelist System**: Only players on the whitelist can execute commands
- **Command Mapping**: Maps tell messages to console commands
- **Configurable Responses**: Can respond to players when commands succeed or fail
- **Logging**: Logs all command execution attempts
- **Case Insensitive**: Commands are case-insensitive by default

## Installation

1. Place the `recieved` folder in your `Windower4/addons/` directory
2. Load the addon with `//lua load recieved`

## Usage

### Basic Commands

The addon responds to tells from whitelisted players. For example:
- Tell "sm on" → executes `sm on`
- Tell "sm off" → executes `sm off`  
- Tell "sm follow kabitokaii" → executes `sm follow kabitokaii`

### Managing the Whitelist

- `//recieved list` - Show all whitelisted players
- `//recieved add <playername>` - Add a player to the whitelist
- `//recieved remove <playername>` - Remove a player from the whitelist
- `//recieved reload` - Reload settings from file

## Configuration

The addon creates a `settings.xml` file in the addon directory where you can configure:

- `whitelist`: Array of player names who can execute commands
- `respond_on_success`: Whether to tell the player when a command succeeds
- `respond_on_failure`: Whether to tell the player when a command fails
- `log_commands`: Whether to log command execution to console
- `case_sensitive`: Whether player names are case-sensitive

## Adding New Commands

Edit the `command_mappings` table in `recieved.lua` to add new command mappings:

```lua
local command_mappings = {
    ['sm on'] = 'sm on',
    ['sm off'] = 'sm off',
    ['sm follow'] = 'sm follow %s',
    ['your command'] = 'actual console command',
    -- Add more mappings here
}
```

## Security

- Only whitelisted players can execute commands
- Commands must be explicitly mapped - arbitrary commands cannot be executed
- All command attempts are logged

## Example Usage

1. Add yourself to whitelist: `//recieved add YourCharacterName`
2. Have a friend tell you: `/tell YourCharacterName sm on`
3. The addon will execute `sm on` and optionally respond to confirm

## Troubleshooting

- Check the console for log messages
- Use `//recieved list` to verify whitelist
- Ensure the tell format is exactly: `/tell targetname command`
- Commands are case-insensitive but must match the mappings exactly
