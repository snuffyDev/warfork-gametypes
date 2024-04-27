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

uint caTimelimit1v1;

Cvar g_ca_timelimit1v1( "g_ca_timelimit1v1", "60", 0 );

Cvar g_noclass_inventory( "g_noclass_inventory", "gb mg rg gl rl pg lg eb cells shells grens rockets plasma lasers bullets", 0 );
Cvar g_class_strong_ammo( "g_class_strong_ammo", "1 75 20 20 40 125 180 15", 0 ); // GB MG RG GL RL PG LG EB
Cvar zmr_min_ups( "min_ups", "1000", 0 );
Cvar zmr_punish( "punish", "1", 0 );
Cvar g_knockback( "g_knockback", "1", 0 );

const int ZMR_ROUNDSTATE_NONE = 0;
const int ZMR_ROUNDSTATE_PREROUND = 1;
const int ZMR_ROUNDSTATE_ROUND = 2;
const int ZMR_ROUNDSTATE_ROUNDFINISHED = 3;
const int ZMR_ROUNDSTATE_POSTROUND = 4;

const int ZMR_LAST_MAN_STANDING_BONUS = 0; // 0 points for each frag

int[] caBonusScores( maxClients );
int[] caLMSCounts( GS_MAX_TEAMS ); // last man standing bonus for each team

// RDM functions

// Do we have builtin math constants?
const float pi = 3.14159265f;

Vec3[] rdmVelocities( maxClients );
uint[] rdmTimes( maxClients );
bool[] isWelcomed( maxClients );
uint rdmEndTime = 0;

Cvar rdmDebug( "rdm_debug", "1", CVAR_ARCHIVE );

///*****************************************************************
/// RDM FUNCTIONS
///*****************************************************************

int RDM_round( float f )
{
    if ( abs( f - floor( f ) ) < 0.5f )
        return int( f );
    else
        return int( f + f / abs( f ) );
}

float RDM_min( float a, float b )
{
    return ( a >= b ) ? b : a;
}

String RDM_getTimeString( int num )
{
    String minsString, secsString;
    String notime = "--:--";
    uint mtime, stime, min, sec;

    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
    case MATCH_STATE_COUNTDOWN:
        return notime;

    case MATCH_STATE_PLAYTIME:
        mtime = levelTime - rdmTimes[ num ];
        break;

    case MATCH_STATE_POSTMATCH:
    case MATCH_STATE_WAITEXIT:
        if ( rdmEndTime > 0 )
        {
            mtime = rdmEndTime - rdmTimes[ num ];
            break;
        }

    default:
        return notime;
    }

    stime = RDM_round( mtime / 1000.0f );
    min = stime / 60;
    sec = stime % 60;

    minsString = ( min >= 10 ) ? "" + min : "0" + min;
    secsString = ( sec >= 10 ) ? "" + sec : "0" + sec;

    return minsString + ":" + secsString;
}

float RDM_getDistance( Entity @a, Entity @b )
{
    return a.origin.distance( b.origin );
}

float RDM_getAngle( Vec3 a, Vec3 b )
{   
    Vec3 my_a = a;
    Vec3 my_b = b;

    if ( my_a.length() == 0 || my_b.length() == 0 )
        return 0;
  
    my_a.normalize();
    my_b.normalize();

    return abs( acos( my_a.x * my_b.x + my_a.y * my_b.y + my_a.z * my_b.z ) );
}

float RDM_getAngleFactor ( float angle )
{
    const float minAcuteFactor = 0.15f;
    const float minObtuseFactor = 0.30f;

    return ( angle < pi / 2.0f ) ?
        minAcuteFactor + ( 1.0f - minAcuteFactor ) * sin( angle ) :
        minObtuseFactor + ( 1.0f - minObtuseFactor ) * sin( angle );
}

Vec3 RDM_getVector( Entity @a, Entity @b )
{
    Vec3 ao;
    Vec3 bo;

    ao = a.origin;
    bo = b.origin;
    bo.x -= ao.x;
    bo.y -= ao.y;
    bo.z -= ao.z;

    return bo;
}

float RDM_getAnticampFactor ( float normalizedVelocity )
{
    // How fast does the factor grow?
    const float scale = 12.0f;

    return ( atan( scale * ( normalizedVelocity - 1.0f ) ) + pi / 2.0f ) / pi;
}

