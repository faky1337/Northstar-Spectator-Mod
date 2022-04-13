untyped
global function CustomSpectator_Init
global float spectatorPressedDebounceTime = 0.4

struct
{
	table<entity, entity> lastSpectated = {}
	table<entity, int> lastTeam = {}
	array<entity> spectateTargets = []
} file

enum spectateCycle
{
	NONE,
	NEXT,
	PREVIOUS
}

void function CustomSpectator_Init()
{
	print( "[SPECTATOR MOD] starting thread for spectator chatinfo broadcast" )
	thread SpectatorChatMessageThread()

	AddClientCommandCallback( "spec", ClientCommandCallbackSpectate )

	AddCallback_OnPlayerRespawned( SpectatorRemoveCycle )
	AddCallback_OnClientConnected( OnClientConnected )
	AddCallback_OnClientDisconnected( OnClientDisconnected )
	AddCallback_OnPlayerKilled( OnPlayerKilled )
}


void function ThreadWaitPlayerRespawnStarted( entity player )
{
	string playerName = player.GetPlayerName()
	print( "[SPECTATOR MOD] Started ThreadWaitPlayerRespawnStarted for " + player.GetPlayerName() )

	player.WaitSignal( "RespawnMe" )

	//this just seems works if you use it before/just right after signal "RespawnMe"!
	player.StopObserverMode()
	player.SetSpecReplayDelay( 0.0 )

	print( "[SPECTATOR MOD] Ended ThreadWaitPlayerRespawnStarted for " + playerName )
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
	print( "[SPECTATOR MOD] removed " + player.GetPlayerName() + " from spectateTargets." )
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	thread ThreadWaitPlayerRespawnStarted( victim )
	int victimTeam = victim.GetTeam()
	file.lastTeam[ victim ] <- victimTeam
	if( GetConVarInt( "spectator_afterdeathcam" ) == 1 && !( victim == attacker) ) // don't spectate if player killed himself
		thread OnPlayerKilledThread( victim, attacker )
}

void function SpectatorRemoveCycle( entity player ) // should be renamed to OnPlayerRespawned
{
	if ( player in file.lastSpectated )
		delete file.lastSpectated[ player ]

	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )
	if ( player in file.lastTeam && !IsFFAGame() )
	{
		SetTeam( player, file.lastTeam[ player ])
		delete file.lastTeam[ player ]
	}
}

void function OnPlayerKilledThread( entity victim, entity attacker )
{
	float deathCamlength = GetDeathCamLength( victim )
	array<string> args

	if( IsValidPlayer( attacker ) ) // make sure it's a player because victim could be killed by world/oob/..?
		args.append( attacker.GetPlayerName() )

	wait deathCamlength + 9 //add seconds just to make sure every sort of death cam is over
	if( !IsAlive( victim ) && IsValidPlayer( victim ) )
	{
		ClientCommandCallbackSpectate( victim, args ) // CRASH SCRIPT ERROR: [SERVER] Attempted to call GetSendInputCallbacks on invalid entity
	}
}

bool function ClientCommandCallbackSpectate(entity player, array<string> args)
{
	//cleanup stuff so we dont accidentally call cycle later
	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

	if( GetGameState() == eGameState.Playing )
	{
		entity target = SpectatorFindTarget( player, spectateCycle.NONE )

		// if user typed in name
		if( args.len() > 0 )
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
						Chat_ServerPrivateMessage( player, "[SPECTATOR MOD] Spectating yourself is disabled", true )
						return true
					}
				}
			}
		}

		AddPlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
		AddPlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

		// if we did not find a target before even user specified string in args
		if( target == player && args.len() > 0 )
		{
			print( "[SPECTATOR MOD] Did not find specified player." )
			Chat_ServerPrivateMessage (player, "[SPECTATOR MOD] Did not find specified player.", true )
			return true
		}

		if( IsAlive( player ) )
			player.Die()

		thread SpectateCamera( player, target )
	}
	else
	{
		print( "[SPECTATOR MOD] Spactator is only available in Playing gamestate")
		Chat_ServerPrivateMessage( player, "[SPECTATOR MOD] Spactator is only available in Playing gamestate", false )
	}

	return true
}

