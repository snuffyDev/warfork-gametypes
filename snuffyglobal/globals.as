Cvar g_allow_collision("g_allow_collision", "1", CVAR_ARCHIVE);
uint collisions=g_allow_collision.get_integer();

class CondLimiter
{
    int limit;

    int nextLevelTime;
    CondLimiter(int limit)
    {
        this.limit=limit;
        this.nextLevelTime=levelTime+limit;
    }

    void inc()
    {
        this.nextLevelTime = levelTime + limit;
    }

    bool check()
    {
        return levelTime>nextLevelTime;
    }
}