int RDM_calculateScore( Entity @target, Entity @attacker )
{
    // Default score for a "normal" shot
    const float defScore = 100.0f;
    // Normal speed
    const float normVelocity = 600.0f;
    // Normal distance
    const float normDist = 800.0f;

    Vec3 directionAt = RDM_getVector( attacker, target );
    Vec3 directionTa = RDM_getVector( target, attacker );

    /* Projection of the attacker's velocity relative to ground to the flat
     * surface that is perpendicular to the vector from the attacker
     * to the target */
    Vec3 velocityA = attacker.velocity;
    float angleA = RDM_getAngle( velocityA, directionAt );
    float projectionA = RDM_getAngleFactor( angleA ) * velocityA.length();

    /* Anti-camping dumping - we significantly decrease projection if the
     * attacker's velocity is lower than the normVelocity */
    float anticampFactor = RDM_getAnticampFactor( velocityA.length() / normVelocity );

    /* Projection of the target's velocity relative to the ground to the flat
     * surface that is perpendicular to the vector from the target
     * to the attacker */
    Vec3 velocityTg = rdmVelocities[ target.playerNum ];
    float angleTg = RDM_getAngle( velocityTg, directionTa );
    float projectionTg = RDM_getAngleFactor( angleTg ) * velocityTg.length();

    /* Projection of the target's velocity relative to the attacker to the flat
     * surface that is perpendicular to the vector from the target
     * to the attacker */
    Vec3 velocityTa = velocityTg - attacker.velocity;
    float angleTa = RDM_getAngle( velocityTa, directionTa );
    float projectionTa = RDM_getAngleFactor( angleTa ) * velocityTa.length();

    /* Choose minimal projection */
    float projectionT = RDM_min( projectionTg, projectionTa );

    float score = defScore
                * anticampFactor
                * pow( projectionA / normVelocity, 2.0f )
                * ( 1.0f + projectionT / normVelocity )
                * ( RDM_getDistance( attacker, target ) / normDist );

    if ( rdmDebug.boolean )
        G_Print( S_COLOR_BLUE + "DEBUG:" +
                 " ACF = " + anticampFactor +
                 " Va = " + velocityA.length() +
                 " Aa = " + int( angleA * 180.0f / pi ) +
                 " Vtg = " + velocityTg.length() +
                 " Atg = " + int( angleTg * 180.0f / pi ) +
                 " Vta = " + velocityTa.length() +
                 " Ata = " + int( angleTa * 180.0f / pi ) +
                 " D = " + RDM_getDistance( attacker, target ) +
                 " S = " + score +
                 "\n" );

    return int( score );
}

// a player has just died. The script is warned about it so it can account scores
void RDM_playerKilled( Entity @target, Entity @attacker, Entity @inflicter )
{
    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    if ( @target.client == null )
        return;

    // punishment for suicide
    if ( @attacker == null || attacker.playerNum == target.playerNum )
        target.client.stats.addScore( -500 );

    // update player score
    if ( @attacker != null && @attacker.client != null )
    {
       int score = RDM_calculateScore( target, attacker );
       attacker.client.stats.addScore( score );
       if ( score >= 500 && score < 1000 )
       {
           attacker.client.addAward("Nice shot");
           G_PrintMsg( null,
                       attacker.client.name + " made a nice shot\n" );
       }
       if ( score >= 1000 )
       {
           attacker.client.addAward(S_COLOR_RED + "!!! A W E S O M E !!!");
           G_PrintMsg( null,
                       attacker.client.name + S_COLOR_RED + " is AWESOME!\n" );
       }
    }
}


class cZMRRound
{
    int state;
    int numRounds;
    uint roundStateStartTime;
    uint roundStateEndTime;
    int countDown;
    Entity @alphaSpawn;
    Entity @betaSpawn;
	uint minuteLeft;
	int timelimit;
	int alpha_oneVS;
	int beta_oneVS;
	

    cZMRRound()
    {
        this.state = ZMR_ROUNDSTATE_NONE;
        this.numRounds = 0;
        this.roundStateStartTime = 0;
        this.countDown = 0;
		this.minuteLeft = 0;
		this.timelimit = 0;
        @this.alphaSpawn = null;
        @this.betaSpawn = null;
        
        this.alpha_oneVS = 0;
        this.beta_oneVS = 0;
    }

    ~cZMRRound() {}

