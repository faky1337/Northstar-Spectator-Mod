//TODO: make player not switch team to spec enemy. HOW? (only without namecards obs_mode_in_eye, also when spectating cant send player chat messages / hud messages from server :|)
//TODO: make player not use slot when spectating. Is that even possible?
//TODO: make logging actually good. :|
//TODO: actually make us of OnThreadEnd()
untyped
global function CustomSpectator_Init
float spectatorPressedDebounceTime = 0.4
int spectator_namecards
array<string> spectator_admins

struct
{
	table<entity, entity> lastSpectated = {}
	table<entity, int> lastTeam = {}
	array<entity> spectateTargets = []
	table<entity, float> playerRespawnTime = {}
} file

enum spectateCycle
{
	NONE,
	NEXT,
	PREVIOUS
}

void function CustomSpectator_Init()
{
	spectator_namecards = GetConVarInt( "spectator_namecards" )
	spectator_admins = split( GetConVarString( "spectator_admins" ), "," )

	LogString( "starting thread for spectator chatinfo broadcast" )
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
	player.EndSignal( "Disconnected" )

	try
	{
		string playerName = player.GetPlayerName()
		LogString( "Started ThreadWaitPlayerRespawnStarted for " + player.GetPlayerName() )

		player.WaitSignal( "RespawnMe" )
		LogString( "After wait for Signal RespawnMe in ThreadWaitPlayerRespawnStarted()" )
		LogString( "Removing PressedCallback" )
		RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime ) // try to fix respawnastitan bug
		RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime ) // try to fix respawnastitan bug

		//this just seems works if you use it before/just right after signal "RespawnMe"!
		player.StopObserverMode()
		player.SetSpecReplayDelay( 0.0 )

		LogString( "Ended ThreadWaitPlayerRespawnStarted for " + playerName )
	}
	catch( ex )
	{
		LogString( "[ERROR]: " + ex )
	}
}

void function OnClientConnected( entity player )
{
	file.spectateTargets.append( player )
	LogString( "added " + player.GetPlayerName() + " to spectateTargets." )
}

void function OnClientDisconnected( entity player )
{
	//BUG: if a person is about to have a timeout and joins again before the server noticing the timeout the server might crash
	//Might be fixed by check 2 lines below. seems like if you reconnect fast the server actually disconnects the player twice?
	int i = file.spectateTargets.find( player )
	if( i >= 0 && i < file.spectateTargets.len() ) //check since int i might be null or something that might crash?
	{
		file.spectateTargets.remove( i )
		LogString( "removed " + player.GetPlayerName() + " from spectateTargets." )
	}
	else
	{
		LogString( "Tried to remove a player from the file.spectateTargets array, but there was an error finding the player in the array" )
	}
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	try
	{
		delete file.playerRespawnTime[ victim ]
		thread ThreadWaitPlayerRespawnStarted( victim ) // titan spawn camera workaround
		int victimTeam = victim.GetTeam()
		file.lastTeam[ victim ] <- victimTeam
		if( GetConVarInt( "spectator_afterdeathcam" ) == 1 && !( victim == attacker) ) // don't spectate if player killed himself
			thread OnPlayerKilledThread( victim, attacker )
		thread ThreadWaitDeathcam( victim )
	}
	catch( ex )
	{
		LogString( "[ERROR]: " + ex )
	}
}

void function ThreadWaitDeathcam( entity player )
{
	player.EndSignal( "Disconnected" )

	try
	{
		float deathcamLength = GetDeathCamLength( player )
		wait deathcamLength
		LogString( "After wait for deathcamLength (float)." )
		player.Signal( "DeathcamOver" )
	}
	catch( ex )
	{
		LogString( "[ERROR]: " + ex )
	}
}

void function SpectatorRemoveCycle( entity player ) // should be renamed to OnPlayerRespawned
{
	LogString( "Removing PressedCallback" )
	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

	file.playerRespawnTime[ player ] <- Time()
	if ( player in file.lastTeam && !IsFFAGame() && spectator_namecards > 0 )
	{
		SetTeam( player, file.lastTeam[ player ])
		delete file.lastTeam[ player ]
	}

	if ( player in file.lastSpectated )
		delete file.lastSpectated[ player ]
}

void function OnPlayerKilledThread( entity victim, entity attacker )
{
	if( !IsValidPlayer( victim ) )
		return

	victim.EndSignal( "OnRespawned" )
	victim.EndSignal( "Disconnected" )

	try
	{
		LogString( "OnPlayerKilledThread() started. Victim: " + victim + " Attacker: " + attacker )
		float deathCamlength = GetDeathCamLength( victim )
		LogString( "Deathcam length is: " + deathCamlength )
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
			LogString( "Called ClientCommandCallbackSpectate() from OnPlayerKilledThread(). Victim: " + victim )
		}
	}
	catch( ex )
	{
		LogString( "[ERROR]: " + ex )
	}
}

