# Spectator Mod
Server side mod that allows every player to spectate everyone.  
Unfortunately it does not display names, but you can call the `spec` function with a string argument to spectate someone specific.

## Changes
- Add function "Automatically spectate your killer after death cam has ended" and related ConVar(int) `spectator_afterdeathcam`.
- Changed ConVars from Bool to Int (please update your config files) because somehow I am too stupid to make them work.
- Fix bug: spectator_chatinfo_message not appearing.
- Replaced spectator cycle function with something less shitty.
- !Hotfix crash when attacker was not a player.

## Usage
Type `spec` into console. Use A/D (LEFT/RIGHT) to switch between players.  
Type `spec pla` to spec a player whose name has `pla` in his name (would for example spectate on "player" now).

## Features still needed
1) Display the name of spectate target (can't send chat messages to player while spectating with `Chat_ServerPrivateMessage` or use OBS_MODE_IN_EYE on to display name card, because OBS_MODE_IN_EYE/THIRD_PERSON seem to only work on same team).

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