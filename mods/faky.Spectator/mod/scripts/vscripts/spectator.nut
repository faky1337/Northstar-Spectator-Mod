//most code is from PostDeathThread_MP in _base_gametype_mp.gnut (v1.6.1)

untyped

global function CustomSpectator_Init
global array<bool> endspec = [true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true]
global array<bool> isspeccing = [false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false]

void function CustomSpectator_Init()
{
	isspeccing = [false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false,false]

	if( GetConVarBool( "spectator_chatinfo" ) )
		print( "[SPECTATOR MOD] enabled spectator chatinfo, starting thread" )
		thread SpectatorChatMessageThread()

	AddClientCommandCallback( "spec", ClientCommandCallbackSpectate )
	AddClientCommandCallback( "endspec", ClientCommandCallbackEndSpectator )
}


bool function ClientCommandCallbackSpectate(entity player, array<string> args)
{
	int playerID = player.GetPlayerIndex() // get id of player calling this

	if( isspeccing[playerID] )
	{
		print( "[SPECTATOR MOD] Already spectating" )
		Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Already spectating", true)
		return true
	}

	int SpectatedPlayerID = 128

	if( GetGameState() == eGameState.Playing )
	{
		foreach( playerfromarray in GetPlayerArray() )
		{
			if(args.len() > 0)
			{
				var findresult = playerfromarray.GetPlayerName().tolower().find( args[0] )
				if( type( findresult ) == "null" ) //.find did not find substring
				{
					print( "[SPECTATOR MOD] spec could not find the specified player" )
					Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] spec could not find the specified player", true)
					return true
				}

				if( type( findresult ) == "int" ) //.find found substring
					SpectatedPlayerID = playerfromarray.GetPlayerIndex()
			}
		}

		if(SpectatedPlayerID == 128) //playerID has not changed
		{
			print("[SPECTATOR MOD DEBUG] Spectate playerid 128")
			return true
		}

		entity attacker = GetPlayerByIndex(SpectatedPlayerID) //attacker == player who's getting spectated
		endspec[playerID] = false
		print( "[SPECTATOR MOD] spectating player ID: " + SpectatedPlayerID + " Name: " + GetPlayerByIndex( SpectatedPlayerID ).GetPlayerName() )
		thread SpectateThread_MP(player, attacker)
	}
	else
	{
		print( "[SPECTATOR MOD] Spactator is only available in Playing gamestate")
		Chat_ServerPrivateMessage(player, "[SPECTATOR MOD] Spactator is only available in Playing gamestate", true)
	}
	return true
}

void function SpectateThread_MP( entity player, entity attacker )
{
	int playerID = player.GetPlayerIndex()
	if ( IsAlive( player ) )
		player.Die()

	float timeOfDeath = Time() //time of start spectate
	player.p.postDeathThreadStartTime = Time()

	Assert( IsValid( player ), "Not a valid player" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnRespawned" )

	player.p.deathOrigin = player.GetOrigin()
	player.p.deathAngles = player.GetAngles()

	player.s.inPostDeath = true
	player.s.respawnSelectionDone = false

	player.cloakedForever = false
	player.stimmedForever = false
	player.SetNoTarget( false )
	player.SetNoTargetSmartAmmo( false )
	player.ClearExtraWeaponMods()

	// disable prediction to prevent it messing with ragdoll in some places, as well as killreplay and such
	player.SetPredictionEnabled( false )

	if ( player.IsTitan() )
		SoulDies( player.GetTitanSoul(), null ) // cleanup some titan stuff, no idea where else to put this

	//ClearRespawnAvailable( player )

	OnThreadEnd( function() : ( player, attacker )
	{
		if ( !IsValid( player ) )
			return

		player.s.inPostDeath = false
	})

	int methodOfDeath = eDamageSourceId.switchback_trap

	player.Signal( "RodeoOver" )
	player.ClearParent()

	// do some pre-replay stuff if we're gonna do a replay
	float replayLength = 2.0 // spectator mod: less = less delay, more = more stable
	bool shouldDoReplay = Replay_IsEnabled() && KillcamsEnabled() && IsValid( attacker ) // had to remove this for spectate ==> && ShouldDoReplay( player, attacker, replayLength, methodOfDeath )
	table replayTracker = { validTime = null }
	if ( shouldDoReplay )
		thread TrackDestroyTimeForReplay( attacker, replayTracker )

	player.StartObserverMode( OBS_MODE_DEATHCAM )
	if ( ShouldSetObserverTarget( attacker ) )
		player.SetObserverTarget( attacker )
	else
		player.SetObserverTarget( null )

	float deathcamLength = GetDeathCamLength( player )


	// hack: double check if killcams are enabled and valid here in case gamestate has changed this
	shouldDoReplay = shouldDoReplay && Replay_IsEnabled() && KillcamsEnabled() && IsValid( attacker )
	// quick note: in cases where player.Die() is called: e.g. for round ends, player == attacker
	if ( shouldDoReplay )
	{
		player.watchingKillreplayEndTime = Time() + replayLength
		float beforeTime = 1.0 //GetKillReplayBeforeTime( player, methodOfDeath )

		replayTracker.validTime <- null

		//not sure if it makes sense to change respawnTime for spectator mod
		float respawnTime = Time() + 2 // seems to get the killreplay to end around the actual kill
		if ( "respawnTime" in attacker.s )
		{
			respawnTime = Time() - expect float ( attacker.s.respawnTime )
		}

		isspeccing[playerID] = true
		thread PlayerWatchesKillReplayWrapperSpectate( player, attacker, respawnTime, timeOfDeath, beforeTime, replayTracker )
	}

	player.SetPlayerSettings( "spectator" ) // prevent a crash with going from titan => pilot on respawn
	player.StopPhysics() // need to set this after SetPlayerSettings

}

void function PlayerWatchesKillReplayWrapperSpectate( entity player, entity attacker, float timeSinceAttackerSpawned, float timeOfDeath, float beforeTime, table replayTracker )
{
	player.EndSignal( "RespawnMe" )
	player.EndSignal( "OnRespawned" )

	player.EndSignal( "OnDestroy" )
	attacker.EndSignal( "OnDestroy" )

	svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	OnThreadEnd( function() : ( player, attacker )
	{
		int playerID = player.GetPlayerIndex()
		// don't clear if we're in a roundwinningkillreplay
		if ( IsValid( player ) && !( ( GetGameState() == eGameState.SwitchingSides || GetGameState() == eGameState.WinnerDetermined ) && IsRoundWinningKillReplayEnabled() ) )
		{
			player.Signal( "KillCamOver" )
			player.ClearReplayDelay()
			player.ClearViewEntity()
			//player.SetPredictionEnabled( true ) doesn't seem needed, as native code seems to set this on respawn

			if( endspec[playerID] )
			{
				isspeccing[playerID] = false //dont start another spectate thread
			}else
			{
				thread SpectateThread_MP(player, attacker)
			}
		}
	})

	player.SetPredictionEnabled( false )
	PlayerWatchesKillReplay( player, attacker.GetEncodedEHandle(), attacker.GetIndexForEntity(), timeSinceAttackerSpawned, timeOfDeath, beforeTime, replayTracker )
}

bool function ClientCommandCallbackEndSpectator( entity player, array<string> args )
{
	int playerID = player.GetPlayerIndex()
	endspec[playerID] = true
	isspeccing[playerID] = false
	return true
}

void function SpectatorChatMessageThread()
{
	while(true)
	{
		wait GetConVarFloat( "spectator_chatinfo_interval" )
		Chat_ServerBroadcast( GetConVarString( "spectator_chatinfo_message" ) )
	}
}