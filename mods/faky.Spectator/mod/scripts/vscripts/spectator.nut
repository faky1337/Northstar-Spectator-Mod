//TODO: detect if target dies so we can switch to next player instead of not doing anything / intermission camera
//TODO: make player not switch team to spec enemy
//TODO: ?make player not use slot when spectating?
//TODO: ?add some error handling to avoid server crashes?
//TODO: Only allow allowed to spec option set by CVAR
//TODO: 
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
	LogString( "[SPECTATOR MOD] starting thread for spectator chatinfo broadcast" )
	thread SpectatorChatMessageThread()

	AddClientCommandCallback( "spec", ClientCommandCallbackSpectate )

	AddCallback_OnPlayerRespawned( SpectatorRemoveCycle )
	AddCallback_OnClientConnected( OnClientConnected )
	AddCallback_OnClientDisconnected( OnClientDisconnected )
	AddCallback_OnPlayerKilled( OnPlayerKilled )

	RegisterSignal( "SpectatorCycle" )
	RegisterSignal( "DeathcamOver" )
}

void function ThreadWaitPlayerRespawnStarted( entity player ) // needed so titan spawn camera works with this mod
{
	string playerName = player.GetPlayerName()
	LogString( "[SPECTATOR MOD] Started ThreadWaitPlayerRespawnStarted for " + player.GetPlayerName() )

	player.WaitSignal( "RespawnMe" )

	//this just seems works if you use it before/just right after signal "RespawnMe"!
	player.StopObserverMode()
	player.SetSpecReplayDelay( 0.0 )

	LogString( "[SPECTATOR MOD] Ended ThreadWaitPlayerRespawnStarted for " + playerName )
}

void function OnClientConnected( entity player )
{
	file.spectateTargets.append( player )
	LogString( "[SPECTATOR MOD] added " + player.GetPlayerName() + " to spectateTargets." )
}

void function OnClientDisconnected( entity player )
{
	//BUG: if a person is about to have a timeout and joins again before the server noticing the timeout the server might crash
	//Might be fixed by check 2 lines below. seems like if you reconnect fast the server actually disconnects the player twice?
	int i = file.spectateTargets.find( player )
	if( i >= 0 && i < file.spectateTargets.len() ) //check since int i might be null or something that might crash?
	{
		file.spectateTargets.remove( i )
		LogString( "[SPECTATOR MOD] removed " + player.GetPlayerName() + " from spectateTargets." )
	}
	else
	{
		LogString( "[SPECTATOR MOD] Tried to remove a player from the file.spectateTargets array, but there was an error finding the player in the array" )
	}
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	thread ThreadWaitPlayerRespawnStarted( victim ) // titan spawn camera workaround
	int victimTeam = victim.GetTeam()
	file.lastTeam[ victim ] <- victimTeam
	if( GetConVarInt( "spectator_afterdeathcam" ) == 1 && !( victim == attacker) ) // don't spectate if player killed himself
		thread OnPlayerKilledThread( victim, attacker )
	thread ThreadWaitDeathcam( victim )
}

void function ThreadWaitDeathcam( entity player )
{
	float deathcamLength = GetDeathCamLength( player )
	wait deathcamLength
	player.Signal( "DeathcamOver" )
}

void function SpectatorRemoveCycle( entity player ) // should be renamed to OnPlayerRespawned
{
	if ( player in file.lastTeam && !IsFFAGame() )
	{
		SetTeam( player, file.lastTeam[ player ])
		delete file.lastTeam[ player ]
	}

	if ( player in file.lastSpectated )
		delete file.lastSpectated[ player ]

	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )
}

void function OnPlayerKilledThread( entity victim, entity attacker )
{
	if( !IsValidPlayer( victim ) )
		return
	victim.EndSignal( "OnRespawned" )

	LogString( "[SPECTATOR MOD] OnPlayerKilledThread() started. Victim: " + victim + " Attacker: " + attacker )
	float deathCamlength = GetDeathCamLength( victim )
	LogString( "[SPECTATOR MOD] Deathcam length is: " + deathCamlength )
	array<string> args

	if( IsValidPlayer( attacker ) ) // make sure it's a player because victim could be killed by world/oob/..?
		args.append( attacker.GetPlayerName() )

	wait deathCamlength
	if( !IsValidPlayer( victim ) )
		return

	if ( victim.IsWatchingKillReplay() )
		victim.WaitSignal( "KillCamOver" )

	if( !IsAlive( victim ) && IsValidPlayer( victim ) )
	{
		ClientCommandCallbackSpectate( victim, args )
		LogString( "[SPECTATOR MOD] Called ClientCommandCallbackSpectate() from OnPlayerKilledThread(). Victim: " + victim )
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
						LogString( "[SPECTATOR MOD] Spectating yourself is disabled" )
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
			LogString( "[SPECTATOR MOD] Did not find specified player." )
			Chat_ServerPrivateMessage (player, "[SPECTATOR MOD] Did not find specified player.", true )
			return true
		}

		if( IsAlive( player ) )
			player.Die()

		thread SpectateCamera( player, target )
	}
	else
	{
		LogString( "[SPECTATOR MOD] Spactator is only available in Playing gamestate")
		Chat_ServerPrivateMessage( player, "[SPECTATOR MOD] Spactator is only available in Playing gamestate", false )
	}

	return true
}

