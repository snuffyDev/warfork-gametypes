/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/
const int SPINGT_SPEED1 = 1;
const int SPINGT_SPEED2 = 5;
const int SPINGT_SPEED3 = 10;
const int SPINGT_SPEED4 = 15;
const int SPINGT_SPEED5 = 20;

const int SPINGT_BASE_TICKRATE = 4;

int[] SPINGT_SPEEDS = { SPINGT_SPEED1, SPINGT_SPEED2, SPINGT_SPEED3, SPINGT_SPEED4, SPINGT_SPEED5 };

Cvar spingt_speed( "spingt_speed", "2", 0 );
Cvar spingt_vodkatech( "spingt_vodkatech", "0", 0 );

///*****************************************************************
/// NEW MAP ENTITY DEFINITIONS
///*****************************************************************


///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************

Cvar g_noclass_inventory( "g_noclass_inventory", "gb mg rg gl rl pg lg eb cells shells grens rockets plasma lasers bullets", 0 );
Cvar g_class_strong_ammo( "g_class_strong_ammo", "1 75 20 20 40 125 180 15", 0 ); // GB MG RG GL RL PG LG EB

// a player has just died. The script is warned about it so it can account scores
void DM_playerKilled( Entity @target, Entity @attacker, Entity @inflictor )
{
    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    if ( @target.client == null )
        return;

    // update player score based on player stats

    target.client.stats.setScore( target.client.stats.frags - target.client.stats.suicides );
    if ( @attacker != null && @attacker.client != null )
        attacker.client.stats.setScore( attacker.client.stats.frags - attacker.client.stats.suicides );

    // drop items
    if ( ( G_PointContents( target.origin ) & CONTENTS_NODROP ) == 0 )
    {
        target.dropItem( AMMO_PACK );
    }
    
    award_playerKilled( @target, @attacker,@inflictor );
}

