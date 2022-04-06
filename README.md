# Spectator Mod
Enables spectator through deathcam for everyone.

## Usage

Open ingame console, type `spec NICKNAME`.  
Example: `spec faky` (works with parts of the name)  
To end spec: `endspec`

## ConVars for chat announcements
You can use following ConVars to edit the config on the run or add them to your `autoexec_ns_server.cfg` to set them.

`spectator_chatinfo`  
Accepted values: `true`, `false`  
Default: `false`

`spectator_chatinfo_interval`  
Accepted values: any integer  
Default: `300` (5 minutes)

`spectator_chatinfo_message`  
Accepted values: any string  
Default: `"to spectate someone type spec NICKNAME in the console. To exit spectator type endspec."`