//TODO: Rename functions
void function SpectateCamera( entity player, entity target ) //TODO: Rename this to SpectatorCameraSetup
{
	player.EndSignal( "PlayerRespawnStarted" )
	player.EndSignal( "OnRespawned" )

	LogString( "[SPECTATOR MOD] Called SpectateCamera() player: " + player + " target: " + target)
	// if player started spawning as titan or player wants to watch himself
	if( player.isSpawning || player == target )
		return

	file.lastSpectated[ player ] <- target

	WaitFrame() // wait for the frame otherwise IsWatchingKillReplay() is not true most of the time
	if( player.IsWatchingKillReplay() )
	{
		player.WaitSignal( "KillCamOver" ) // wait until killcam is over
		WaitFrame() // wait for frame because EndSignal OnRespawned might be a bit late or so?
	}
	LogString( "[SPECTATOR MOD] Player: " + player + " Target: " + target )
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

		//If player started spawning as titan
		if( player.isSpawning )
			return

		SetSpectatorCamera( player, target )
		ThreadSpectatorCameraDeathcamFix( player, target )
	}
}

void function SetSpectatorCamera( entity player, entity target )
{
	if( !IsAlive( player ) && IsValidPlayer( player ) && IsValidPlayer( target ) && IsAlive( target ) )
	{
		player.EndSignal( "PlayerRespawnStarted" )
		player.EndSignal( "OnRespawned" )

		player.SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY )
		player.SetObserverTarget( target )
		player.SetViewEntity( player.GetObserverTarget(), true )

		LogString( "[SPECTATOR MOD] SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY ) on player: " + player )
		if( !IsFFAGame() )
		{
			player.StartObserverMode( OBS_MODE_IN_EYE )
			LogString( "[SPECTATOR MOD] StartObserverMode( OBS_MODE_IN_EYE ) on player: " + player )
		}
	}
}

void function ThreadSpectatorCameraDeathcamFix( entity player, entity target )
{
	LogString( "[SPECTATOR MOD] ThreadSpectatorCameraDeathcamFix() player: " + player + " target: " + target )
	player.EndSignal( "PlayerRespawnStarted" )
	player.EndSignal( "OnRespawned" )
	player.EndSignal( "SpectatorCycle" ) // sometimes if you cycle too fast the fix will crash the server!

	// when calling the spec callback the player dies and resets to intermission camera after deathcam. just set the camera to once again.
	//float deathcamLength = GetDeathCamLength( player )
	player.WaitSignal( "DeathcamOver" )
	if( !IsValidPlayer ( player ) )
		return
	if ( player.IsWatchingKillReplay() )
		player.WaitSignal( "KillCamOver" )
	SetSpectatorCamera( player, target )
}

entity function SpectatorFindTarget( entity player, int cycleDirection )
{
	entity lastSpectated = GetPlayerByIndex(0) //entity of last spectated player or first player
	int nextSpectatedIndex = 0 // index of next spectated player from file.spectateTargets
	bool foundNoTarget = true

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

	int spectateTargetsCount = file.spectateTargets.len()
	int loops = 0
	while( foundNoTarget )
		{
			// if end or start of array was reached
			if( nextSpectatedIndex > file.spectateTargets.len() -1 )
				nextSpectatedIndex = 0
			if( nextSpectatedIndex < 0 )
				nextSpectatedIndex = file.spectateTargets.len() -1

			if( player == file.spectateTargets[ nextSpectatedIndex ] && ( cycleDirection == spectateCycle.NEXT || cycleDirection == spectateCycle.NONE ) )
				nextSpectatedIndex++
			else if( player == file.spectateTargets[ nextSpectatedIndex ] && cycleDirection == spectateCycle.PREVIOUS )
				nextSpectatedIndex--

			// do it again because we just changed the index
			if( nextSpectatedIndex > file.spectateTargets.len() -1 )
				nextSpectatedIndex = 0
			if( nextSpectatedIndex < 0 )
				nextSpectatedIndex = file.spectateTargets.len() -1

			if( IsAlive( file.spectateTargets[ nextSpectatedIndex ] ) )
			{
				break
			}

			loops++
			if( loops >= spectateTargetsCount )
				break

			if( cycleDirection == spectateCycle.PREVIOUS )
				nextSpectatedIndex--
			else
				nextSpectatedIndex++
		}

	return file.spectateTargets[ nextSpectatedIndex ]
}

bool function SpectatorCycleNext( entity player )
{
	player.Signal( "SpectatorCycle" )
	entity target = SpectatorFindTarget( player, spectateCycle.NEXT )
	thread SpectateCamera( player, target )
	return true
}

bool function SpectatorCyclePrevious( entity player )
{
	player.Signal( "SpectatorCycle" )
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

void function LogString( string logstring )
{
	if( GetConVarInt( "spectator_log" ) == 1 )
		print( logstring )
}