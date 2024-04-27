Player[] Players( maxClients );



class Player
{
    Client@ client;
    Entity@ player;
    int speedIndex; // 1 = slowest, 5 = fastest
    int speed;
    int vodkatech;
    int direction = 1; // 1 = right, -1 = left
    int time = 0;
    int nextTime = 0;
    bool isInitialized = false;
    Vec3 angles = Vec3(0, 0, 0);

    int x_dir = 0; // 0 = up, 1 = down
    int z_dir = 0; // 0 = left, 1 = right


    void resetAngles()
    {
        float y_angle = player.angles.y;
        player.angles = Vec3(0, y_angle, 0);
    }

    void think()
    {
        if ( player.client.state() >= CS_SPAWNED && player.team != TEAM_SPECTATOR )
        {

            angles = player.angles;
            if ( this.isInitialized == false ) {
                player.angles.normalize();
                player.avelocity.normalize();


                // reset the angles
                angles = player.angles;
                angles ^= Vec3(0, -1, 0);
                this.isInitialized = true;

            }


            float spinAmount = getSpinSpeed( this.speedIndex, this.direction );

            if ( player.velocity.x != 0 || player.velocity.y != 0 || player.velocity.z != 0) {

                player.origin2 =  (player.velocity * (frameTime* -spinAmount)) +player.origin2 - (player.velocity * (frameTime * -spinAmount ) ) + player.origin2 + (player.velocity * (frameTime * spinAmount) );



            }
            // we also need to take into account the player's current velocity and position, so we can correct the player's position as they spin, otherwise their screen will jitter when they move

            Vec3 fwd = Vec3(0,0,0);
            Vec3 right = Vec3(0,0,0);
            Vec3 up = Vec3(0,0,0);

            // calculate the forward vector
            fwd.x = cos( angles.y ) * cos( angles.x );
            fwd.y = sin( angles.y ) * cos( angles.x );
            fwd.z = sin( angles.x );

            // calculate the right vector
            right = fwd ^ Vec3(0,0,1);
            right.normalize();

            // calculate the up vector
            up = fwd ^ right;
            up.normalize();

            // we need to interpolate the spin/rotation here so it's smooth
            // then interpolate the y angle



            if (this.vodkatech == 1) {
                angles.y = angles.y - spinAmount;
                // if x or z angle is at the limit, reverse the direction
                if ( angles.x > 90 && this.x_dir == 0) {
                        this.x_dir = 1;
                    } else if ( angles.x < -90 && this.x_dir == 1) {
                        this.x_dir = 0;
                    }

                    if ( angles.z > 90 && this.z_dir == 0 ) {
                        this.z_dir = 1;
                    } else if ( angles.z < 0 && this.z_dir == 1 ) {
                        this.z_dir = 0;
                    }

                    if ( this.x_dir == 0 ) {
                        angles.x += spinAmount ;
                    } else {
                        angles.x -= spinAmount ;
                    }

                    if ( this.z_dir == 0 ) {
                        angles.z += spinAmount ;
                    } else {
                        angles.z -= spinAmount;
                    }

                }
            angles.y = angles.y - (spinAmount * ((right * fwd) + 1.0f) * 0.5f) - frameTime * 0.01f * spinAmount * ((right * fwd) + 1.0f) * 0.5f;
            angles.y = angles.y - ( frameTime * 0.01f / spinAmount * ((right * fwd) * 0.5f) * 0.5f);
            angles.y = angles.y  % 360;
            player.angles = angles;
            player.avelocity = angles.toAngles();
            player.avelocity = player.avelocity * 0.5f;

            if ( player.health > player.maxHealth ) {
                player.health -= ( frameTime * 0.001f );
                // fix possible rounding errors
                if( player.health < player.maxHealth ) {
                    player.health = player.maxHealth;
                }
            }

            if ( player.health > player.maxHealth ) {
                player.health -= ( frameTime * 0.001f );
				// fix possible rounding errors
				if( player.health < player.maxHealth ) {
					player.health = player.maxHealth;
				}
			}

        }

    }

    void setSpeed( int speed )
    {
        this.speedIndex = speed;
        this.speed = SPINGT_SPEEDS[speed - 1];
    }
}