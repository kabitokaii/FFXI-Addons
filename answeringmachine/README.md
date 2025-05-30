# FFXI Windower Answering Machine (Enhanced)

**Author:** Byrth (Enhanced by Kabitokaii)  
**Version:** 1.4 (Enhanced)  
**Abbreviation:** //am, //answeringmachine

## Overview

Enhanced answering machine addon for FFXI Windower that records not only tell messages but also mentions of your character name in party and linkshell chat. Never miss when someone mentions you while you're away!

## Features

The addon now records three types of messages:

* **Tell messages** - Direct tells sent to you (triggers away message response)
* **Party chat mentions** - Messages in party chat that mention your character name
* **Linkshell chat mentions** - Messages in linkshell chat that mention your character name

## Commands

* **`//am list`** - Lists the number of messages recorded from each person, including tells, party mentions, and linkshell mentions
* **`//am play [name]`** - Plays available messages. Will default to playing all messages if a name is not provided. Shows all message types for the specified player
* **`//am clear [name]`** - Clears available messages. Will default to clearing all messages if a name is not provided. Clears all message types for the specified player
* **`//am help`** - Lists commands and features in game
* **`//am msg <message>`** - Sets your away message, which will be sent to non-GMs the first time they send you a tell after loading the plugin or clearing messages from them

## How It Works

- **Tell Messages**: Work exactly as before - recorded and trigger automatic away message responses
- **Party/Linkshell Mentions**: The addon monitors party chat (mode 4) and linkshell chat (mode 5) for messages containing your character name (case-insensitive). These mentions are recorded but do NOT trigger away message responses
- **Smart Display**: Messages are clearly labeled with `[Party]` or `[LS]` prefixes to identify their source
- **Separate Storage**: Each message type is stored separately, allowing you to manage tells and mentions independently

## Usage Examples

```
//am list              # Show all recorded messages
//am play Playername   # Play all messages from Playername (tells, party mentions, LS mentions)
//am clear Playername  # Clear all messages from Playername
//am msg I'm AFK       # Set away message for tells
```

## Technical Details

- **Chat Mode Detection**: Uses Windower chat mode constants (3=tells, 4=party, 5=linkshell)
- **Name Matching**: Case-insensitive string matching using `string.find()`
- **Storage Structure**: 
  - Tells: stored under `PLAYERNAME`
  - Party mentions: stored under `PLAYERNAME_PARTY`
  - Linkshell mentions: stored under `PLAYERNAME_LINKSHELL`
- **Player Detection**: Uses `windower.ffxi.get_player()` to get current character name

## Version History

- **1.4 (Enhanced)** - Added party chat and linkshell chat mention detection. Messages that mention your character name in party or linkshell chat are now recorded separately from tells. Enhanced display with chat type prefixes and improved command functionality.
- **1.4** - Added a black/red box that appears if you have messages that you probably haven't read.
- **1.3** - Adjusted trim function to prevent error when dealing with 15 character names.
- **1.2** - Timestamps added. Massive refactoring. Outgoing tells now included.
- **1.1** - Version History started, fundamental recording and answering features created.

## Installation

1. Place the `answeringmachine.lua` file in your `Windower4/addons/answeringmachine/` directory
2. Load the addon in game with `//lua load answeringmachine`
3. Optionally add it to your auto-load list in `Windower4/scripts/init.txt`

## Notes

- Only tell messages trigger away message responses - party and linkshell mentions do not
- Name detection is case-insensitive for maximum reliability
- The addon will automatically detect your character name when loaded
- All message types are preserved across game sessions