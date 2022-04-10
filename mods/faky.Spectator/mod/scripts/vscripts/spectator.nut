untyped
global function CustomSpectator_Init
global float spectatorPressedDebounceTime = 0.4

struct
{
	table<entity, entity> lastSpectated = {}
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
	if( GetConVarInt( "spectator_chatinfo" ) == 1)
		print( "[SPECTATOR MOD] enabled spectator chatinfo, starting thread" )
		thread SpectatorChatMessageThread()

	AddClientCommandCallback( "spec", ClientCommandCallbackSpectate )

	//remove next/previous cycle on respawn
	AddCallback_OnPlayerRespawned( SpectatorRemoveCycle )
	AddCallback_OnClientConnected( OnClientConnected )
	AddCallback_OnClientDisconnected( OnClientDisconnected )
	AddCallback_OnPlayerKilled( OnPlayerKilled )
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

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if( GetConVarInt( "spectator_afterdeathcam" ) == 1 )
		thread OnPlayerKilledThread( victim, attacker )
}

void function OnPlayerKilledThread( entity victim, entity attacker )
{
	float deathCamlength = GetDeathCamLength( victim )
	wait deathCamlength + 9 //add 9 seconds just to make sure every sort of death cam is over
	if( !IsAlive( victim ) )
	{
		array<string> args
		ClientCommandCallbackSpectate( victim, args )
	}
}

bool function ClientCommandCallbackSpectate(entity player, array<string> args)
{
	//cleanup stuff so we dont accidentally call cycle later
	RemovePlayerPressedLeftCallback( player, SpectatorCyclePrevious, spectatorPressedDebounceTime )
	RemovePlayerPressedRightCallback( player, SpectatorCycleNext, spectatorPressedDebounceTime )

	if( GetGameState() == eGameState.Playing )
	{
		entity target = FindSpectateTarget( player, spectateCycle.NONE )

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
		player.StartObserverMode( OBS_MODE_IN_EYE_SIMPLE ) // change observermode not needed?
	}
}

entity function FindSpectateTarget( entity player, int cycleDirection )
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
	entity target = FindSpectateTarget( player, spectateCycle.NEXT )
	SpectateCamera( player, target )
	return true
}

bool function SpectatorCyclePrevious( entity player )
{
	entity target = FindSpectateTarget( player, spectateCycle.PREVIOUS )
	SpectateCamera( player, target )
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
		if(GetConVarInt( "spectator_chatinfo" ) == 1 )
			Chat_ServerBroadcast( GetConVarString( "spectator_chatinfo_message" ) )
	}
}