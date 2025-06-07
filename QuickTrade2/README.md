# QuickTrade 2

QuickTrade 2 is a Windower Lua addon for Final Fantasy XI that automates and streamlines the process of trading items to NPCs. It is designed to support repetitive trades, inventory management, and special trade scenarios, making it easier for players to handle large numbers of trades efficiently.

## Features

- **Automated Trading:** Automatically trades items to configured NPCs based on your inventory and trade group settings.
- **Looped Trades:** Supports looped trades for bulk item turn-ins (e.g., "qt2 loop 5").
- **Pull from Storage:** Can pull items from satchel, sack, or case for trading ("qt2 pull").
- **Spam Item Use:** Automates repeated use of items ("qt2 spam <item name>").
- **Example Mode:** Shows the trade command without actually trading (for testing).
- **Fake NPC Mode:** Simulates trading with a specified NPC for testing purposes.
- **Debugging:** Includes debug output for troubleshooting and development.

## Usage

### Basic Commands

- `/qt2` — Initiates a trade with the currently targeted NPC if configured.
- `/qt2 loop <number>` — Trades items in a loop for the specified number of times.
- `/qt2 pull` — Pulls items from storage (satchel, sack, case) and trades them.
- `/qt2 spam <item name>` — Repeatedly uses the specified item on yourself.
- `/qt2 ex` — Toggles example mode (no actual trades, just shows the command).
- `/qt2 fake <npc name>` — Sets a fake NPC for testing (no actual trades).
- `/qt2 xyz` — Prints the coordinates of your current target for configuration.

### Example

```
/qt2 loop 10 pull
/qt2 spam "Echo Drops"
/qt2 ex
/qt2 fake "NPC Name"
```

## Configuration

- Edit the `tradeGroup` table in the script to define which items can be traded to which NPCs.
- NPCs and items must be configured with their names and, optionally, coordinates and zones for precise matching.

## Requirements

- Windower 4
- The `packets` and `resources` libraries (included with Windower)

## Installation

1. Place `qt2.lua` in a new folder named `QuickTrade 2` inside your Windower `addons` directory.
2. Load the addon in-game with:
   ```
   //lua load qt2
   ```

## Notes

- The addon will disable itself if it detects configuration errors or unmatched items.
- Debug output can be enabled/disabled by setting the `debug` variable in the script.
- Example mode and fake NPC mode are for testing and will not perform actual trades.

## Credits

- Author: Valok@Asura

## License

See `LICENSE` for details.
