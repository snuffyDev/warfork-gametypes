
const int PARTYMODE_LOW_GRAVITY = 1;
const int PARTYMODE_HIGH_GRAVITY = 2;
const int PARTYMODE_INSTAGIB = 3;
const int PARTYMODE_NORMAL = 4;
const int PARTYMODE_ONEVS = 5;
const int PARTYMODE_FASTEST_TEAM = 6;
const int PARTYMODE_SIDEWAYS = 7;
const int PARTYMODE_RANDOM_WEAP_LAYOUT = 8;
const int PARTYMODE_RANDOM_WEAP = 9;
const int PARTYMODE_SOULSWAP = 10;

bool[] modesPlayed = new bool[4];

int randomPartyMode() {
    int mode = randomInt(1, 4);
    int count = 0;
    for (int i = 0; i < 4; i++) {
        if (modesPlayed[i]) {
            count++;
        }
    }
    if (count == 4) {
        for (int i = 0; i < 4; i++) {
            modesPlayed[i] = false;
        }
        return;
    }
    while (modesPlayed[mode]) {
        mode = randomInt(1, 4);
    }
    modesPlayed[mode] = true;
    return mode;
}

// MODES
LowGravityMode lowGravityMode;
HighGravityMode highGravityMode;
InstagibMode instagibMode;
/* FastestTeamMode fastestTeamMode;
SidewaysMode sidewaysMode;
RandWeaponMode randWeaponMode;
 */


// Class to represent a round of the party gametype for Warfork
class PartyGt {

    int roundNumber;
    int partyMode;

    int[] motionSicknessOptOut(maxClients);

    PartyGt() {
        this.roundNumber = 0;
        this.partyMode = 0;
        for (int i = 0; i < maxClients; i++) {
            this.motionSicknessOptOut[i] = 0;
        }

    }

    void newRoundState() {
        this.roundNumber = this.roundNumber + 1;
        this.partyMode = randomPartyMode();

        switch (this.partyMode) {
            case PARTYMODE_INSTAGIB:
                instagibMode.enable();
                break;
            case PARTYMODE_RANDOM_WEAP:
//                randWeaponMode.enable();
                break;

            default:
  //              randWeaponMode.disable();
                instagibMode.disable();
                break;

        }

    }

    void think() {
        Entity@ @player;
        Client@ @client;

        switch (this.partyMode) {
            case PARTYMODE_LOW_GRAVITY:
                for (int i = 0; i < maxClients; i++) {
                    @client = @G_GetClient(i);
                    if (@client == null) {
                        continue;
                    }

                    @player = @client.getEnt();
                    if (@player == null) {
                        continue;
                    }
                    if (this.motionSicknessOptOut[i] == 0) {
                        lowGravityMode.think(@client, @player);

                    }
                }
                break;
            case PARTYMODE_HIGH_GRAVITY:
                for (int i = 0; i < maxClients; i++) {
                    @client = @G_GetClient(i);
                    if (@client == null) {
                        continue;
                    }
                    @player = @client.getEnt();
                    if (@player == null) {
                        continue;
                    }
                    if (this.motionSicknessOptOut[i] == 0) {
                        highGravityMode.think(@client,@player);
                    }
                }
                break;
            case PARTYMODE_NORMAL:
                break;
            /* case PARTYMODE_ONEVS:
                break;
            case PARTYMODE_FASTEST_TEAM:
                fastestTeamMode.think();
                break;
            case PARTYMODE_SIDEWAYS:
                sidewaysMode.think();
                break;
            case PARTYMODE_RANDOM_WEAP_LAYOUT:
                break;
            case PARTYMODE_RANDOM_WEAP:
                randWeaponMode.think();
                break; */
        }
    }

    void motionSickOptOut( int clientNum ) {
        this.motionSicknessOptOut[clientNum] = 1;
    }

    void motionSickOptIn( int clientNum ) {
        this.motionSicknessOptOut[clientNum] = 0;
    }

    int getRoundNumber() {
        return this.roundNumber;
    }

    int getPartyMode() {
        return this.partyMode;
    }

    int[] getMotionSicknessOptOut() {
        return this.motionSicknessOptOut;
    }

    void setRoundNumber( int roundNumber ) {
        this.roundNumber = roundNumber;
    }






}