    void setupSpawnPoints()
    {
        String className( "info_player_deathmatch" );
        Entity @spot1;
        Entity @spot2;
        Entity @spawn;
        float dist, bestDistance;

        // pick a random spawn first
        @spot1 = @GENERIC_SelectBestRandomSpawnPoint( null, className );

        // pick the furthest spawn second
		array<Entity @> @spawns = G_FindByClassname( className );
		@spawn = null;
        bestDistance = 0;
        @spot2 = null;
		
        for( uint i = 0; i < spawns.size(); i++ )
        {
			@spawn = spawns[i];
            dist = spot1.origin.distance( spawn.origin );
            if ( dist > bestDistance || @spot2 == null )
            {
                bestDistance = dist;
                @spot2 = @spawn;
            }
        }

        if ( random() > 0.5f )
        {
            @this.alphaSpawn = @spot1;
            @this.betaSpawn = @spot2;
        }
        else
        {
            @this.alphaSpawn = @spot2;
            @this.betaSpawn = @spot1;
        }
    }

    void newGame()
    {
        gametype.readyAnnouncementEnabled = false;
        gametype.scoreAnnouncementEnabled = true;
        gametype.countdownEnabled = false;

        // set spawnsystem type to not respawn the players when they die
        for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
            gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_HOLD, 0, 0, true );

        // clear scores

        Entity @ent;
        Team @team;
        int i;

        for ( i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
        {
            @team = @G_GetTeam( i );
            team.stats.clear();

            // respawn all clients inside the playing teams
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                ent.client.stats.clear(); // clear player scores & stats
            }
        }

        // clear bonuses
        for ( i = 0; i < maxClients; i++ )
            caBonusScores[i] = 0;

		this.clearLMSCounts();

        this.numRounds = 0;
        this.newRound();
        