void function SpectateCamera( entity player, entity target )
{
	// if player started spawning as titan or player wants to watch himself
	if( player.isSpawning || player == target )
		return

	file.lastSpectated[ player ] <- target

	print( "[SPECTATOR MOD] Player: " + player + " Target: " + target )
	Chat_ServerPrivateMessage( player, "[SPECTATOR MOD] Spectating: " + target.GetPlayerName(), false )
	if( IsAlive( player ) )
		player.Die()

	if( IsAlive( target ) )
	{
		int playerTeam = player.GetTeam()
		int targetTeam = target.GetTeam()
		if( playerTeam != targetTeam && !IsFFAGame() )
		{
			SetTeam( player, targetTeam )
		}

		player.SetObserverTarget( target )
		player.SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY )
		player.SetViewEntity( player.GetObserverTarget(), true )

		float deathcamLength = GetDeathCamLength( player )
		wait deathcamLength
		if( player.isSpawning )
			return

		//If player started spawning as titan
		if( !IsAlive( player ) && IsValidPlayer( player ) )
		{
			player.SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY ) // CRASH SCRIPT ERROR: [SERVER] Attempted to call SetSpecReplayDelay on invalid entity
			if( !IsFFAGame() )
				player.StartObserverMode( OBS_MODE_IN_EYE )
		}
	}
}

entity function SpectatorFindTarget( entity player, int cycleDirection )
{
	entity lastSpectated = GetPlayerByIndex(0) //entity of last spectated player or first player
	int nextSpectatedIndex = 0 // index of next spectated player from file.spectateTargets

	if( player in file.lastSpectated )
	{
		lastSpectated = file.lastSpectated[ player ]
	}

	nextSpectatedIndex = file.spectateTargets.find( lastSpectated ) //get last spectated player index first
	switch( cycleDirection )
	{
		case spectateCycle.NONE:
			break
		case spectateCycle.NEXT:
			nextSpectatedIndex++
			break
		case spectateCycle.PREVIOUS:
			nextSpectatedIndex--
			break
	}

	if( nextSpectatedIndex > file.spectateTargets.len() -1 )
		nextSpectatedIndex = 0
	if( nextSpectatedIndex < 0 )
		nextSpectatedIndex = file.spectateTargets.len() -1

	if( player == file.spectateTargets[ nextSpectatedIndex ] && ( cycleDirection == spectateCycle.NEXT || cycleDirection == spectateCycle.NONE ) )
		nextSpectatedIndex++
	else if( player == file.spectateTargets[ nextSpectatedIndex ] && cycleDirection == spectateCycle.PREVIOUS )
		nextSpectatedIndex--

	if( nextSpectatedIndex > file.spectateTargets.len() -1 )
		nextSpectatedIndex = 0
	if( nextSpectatedIndex < 0 )
		nextSpectatedIndex = file.spectateTargets.len() -1

	return file.spectateTargets[ nextSpectatedIndex ]
}

bool function SpectatorCycleNext( entity player )
{
	entity target = SpectatorFindTarget( player, spectateCycle.NEXT )
	thread SpectateCamera( player, target )
	return true
}

bool function SpectatorCyclePrevious( entity player )
{
	entity target = SpectatorFindTarget( player, spectateCycle.PREVIOUS )
	thread SpectateCamera( player, target )
	return true
}

void function SpectatorChatMessageThread()
{
	while(true)
	{
		wait GetConVarFloat( "spectator_chatinfo_interval" )
		if(GetConVarInt( "spectator_chatinfo" ) == 1 )
			Chat_ServerBroadcast( GetConVarString( "spectator_chatinfo_message" ) )
	}
}