///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "drop" )
    {
        String token;

        for ( int i = 0; i < argc; i++ )
        {
            token = argsString.getToken( i );
            if ( token.len() == 0 )
                break;

            if ( token == "weapon" || token == "fullweapon" )
            {
                GENERIC_DropCurrentWeapon( client, true );
            }
            else if ( token == "strong" )
            {
                GENERIC_DropCurrentAmmoStrong( client );
            }
            else
            {
                GENERIC_CommandDropItem( client, token );
            }
        }

        return true;
    }
    else if ( cmdString == "cvarinfo" )
    {
        GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
        return true;
    }
    // example of registered command
    else if ( cmdString == "gametype" )
    {
        String response = "";
		Cvar fs_game( "fs_game", "", 0 );
		String manifest = gametype.manifest;

        response += "\n";
        response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
        response += "----------------\n";
        response += "Version: " + gametype.version + "\n";
        response += "Author: " + gametype.author + "\n";
        response += "Mod: " + fs_game.string + (!manifest.empty() ? " (manifest: " + manifest + ")" : "") + "\n";
        response += "----------------\n";

        G_PrintMsg( client.getEnt(), response );
        return true;
    }
    else if ( cmdString == "callvotevalidate")
    {
        
        String voteName = argsString.getToken( 0 );
        
        if ( voteName == "spin_speed" )
        {

            String speedStr = argsString.getToken( 1 );
            int speedIndex = speedStr.toInt();
            if (speedIndex < 1 || speedIndex > 5 ) {
                G_PrintMsg( client.getEnt(), "Invalid speed. Must be between 1 and 5.\n" );
                return false;
            }
         
            return true;
        }

        if ( voteName == "vodkatech" )
        {
            String modifierStr = argsString.getToken( 1 );
            if (modifierStr != "1" && modifierStr != "0" ) {
                G_PrintMsg( client.getEnt(), "Invalid value. Must be 1 or 0.\n" );
                return false;
            }

            if (modifierStr.toInt() == spingt_vodkatech.integer) {
                G_PrintMsg( client.getEnt(), "Vodkatech is already set to " + spingt_vodkatech.integer + ".\n" );
                return false;
            }

            return true;
        }

        return false;
    }
    // example of callvote
    else if ( cmdString == "callvotepassed" )
    {
        
        String voteName = argsString.getToken( 0 );

        if ( voteName == "spin_speed" )
        {

            String speedStr = argsString.getToken( 1 );
            int speedIndex = speedStr.toInt();
            
            spingt_speed.set( speedIndex );

            changeSpeedForPlayers();
            return true;
        }
    
        if ( voteName == "vodkatech" )
        {
            String modifierStr = argsString.getToken( 1 );
            spingt_vodkatech.set( modifierStr.toInt() );

            changeModifierForPlayers();
            return true;
        }
        return false;
    }

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @self )
{
    return GENERIC_UpdateBotStatus( self );
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    int i;

    @team = @G_GetTeam( TEAM_PLAYERS );

    // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
    entry = "&t " + int( TEAM_PLAYERS ) + " " + team.stats.score + " 0 ";
    if ( scoreboardMessage.len() + entry.len() < maxlen )
        scoreboardMessage += entry;

    for ( i = 0; @team.ent( i ) != null; i++ )
    {
        @ent = @team.ent( i );

		int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

        entry = "&p " + playerID + " " + playerID + " "
                + ent.client.clanName + " "
                + ent.client.stats.score + " "
                + ent.client.ping + " "
                + ( ent.client.isReady() ? "1" : "0" ) + " ";

        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;
    }

    return scoreboardMessage;
}
// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
// Warning: client can be null
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {
    }
    else if ( score_event == "kill" )
    {
        Entity @attacker = null;

        if ( @client != null )
            @attacker = @client.getEnt();

        int arg1 = args.getToken( 0 ).toInt();
        int arg2 = args.getToken( 1 ).toInt();

        // target, attacker, inflictor
        DM_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "award" )
    {
    }
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
    if ( ent.isGhosting() )
        return;

    if ( gametype.isInstagib )
    {
        ent.client.inventoryGiveItem( WEAP_INSTAGUN );
        ent.client.inventorySetCount( AMMO_INSTAS, 1 );
        ent.client.inventorySetCount( AMMO_WEAK_INSTAS, 1 );
    }
    else
    {
    	// give the weapons and ammo as defined in cvars
    	String token, weakammotoken, ammotoken;
    	String itemList = g_noclass_inventory.string;
    	String ammoCounts = g_class_strong_ammo.string;

    	ent.client.inventoryClear();

        for ( int i = 0; ;i++ )
        {
            token = itemList.getToken( i );
            if ( token.len() == 0 )
                break; // done

            Item @item = @G_GetItemByName( token );
            if ( @item == null )
                continue;

            ent.client.inventoryGiveItem( item.tag );

            // if it's ammo, set the ammo count as defined in the cvar
            if ( ( item.type & IT_AMMO ) != 0 )
            {
                token = ammoCounts.getToken( item.tag - AMMO_GUNBLADE );

                if ( token.len() > 0 )
                {
                    ent.client.inventorySetCount( item.tag, token.toInt() );
                }
            }
        }

        // give armor
        ent.client.armor = 150;

        // select rocket launcher
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
    }

	// auto-select best weapon in the inventory
    if( ent.client.pendingWeapon == WEAP_NONE )
		ent.client.selectWeapon( -1 );

    // add a teleportation effect
    ent.respawnEffect();
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
        match.launchState( match.getState() + 1 );

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
        return;

	GENERIC_Think();

    // check maxHealth rule
    Entity @ent;
    Team @team;

    @team = @G_GetTeam( TEAM_PLAYERS );

    for ( int j = 0; @team.ent( j ) != null; j++ )
    {
        @ent = @team.ent( j );
        if ( ent.isGhosting() )
            continue;

        Vec3 angles = ent.angles;
        float amount = 5;
        angles += Vec3( brandom(-amount,amount), brandom(-amount,amount), 0 );
        ent.angles = angles;
    }
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP
            && incomingMatchState < MATCH_STATE_POSTMATCH )
        match.startAutorecord();

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();

    return true;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;
        GENERIC_SetUpWarmup();
		SpawnIndicators::Create( "info_player_deathmatch", TEAM_PLAYERS );
        break;

    case MATCH_STATE_COUNTDOWN:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop
        GENERIC_SetUpCountdown();
        
		SpawnIndicators::Delete();
        break;

    case MATCH_STATE_PLAYTIME:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;
        GENERIC_SetUpMatch();
        break;

    case MATCH_STATE_POSTMATCH:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop
        GENERIC_SetUpEndMatch();
        break;

    default:
        break;
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
    gametype.title = "Spinsta";
    gametype.version = "1.0.4";
    gametype.author = "snuffyDev";
    // Forked by Gelmo

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"wfca1 wfca2 wfdm1 wfdm2 wfdm3 wfdm4 wfdm5 wfdm6 wfdm7 wfdm8 wfdm9 wfdm10 wfdm11 wfdm12 wfdm13 wfdm14 wfdm15 wfdm16 wfdm17 wfdm18 wfdm19 wfdm20\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"1\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"0\"\n"
                 + "set g_timelimit \"15\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"0\"\n"
                 + "set g_allow_falldamage \"0\"\n"
                 + "set g_allow_selfdamage \"0\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"0\"\n"
                 + "set g_countdown_time \"5\"\n"
                 + "set g_maxtimeouts \"0\" // -1 = unlimited\n"
                 + "set spingt_speed \"2\" // 1 - slowest | 5 - fastest\n"
                 + "set spingt_vodkatech \"0\" // 0 - off | 1 - on\n"
                 + "\n// classes settings\n"
                 + "set g_noclass_inventory \"ig\"\n"
                 + "set g_class_strong_ammo \"1 75 20 20 40 125 180 15\" // GB MG RG GL RL PG LG EB\n"
                 + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    gametype.spawnableItemsMask = ( IT_AMMO | IT_ARMOR | IT_HEALTH );
    if ( gametype.isInstagib )
        gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);

    gametype.respawnableItemsMask = gametype.spawnableItemsMask;
    gametype.dropableItemsMask = gametype.spawnableItemsMask;
    gametype.pickableItemsMask = gametype.spawnableItemsMask;

    gametype.isTeamBased = false;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 5;
    gametype.healthRespawn = 25;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 40;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = false;
    gametype.canForceModels = true;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = true;
    gametype.removeInactivePlayers = true;

	gametype.mmCompatible = true;
	
    gametype.spawnpointRadius = 256;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%a l1 %n 112 %s 52 %i 52 %l 48 %r l1" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "AVATAR Name Clan Score Ping R" );

    // add commands
    G_RegisterCommand( "drop" );
    G_RegisterCommand( "gametype" );
    
	G_RegisterCallvote( "spin_speed", "<1|2|3|4|5>", "integer", "Changes the spin speed for all players.\n1 - slowest | 5 - fastest\n\nCurrent: " + spingt_speed.integer + "\n");
	G_RegisterCallvote( "vodkatech", "1 or 0", "integer", "Toggle the 'vodkatech' modifier, which spins players on the X, Y, and Z axis.\n\nCurrent: " + spingt_vodkatech.integer + "\n");


    changeSpeedForPlayers();
    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}