        this.alpha_oneVS = 0;
        this.beta_oneVS = 0;

    }

    void addPlayerBonus( Client @client, int bonus )
    {
        if ( @client == null )
            return;

        caBonusScores[ client.playerNum ] += bonus;
    }

    int getPlayerBonusScore( Client @client )
    {
        if ( @client == null )
            return 0;

        return caBonusScores[ client.playerNum ];
    }

	void clearLMSCounts()
	{
		// clear last-man-standing counts
		for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
			caLMSCounts[i] = 0;
	}

    void endGame()
    {
        this.newRoundState( ZMR_ROUNDSTATE_NONE );

        GENERIC_SetUpEndMatch();
    }

    void newRound()
    {
        G_RemoveDeadBodies();
        G_RemoveAllProjectiles();

        this.newRoundState( ZMR_ROUNDSTATE_PREROUND );
        this.numRounds++;
    }

    void newRoundState( int newState )
    {
        if ( newState > ZMR_ROUNDSTATE_POSTROUND )
        {
            this.newRound();
            return;
        }

        this.state = newState;
        this.roundStateStartTime = levelTime;

        switch ( this.state )
        {
        case ZMR_ROUNDSTATE_NONE:
            this.roundStateEndTime = 0;
            this.countDown = 0;
			this.timelimit = 0;
			this.minuteLeft = 0;
            break;

        case ZMR_ROUNDSTATE_PREROUND:
        {
            this.roundStateEndTime = levelTime + 7000;
            this.countDown = 5;
			this.timelimit = 0;
			this.minuteLeft = 0;

            // respawn everyone and disable shooting
            gametype.shootingDisabled = true;
            gametype.removeInactivePlayers = false;

            this.setupSpawnPoints();
	
			this.alpha_oneVS = 0;
			this.beta_oneVS = 0;

            Entity @ent;
            Team @team;

            for ( int i = TEAM_PLAYERS; i < GS_MAX_TEAMS; i++ )
            {
                @team = @G_GetTeam( i );

                // respawn all clients inside the playing teams
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    ent.client.respawn( false );
                }
            }

			this.clearLMSCounts();
	    }
        break;

        case ZMR_ROUNDSTATE_ROUND:
        {
            gametype.shootingDisabled = false;
            gametype.removeInactivePlayers = true;
            this.countDown = 0;
            this.roundStateEndTime = 0;
            int soundIndex = G_SoundIndex( "sounds/announcer/countdown/fight0" + (1 + (rand() & 1)) );
            G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
            G_CenterPrintMsg( null, 'Fight!');
        }
        break;

        case ZMR_ROUNDSTATE_ROUNDFINISHED:
            gametype.shootingDisabled = true;
            this.roundStateEndTime = levelTime + 1500;
            this.countDown = 0;
			this.timelimit = 0;
			this.minuteLeft = 0;
            break;

        case ZMR_ROUNDSTATE_POSTROUND:
        {
            this.roundStateEndTime = levelTime + 3000;

            // add score to round-winning team
            Entity @ent;
            Entity @lastManStanding = null;
            Team @team;
            int count_alpha, count_beta;
            int count_alpha_total, count_beta_total;

            count_alpha = count_alpha_total = 0;
            @team = @G_GetTeam( TEAM_ALPHA );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() )
                {
                    count_alpha++;
                    @lastManStanding = @ent;
                    // ch : add round
                    if( @ent.client != null )
                    	ent.client.stats.addRound();
                }
                count_alpha_total++;
            }

            count_beta = count_beta_total = 0;
            @team = @G_GetTeam( TEAM_BETA );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() )
                {
                    count_beta++;
                    @lastManStanding = @ent;
                    // ch : add round
                    if( @ent.client != null )
                    	ent.client.stats.addRound();
                }
                count_beta_total++;
            }

            int soundIndex;

            if ( count_alpha > count_beta )
            {
                G_GetTeam( TEAM_ALPHA ).stats.addScore( 1 );

                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_team0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_enemy0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );

                if ( !gametype.isInstagib && count_alpha == 1 ) // he's the last man standing. Drop a bonus
                {
                    if ( count_beta_total > 1 )
                    {
                        lastManStanding.client.addAward( S_COLOR_GREEN + "Last Player Standing!" );
                        // ch :
                        if( alpha_oneVS > ONEVS_AWARD_COUNT )
                        	// lastManStanding.client.addMetaAward( "Last Man Standing" );
                        	lastManStanding.client.addAward( "Last Man Standing" );

                        this.addPlayerBonus( lastManStanding.client, caLMSCounts[TEAM_ALPHA] * ZMR_LAST_MAN_STANDING_BONUS );
                        GT_updateScore( lastManStanding.client );
                        
                    }
                }
            }
            else if ( count_beta > count_alpha )
            {
                G_GetTeam( TEAM_BETA ).stats.addScore( 1 );

                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_team0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_BETA, false, null );
                soundIndex = G_SoundIndex( "sounds/announcer/ctf/score_enemy0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, TEAM_ALPHA, false, null );

                if ( !gametype.isInstagib && count_beta == 1 ) // he's the last man standing. Drop a bonus
                {
                    if ( count_alpha_total > 1 )
                    {
                        lastManStanding.client.addAward( S_COLOR_GREEN + "Last Player Standing!" );
                        // ch :
                        if( beta_oneVS > ONEVS_AWARD_COUNT )
                        	// lastManStanding.client.addMetaAward( "Last Man Standing" );
                        	lastManStanding.client.addAward( "Last Man Standing" );

                        this.addPlayerBonus( lastManStanding.client, caLMSCounts[TEAM_BETA] * ZMR_LAST_MAN_STANDING_BONUS );
												GT_updateScore( lastManStanding.client );
                    }
                }
            }
			else // draw round
            {
                G_CenterPrintMsg( null, "Draw Round!" );
            }
        }
        break;

        default:
            break;
        }
    }

    void think()
    {
        if ( this.state == ZMR_ROUNDSTATE_NONE )
            return;
		
        if ( match.getState() != MATCH_STATE_PLAYTIME )
        {
            this.endGame();
            return;
        }

        if ( this.roundStateEndTime != 0 )
        {
            if ( this.roundStateEndTime < levelTime )
            {
                this.newRoundState( this.state + 1 );
                return;
            }

            if ( this.countDown > 0 )
            {
                // we can't use the authomatic countdown announces because their are based on the
                // matchstate timelimit, and prerounds don't use it. So, fire the announces "by hand".
                int remainingSeconds = int( ( this.roundStateEndTime - levelTime ) * 0.001f ) + 1;
                if ( remainingSeconds < 0 )
                    remainingSeconds = 0;

                if ( remainingSeconds < this.countDown )
                {
                    this.countDown = remainingSeconds;

                    if ( this.countDown == 4 )
                    {
                        int soundIndex = G_SoundIndex( "sounds/announcer/countdown/ready0" + (1 + (rand() & 1)) );
                        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                    }
                    else if ( this.countDown <= 3 )
                    {
                        int soundIndex = G_SoundIndex( "sounds/announcer/countdown/" + this.countDown + "_0" + (1 + (rand() & 1)) );
                        G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );

                    }
                    G_CenterPrintMsg( null, String( this.countDown ) );
                }
            }
        }

        // if one of the teams has no player alive move from ZMR_ROUNDSTATE_ROUND
        if ( this.state == ZMR_ROUNDSTATE_ROUND )
        {
			// 1 minute left if 1v1
			if( this.minuteLeft > 0 )
			{
				uint left = this.minuteLeft - levelTime;

				if ( caTimelimit1v1 != 0 && ( caTimelimit1v1 * 1000 ) == left )
				{
					if( caTimelimit1v1 < 60 )
					{
						G_CenterPrintMsg( null, caTimelimit1v1 + " seconds left. Hurry up!" );
					}
					else
					{
						uint minutes;					
						uint seconds = caTimelimit1v1 % 60;
						
						if( seconds == 0 )
						{
							minutes = caTimelimit1v1 / 60;
							if(minutes == 1) {
								G_CenterPrintMsg( null, minutes + " minute left. Hurry up!");
							} else {
								G_CenterPrintMsg( null, minutes + " minutes left. Hurry up!" );							
							}
						}
						else
						{
							minutes = ( caTimelimit1v1 - seconds ) / 60;
							G_CenterPrintMsg( null, minutes + " minutes and "+ seconds +" seconds left. Hurry up!"  );
						}
					}
				}
				
                int remainingSeconds = int( left * 0.001f ) + 1;
                if ( remainingSeconds < 0 )
                    remainingSeconds = 0;
				
				this.timelimit = remainingSeconds;
				match.setClockOverride( minuteLeft - levelTime );
				
				if( levelTime > this.minuteLeft )
				{
					G_CenterPrintMsg( null , S_COLOR_RED + 'Timelimit hit!');
					this.newRoundState( this.state + 1 );
				}
			}
		
			// if one of the teams has no player alive move from ZMR_ROUNDSTATE_ROUND
            Entity @ent;
            Team @team;
            int count;

            for ( int i = TEAM_ALPHA; i < GS_MAX_TEAMS; i++ )
            {
                @team = @G_GetTeam( i );
                count = 0;

                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    if ( !ent.isGhosting() )
                        count++;
                }

                if ( count == 0 )
                {
                    this.newRoundState( this.state + 1 );
                    break; // no need to continue
                }
            }
        }
    }

    void playerKilled( Entity @target, Entity @attacker, Entity @inflictor )
    {
        Entity @ent;
        Team @team;

        if ( this.state != ZMR_ROUNDSTATE_ROUND )
            return;

        if ( @target != null && @target.client != null && @attacker != null && @attacker.client != null )
        {
			if ( gametype.isInstagib )
			{
				G_PrintMsg( target, "You were fragged by " + attacker.client.name + " at " + attacker.velocity.length() + "up/s!\n" );
			}
			else
			{
				// report remaining health/armor of the killer
				G_PrintMsg( target, "You were fragged by " + attacker.client.name + " (health: " + rint( attacker.health ) + ", armor: " + rint( attacker.client.armor ) + ", velocity: " + attacker.velocity.length() +"up/s"+")\n" );
			}

            // if the attacker is the only remaining player on the team,
            // report number or remaining enemies

            int attackerCount = 0, targetCount = 0;

            // count attacker teammates
            @team = @G_GetTeam( attacker.team );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() )
                    attackerCount++;
            }

            // count target teammates
            @team = @G_GetTeam( target.team );
            for ( int j = 0; @team.ent( j ) != null; j++ )
            {
                @ent = @team.ent( j );
                if ( !ent.isGhosting() && @ent != @target )
                    targetCount++;
            }

			// amount of enemies for the last-man-standing award
			if ( targetCount == 1 && caLMSCounts[target.team] == 0 )
				caLMSCounts[target.team] = attackerCount;

            if ( attackerCount == 1 && targetCount == 1 )
            {
                G_PrintMsg( null, "1v1! Good luck!\n" );
                attacker.client.addAward( "1v1! Good luck!" );

                // find the alive player in target team again (doh)
                @team = @G_GetTeam( target.team );
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    if ( ent.isGhosting() || @ent == @target )
                        continue;

                    ent.client.addAward( S_COLOR_ORANGE + "1v1! Good luck!" );
                    break;
                }
				
				this.minuteLeft = levelTime + ( caTimelimit1v1 * 1000 );
            }
            else if ( attackerCount == 1 && targetCount > 1 )
            {
                attacker.client.addAward( "1v" + targetCount + "! You're on your own!" );

                // console print for the team
                @team = @G_GetTeam( attacker.team );
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    G_PrintMsg( team.ent( j ), "1v" + targetCount + "! " + attacker.client.name + " is on its own!\n" );
                }
                
                // ch : update last man standing count
                if( attacker.team == TEAM_ALPHA && targetCount > alpha_oneVS )
                	alpha_oneVS = targetCount;
                else if( attacker.team == TEAM_BETA && targetCount > beta_oneVS )
                	beta_oneVS = targetCount;
            }
            else if ( attackerCount > 1 && targetCount == 1 )
            {
                Entity @survivor;

                // find the alive player in target team again (doh)
                @team = @G_GetTeam( target.team );
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    if ( ent.isGhosting() || @ent == @target )
                        continue;

                    ent.client.addAward( "1v" + attackerCount + "! You're on your own!" );
                    @survivor = @ent;
                    break;
                }

                // console print for the team
                for ( int j = 0; @team.ent( j ) != null; j++ )
                {
                    @ent = @team.ent( j );
                    G_PrintMsg( ent, "1v" + attackerCount + "! " + survivor.client.name + " is on its own!\n" );
                }
                
                // ch : update last man standing count
                if( target.team == TEAM_ALPHA && attackerCount > alpha_oneVS )
					alpha_oneVS = attackerCount;
				else if( target.team == TEAM_BETA && attackerCount > beta_oneVS )
					beta_oneVS = attackerCount;
            }
            
            // check for generic awards for the frag
            if( attacker.team != target.team )
				award_playerKilled( @target, @attacker, @inflictor );
        }
        
        // ch : add a round for victim
        if ( @target != null && @target.client != null )
        	target.client.stats.addRound();
    }
}

