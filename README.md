# Spectator Mod
Server side mod that allows every player to spectate everyone.  
You can call the `spec` function with a string argument to spectate someone specific.  
Please not that this is absolutely not stable, if you experience crashes do not hesitate to send me your log on Discord faky#2514.

## Changes
- Add function "Automatically spectate your killer after death cam has ended" and related ConVar(int) `spectator_afterdeathcam`.
- Changed ConVars from Bool to Int (please update your config files) because somehow I am too stupid to make them work.
- Fix bug: spectator_chatinfo_message not appearing.
- Replaced spectator cycle function with something less shitty.
- !Hotfix: crash when attacker was not a player.
- Now displays name card of spectated player (to make it work you will switch to the enemy team when spectating, but you will be switched back on respawn). Does not work in FFA gamemodes.
- fix some of the frequent crashes because player entity is not valid anymore.
- fix cam sometimes switching again / name card appearing late.
- HOTFIX crash when spectated player (target) dies during deathcam duration
- if you cycle through players skip players not alive.
- You can now enable/disable logging with the ConVar `spectator_log`
- 0.2.11 Fix crash when people reconnect fast or somehow get disconnected twice in a row (no clue when that happens?).
- 0.2.12 Only start spectating/switch team if kill cam is over. This will reduce many unnecessary team swaps that mess up spawns, etc.
- 0.2.13 fix a crash inside SpectateCamera() because a player entity was not valid (around line 212).
- 0.2.13 added `spectator_namecards` ConVar which allows enabling/disabling name cards, which need team switches to be displayed correctly.
- 0.2.13 added `spectator_admins` ConVar so you can restrict spectator to certain players/UIDs.
## Known issues
- When you spectate an enemy but your auto titan is alive (probably also turrets and other things) and kills someone, the enemy team will get rewarded.
- FFA gamemodes will not show names.
- If you go OOB, immediately spec, immediately spawn in as titan => you will get killed (by OOB timer?)
- When a new player joins and you are spectating the enemy team: Teams will get unbalanced
- When a player is having a timeout and rejoins before the server knows, that the client is having a timeout => crash
- To spectate enemies we need to switch to the enemy team until I figure out how it works without switching :)
## Usage
Type `spec` into console. Use A/D (LEFT/RIGHT) to switch between players.
Type `spec pla` to spec a player whose name has `pla` in his name (would for example spectate on "player" now).
## ConVars for chat announcements
You can use following ConVars to edit the config on the run or add them to your `autoexec_ns_server.cfg` to set them on server start.

`spectator_chatinfo`  
Accepted values: `0`, `1`  
Default: `1`  
Description: Enables chat broadcast to all players.

`spectator_chatinfo_interval`  
Accepted values: any integer  
Default: `300` (5 minutes)  
Description: Sets interval of chat broadcast.

`spectator_chatinfo_message`  
Accepted values: any string  
Default: `"To spectate type spec in the console. Press A/D (LEFT/RIGHT) to change player."`  
Description: Sets text for chat broadcast.

`spectator_afterdeathcam`  
Accepted values: `0`, `1`  
Default: `0`  
Description: Automatically spectate your killer after death cam has ended.

`spectator_log`  
Accepted values: `0`, `1`  
Default: `0`  
Description: Enable or disable logging for this mod.

`spectator_namecards`  
Accepted values: `0`, `1`  
Default: `1`  
Description: Enable or disable namecards. Namecards need switching to the enemy team to be working correctly. Set this to 0 if you have issues with team switching/spawns. No effect if you use FFA gamemodes (always disabled in FFA).

`spectator_admins`  
Accepted values: "UID,UID" or "" (empty string)
Example 1: "12331232"  
Example 2: "2512342421,21315122,521452152"  
Default: ""  
Description: If you add UIDs in this string, spectator will only be available for these users. If the string is empty it will allow everybody to spectate.