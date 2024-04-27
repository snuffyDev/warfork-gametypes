class HighGravityMode
{
    void think(Client @client, Entity @ent)
    {
        if (@client == null || @ent == null)
            return;


        // start floating to the top of the map exponentially

        if ( ent.health > 40 )
        {
            // set the players moveDir

            ent.mass = 500 * (1 - ent.health / ent.maxHealth);
            Vec3 velocity = ent.velocity;

            velocity.z += ent.health * -(ent.health / ent.maxHealth);
            if ( velocity.z < ent.velocity.z )
            {
                velocity.z -= velocity.z*2;
                ent.velocity = velocity;

            }else {


                ent.velocity = velocity;
            }
            G_PrintMsg( null, "Player " + client.name + " is floating at height " + ent.origin.z + "\n" );
        }




    }
}