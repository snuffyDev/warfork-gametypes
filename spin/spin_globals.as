const int SPINGT_SPEED1 = 2.5;
const int SPINGT_SPEED2 = 5;
const int SPINGT_SPEED3 = 7;
const int SPINGT_SPEED4 = 10;
const int SPINGT_SPEED5 = 20;

const int SPINGT_BASE_TICKRATE = 4;

uint[] SPINGT_SPEEDS = { SPINGT_SPEED1, SPINGT_SPEED2, SPINGT_SPEED3, SPINGT_SPEED4, SPINGT_SPEED5 };

// function which calculates the speed to spin the player
// direction: -1 = left, 1 = right
float calculateDirectionalSpeed( int speed, int direction ) 
{
    return (128.0f / 10000) * speed * direction * 2.5;
}

// SPEED CACHES

float[] SPEED_RIGHT_CACHE =
{
    calculateDirectionalSpeed( SPINGT_SPEED1, 1 ),
    calculateDirectionalSpeed( SPINGT_SPEED2, 1 ),
    calculateDirectionalSpeed( SPINGT_SPEED3, 1 ),
    calculateDirectionalSpeed( SPINGT_SPEED4, 1 ),
    calculateDirectionalSpeed( SPINGT_SPEED5, 1 )
};

float[] SPEED_LEFT_CACHE =
{
    calculateDirectionalSpeed( SPINGT_SPEED1, -1 ),
    calculateDirectionalSpeed( SPINGT_SPEED2, -1 ),
    calculateDirectionalSpeed( SPINGT_SPEED3, -1 ),
    calculateDirectionalSpeed( SPINGT_SPEED4, -1 ),
    calculateDirectionalSpeed( SPINGT_SPEED5, -1 )
};

// function which returns the speed to spin the player from the cache
float getSpinSpeed( int speed, int direction )
{
    if ( direction == 1 )
    {
        return SPEED_RIGHT_CACHE[speed - 1];
    }
    else
    {
        return SPEED_LEFT_CACHE[speed - 1];
    }
}

Cvar spingt_speed( "spingt_speed", "2", 0 );
Cvar spingt_vodkatech( "spingt_vodkatech", "0", 0 );
Cvar spingt_direction( "spingt_direction", "left", 0 );

bool validateSpeedCvar( uint speed )
{
    for( uint i = 0; i < SPINGT_SPEEDS.length(); i++ )
    {
        if( i == speed - 1)
            return true;
    }
    return false;
}

bool validateVodkatechCvar( int vodkatech )
{
    return vodkatech == 0 || vodkatech == 1;
}

bool validateDirectionCvar( String direction )
{
    return direction == "left" || direction == "right";
}

int directionToSign( String direction )
{
    return direction == "left" ? -1 : 1;
}

class SpinGTRound {
    void GT_InitGametype() {
        for ( int i = 0; i < maxClients; i++ )
        {
            @Players[i].client = @G_GetClient(i);
            @Players[i].player = @G_GetClient(i).getEnt();
            Players[i].setSpeed(spingt_speed.integer);
            Players[i].vodkatech = spingt_vodkatech.integer;
            Players[i].direction = spingt_direction.integer == "left" ? -1 : 1;
        }

        // register callvotes
        registerCallvotes();

        // ensure speed is correctly set for all players
        changeSpeedForPlayers();

    }
    bool GT_CallvoteValidate( Client @client, const String &vote, const String &args )
    {
        if ( vote == "spin_speed" )
        {
            String value = args.getToken( 1 );
            uint speed = args.toInt();
            if ( validateSpeedCvar( speed ) )
            {
                return false;
            }
            return true;
        }
        else if ( vote == "vodkatech" )
        {
            String value = args.getToken( 1 );
            int vodkatech = args.toInt();
            if ( !validateVodkatechCvar( vodkatech ) )
            {
                return false;
            }
            return true;
        }
        else if ( vote == "direction" )
        {
            if ( validateDirectionCvar( args ) )
            {
                return false;
            }
            return true;
        }
        return false;
    }

    bool GT_CallvotePassed( Client @client, const String &vote, const String &args )
    {
        if ( vote == "spin_speed" )
        {
            String value = args.getToken( 1 );
            spingt_speed.set( value.toInt() );
            G_PrintMsg( client.getEnt(), "Set speed to " + value.toInt() + "\n" );
            changeSpeedForPlayers();
            return true;
        }
        else if ( vote == "vodkatech" )
        {
            String value = args.getToken( 1 );
            spingt_vodkatech.set( value.toInt() );
            G_PrintMsg( client.getEnt(), "Set vodkatech to " + value.toInt() + "\n" );
            changeSpeedForPlayers();
            changeModifierForPlayers();
            return true;
        }
        else if ( vote == "direction" )
        {
            String value = args.getToken( 1 );

            spingt_direction.set( directionToSign( value ) );
            G_PrintMsg( client.getEnt(), "Set direction to " + args + "\n" );
            return true;
        }

        return false;
    }

    void GT_Shutdown() {
        // make sure all players are set to null
        for ( int i = 0; i < maxClients; i++ )
        {
            @Players[i].client = null;
            @Players[i].player = null;
        }
    }
}