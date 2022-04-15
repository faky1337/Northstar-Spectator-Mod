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
- 13 April: fix some of the frequent crashes because player entity is not valid anymore.
- 15 April: fix cam sometimes switching again / name card appearing late.
- 15 April: HOTFIX crash when spectated player (target) dies during deathcam duration
- 15 April: if you cycle through players skip players not alive.
- 15 April: You can now enable/disable logging with the ConVar `spectator_log`
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