Player[] Players( maxClients );

int[] GG_WEAP_LIST = { WEAP_PLASMAGUN, WEAP_RIOTGUN, WEAP_MACHINEGUN, WEAP_GRENADELAUNCHER, WEAP_ROCKETLAUNCHER, WEAP_LASERGUN, WEAP_ELECTROBOLT, WEAP_GUNBLADE };

String GG_WEAPNAME_TO_TOKEN( int weap )
{
    switch ( weap ) 
    {
        case WEAP_GUNBLADE: return "gb";
        case WEAP_PLASMAGUN: return "pg";
        case WEAP_RIOTGUN: return "rg";
        case WEAP_LASERGUN: return "lg";
        case WEAP_MACHINEGUN: return "mg";
        case WEAP_GRENADELAUNCHER: return "gl";
        case WEAP_ROCKETLAUNCHER: return "rl";
        case WEAP_ELECTROBOLT: return "eb";
    }
    
    return "gb";
}

/**
 * Player class for Warfork/Warsow "Gun Game" gametype
 */
class Player
{
    Entity@ player;
    Client@ client;
    
    int progress = 0;
    int kills = 0;
    int deaths = 0;
    int demotions = 0;
    
    int weaponIndex = 0;

    void setWeaponIndex( int index )
    {
        this.weaponIndex = index;
        
        this.client.selectWeapon(index);
    }

    void addKill()
    {
        this.kills+=1;
        this.progress+=1;

        G_PrintMsg( player, ""+gungame_rankup_kills.integer - this.progress  + " kills left to rank up!" );
        if ( this.progress >= gungame_rankup_kills.integer )
        {
            this.progress = 0;
            
            if ( this.weaponIndex >= GG_WEAP_LIST.length() - 1 )
            {
                this.weaponIndex = 0;
            }
            
            this.weaponIndex = this.weaponIndex + 1;
            this.client.stats.setScore( this.weaponIndex );
            this.changeInventory();
            client.addAward( "You have ranked up!" );
        }
    }

    void demote()
    {
        this.progress = 0;
        
        if ( this.weaponIndex > 0 )
        {
            this.weaponIndex -= 1;
            this.demotions += 1;
        }

        this.client.stats.setScore( this.weaponIndex );
        
        this.changeInventory();
    }

    void reset()
    {
        this.kills = 0;
        this.demotions = 0;
        this.progress = 0;

        this.deaths = 0;
        this.weaponIndex = 0;
        
        this.setWeaponIndex(0);
    }

    void think()
    {
        if ( player.client.state() >= CS_SPAWNED && player.team != TEAM_SPECTATOR )
        {  
            if ( player.health > player.maxHealth ) {
                player.health -= ( frameTime * 0.001f );
                // fix possible rounding errors
                if( player.health < player.maxHealth ) {
                    player.health = player.maxHealth;
                }
            }
        }
    }

    void prepareRespawn() 
    {
        this.deaths += 1;
        this.progress = 0;
        // give armor
        client.armor = 150;

        // give health
        player.health = 125;

        this.changeInventory();
        client.selectWeapon( -1 );
    }

    void changeInventory()
    {
        client.inventoryClear();
        // give the weapons and ammo as defined in cvars
    	String token, weakammotoken, ammotoken;
    	
        int currentWeapon = GG_WEAP_LIST[this.weaponIndex];
        token = GG_WEAPNAME_TO_TOKEN(currentWeapon);

        Item @item = @G_GetItemByName( token );
        Item @gunblade = @G_GetItemByName( "gb" );
        client.inventoryGiveItem( item.tag );
        client.inventoryGiveItem( gunblade.tag );

        // give ammo

        client.inventorySetCount( item.tag, 99 );
        
        if ( this.weaponIndex == GG_WEAP_LIST.length() - 1 ) {
            client.inventorySetCount( WEAP_GUNBLADE, 1 );
        } else {
            client.inventorySetCount( gunblade.tag, 99 );
        }

        client.selectWeapon( -1 );
    
    }
}