cZMRRound caRound;

///*****************************************************************
/// NEW MAP ENTITY DEFINITIONS
///*****************************************************************


///*****************************************************************
/// LOZMRL FUNCTIONS
///*****************************************************************

void ZMR_SetUpWarmup()
{
    GENERIC_SetUpWarmup();

    // set spawnsystem type to instant while players join
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );
}

void ZMR_SetUpCountdown()
{
    gametype.shootingDisabled = true;
    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    G_RemoveAllProjectiles();

    // lock teams
    bool anyone = false;
    if ( gametype.isTeamBased )
    {
        for ( int team = TEAM_ALPHA; team < GS_MAX_TEAMS; team++ )
        {
            if ( G_GetTeam( team ).lock() )
                anyone = true;
        }
    }
    else
    {
        if ( G_GetTeam( TEAM_PLAYERS ).lock() )
            anyone = true;
    }

    if ( anyone )
        G_PrintMsg( null, "Teams locked.\n" );

    // Countdowns should be made entirely client side, because we now can

    int soundIndex = G_SoundIndex( "sounds/announcer/countdown/get_ready_to_fight0" + (1 + (rand() & 1)) );
    G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
}

///*****************************************************************
/// MODULE SCRIPT ZMRLLS
///*****************************************************************

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    if ( cmdString == "gametype" )
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
    else if ( cmdString == "cvarinfo" )
    {
        GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
        return true;
    }
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );


        if ( votename == "min_ups" )
        {
            int min_ups = argsString.getToken( 1 ).toInt();
            if ( min_ups < 100 || min_ups>8000 )
            {
                G_PrintMsg( client.getEnt(), "Min UPS must be between 100 and 8000\n" );
                return false;
            }
            G_PrintMsg( client.getEnt(), "Min UPS set to " + min_ups + "\n" );
            return true;
        }
        else if ( votename == "knockback" ) 
        {
            float knockback = argsString.getToken( 1 ).toFloat();
            if ( knockback < 1 || knockback > 3 )
            {
                G_PrintMsg( client.getEnt(), "Knockback must be between 1 and 3\n" );
                return false;
            }
            G_PrintMsg( client.getEnt(), "Knockback set to " + knockback + "\n" );
            return true;
        }
        else if ( votename == "punish" )
        {
            int punish = argsString.getToken( 1 ).toInt();
            if ( punish < 0 || punish > 1 )
            {
                G_PrintMsg( client.getEnt(), "Punish must be 0 or 1\n" );
                return false;
            }
            G_PrintMsg( client.getEnt(), "Punish set to " + punish + "\n" );
            return true;
        }
    }
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "min_ups" )
        {
            int min_ups = argsString.getToken( 1 ).toInt();
            zmr_min_ups.set( min_ups );
            return true;
        }
        else if ( votename == "knockback" )
        {
            float knockback = argsString.getToken( 1 ).toFloat();
            g_knockback.set( knockback );
            return true;
        }
        else if ( votename == "punish" )
        {
            int punish = argsString.getToken( 1 ).toInt();
            zmr_punish.set( punish );
            return true;
        }
    }

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @ent )
{
    Entity @goal;
    Bot @bot;

    @bot = @ent.client.getBot();
    if ( @bot == null )
        return false;

    float offensiveStatus = GENERIC_OffensiveStatus( ent );

    // loop all the goal entities
    for ( int i = AI::GetNextGoal( AI::GetRootGoal() ); i != AI::GetRootGoal(); i = AI::GetNextGoal( i ) )
    {
        @goal = @AI::GetGoalEntity( i );

        // by now, always full-ignore not solid entities
        if ( goal.solid == SOLID_NOT )
        {
            bot.setGoalWeight( i, 0 );
            continue;
        }

        if ( @goal.client != null )
        {
            bot.setGoalWeight( i, GENERIC_PlayerWeight( ent, goal ) * 2.5 * offensiveStatus );
            continue;
        }

        // ignore it
        bot.setGoalWeight( i, 0 );
    }

    return true; // handled by the script
}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    if ( caRound.state == ZMR_ROUNDSTATE_PREROUND )
    {
        if ( self.team == TEAM_ALPHA )
            return @caRound.alphaSpawn;

        if ( self.team == TEAM_BETA )
            return @caRound.betaSpawn;
    }

    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

