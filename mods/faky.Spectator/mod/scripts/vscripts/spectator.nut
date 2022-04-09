untyped
global function CustomSpectator_Init
global float spectatorPressedDebounceTime = 0.4

struct
{
	table<entity, entity> lastSpectated = {}
	array<entity> spectateTargets = []
} file

void function CustomSpectator_Init()
{
	if( GetConVarBool( "spectator_chatinfo" ) )
		print( "[SPECTATOR MOD] enabled spectator chatinfo, starting thread" )
		thread SpectatorChatMessageThread()

	AddClientCommandCallback( "spec", ClientCommandCallbackSpectate )

	//remove next/previous cycle on respawn
	AddCallback_OnPlayerRespawned( SpectatorRemoveCycle )
	AddCallback_OnClientConnected( OnClientConnected )
	AddCallback_OnClientDisconnected( OnClientDisconnected )
}

void function OnClientConnected( entity player )
{
	file.spectateTargets.append( player )
	print( "[SPECTATOR MOD] added " + player.GetPlayerName() + " to spectateTargets." )
}

void function OnClientDisconnected( entity player )
{
	int i = file.spectateTargets.find( player )
	file.spectateTargets.remove( i )
}

bool function ClientCommandCallbackSpectate(entity player, array<string> args)
{
	//cleanup stuff so we dont accidentally call cycle later
	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

	if( GetGameState() == eGameState.Playing )
	{
		entity target = GetPlayerByIndex(0)
		if( player in file.lastSpectated )
		{
			if( IsValid( file.lastSpectated[ player ] ) )
				target = file.lastSpectated[ player ]
		}

		// if user typed in name
		if( args.len() > 0)
		{
			foreach( playerfromarray in GetPlayerArray() ) //find target
			{
				var findresult = playerfromarray.GetPlayerName().tolower().find( args[0].tolower() )

				if( type( findresult ) == "int" ) //.find found substring
				{
					target = playerfromarray
					if( ( player == target ) )
					{
						print( "[SPECTATOR MOD] Spectating yourself is disabled" )
						Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Spectating yourself is disabled", true)
						return true
					}
				}
			}
		}


		AddPlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
		AddPlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

		//if we did not find a target before even user specified string in args
		if( target == player && args.len() > 0)
		{
			print( "[SPECTATOR MOD] Did not find specified player." )
			Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Did not find specified player.", true)
			return true
		}

		if( IsAlive( player ) )
			player.Die()

		//just cycle to next player if current player has actually index 0 (if youre hosting a private match from the game)
		if( target == player )
		{
			SpectatorCycleNext( player )
			return true
		}

		SpectateCamera( player, target )
	}
	else
	{
		print( "[SPECTATOR MOD] Spactator is only available in Playing gamestate")
		Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Spactator is only available in Playing gamestate", false)
	}

	return true
}

void function SpectateCamera( entity player, entity target )
{
	file.lastSpectated[ player ] <- target

	print( "[SPECTATOR MOD] Player: " + player + " Target: " + target )
	Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Spectating: " + target.GetPlayerName(), false)
	if( IsAlive( player ) )
		player.Die()

	if( player == target )
		return

	if( IsAlive( target ) )
	{
		player.SetObserverTarget( target )
		player.SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY ) //first
		player.SetViewEntity( player.GetObserverTarget(), true ) // first person
		//player.StartObserverMode( OBS_MODE_IN_EYE_SIMPLE ) // change observermode not needed?
	}
}


//watch out!!!! absolute shitshow coming up for cyclenext and previous. this needs to be redone holy fuck.
// sorry if you have to read this :|
bool function SpectatorCycleNext( entity player )
{
	entity lastSpectated = GetPlayerByIndex(0)
	if( player in file.lastSpectated )
	{
		lastSpectated = file.lastSpectated[ player ]
	}

	int i = file.spectateTargets.find( lastSpectated )
	i++

	if( i > ( file.spectateTargets.len() -1 ) )
	{
		if( player == file.spectateTargets[ 0 ] )
			{
				if( file.spectateTargets.len() > 1 )
				{
					SpectateCamera( player, file.spectateTargets[ 1 ] )
					return true
				}
				return true
			}
		SpectateCamera( player, file.spectateTargets[ 0 ] )
		return true
	}
	else
	{
		if( player == file.spectateTargets[ i ] )
		{
			i++
			if( i > file.spectateTargets.len() )
				SpectateCamera( player, file.spectateTargets[ 0 ] )
				return true
		}
		SpectateCamera( player, file.spectateTargets[ i ] )
		return true
	}

	return true
}

//shit #2
bool function SpectatorCyclePrevious( entity player )
{
	entity lastSpectated = GetPlayerByIndex(0)
	if( player in file.lastSpectated )
	{
		lastSpectated = file.lastSpectated[ player ]
	}

	int i = file.spectateTargets.find( lastSpectated )
	i--

	if( i  < 0 )
	{
		int len = ( file.spectateTargets.len() -1 )
		if( player == file.spectateTargets[ len ] )
		{
			len--
			if( len == -1)
				return true
		}
		SpectateCamera( player, file.spectateTargets[ len ] )
		return true
	}
	else
		if( player == file.spectateTargets[ i ] )
		{
			i--
			if( i < 0 )
			{
				int len = ( file.spectateTargets.len() -1 )
				SpectateCamera( player, file.spectateTargets[ len ] )
				return true
			}
		}
		if( i < 0 )
			return true
		SpectateCamera( player, file.spectateTargets[ i ] )

	return true
}

void function SpectatorRemoveCycle( entity player )
{
	if (player in file.lastSpectated)
		delete file.lastSpectated[ player ]
	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )
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