bool function ClientCommandCallbackSpectate(entity player, array<string> args)
{
	LogString( "Removing PressedCallback" )
	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

	if( spectator_admins.len() > 0 && !spectator_admins.contains( player.GetUID() ) )
		return false
	//cleanup stuff so we dont accidentally call cycle later

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
						LogString( "Spectating yourself is disabled" )
						Chat_ServerPrivateMessage( player, "Spectating yourself is disabled", true )
						return true
					}
				}
			}
		}

		// if we did not find a target before even user specified string in args
		if( target == player && args.len() > 0 )
		{
			LogString( "Did not find specified player." )
			Chat_ServerPrivateMessage (player, "Did not find specified player.", true )
			return true
		}

		//if( IsAlive( player ) )
			//player.Die()

		thread SpectateCamera( player, target )
	}
	else
	{
		LogString( "Spactator is only available in Playing gamestate")
		Chat_ServerPrivateMessage( player, "Spactator is only available in Playing gamestate", false )
	}

	return true
}

//TODO: Rename functions
void function SpectateCamera( entity player, entity target ) //TODO: Rename this to SpectatorCameraSetup
{
	LogString( "Removing PressedCallback in SpectateCamera () before EndSignals block" )
	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )
	player.EndSignal( "PlayerRespawnStarted" )
	player.EndSignal( "OnRespawned" )
	player.EndSignal( "Disconnected" )

	try
	{
		LogString( "Called SpectateCamera() player: " + player + " target: " + target)
		//LogString( "Deathcam length: " + GetDeathCamLength( player ) )
		LogString( "Removing PressedCallback" )
		RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
		RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

		file.lastSpectated[ player ] <- target

		WaitFrame() // wait for the frame otherwise IsWatchingKillReplay() is not true most of the time

		if( !IsValidPlayer( player ) || !IsValidPlayer( target ))
			return
		if( GetConVarInt( "spectator_teamonly" ) == 1 && target.GetTeam() != player.GetTeam() )
			return

		if( player.IsWatchingKillReplay() )
		{
			player.WaitSignal( "KillCamOver" ) // wait until killcam is over
			WaitFrame() // wait for frame because EndSignal OnRespawned might be a bit late or so?
			if( !IsValidPlayer( player ) || !IsValidPlayer( target ))
				return
		}

		if( !IsValidPlayer( player ) || !IsValidPlayer( target ) ) // check if players are valid or we might crash later using invalid players
			return
		if( player.isSpawning )
			return
		LogString( "Player: " + player + " Target: " + target )
		if( IsAlive( player ) && ( Time() - file.playerRespawnTime[ player ]  ) > 2.0 )
			player.Die()

		if( IsAlive( target ) && !IsAlive( player ) )
		{
			int playerTeam = player.GetTeam()
			int targetTeam = target.GetTeam()
			if( playerTeam != targetTeam && !IsFFAGame() && spectator_namecards > 0 )
			{
				SetTeam( player, targetTeam )
			}
			LogString( "Adding PressedCallback in SpectateCamera()" )
			AddPlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
			AddPlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )
			Chat_ServerPrivateMessage( player, "Spectating: " + target.GetPlayerName(), false )
			SetSpectatorCamera( player, target )
			thread ThreadSpectatorCameraDeathcamFix( player, target )
		}
	}
	catch( ex )
	{
		LogString( "[ERROR]: " + ex )
	}
}

void function SetSpectatorCamera( entity player, entity target )
{
	try
	{
		if( !IsAlive( player ) && IsValidPlayer( player ) && IsValidPlayer( target ) && IsAlive( target ) )
		{
			player.EndSignal( "PlayerRespawnStarted" )
			player.EndSignal( "OnRespawned" )

			player.SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY )
			player.SetObserverTarget( target )
			player.SetViewEntity( player.GetObserverTarget(), true )

			LogString( "SetSpecReplayDelay( FIRST_PERSON_SPECTATOR_DELAY ) on player: " + player )
			if( !IsFFAGame()  && spectator_namecards > 0)
			{
				player.StartObserverMode( OBS_MODE_IN_EYE )
				LogString( "StartObserverMode( OBS_MODE_IN_EYE ) on player: " + player )
			}
		}
	}
	catch( ex )
	{
		LogString( "[ERROR]:" + ex )
	}
}

void function ThreadSpectatorCameraDeathcamFix( entity player, entity target )
{
	LogString( "ThreadSpectatorCameraDeathcamFix() player: " + player + " target: " + target )
	player.EndSignal( "PlayerRespawnStarted" )
	player.EndSignal( "OnRespawned" )
	player.EndSignal( "SpectatorCycle" ) // sometimes if you cycle too fast the fix will crash the server!
	player.EndSignal( "Disconnected" )

	try
	{
		// when calling the spec callback the player dies and resets to intermission camera after deathcam. just set the camera to once again.
		//float deathcamLength = GetDeathCamLength( player )
		player.WaitSignal( "DeathcamOver" )
		LogString("after Wait for Signal DeathcamOver signal int ThreadSpectatorCameraDeathcamFix()")
		if( !IsValidPlayer ( player ) )
			return
		if ( player.IsWatchingKillReplay() )
			player.WaitSignal( "KillCamOver" )
		SetSpectatorCamera( player, target )
	}
	catch( ex )
	{
		LogString( "[ERROR]:" + ex )
	}
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
		print( "[SPECTATOR MOD] [" + Time() + "] " + logstring )
}