String @GT_ScoreboardMessage( uint maxlen )
{
    String scoreboardMessage = "";
    String entry;
    Team @team;
    Entity @ent;
    int i, t;

    for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );

        // &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
        entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
        if ( scoreboardMessage.len() + entry.len() < maxlen )
            scoreboardMessage += entry;

        for ( i = 0; @team.ent( i ) != null; i++ )
        {
            @ent = @team.ent( i );

            int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

            if ( gametype.isInstagib )
            {
                // "AVATAR Name Clan Score Ping R"
                entry = "&p " + playerID + " " + playerID + " " + ent.client.clanName + " "
                        + ent.client.stats.score + " "
                        + ent.client.ping + " " + ( ent.client.isReady() ? "1" : "0" ) + " ";
            }
            else
            {
                // "AVATAR Name Clan Score Frags Ping R"
                entry = "&p " + playerID + " " + playerID + " " + ent.client.clanName + " "
                        + ent.client.stats.score + " " + ent.client.stats.frags + " "
                        + ent.client.ping + " " + ( ent.client.isReady() ? "1" : "0" ) + " ";
            }

            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;
        }
    }

    return scoreboardMessage;
}

//
void ZMR_updateScore( Entity @ent, Entity @attacker )
{
    if ( @ent != null && @attacker != null ) 
    {
        int minUps = zmr_min_ups.integer;
        G_Print( "velocity: " + ent.velocity.length() + " minUps: " + minUps + "\n" );
        if ( @ent.client != null && @attacker.client != null && ent.velocity.length() >= minUps )
        {
            // use RDM score system for calculating score
            if ( gametype.isInstagib )
            {
                ent.client.stats.setScore( RDM_calculateScore( ent, attacker ) );
            }
            else
            {
                ent.client.stats.setScore( RDM_calculateScore( ent, attacker ) );
            }
        }

        // if velocity is too low, kill the player who did the killing
        if ( @ent.client != null && @attacker.client != null )
        {
            if ( attacker.velocity.length() < zmr_min_ups.integer )
                attacker.health = 0;
        }
    }
}

