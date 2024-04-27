void registerCallvotes() {
	G_RegisterCallvote( "spin_speed", "<1|2|3|4|5>", "integer", "Changes the spin speed for all players.\n1 - slowest | 5 - fastest\n\nCurrent: " + getCurrentSpeed() + "\n");
	G_RegisterCallvote( "vodkatech", "1 or 0", "integer", "Toggle the 'vodkatech' modifier, which spins players on the X, Y, and Z axis.\n\nCurrent: " + getCurrentVodkatech() + "\n");
	G_RegisterCallvote( "direction", "left or right", "string", "Changes the spin direction for all players.\nCan be left or right\n\nCurrent: " + getCurrentDirection() + "\n");

}

int getCurrentSpeed() {
    return spingt_speed.integer;
}

int getCurrentVodkatech() {
    return spingt_vodkatech.integer;
}

String getCurrentDirection() {
    return spingt_direction.string == "left" ? "left" : "right";
}

int directionToSign() {
    return spingt_direction.string == "left" ? -1 : 1;
}


void changeModifierForPlayers()
{
    for ( int i = 0; i < maxClients; i++ )
    {
        if ( @Players[i].player == null )
            continue;
        
            // reset the player's angles x & z to 0
        Players[i].resetAngles();
        Players[i].vodkatech = spingt_vodkatech.integer;
        
    }
}

void changeSpeedForPlayers() 
{
    int speed = spingt_speed.integer;
    for ( int i = 0; i < maxClients; i++ )
    {
        if ( @Players[i].player == null )
            continue;
        
        Players[i].setSpeed( speed );
    }
}
