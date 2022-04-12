# Spectator Mod
Server side mod that allows every player to spectate everyone.  
You can call the `spec` function with a string argument to spectate someone specific.

## Changes
- Add function "Automatically spectate your killer after death cam has ended" and related ConVar(int) `spectator_afterdeathcam`.
- Changed ConVars from Bool to Int (please update your config files) because somehow I am too stupid to make them work.
- Fix bug: spectator_chatinfo_message not appearing.
- Replaced spectator cycle function with something less shitty.
- !Hotfix: crash when attacker was not a player.
- Now displays name card of spectated player (to make it work you will switch to the enemy team when spectating, but you will be switched back on respawn). Does not work in FFA gamemodes.
## Known issues
- When you spectate an enemy but your auto titan is alive (probably also turrets and other things) and kills someone, the enemy team will get rewarded.
- FFA gamemodes will not show names.
- If you go OOB, immediately spec, immediately spawn in as titan => you will get killed (by OOB timer?)

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