//
void GT_updateScore( Client @client )
{
    if ( @client != null )
    {
        Entity @ent = @client.getEnt();
        if ( gametype.isInstagib)
            client.stats.setScore( client.stats.frags + caRound.getPlayerBonusScore( client ) );
        else
            client.stats.setScore( int( client.stats.totalDamageGiven * 0.1 ) + caRound.getPlayerBonusScore( client ) );
    }
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
        caRound.playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );

        ZMR_updateScore( G_GetEntity( arg1 ), attacker );
		
    }
    else if ( score_event == "award" )
    {
    }
	else if( score_event == "rebalance" || score_event == "shuffle" )
	{
		// end round when in match
		if ( ( @client == null ) && ( match.getState() == MATCH_STATE_PLAYTIME ) )
		{
			caRound.newRoundState( ZMR_ROUNDSTATE_ROUNDFINISHED );
		}	
	}
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{
    if ( ent.isGhosting() )
	{
		ent.svflags &= ~SVF_FORCETEAM;
        return;
	}

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

	ent.svflags |= SVF_FORCETEAM;

    // add a teleportation effect
    ent.respawnEffect();
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished() )
        match.launchState( match.getState() + 1 );

	GENERIC_Think();

    // print count of players alive and show class icon in the HUD

    Team @team;
    int[] alive( GS_MAX_TEAMS );

    alive[TEAM_SPECTATOR] = 0;
    alive[TEAM_PLAYERS] = 0;
    alive[TEAM_ALPHA] = 0;
    alive[TEAM_BETA] = 0;

    for ( int t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
    {
        @team = @G_GetTeam( t );
        for ( int i = 0; @team.ent( i ) != null; i++ )
        {
            Entity @ent = @team.ent( i );
            if ( !team.ent( i ).isGhosting() )
                alive[t]++;
            
            if ( ent.client.state() == CS_SPAWNED )
                rdmVelocities[ ent.playerNum ] = ent.velocity;

        }
    }

    G_ConfigString( CS_GENERAL, "" + alive[TEAM_ALPHA] );
    G_ConfigString( CS_GENERAL + 1, "" + alive[TEAM_BETA] );

    for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );

        if ( match.getState() >= MATCH_STATE_POSTMATCH || match.getState() < MATCH_STATE_PLAYTIME )
        {
            client.setHUDStat( STAT_MESSAGE_ALPHA, 0 );
            client.setHUDStat( STAT_MESSAGE_BETA, 0 );
            client.setHUDStat( STAT_IMAGE_BETA, 0 );
        }
        else
        {
            client.setHUDStat( STAT_MESSAGE_ALPHA, CS_GENERAL );
            client.setHUDStat( STAT_MESSAGE_BETA, CS_GENERAL + 1 );
        }

        if ( client.getEnt().isGhosting()
                || match.getState() >= MATCH_STATE_POSTMATCH )
        {
            client.setHUDStat( STAT_IMAGE_BETA, 0 );
        }
        
    }

    if ( match.getState() >= MATCH_STATE_POSTMATCH )
        return;

    caRound.think();
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    // ** MISSING EXTEND PLAYTIME CHECK **

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
        ZMR_SetUpWarmup();
        break;

    case MATCH_STATE_COUNTDOWN:
        ZMR_SetUpCountdown();
        break;

    case MATCH_STATE_PLAYTIME:
        caRound.newGame();
        break;

    case MATCH_STATE_POSTMATCH:
        caRound.endGame();
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
    gametype.title = "Clan Arena";
    gametype.version = "1.04";
    gametype.author = "Warsow Development Team";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"return pressure\" // list of maps in automatic rotation\n"
                 + "set g_maprotation \"0\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"11\"\n"
                 + "set g_timelimit \"0\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"0\"\n"
                 + "set g_allow_falldamage \"0\"\n"
                 + "set g_allow_selfdamage \"0\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"0\"\n"
                 + "set g_teams_maxplayers \"8\"\n"
                 + "set g_teams_allow_uneven \"0\"\n"
                 + "set g_countdown_time \"3\"\n"
                 + "set g_maxtimeouts \"1\" // -1 = unlimited\n"
                 + "\n// gametype settings\n"
				 + "set g_ca_timelimit1v1 \"60\"\n"
                 + "set zmr_min_ups \"1000\"\n"
                 + "set zmr_punish \"1\"\n"
                 + "set g_knockback \"1\"\n"
                 + "\n// classes settings\n"
                 + "set g_noclass_inventory \"gb mg rg gl rl pg lg eb cells shells grens rockets plasma lasers bolts bullets\"\n"
                 + "set g_class_strong_ammo \"1 75 20 20 40 125 180 15\" // GB MG RG GL RL PG LG EB\n"
                 + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

	caTimelimit1v1 = g_ca_timelimit1v1.integer;

    gametype.spawnableItemsMask = 0;
    gametype.respawnableItemsMask = 0;
    gametype.dropableItemsMask = 0;
    gametype.pickableItemsMask = 0;

    gametype.isTeamBased = true;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.ammoRespawn = 20;
    gametype.armorRespawn = 25;
    gametype.weaponRespawn = 15;
    gametype.healthRespawn = 25;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 20;
    gametype.ultrahealthRespawn = 60;

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

    // set spawnsystem type to instant while players join
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    if ( gametype.isInstagib )
    {
        G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%a l1 %n 112 %s 52 %i 52 %l 48 %r l1" );
        G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "AVATAR Name Clan Score Ping R" );
    }
    else
    {
        G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%a l1 %n 112 %s 52 %i 52 %i 52 %l 48 %r l1" );
        G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "AVATAR Name Clan Score Frags Ping R" );
    }

    // add commands
    G_RegisterCommand( "gametype" );

    // register callvotes
    G_RegisterCallvote( "knockback", "1 to 2", "integer", "Sets the weapon knockback" );
    G_RegisterCallvote( "punish", "0 to 1", "integer", "Punish players for low UPS" );
    G_RegisterCallvote( "min_ups", "<number>", "integer", "Sets the minimum UPS for a frag to be counted towards score" );


    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
}