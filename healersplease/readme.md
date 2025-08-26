# HealersPlease Addon for Windower4

**Author:** Kabitokaii, Based on Scoreboard by Suji  
**Version:** 1.0  
**Abbreviation:** `//hps`

This addon tracks healing done by alliance members in real time, showing HPS (Healing Per Second) and total healing amounts.

## Description

HealersPlease allows players to see their healing output live while in combat. Party and alliance member healing is also displayed. In addition to HPS, each player's total healing and their percent contribution is also displayed.

### Notable Features

- Live HPS tracking
- Tracks healing even with chat filters enabled
- Ability to filter only the targets you want to see healing for
- 'Report' command for reporting healing back to party/linkshell
- Detailed healing statistics

HPS accumulation is active whenever anyone in your alliance is currently in battle.

## Commands

All in-game commands are prefixed with `//hps` or `//healersplease`, for example: `//hps help`.

### HELP

Displays the help text

### POS \<x> \<y>

Positions the healing tracker to the given coordinates

### RESET

Resets all the healing data that's been tracked so far.

### REPORT [target]

Reports the healing. With no argument, it will go to whatever you have your current chatmode set to. You may also pass the standard FFXI chat abbreviations as arguments. Support arguments are `s`, `t`, `p`, `l`.

If you pass `t` (for tell), you must also pass a player name to send the tell to.

**Examples:**

- `//hps report` - Reports to current chatmode
- `//hps report l` - Reports to your linkshell
- `//hps report t suji` - Reports in tell to Suji

### REPORTSTAT \<stat> [playerName] [target]

**Alias:** `RS \<stat> [playerName] [target]`

Reports the given stat. Supported stats are:

- `havg`, `hrange`, `healcritavg`, `healcritrange`, `healcrit`
- `totalheal`, `hps`, `maxheal`, `minheal`

`playerName` may be the name of a player if you wish to see only one player.

For `target`, with no argument, it will go to whatever you have your current chatmode set to. You may also pass the standard FFXI chat abbreviations.

**Examples:**

- `//hps rs havg` - Reports healing average for all players
- `//hps rs havg Suji` - Reports healing average for Suji only
- `//hps rs havg p` - Reports healing average to party chat
- `//hps rs havg Suji t Cure` - Reports Suji's healing average via tell to Cure

### STAT \<stat> [playerName]

Shows specific healing stats. Respects filters. If player isn't specified, stats for everyone are displayed. Same stats as REPORTSTAT.

### FILTER SHOW

Shows current filter settings

### FILTER ADD \<target1> \<target2>

Adds healing target patterns to the filter (substrings ok). Only healing done to targets matching these patterns will be tracked.

### FILTER CLEAR

Clears target filter

### VISIBLE

Toggles healing tracker visibility

### SET \<flag> \<value>

Sets configuration variables. Valid flags are:

| Flag | Type | Description |
|------|------|-------------|
| `CombinePets` | true/false | Combine pet healing under "Pets" entry |
| `NumPlayers` | number | How many players to show in display |
| `BGTransparency` | 0-255 | Background transparency |
| `Font` | font name | Display font |
| `HPColor` | color code | Chat output color |
| `ShowAlliHealing` | true/false | Show alliance total HPS |
| `ResetFilters` | true/false | Reset filters when resetting data |
| `ShowFellow` | true/false | Include fellow in tracking |
| `OnePerLine` | true/false | One player per line in reports |
| `CompactSC` | true/false | Compact skillchain display |
| `CreditPetHealingToOwner` | true/false | Credit pet healing to owner |

## Notes

- The addon tracks healing done to alliance members
- Message IDs tracked include standard cure spells, blue magic healing, and other healing effects
- Healing critical hits are tracked separately
- The display updates in real-time during combat

## Installation

1. Place the `healersplease` folder in your `Windower4/addons/` directory
2. Load the addon with `//lua load healersplease`
3. Use `//hps help` to see all available commands

## License

Based on Scoreboard addon. See original license terms.

---

*Copyright (c) 2013-2014, Jerry Hebert. Modified for healing tracking by Kabitokaii.*
