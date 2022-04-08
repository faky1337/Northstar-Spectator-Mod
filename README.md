# Spectator Mod
Spectate everyone on the server.

## Known issues
If spec is called in deathcam you get a bug and need to respawn / spec again.

## Usage
Type spec then parts of the nickname.  
Example: `spec fa` will spec the first player whose nickname contains the string `fa`

## ConVars for chat announcements
You can use following ConVars to edit the config on the run or add them to your `autoexec_ns_server.cfg` to set them.

`spectator_selfspec_allow`  
Accepted values: `true`, `false` 
default: `false`  
Description: Allows spectating yourself for testing purposes.

`spectator_chatinfo`  
Accepted values: `true`, `false`  
Default: `false`

`spectator_chatinfo_interval`  
Accepted values: any integer  
Default: `300` (5 minutes)
`spectator_chatinfo_message`  
Accepted values: any string  
Default: `"To spectate someone type spec NICKNAME or spec PARTOFNAME in the console."`