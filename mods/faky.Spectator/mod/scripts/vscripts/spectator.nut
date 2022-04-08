untyped
global function CustomSpectator_Init

void function CustomSpectator_Init()
{
	if( GetConVarBool( "spectator_chatinfo" ) )
		print( "[SPECTATOR MOD] enabled spectator chatinfo, starting thread" )
		thread SpectatorChatMessageThread()

	AddClientCommandCallback( "spec", ClientCommandCallbackSpectate )
}

bool function ClientCommandCallbackSpectate(entity player, array<string> args)
{
	int playerID = player.GetPlayerIndex() // get id of player calling this
	int SpectatedPlayerID = 128

	if( GetGameState() == eGameState.Playing )
	{
		foreach( playerfromarray in GetPlayerArray() )
		{
			if(args.len() > 0)
			{
				var findresult = playerfromarray.GetPlayerName().tolower().find( args[0].tolower() )
				if( type( findresult ) == "null" ) //.find did not find substring
				{

				}

				if( type( findresult ) == "int" ) //.find found substring
				{
					SpectatedPlayerID = playerfromarray.GetPlayerIndex()
					if( !( GetConVarBool( "spectator_selfspec_allow" ) ) && ( player.GetPlayerIndex() == SpectatedPlayerID ) )
					{
						print( "[SPECTATOR MOD] Spectating yourself is disabled" )
						Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Spectating yourself is disabled", true)
						return true
					}
				}
			}
		}

		if(SpectatedPlayerID == 128) //playerID has not changed
		{
			print("[SPECTATOR MOD DEBUG] Spectate playerid 128")
			print( "[SPECTATOR MOD] spec could not find the specified player" )
			Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] spec could not find the specified player", true)
			return true
		}

		entity target = GetPlayerByIndex(SpectatedPlayerID)
		print( "[SPECTATOR MOD] spectating player ID: " + SpectatedPlayerID + " Name: " + GetPlayerByIndex( SpectatedPlayerID ).GetPlayerName() )
		thread SpectateThread_MP(player, target)
	}
	else
	{
		print( "[SPECTATOR MOD] Spactator is only available in Playing gamestate")
		Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Spactator is only available in Playing gamestate", true)
	}
	return true
}

void function SpectateThread_MP( entity player, entity target )
{
	if( IsAlive( player ) )
		player.Die()
	player.SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY )
	player.SetObserverTarget( target )
	player.SetViewEntity( player.GetObserverTarget(), true )
	player.StartObserverMode( OBS_MODE_IN_EYE_SIMPLE ) // should use OBS_MODE_IN_EYE or CHASE, but they don't seem to be able to view the enemy team
}

void function SpectatorChatMessageThread()
{
	while(true)
	{
		wait GetConVarFloat( "spectator_chatinfo_interval" )
		if(GetConVarBool( "spectator_chatinfo" ) )
			Chat_ServerBroadcast( GetConVarString( "spectator_chatinfo_message" ) )
	}
}