/* Spin speed to tick rate function
   NOTE: The 'tick rate' is the number of times the server will call the think function per second per player.
   We want this to be smooth, yet not too intensive. The default is 64, which is 64 times per second.
 */
int spinSpeedToTickRate( float speed )
{
    // Calculate the multiplier for the speed relative to the slowest speed
    float speedMultiplier = speed / SPINGT_SPEED1;
    
    // Adjust the tick rate linearly based on the speed multiplier, rounding to the nearest integer
    return int( floor( SPINGT_BASE_TICKRATE * speedMultiplier ) );
}

void changeModifierForPlayers()
{
    for ( int i = 0; i < maxClients; i++ )
    {
        if ( Players[i].player == null )
            continue;
        
        Players[i].resetAngles();
        Players[i].modifier = spingt_vodkatech.integer;
        // reset the player's angles x & z to 0
        
    }
}

void changeSpeedForPlayers() 
{
    float speed = SPINGT_SPEEDS[spingt_speed.integer - 1];
    int tickrate = 1;
    
    if ( spingt_speed.integer >= 3 )
    {
        tickrate = 7;
    }
    else
    {
        tickrate = 6 - spingt_speed.integer;
    }

    for ( int i = 0; i < maxClients; i++ )
    {
        if ( Players[i].player == null )
            continue;
        
        Players[i].tickrate = tickrate;
        Players[i].speed = speed;
    }
}
