class InstagibMode
{

    void enable()
    {
        // Enable instagib mode
        g_noclass_inventory.set( "ig" );
        g_class_strong_ammo.set( "99" );
        gametype.infiniteAmmo = true;

    }

    void disable()
    {
        // Disable instagib mode
        g_noclass_inventory.reset();
        g_class_strong_ammo.reset();
    }
}