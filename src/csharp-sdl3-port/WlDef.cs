// WL_DEF.H -> WlDef.cs
// Core type definitions, constants, enums, and global state for Wolfenstein 3D

using System;
using System.IO;
using System.Runtime.InteropServices;

namespace Wolf3D
{
    // =========================================================================
    //  VERSION.H defines
    // =========================================================================
    // GOODTIMES, ARTSEXTERN, DEMOSEXTERN, CARMACIZED are defined in csproj

    // =========================================================================
    //  Basic types (ID_HEAD.H / ID_HEADS.H)
    // =========================================================================

    // In C: boolean = int/bool, byte = uint8_t, word = uint16_t, longword = uint32_t
    // In C#: bool, byte, ushort, uint map naturally.
    // "fixed" in wolf3d is a 32-bit fixed-point (16.16), mapped to int.

    [StructLayout(LayoutKind.Sequential)]
    public struct Point
    {
        public int x, y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Rect
    {
        public Point ul, lr;
    }

    // =========================================================================
    //  GFXV_WL6.H - Graphics chunk enums and constants
    // =========================================================================

    public enum graphicnums
    {
        // Lump Start
        H_BJPIC = 3,
        H_CASTLEPIC,                         // 4
        H_BLAZEPIC,                          // 5
        H_TOPWINDOWPIC,                      // 6
        H_LEFTWINDOWPIC,                     // 7
        H_RIGHTWINDOWPIC,                    // 8
        H_BOTTOMINFOPIC,                     // 9
        // Lump Start
        C_OPTIONSPIC,                        // 10
        C_CURSOR1PIC,                        // 11
        C_CURSOR2PIC,                        // 12
        C_NOTSELECTEDPIC,                    // 13
        C_SELECTEDPIC,                       // 14
        C_FXTITLEPIC,                        // 15
        C_DIGITITLEPIC,                      // 16
        C_MUSICTITLEPIC,                     // 17
        C_MOUSELBACKPIC,                     // 18
        C_BABYMODEPIC,                       // 19
        C_EASYPIC,                           // 20
        C_NORMALPIC,                         // 21
        C_HARDPIC,                           // 22
        C_LOADSAVEDISKPIC,                   // 23
        C_DISKLOADING1PIC,                   // 24
        C_DISKLOADING2PIC,                   // 25
        C_CONTROLPIC,                        // 26
        C_CUSTOMIZEPIC,                      // 27
        C_LOADGAMEPIC,                       // 28
        C_SAVEGAMEPIC,                       // 29
        C_EPISODE1PIC,                       // 30
        C_EPISODE2PIC,                       // 31
        C_EPISODE3PIC,                       // 32
        C_EPISODE4PIC,                       // 33
        C_EPISODE5PIC,                       // 34
        C_EPISODE6PIC,                       // 35
        C_CODEPIC,                           // 36
        C_TIMECODEPIC,                       // 37
        C_LEVELPIC,                          // 38
        C_NAMEPIC,                           // 39
        C_SCOREPIC,                          // 40
        C_JOY1PIC,                           // 41
        C_JOY2PIC,                           // 42
        // Lump Start
        L_GUYPIC,                            // 43
        L_COLONPIC,                          // 44
        L_NUM0PIC,                           // 45
        L_NUM1PIC,                           // 46
        L_NUM2PIC,                           // 47
        L_NUM3PIC,                           // 48
        L_NUM4PIC,                           // 49
        L_NUM5PIC,                           // 50
        L_NUM6PIC,                           // 51
        L_NUM7PIC,                           // 52
        L_NUM8PIC,                           // 53
        L_NUM9PIC,                           // 54
        L_PERCENTPIC,                        // 55
        L_APIC,                              // 56
        L_BPIC,                              // 57
        L_CPIC,                              // 58
        L_DPIC,                              // 59
        L_EPIC,                              // 60
        L_FPIC,                              // 61
        L_GPIC,                              // 62
        L_HPIC,                              // 63
        L_IPIC,                              // 64
        L_JPIC,                              // 65
        L_KPIC,                              // 66
        L_LPIC,                              // 67
        L_MPIC,                              // 68
        L_NPIC,                              // 69
        L_OPIC,                              // 70
        L_PPIC,                              // 71
        L_QPIC,                              // 72
        L_RPIC,                              // 73
        L_SPIC,                              // 74
        L_TPIC,                              // 75
        L_UPIC,                              // 76
        L_VPIC,                              // 77
        L_WPIC,                              // 78
        L_XPIC,                              // 79
        L_YPIC,                              // 80
        L_ZPIC,                              // 81
        L_EXPOINTPIC,                        // 82
        L_APOSTROPHEPIC,                     // 83
        L_GUY2PIC,                           // 84
        L_BJWINSPIC,                         // 85
        STATUSBARPIC,                        // 86
        TITLEPIC,                            // 87
        PG13PIC,                             // 88
        CREDITSPIC,                          // 89
        HIGHSCORESPIC,                       // 90
        // Lump Start
        KNIFEPIC,                            // 91
        GUNPIC,                              // 92
        MACHINEGUNPIC,                       // 93
        GATLINGGUNPIC,                       // 94
        NOKEYPIC,                            // 95
        GOLDKEYPIC,                          // 96
        SILVERKEYPIC,                        // 97
        N_BLANKPIC,                          // 98
        N_0PIC,                              // 99
        N_1PIC,                              // 100
        N_2PIC,                              // 101
        N_3PIC,                              // 102
        N_4PIC,                              // 103
        N_5PIC,                              // 104
        N_6PIC,                              // 105
        N_7PIC,                              // 106
        N_8PIC,                              // 107
        N_9PIC,                              // 108
        FACE1APIC,                           // 109
        FACE1BPIC,                           // 110
        FACE1CPIC,                           // 111
        FACE2APIC,                           // 112
        FACE2BPIC,                           // 113
        FACE2CPIC,                           // 114
        FACE3APIC,                           // 115
        FACE3BPIC,                           // 116
        FACE3CPIC,                           // 117
        FACE4APIC,                           // 118
        FACE4BPIC,                           // 119
        FACE4CPIC,                           // 120
        FACE5APIC,                           // 121
        FACE5BPIC,                           // 122
        FACE5CPIC,                           // 123
        FACE6APIC,                           // 124
        FACE6BPIC,                           // 125
        FACE6CPIC,                           // 126
        FACE7APIC,                           // 127
        FACE7BPIC,                           // 128
        FACE7CPIC,                           // 129
        FACE8APIC,                           // 130
        GOTGATLINGPIC,                       // 131
        MUTANTBJPIC,                         // 132
        PAUSEDPIC,                           // 133
        GETPSYCHEDPIC,                       // 134

        ORDERSCREEN = 136,
        ERRORSCREEN,                         // 137
        T_HELPART,                           // 138
        T_DEMO0,                             // 139
        T_DEMO1,                             // 140
        T_DEMO2,                             // 141
        T_DEMO3,                             // 142
        T_ENDART1,                           // 143
        T_ENDART2,                           // 144
        T_ENDART3,                           // 145
        T_ENDART4,                           // 146
        T_ENDART5,                           // 147
        T_ENDART6,                           // 148
        ENUMEND
    }

    // Graphics chunk constants
    public static class GfxConstants
    {
        public const int README_LUMP_START = 3;
        public const int README_LUMP_END = 9;
        public const int CONTROLS_LUMP_START = 10;
        public const int CONTROLS_LUMP_END = 42;
        public const int LEVELEND_LUMP_START = 43;
        public const int LEVELEND_LUMP_END = 85;
        public const int LATCHPICS_LUMP_START = 91;
        public const int LATCHPICS_LUMP_END = 134;

        public const int NUMCHUNKS = 149;
        public const int NUMFONT = 2;
        public const int NUMFONTM = 0;
        public const int NUMPICS = 132;
        public const int NUMPICM = 0;
        public const int NUMSPRITES = 0;
        public const int NUMTILE8 = 72;
        public const int NUMTILE8M = 0;
        public const int NUMTILE16 = 0;
        public const int NUMTILE16M = 0;
        public const int NUMTILE32 = 0;
        public const int NUMTILE32M = 0;
        public const int NUMEXTERNS = 13;

        public const int STRUCTPIC = 0;
        public const int STARTFONT = 1;
        public const int STARTFONTM = 3;
        public const int STARTPICS = 3;
        public const int STARTPICM = 135;
        public const int STARTSPRITES = 135;
        public const int STARTTILE8 = 135;
        public const int STARTTILE8M = 136;
        public const int STARTTILE16 = 136;
        public const int STARTTILE16M = 136;
        public const int STARTTILE32 = 136;
        public const int STARTTILE32M = 136;
        public const int STARTEXTERNS = 136;
    }

    // =========================================================================
    //  AUDIOWL6.H - Sound names
    // =========================================================================

    public enum soundnames
    {
        HITWALLSND,              // 0
        SELECTWPNSND,            // 1
        SELECTITEMSND,           // 2
        HEARTBEATSND,            // 3
        MOVEGUN2SND,             // 4
        MOVEGUN1SND,             // 5
        NOWAYSND,                // 6
        NAZIHITPLAYERSND,        // 7
        SCHABBSTHROWSND,         // 8
        PLAYERDEATHSND,          // 9
        DOGDEATHSND,             // 10
        ATKGATLINGSND,           // 11
        GETKEYSND,               // 12
        NOITEMSND,               // 13
        WALK1SND,                // 14
        WALK2SND,                // 15
        TAKEDAMAGESND,           // 16
        GAMEOVERSND,             // 17
        OPENDOORSND,             // 18
        CLOSEDOORSND,            // 19
        DONOTHINGSND,            // 20
        HALTSND,                 // 21
        DEATHSCREAM2SND,         // 22
        ATKKNIFESND,             // 23
        ATKPISTOLSND,            // 24
        DEATHSCREAM3SND,         // 25
        ATKMACHINEGUNSND,        // 26
        HITENEMYSND,             // 27
        SHOOTDOORSND,            // 28
        DEATHSCREAM1SND,         // 29
        GETMACHINESND,           // 30
        GETAMMOSND,              // 31
        SHOOTSND,                // 32
        HEALTH1SND,              // 33
        HEALTH2SND,              // 34
        BONUS1SND,               // 35
        BONUS2SND,               // 36
        BONUS3SND,               // 37
        GETGATLINGSND,           // 38
        ESCPRESSEDSND,           // 39
        LEVELDONESND,            // 40
        DOGBARKSND,              // 41
        ENDBONUS1SND,            // 42
        ENDBONUS2SND,            // 43
        BONUS1UPSND,             // 44
        BONUS4SND,               // 45
        PUSHWALLSND,             // 46
        NOBONUSSND,              // 47
        PERCENT100SND,           // 48
        BOSSACTIVESND,           // 49
        MUTTISND,                // 50
        SCHUTZADSND,             // 51
        AHHHGSND,                // 52
        DIESND,                  // 53
        EVASND,                  // 54
        GUTENTAGSND,             // 55
        LEBENSND,                // 56
        SCHEISTSND,              // 57
        NAZIFIRESND,             // 58
        BOSSFIRESND,             // 59
        SSFIRESND,               // 60
        SLURPIESND,              // 61
        TOT_HUNDSND,             // 62
        MEINGOTTSND,             // 63
        SCHABBSHASND,            // 64
        HITLERHASND,             // 65
        SPIONSND,                // 66
        NEINSOVASSND,            // 67
        DOGATTACKSND,            // 68
        FLAMETHROWERSND,         // 69
        MECHSTEPSND,             // 70
        GOOBSSND,                // 71
        YEAHSND,                 // 72
        DEATHSCREAM4SND,         // 73
        DEATHSCREAM5SND,         // 74
        DEATHSCREAM6SND,         // 75
        DEATHSCREAM7SND,         // 76
        DEATHSCREAM8SND,         // 77
        DEATHSCREAM9SND,         // 78
        DONNERSND,               // 79
        EINESND,                 // 80
        ERLAUBENSND,             // 81
        KEINSND,                 // 82
        MEINSND,                 // 83
        ROSESND,                 // 84
        MISSILEFIRESND,          // 85
        MISSILEHITSND,           // 86
        LASTSOUND
    }

    public static class AudioConstants
    {
        public const int NUMSOUNDS = 87;
        public const int NUMSNDCHUNKS = 288;
        public const int STARTPCSOUNDS = 0;
        public const int STARTADLIBSOUNDS = 87;
        public const int STARTDIGISOUNDS = 174;
        public const int STARTMUSIC = 261;
    }

    public enum musicnames
    {
        CORNER_MUS,              // 0
        DUNGEON_MUS,             // 1
        WARMARCH_MUS,            // 2
        GETTHEM_MUS,             // 3
        HEADACHE_MUS,            // 4
        HITLWLTZ_MUS,            // 5
        INTROCW3_MUS,            // 6
        NAZI_NOR_MUS,            // 7
        NAZI_OMI_MUS,            // 8
        POW_MUS,                 // 9
        SALUTE_MUS,              // 10
        SEARCHN_MUS,             // 11
        SUSPENSE_MUS,            // 12
        VICTORS_MUS,             // 13
        WONDERIN_MUS,            // 14
        FUNKYOU_MUS,             // 15
        ENDLEVEL_MUS,            // 16
        GOINGAFT_MUS,            // 17
        PREGNANT_MUS,            // 18
        ULTIMATE_MUS,            // 19
        NAZI_RAP_MUS,            // 20
        ZEROHOUR_MUS,            // 21
        TWELFTH_MUS,             // 22
        ROSTER_MUS,              // 23
        URAHERO_MUS,             // 24
        VICMARCH_MUS,            // 25
        PACMAN_MUS,              // 26
        LASTMUSIC
    }

    // =========================================================================
    //  MAPSWL6.H - Map names
    // =========================================================================

    public enum mapnames
    {
        WOLF1_MAP1_MAP,
        WOLF1_MAP2_MAP,
        WOLF1_MAP3_MAP,
        WOLF1_MAP4_MAP,
        WOLF1_MAP5_MAP,
        WOLF1_MAP6_MAP,
        WOLF1_MAP7_MAP,
        WOLF1_MAP8_MAP,
        WOLF1_BOSS_MAP,
        WOLF1_SECRET_MAP,
        WOLF2_MAP1_MAP,
        WOLF2_MAP2_MAP,
        WOLF2_MAP3_MAP,
        WOLF2_MAP4_MAP,
        WOLF2_MAP5_MAP,
        WOLF2_MAP6_MAP,
        WOLF2_MAP7_MAP,
        WOLF2_MAP8_MAP,
        WOLF2_BOSS_MAP,
        WOLF2_SECRET_MAP,
        WOLF3_MAP1_MAP,
        WOLF3_MAP2_MAP,
        WOLF3_MAP3_MAP,
        WOLF3_MAP4_MAP,
        WOLF3_MAP5_MAP,
        WOLF3_MAP6_MAP,
        WOLF3_MAP7_MAP,
        WOLF3_MAP8_MAP,
        WOLF3_BOSS_MAP,
        WOLF3_SECRET_MAP,
        WOLF4_MAP_1_MAP,
        WOLF4_MAP_2_MAP,
        WOLF4_MAP_3_MAP,
        WOLF4_MAP_4_MAP,
        WOLF4_MAP_5_MAP,
        WOLF4_MAP_6_MAP,
        WOLF4_MAP_7_MAP,
        WOLF4_MAP_8_MAP,
        WOLF4_BOSS_MAP,
        WOLF4_SECRET_MAP,
        WOLF5_MAP_1_MAP,
        WOLF5_MAP_2_MAP,
        WOLF5_MAP_3_MAP,
        WOLF5_MAP_4_MAP,
        WOLF5_MAP_5_MAP,
        WOLF5_MAP_6_MAP,
        WOLF5_MAP_7_MAP,
        WOLF5_MAP_8_MAP,
        WOLF5_BOSS_MAP,
        WOLF5_SECRET_MAP,
        WOLF6_MAP_1_MAP,
        WOLF6_MAP_2_MAP,
        WOLF6_MAP_3_MAP,
        WOLF6_MAP_4_MAP,
        WOLF6_MAP_5_MAP,
        WOLF6_MAP_6_MAP,
        WOLF6_MAP_7_MAP,
        WOLF6_MAP_8_MAP,
        WOLF6_BOSS_MAP,
        WOLF6_SECRET_MAP,
        MAP4L10PATH_MAP,
        LASTMAP
    }

    // =========================================================================
    //  WL_DEF.H - Main game definitions
    // =========================================================================

    // Sprite constants (WL6 - non-SPEAR)
    public enum SpriteEnum
    {
        SPR_DEMO,
        SPR_DEATHCAM,
        // static sprites
        SPR_STAT_0, SPR_STAT_1, SPR_STAT_2, SPR_STAT_3,
        SPR_STAT_4, SPR_STAT_5, SPR_STAT_6, SPR_STAT_7,
        SPR_STAT_8, SPR_STAT_9, SPR_STAT_10, SPR_STAT_11,
        SPR_STAT_12, SPR_STAT_13, SPR_STAT_14, SPR_STAT_15,
        SPR_STAT_16, SPR_STAT_17, SPR_STAT_18, SPR_STAT_19,
        SPR_STAT_20, SPR_STAT_21, SPR_STAT_22, SPR_STAT_23,
        SPR_STAT_24, SPR_STAT_25, SPR_STAT_26, SPR_STAT_27,
        SPR_STAT_28, SPR_STAT_29, SPR_STAT_30, SPR_STAT_31,
        SPR_STAT_32, SPR_STAT_33, SPR_STAT_34, SPR_STAT_35,
        SPR_STAT_36, SPR_STAT_37, SPR_STAT_38, SPR_STAT_39,
        SPR_STAT_40, SPR_STAT_41, SPR_STAT_42, SPR_STAT_43,
        SPR_STAT_44, SPR_STAT_45, SPR_STAT_46, SPR_STAT_47,
        // guard
        SPR_GRD_S_1, SPR_GRD_S_2, SPR_GRD_S_3, SPR_GRD_S_4,
        SPR_GRD_S_5, SPR_GRD_S_6, SPR_GRD_S_7, SPR_GRD_S_8,
        SPR_GRD_W1_1, SPR_GRD_W1_2, SPR_GRD_W1_3, SPR_GRD_W1_4,
        SPR_GRD_W1_5, SPR_GRD_W1_6, SPR_GRD_W1_7, SPR_GRD_W1_8,
        SPR_GRD_W2_1, SPR_GRD_W2_2, SPR_GRD_W2_3, SPR_GRD_W2_4,
        SPR_GRD_W2_5, SPR_GRD_W2_6, SPR_GRD_W2_7, SPR_GRD_W2_8,
        SPR_GRD_W3_1, SPR_GRD_W3_2, SPR_GRD_W3_3, SPR_GRD_W3_4,
        SPR_GRD_W3_5, SPR_GRD_W3_6, SPR_GRD_W3_7, SPR_GRD_W3_8,
        SPR_GRD_W4_1, SPR_GRD_W4_2, SPR_GRD_W4_3, SPR_GRD_W4_4,
        SPR_GRD_W4_5, SPR_GRD_W4_6, SPR_GRD_W4_7, SPR_GRD_W4_8,
        SPR_GRD_PAIN_1, SPR_GRD_DIE_1, SPR_GRD_DIE_2, SPR_GRD_DIE_3,
        SPR_GRD_PAIN_2, SPR_GRD_DEAD,
        SPR_GRD_SHOOT1, SPR_GRD_SHOOT2, SPR_GRD_SHOOT3,
        // dogs
        SPR_DOG_W1_1, SPR_DOG_W1_2, SPR_DOG_W1_3, SPR_DOG_W1_4,
        SPR_DOG_W1_5, SPR_DOG_W1_6, SPR_DOG_W1_7, SPR_DOG_W1_8,
        SPR_DOG_W2_1, SPR_DOG_W2_2, SPR_DOG_W2_3, SPR_DOG_W2_4,
        SPR_DOG_W2_5, SPR_DOG_W2_6, SPR_DOG_W2_7, SPR_DOG_W2_8,
        SPR_DOG_W3_1, SPR_DOG_W3_2, SPR_DOG_W3_3, SPR_DOG_W3_4,
        SPR_DOG_W3_5, SPR_DOG_W3_6, SPR_DOG_W3_7, SPR_DOG_W3_8,
        SPR_DOG_W4_1, SPR_DOG_W4_2, SPR_DOG_W4_3, SPR_DOG_W4_4,
        SPR_DOG_W4_5, SPR_DOG_W4_6, SPR_DOG_W4_7, SPR_DOG_W4_8,
        SPR_DOG_DIE_1, SPR_DOG_DIE_2, SPR_DOG_DIE_3, SPR_DOG_DEAD,
        SPR_DOG_JUMP1, SPR_DOG_JUMP2, SPR_DOG_JUMP3,
        // ss
        SPR_SS_S_1, SPR_SS_S_2, SPR_SS_S_3, SPR_SS_S_4,
        SPR_SS_S_5, SPR_SS_S_6, SPR_SS_S_7, SPR_SS_S_8,
        SPR_SS_W1_1, SPR_SS_W1_2, SPR_SS_W1_3, SPR_SS_W1_4,
        SPR_SS_W1_5, SPR_SS_W1_6, SPR_SS_W1_7, SPR_SS_W1_8,
        SPR_SS_W2_1, SPR_SS_W2_2, SPR_SS_W2_3, SPR_SS_W2_4,
        SPR_SS_W2_5, SPR_SS_W2_6, SPR_SS_W2_7, SPR_SS_W2_8,
        SPR_SS_W3_1, SPR_SS_W3_2, SPR_SS_W3_3, SPR_SS_W3_4,
        SPR_SS_W3_5, SPR_SS_W3_6, SPR_SS_W3_7, SPR_SS_W3_8,
        SPR_SS_W4_1, SPR_SS_W4_2, SPR_SS_W4_3, SPR_SS_W4_4,
        SPR_SS_W4_5, SPR_SS_W4_6, SPR_SS_W4_7, SPR_SS_W4_8,
        SPR_SS_PAIN_1, SPR_SS_DIE_1, SPR_SS_DIE_2, SPR_SS_DIE_3,
        SPR_SS_PAIN_2, SPR_SS_DEAD,
        SPR_SS_SHOOT1, SPR_SS_SHOOT2, SPR_SS_SHOOT3,
        // mutant
        SPR_MUT_S_1, SPR_MUT_S_2, SPR_MUT_S_3, SPR_MUT_S_4,
        SPR_MUT_S_5, SPR_MUT_S_6, SPR_MUT_S_7, SPR_MUT_S_8,
        SPR_MUT_W1_1, SPR_MUT_W1_2, SPR_MUT_W1_3, SPR_MUT_W1_4,
        SPR_MUT_W1_5, SPR_MUT_W1_6, SPR_MUT_W1_7, SPR_MUT_W1_8,
        SPR_MUT_W2_1, SPR_MUT_W2_2, SPR_MUT_W2_3, SPR_MUT_W2_4,
        SPR_MUT_W2_5, SPR_MUT_W2_6, SPR_MUT_W2_7, SPR_MUT_W2_8,
        SPR_MUT_W3_1, SPR_MUT_W3_2, SPR_MUT_W3_3, SPR_MUT_W3_4,
        SPR_MUT_W3_5, SPR_MUT_W3_6, SPR_MUT_W3_7, SPR_MUT_W3_8,
        SPR_MUT_W4_1, SPR_MUT_W4_2, SPR_MUT_W4_3, SPR_MUT_W4_4,
        SPR_MUT_W4_5, SPR_MUT_W4_6, SPR_MUT_W4_7, SPR_MUT_W4_8,
        SPR_MUT_PAIN_1, SPR_MUT_DIE_1, SPR_MUT_DIE_2, SPR_MUT_DIE_3,
        SPR_MUT_PAIN_2, SPR_MUT_DIE_4, SPR_MUT_DEAD,
        SPR_MUT_SHOOT1, SPR_MUT_SHOOT2, SPR_MUT_SHOOT3, SPR_MUT_SHOOT4,
        // officer
        SPR_OFC_S_1, SPR_OFC_S_2, SPR_OFC_S_3, SPR_OFC_S_4,
        SPR_OFC_S_5, SPR_OFC_S_6, SPR_OFC_S_7, SPR_OFC_S_8,
        SPR_OFC_W1_1, SPR_OFC_W1_2, SPR_OFC_W1_3, SPR_OFC_W1_4,
        SPR_OFC_W1_5, SPR_OFC_W1_6, SPR_OFC_W1_7, SPR_OFC_W1_8,
        SPR_OFC_W2_1, SPR_OFC_W2_2, SPR_OFC_W2_3, SPR_OFC_W2_4,
        SPR_OFC_W2_5, SPR_OFC_W2_6, SPR_OFC_W2_7, SPR_OFC_W2_8,
        SPR_OFC_W3_1, SPR_OFC_W3_2, SPR_OFC_W3_3, SPR_OFC_W3_4,
        SPR_OFC_W3_5, SPR_OFC_W3_6, SPR_OFC_W3_7, SPR_OFC_W3_8,
        SPR_OFC_W4_1, SPR_OFC_W4_2, SPR_OFC_W4_3, SPR_OFC_W4_4,
        SPR_OFC_W4_5, SPR_OFC_W4_6, SPR_OFC_W4_7, SPR_OFC_W4_8,
        SPR_OFC_PAIN_1, SPR_OFC_DIE_1, SPR_OFC_DIE_2, SPR_OFC_DIE_3,
        SPR_OFC_PAIN_2, SPR_OFC_DIE_4, SPR_OFC_DEAD,
        SPR_OFC_SHOOT1, SPR_OFC_SHOOT2, SPR_OFC_SHOOT3,
        // ghosts (non-SPEAR)
        SPR_BLINKY_W1, SPR_BLINKY_W2, SPR_PINKY_W1, SPR_PINKY_W2,
        SPR_CLYDE_W1, SPR_CLYDE_W2, SPR_INKY_W1, SPR_INKY_W2,
        // hans
        SPR_BOSS_W1, SPR_BOSS_W2, SPR_BOSS_W3, SPR_BOSS_W4,
        SPR_BOSS_SHOOT1, SPR_BOSS_SHOOT2, SPR_BOSS_SHOOT3, SPR_BOSS_DEAD,
        SPR_BOSS_DIE1, SPR_BOSS_DIE2, SPR_BOSS_DIE3,
        // schabbs
        SPR_SCHABB_W1, SPR_SCHABB_W2, SPR_SCHABB_W3, SPR_SCHABB_W4,
        SPR_SCHABB_SHOOT1, SPR_SCHABB_SHOOT2,
        SPR_SCHABB_DIE1, SPR_SCHABB_DIE2, SPR_SCHABB_DIE3, SPR_SCHABB_DEAD,
        SPR_HYPO1, SPR_HYPO2, SPR_HYPO3, SPR_HYPO4,
        // fake
        SPR_FAKE_W1, SPR_FAKE_W2, SPR_FAKE_W3, SPR_FAKE_W4,
        SPR_FAKE_SHOOT, SPR_FIRE1, SPR_FIRE2,
        SPR_FAKE_DIE1, SPR_FAKE_DIE2, SPR_FAKE_DIE3, SPR_FAKE_DIE4,
        SPR_FAKE_DIE5, SPR_FAKE_DEAD,
        // hitler
        SPR_MECHA_W1, SPR_MECHA_W2, SPR_MECHA_W3, SPR_MECHA_W4,
        SPR_MECHA_SHOOT1, SPR_MECHA_SHOOT2, SPR_MECHA_SHOOT3, SPR_MECHA_DEAD,
        SPR_MECHA_DIE1, SPR_MECHA_DIE2, SPR_MECHA_DIE3,
        SPR_HITLER_W1, SPR_HITLER_W2, SPR_HITLER_W3, SPR_HITLER_W4,
        SPR_HITLER_SHOOT1, SPR_HITLER_SHOOT2, SPR_HITLER_SHOOT3, SPR_HITLER_DEAD,
        SPR_HITLER_DIE1, SPR_HITLER_DIE2, SPR_HITLER_DIE3, SPR_HITLER_DIE4,
        SPR_HITLER_DIE5, SPR_HITLER_DIE6, SPR_HITLER_DIE7,
        // giftmacher
        SPR_GIFT_W1, SPR_GIFT_W2, SPR_GIFT_W3, SPR_GIFT_W4,
        SPR_GIFT_SHOOT1, SPR_GIFT_SHOOT2,
        SPR_GIFT_DIE1, SPR_GIFT_DIE2, SPR_GIFT_DIE3, SPR_GIFT_DEAD,
        // rockets/smoke/explosion
        SPR_ROCKET_1, SPR_ROCKET_2, SPR_ROCKET_3, SPR_ROCKET_4,
        SPR_ROCKET_5, SPR_ROCKET_6, SPR_ROCKET_7, SPR_ROCKET_8,
        SPR_SMOKE_1, SPR_SMOKE_2, SPR_SMOKE_3, SPR_SMOKE_4,
        SPR_BOOM_1, SPR_BOOM_2, SPR_BOOM_3,
        // gretel
        SPR_GRETEL_W1, SPR_GRETEL_W2, SPR_GRETEL_W3, SPR_GRETEL_W4,
        SPR_GRETEL_SHOOT1, SPR_GRETEL_SHOOT2, SPR_GRETEL_SHOOT3, SPR_GRETEL_DEAD,
        SPR_GRETEL_DIE1, SPR_GRETEL_DIE2, SPR_GRETEL_DIE3,
        // fat face
        SPR_FAT_W1, SPR_FAT_W2, SPR_FAT_W3, SPR_FAT_W4,
        SPR_FAT_SHOOT1, SPR_FAT_SHOOT2, SPR_FAT_SHOOT3, SPR_FAT_SHOOT4,
        SPR_FAT_DIE1, SPR_FAT_DIE2, SPR_FAT_DIE3, SPR_FAT_DEAD,
        // bj
        SPR_BJ_W1, SPR_BJ_W2, SPR_BJ_W3, SPR_BJ_W4,
        SPR_BJ_JUMP1, SPR_BJ_JUMP2, SPR_BJ_JUMP3, SPR_BJ_JUMP4,
        // player weapons
        SPR_KNIFEREADY, SPR_KNIFEATK1, SPR_KNIFEATK2, SPR_KNIFEATK3,
        SPR_KNIFEATK4,
        SPR_PISTOLREADY, SPR_PISTOLATK1, SPR_PISTOLATK2, SPR_PISTOLATK3,
        SPR_PISTOLATK4,
        SPR_MACHINEGUNREADY, SPR_MACHINEGUNATK1, SPR_MACHINEGUNATK2, MACHINEGUNATK3,
        SPR_MACHINEGUNATK4,
        SPR_CHAINREADY, SPR_CHAINATK1, SPR_CHAINATK2, SPR_CHAINATK3,
        SPR_CHAINATK4,
    }

    // =========================================================================
    //  Game type enums
    // =========================================================================

    public enum controldir_t { di_north, di_east, di_south, di_west }

    public enum door_t { dr_normal, dr_lock1, dr_lock2, dr_lock3, dr_lock4, dr_elevator }

    public enum activetype { ac_badobject = -1, ac_no, ac_yes, ac_allways }

    public enum classtype
    {
        nothing, playerobj, inertobj, guardobj, officerobj, ssobj, dogobj,
        bossobj, schabbobj, fakeobj, mechahitlerobj, mutantobj, needleobj,
        fireobj, bjobj, ghostobj, realhitlerobj, gretelobj, giftobj, fatobj,
        rocketobj, spectreobj, angelobj, transobj, uberobj, willobj,
        deathobj, hrocketobj, sparkobj
    }

    public enum stat_t
    {
        dressing, block, bo_gibs, bo_alpo, bo_firstaid, bo_key1, bo_key2,
        bo_key3, bo_key4, bo_cross, bo_chalice, bo_bible, bo_crown, bo_clip,
        bo_clip2, bo_machinegun, bo_chaingun, bo_food, bo_fullheal, bo_25clip,
        bo_spear
    }

    public enum dirtype
    {
        east, northeast, north, northwest, west, southwest, south, southeast, nodir
    }

    public enum enemy_t
    {
        en_guard, en_officer, en_ss, en_dog, en_boss, en_schabbs, en_fake,
        en_hitler, en_mutant, en_blinky, en_clyde, en_pinky, en_inky,
        en_gretel, en_gift, en_fat, en_spectre, en_angel, en_trans,
        en_uber, en_will, en_death
    }

    public enum weapontype { wp_knife, wp_pistol, wp_machinegun, wp_chaingun }

    public enum gamedifficulty_t { gd_baby, gd_easy, gd_medium, gd_hard }

    public enum exit_t
    {
        ex_stillplaying, ex_completed, ex_died, ex_warped, ex_resetgame,
        ex_loadedgame, ex_victorious, ex_abort, ex_demodone, ex_secretlevel
    }

    public enum dooraction_t { dr_open, dr_closed, dr_opening, dr_closing }

    // =========================================================================
    //  Delegate type for statetype think/action functions
    // =========================================================================

    public delegate void StateFunc(objtype ob);

    // =========================================================================
    //  Core game structures
    // =========================================================================

    public class statetype
    {
        public bool rotate;
        public int shapenum;          // -1 means get from ob.temp1
        public int tictime;
        public StateFunc think;
        public StateFunc action;
        public statetype next;
    }

    public class statobj_t
    {
        public byte tilex, tiley;
        public int visspot;           // index into spotvis or -1
        public int shapenum;          // -1 = removed
        public byte flags;
        public byte itemnumber;
    }

    public class doorobj_t
    {
        public byte tilex, tiley;
        public bool vertical;
        public byte lock_;            // renamed to avoid C# keyword
        public dooraction_t action;
        public int ticcount;
    }

    public class objtype
    {
        public activetype active;
        public int ticcount;
        public classtype obclass;
        public statetype state;

        public byte flags;            // FL_SHOOTABLE, etc

        public int distance;          // if negative, wait for that door to open
        public dirtype dir;

        public int x, y;              // fixed-point position
        public int tilex, tiley;
        public byte areanumber;

        public int viewx;
        public int viewheight;
        public int transx, transy;    // in global coord

        public int angle;
        public int hitpoints;
        public int speed;

        public int temp1, temp2, temp3;
        public objtype next, prev;
    }

    public class gametype
    {
        public int difficulty;
        public int mapon;
        public int oldscore, score, nextextra;
        public int lives;
        public int health;
        public int ammo;
        public int keys;
        public weapontype bestweapon, weapon, chosenweapon;

        public int faceframe;
        public int attackframe, attackcount, weaponframe;

        public int episode, secretcount, treasurecount, killcount,
                   secrettotal, treasuretotal, killtotal;
        public int TimeCount;
        public int killx, killy;
        public bool victoryflag;
    }

    // =========================================================================
    //  ID_CA.H structures
    // =========================================================================

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct maptype
    {
        public int planestart0, planestart1, planestart2;
        public ushort planelength0, planelength1, planelength2;
        public ushort width, height;
        // name is 16 chars - we read it separately
    }

    // =========================================================================
    //  ID_VH.H structures
    // =========================================================================

    [StructLayout(LayoutKind.Sequential)]
    public struct pictabletype
    {
        public short width, height;
    }

    public class fontstruct
    {
        public short height;
        public short[] location = new short[256];
        public byte[] width = new byte[256];
    }

    // =========================================================================
    //  ID_PM.H structures
    // =========================================================================

    public enum PMLockType { pml_Unlocked, pml_Locked }
    public enum PMBlockAttr { pmba_Unused = 0, pmba_Used = 1, pmba_Allocated = 2 }

    public class PageListStruct
    {
        public uint offset;
        public ushort length;
        public int xmsPage;
        public PMLockType locked;
        public int emsPage;
        public int mainPage;
        public uint lastHit;
    }

    // =========================================================================
    //  ID_IN.H types
    // =========================================================================

    public enum Demo { demo_Off, demo_Record, demo_Playback, demo_PlayDone }

    public enum ControlType
    {
        ctrl_Keyboard, ctrl_Keyboard1 = ctrl_Keyboard, ctrl_Keyboard2,
        ctrl_Joystick, ctrl_Joystick1 = ctrl_Joystick, ctrl_Joystick2,
        ctrl_Mouse
    }

    public enum Motion { motion_Left = -1, motion_Up = -1, motion_None = 0, motion_Right = 1, motion_Down = 1 }

    public enum Direction
    {
        dir_North, dir_NorthEast, dir_East, dir_SouthEast,
        dir_South, dir_SouthWest, dir_West, dir_NorthWest, dir_None
    }

    public class ControlInfo
    {
        public bool button0, button1, button2, button3;
        public int x, y;
        public int xaxis, yaxis;     // Motion values
        public Direction dir;
    }

    public struct KeyboardDef
    {
        public byte button0, button1;
        public byte upleft, up, upright;
        public byte left, right;
        public byte downleft, down, downright;
    }

    public struct JoystickDef
    {
        public ushort joyMinX, joyMinY;
        public ushort threshMinX, threshMinY;
        public ushort threshMaxX, threshMaxY;
        public ushort joyMaxX, joyMaxY;
        public ushort joyMultXL, joyMultYL;
        public ushort joyMultXH, joyMultYH;
    }

    // =========================================================================
    //  ID_SD.H types
    // =========================================================================

    public enum SDMode { sdm_Off, sdm_PC, sdm_AdLib }
    public enum SMMode { smm_Off, smm_AdLib }
    public enum SDSMode { sds_Off, sds_PC, sds_SoundSource, sds_SoundBlaster }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct Instrument
    {
        public byte mChar, cChar;
        public byte mScale, cScale;
        public byte mAttack, cAttack;
        public byte mSus, cSus;
        public byte mWave, cWave;
        public byte nConn;
        public byte voice;
        public byte mode;
        public byte unused0, unused1, unused2;
    }

    // =========================================================================
    //  ID_US.H types
    // =========================================================================

    public class HighScore
    {
        public string name = "";
        public int score;
        public ushort completed, episode;
    }

    public class SaveGame
    {
        public string signature = "";
        public bool present;
        public string name = "";
    }

    public struct WindowRec
    {
        public int x, y, w, h, px, py;
    }

    public enum GameDiff { gd_Continue, gd_Easy, gd_Normal, gd_Hard }

    // =========================================================================
    //  WL_MENU.H types
    // =========================================================================

    public class CP_iteminfo
    {
        public int x, y, amount, curpos, indent;
    }

    public delegate void MenuRoutine(int temp1);

    public class CP_itemtype
    {
        public int active;
        public string str = "";
        public MenuRoutine routine;
    }

    public class CustomCtrls
    {
        public int[] allowed = new int[4];
    }

    public class LRstruct
    {
        public int kill, secret, treasure;
        public int time;
    }

    // =========================================================================
    //  WL_SCALE.H types
    // =========================================================================

    public class t_compscale
    {
        public ushort[] codeofs = new ushort[65];
        public ushort[] width = new ushort[65];
        public byte[] code;
    }

    public class t_compshape
    {
        public ushort leftpix, rightpix;
        public ushort[] dataofs = new ushort[64];
        public byte[] data;          // table data after dataofs
    }

    // =========================================================================
    //  FOREIGN.H - English strings
    // =========================================================================

    public static class ForeignStrings
    {
        public const string QUITSUR = "Are you sure you want\nto quit this great game?";
        public const string CURGAME = "You are currently in\na game. Continuing will\nerase old game. Ok?";
        public const string GAMESVD = "There's already a game\nsaved at this position.\n      Overwrite?";
        public const string ENDGAMESTR = "Are you sure you want\nto end the game you\nare playing? (Y or N):";
        public const string STR_NG = "New Game";
        public const string STR_SD = "Sound";
        public const string STR_CL = "Control";
        public const string STR_LG = "Load Game";
        public const string STR_SG = "Save Game";
        public const string STR_CV = "Change View";
        public const string STR_VS = "View Scores";
        public const string STR_EG = "End Game";
        public const string STR_BD = "Back to Demo";
        public const string STR_QT = "Quit";
        public const string STR_LOADING = "Loading";
        public const string STR_SAVING = "Saving";
        public const string STR_GAME = "Game";
        public const string STR_DEMO = "Demo";
        public const string STR_LGC = "Load Game called\n\"";
        public const string STR_EMPTY = "empty";
        public const string STR_CALIB = "Calibrate";
        public const string STR_JOYST = "Joystick";
        public const string STR_NONE = "None";
        public const string STR_PC = "PC Speaker";
        public const string STR_ALSB = "AdLib/Sound Blaster";
        public const string STR_DISNEY = "Disney Sound Source";
        public const string STR_SB = "Sound Blaster";
        public const string STR_MOUSEEN = "Mouse Enabled";
        public const string STR_JOYEN = "Joystick Enabled";
        public const string STR_PORT2 = "Use joystick port 2";
        public const string STR_GAMEPAD = "Gravis GamePad Enabled";
        public const string STR_SENS = "Mouse Sensitivity";
        public const string STR_CUSTOM = "Customize controls";
        public const string STR_DADDY = "Can I play, Daddy?";
        public const string STR_HURTME = "Don't hurt me.";
        public const string STR_BRINGEM = "Bring 'em on!";
        public const string STR_DEATH = "I am Death incarnate!";
        public const string STR_SLOW = "Slow";
        public const string STR_FAST = "Fast";
    }

    // =========================================================================
    //  WL_MENU.H constants
    // =========================================================================

    public static class MenuConstants
    {
        public const int BORDCOLOR = 0x29;
        public const int BORD2COLOR = 0x23;
        public const int DEACTIVE = 0x2b;
        public const int BKGDCOLOR = 0x2d;
        public const int STRIPE = 0x2c;
        public const int READCOLOR = 0x4a;
        public const int READHCOLOR = 0x47;
        public const int VIEWCOLOR = 0x7f;
        public const int TEXTCOLOR = 0x17;
        public const int HIGHLIGHT = 0x13;

        public const int SENSITIVE = 60;
        public const int CENTER = SENSITIVE * 2;

        public const int MENU_X = 76;
        public const int MENU_Y = 55;
        public const int MENU_W = 178;
        public const int MENU_H = 13 * 10 + 6;

        public const int SM_X = 48;
        public const int SM_W = 250;
        public const int SM_Y1 = 20;
        public const int SM_H1 = 4 * 13 - 7;
        public const int SM_Y2 = SM_Y1 + 5 * 13;
        public const int SM_H2 = 4 * 13 - 7;
        public const int SM_Y3 = SM_Y2 + 5 * 13;
        public const int SM_H3 = 3 * 13 - 7;

        public const int CTL_X = 24;
        public const int CTL_Y = 70;
        public const int CTL_W = 284;
        public const int CTL_H = 13 * 7 - 7;

        public const int LSM_X = 85;
        public const int LSM_Y = 55;
        public const int LSM_W = 175;
        public const int LSM_H = 10 * 13 + 10;

        public const int NM_X = 50;
        public const int NM_Y = 100;
        public const int NM_W = 225;
        public const int NM_H = 13 * 4 + 15;

        public const int NE_X = 10;
        public const int NE_Y = 23;
        public const int NE_W = 320 - NE_X * 2;
        public const int NE_H = 200 - NE_Y * 2;

        public const int CST_X = 20;
        public const int CST_Y = 48;
        public const int CST_START = 60;
        public const int CST_SPC = 60;
    }

    // =========================================================================
    //  Global constants (WL_DEF.H macros)
    // =========================================================================

    public static class WolfConstants
    {
        public const int YEAR = 1992;
        public const int MONTH = 9;
        public const int DAY = 30;

        public const int MAXACTORS = 150;
        public const int MAXSTATS = 400;
        public const int MAXDOORS = 64;
        public const int MAXWALLTILES = 64;

        public const int ICONARROWS = 90;
        public const int PUSHABLETILE = 98;
        public const int EXITTILE = 99;
        public const int AREATILE = 107;
        public const int NUMAREAS = 37;
        public const int ELEVATORTILE = 21;
        public const int AMBUSHTILE = 106;
        public const int ALTELEVATORTILE = 107;

        public const int NUMBERCHARS = 9;
        public const int EXTRAPOINTS = 40000;
        public const int PLAYERSPEED = 3000;
        public const int RUNSPEED = 6000;

        public const int SCREENBWIDE = 80;
        public const double HEIGHTRATIO = 0.50;

        public const int BORDERCOLOR = 3;
        public const int FLASHCOLOR = 5;
        public const int FLASHTICS = 4;

        public const int NUMLATCHPICS = 100;

        public const double PI = 3.141592657;
        public const double M_PI = 3.14159265358979323846;

        public const int GLOBAL1 = (1 << 16);
        public const int TILEGLOBAL = GLOBAL1;
        public const int PIXGLOBAL = (GLOBAL1 / 64);
        public const int TILESHIFT = 16;
        public const int UNSIGNEDSHIFT = 8;

        public const int ANGLES = 360;
        public const int ANGLEQUAD = (ANGLES / 4);
        public const int FINEANGLES = 3600;
        public const int ANG90 = (FINEANGLES / 4);
        public const int ANG180 = (ANG90 * 2);
        public const int ANG270 = (ANG90 * 3);
        public const int ANG360 = (ANG90 * 4);
        public const int VANG90 = (ANGLES / 4);
        public const int VANG180 = (VANG90 * 2);
        public const int VANG270 = (VANG90 * 3);
        public const int VANG360 = (VANG90 * 4);

        public const int MINDIST = 0x5800;

        public const int MAXSCALEHEIGHT = 256;
        public const int MAXVIEWWIDTH = 320;
        public const int MAPSIZE = 64;

        public const int NORTH = 0;
        public const int EAST = 1;
        public const int SOUTH = 2;
        public const int WEST = 3;

        public const int STATUSLINES = 40;
        public const int SCREENSIZE = (SCREENBWIDE * 208);
        public const int PAGE1START = 0;
        public const int PAGE2START = SCREENSIZE;
        public const int PAGE3START = (SCREENSIZE * 2);
        public const int FREESTART = (SCREENSIZE * 3);

        public const int PIXRADIUS = 512;
        public const int STARTAMMO = 8;

        // Object flags
        public const int FL_SHOOTABLE = 1;
        public const int FL_BONUS = 2;
        public const int FL_NEVERMARK = 4;
        public const int FL_VISABLE = 8;
        public const int FL_ATTACKMODE = 16;
        public const int FL_FIRSTATTACK = 32;
        public const int FL_AMBUSH = 64;
        public const int FL_NONMARK = 128;

        // Button constants
        public const int NUMBUTTONS = 8;
        public const int bt_nobutton = -1;
        public const int bt_attack = 0;
        public const int bt_strafe = 1;
        public const int bt_run = 2;
        public const int bt_use = 3;
        public const int bt_readyknife = 4;
        public const int bt_readypistol = 5;
        public const int bt_readymachinegun = 6;
        public const int bt_readychaingun = 7;

        public const int NUMWEAPONS = 5;

        public const int NUMENEMIES = 22;

        // Refresh manager
        public const int PORTTILESWIDE = 20;
        public const int PORTTILESHIGH = 13;
        public const int UPDATEWIDE = PORTTILESWIDE;
        public const int UPDATEHIGH = PORTTILESHIGH;
        public const int MAXTICS = 10;
        public const int DEMOTICS = 4;
        public const int UPDATETERMINATE = 0x0301;
        public const int UPDATESIZE = (UPDATEWIDE * UPDATEHIGH);

        // State constants
        public const int TURNTICS = 10;
        public const int SPDPATROL = 512;
        public const int SPDDOG = 1500;

        // ID_CA constants
        public const int NUMMAPS = 60;
        public const int MAPPLANES = 2;

        // Scale
        public const int COMPSCALECODESTART = (65 * 4);

        // ID_VL constants
        public const int SCREENWIDTH = 80;
        public const int MAXSCANLINES = 200;
        public const int CHARWIDTH = 2;
        public const int TILEWIDTH = 4;
        public const int SCREENSEG = 0xa000;

        // ID_PM constants
        public const int EMSPageSize = 16384;
        public const int PMPageSize = 4096;
        public const int PMMinMainMem = 10;
        public const int PMMaxMainMem = 100;

        // ID_IN constants
        public const int MaxPlayers = 4;
        public const int MaxKbds = 2;
        public const int MaxJoys = 2;
        public const int NumCodes = 128;

        // ID_SD constants
        public const int TickBase = 70;
        public const int sqMaxTracks = 10;

        // ID_US constants
        public const int MaxX = 320;
        public const int MaxY = 200;
        public const int MaxHighName = 57;
        public const int MaxScores = 7;
        public const int MaxSaveGames = 6;
        public const int MaxGameName = 32;
        public const int MaxString = 128;

        // ID_MM constants
        public const int MAXBLOCKS = 700;
        public const int BUFFERSIZE = 0x1000;

        // ID_VH constants
        public const int WHITE = 15;
        public const int BLACK = 0;
        public const int MAXSHIFTS = 1;
    }

    // =========================================================================
    //  Scan code constants (from ID_IN.H)
    // =========================================================================

    public static class ScanCodes
    {
        public const byte sc_None = 0;
        public const byte sc_Bad = 0xff;
        public const byte sc_Return = 0x1c;
        public const byte sc_Enter = sc_Return;
        public const byte sc_Escape = 0x01;
        public const byte sc_Space = 0x39;
        public const byte sc_BackSpace = 0x0e;
        public const byte sc_Tab = 0x0f;
        public const byte sc_Alt = 0x38;
        public const byte sc_Control = 0x1d;
        public const byte sc_CapsLock = 0x3a;
        public const byte sc_LShift = 0x2a;
        public const byte sc_RShift = 0x36;
        public const byte sc_UpArrow = 0x48;
        public const byte sc_DownArrow = 0x50;
        public const byte sc_LeftArrow = 0x4b;
        public const byte sc_RightArrow = 0x4d;
        public const byte sc_Insert = 0x52;
        public const byte sc_Delete = 0x53;
        public const byte sc_Home = 0x47;
        public const byte sc_End = 0x4f;
        public const byte sc_PgUp = 0x49;
        public const byte sc_PgDn = 0x51;
        public const byte sc_F1 = 0x3b;
        public const byte sc_F2 = 0x3c;
        public const byte sc_F3 = 0x3d;
        public const byte sc_F4 = 0x3e;
        public const byte sc_F5 = 0x3f;
        public const byte sc_F6 = 0x40;
        public const byte sc_F7 = 0x41;
        public const byte sc_F8 = 0x42;
        public const byte sc_F9 = 0x43;
        public const byte sc_F10 = 0x44;
        public const byte sc_F11 = 0x57;
        public const byte sc_F12 = 0x59;
        public const byte sc_1 = 0x02;
        public const byte sc_2 = 0x03;
        public const byte sc_3 = 0x04;
        public const byte sc_4 = 0x05;
        public const byte sc_5 = 0x06;
        public const byte sc_6 = 0x07;
        public const byte sc_7 = 0x08;
        public const byte sc_8 = 0x09;
        public const byte sc_9 = 0x0a;
        public const byte sc_0 = 0x0b;
        public const byte sc_A = 0x1e;
        public const byte sc_B = 0x30;
        public const byte sc_C = 0x2e;
        public const byte sc_D = 0x20;
        public const byte sc_E = 0x12;
        public const byte sc_F = 0x21;
        public const byte sc_G = 0x22;
        public const byte sc_H = 0x23;
        public const byte sc_I = 0x17;
        public const byte sc_J = 0x24;
        public const byte sc_K = 0x25;
        public const byte sc_L = 0x26;
        public const byte sc_M = 0x32;
        public const byte sc_N = 0x31;
        public const byte sc_O = 0x18;
        public const byte sc_P = 0x19;
        public const byte sc_Q = 0x10;
        public const byte sc_R = 0x13;
        public const byte sc_S = 0x1f;
        public const byte sc_T = 0x14;
        public const byte sc_U = 0x16;
        public const byte sc_V = 0x2f;
        public const byte sc_W = 0x11;
        public const byte sc_X = 0x2d;
        public const byte sc_Y = 0x15;
        public const byte sc_Z = 0x2c;
    }

    // =========================================================================
    //  Global state - all the "extern" variables from C, centralized
    // =========================================================================

    public static class WL_Globals
    {
        // ID_HEADS globals
        public static int _argc;
        public static string[] _argv = Array.Empty<string>();

        // Refresh manager
        public static int mapwidth, mapheight, tics;
        public static bool compatability;
        public static byte[] updateptr_backing = new byte[WolfConstants.UPDATESIZE];
        public static int updateptr_offset;
        public static int[] uwidthtable = new int[WolfConstants.UPDATEHIGH];
        public static int[] blockstarts = new int[WolfConstants.UPDATEWIDE * WolfConstants.UPDATEHIGH];
        public static byte fontcolor, backcolor;

        // WL_MAIN
        public static byte[] str = new byte[80];
        public static byte[] str2 = new byte[20];
        public static int tedlevelnum;
        public static bool tedlevel;
        public static bool nospr;
        public static bool IsA386;

        public static int focallength;  // fixed
        public static int viewangles;
        public static int screenofs;
        public static int viewwidth;
        public static int viewheight;
        public static int centerx;
        public static int shootdelta;

        public static int[] dirangle = new int[9];
        public static bool startgame, loadedgame, virtualreality;
        public static int mouseadjustment;

        // Math tables
        public static int[] pixelangle = new int[WolfConstants.MAXVIEWWIDTH];
        public static int[] finetangent = new int[WolfConstants.FINEANGLES / 4];
        public static int[] sintable = new int[WolfConstants.ANGLES + WolfConstants.ANGLES / 4 + 1];
        public static int[] costable; // points into sintable at offset ANGLES/4

        // Derived constants
        public static int scale, maxslope;
        public static int heightnumerator;
        public static int minheightdiv;

        public static string configname = "CONFIG.WL6";

        // WL_GAME
        public static bool ingame, fizzlein;
        public static int[] latchpics = new int[WolfConstants.NUMLATCHPICS];
        public static gametype gamestate = new gametype();
        public static int doornum;

        public static string demoname = "DEMO0.WL6";

        public static int spearx, speary;
        public static int spearangle;
        public static bool spearflag;

        // WL_PLAY
        public static exit_t playstate;
        public static bool madenoise;

        public static objtype[] objlist = new objtype[WolfConstants.MAXACTORS];
        public static objtype new_;   // C: "new"
        public static objtype obj;
        public static objtype player;
        public static objtype lastobj;
        public static objtype objfreelist;
        public static objtype killerobj;

        public static statobj_t[] statobjlist = new statobj_t[WolfConstants.MAXSTATS];
        public static statobj_t laststatobj;

        public static doorobj_t[] doorobjlist = new doorobj_t[WolfConstants.MAXDOORS];
        public static doorobj_t lastdoorobj;

        public static int[] farmapylookup = new int[WolfConstants.MAPSIZE];
        // nearmapylookup not needed in SDL3 port

        public static byte[,] tilemap = new byte[WolfConstants.MAPSIZE, WolfConstants.MAPSIZE];
        public static byte[,] spotvis = new byte[WolfConstants.MAPSIZE, WolfConstants.MAPSIZE];
        public static objtype[,] actorat = new objtype[WolfConstants.MAPSIZE, WolfConstants.MAPSIZE];
        // actorat can also hold tile values - we use a parallel int array
        public static int[,] actorat_tile = new int[WolfConstants.MAPSIZE, WolfConstants.MAPSIZE];

        public static byte[] update = new byte[WolfConstants.UPDATESIZE];

        public static bool singlestep, godmode, noclip;
        public static int extravbls;
        public static int DebugOk;

        // Control info
        public static bool mouseenabled, joystickenabled, joypadenabled, joystickprogressive;
        public static int joystickport;
        public static int[] dirscan = new int[4];
        public static int[] buttonscan = new int[WolfConstants.NUMBUTTONS];
        public static int[] buttonmouse = new int[4];
        public static int[] buttonjoy = new int[4];
        public static bool[] buttonheld = new bool[WolfConstants.NUMBUTTONS];
        public static int viewsize;

        // Current user input
        public static int controlx, controly;
        public static bool[] buttonstate = new bool[WolfConstants.NUMBUTTONS];

        public static bool demorecord, demoplayback;
        public static byte[] demobuffer;
        public static int demoptr_offset;

        // WL_DRAW
        public static int[] screenloc = new int[3];
        public static int freelatch;
        public static int lasttimecount;
        public static int frameon;

        public static int[] wallheight = new int[WolfConstants.MAXVIEWWIDTH];
        public static int tileglobal;
        public static int mindist;

        // Refresh variables
        public static int viewx, viewy;  // focal point (fixed)
        public static int viewangle;
        public static int viewsin, viewcos;

        public static byte[] postsource;
        public static int postsource_offset;
        public static int postx;
        public static int postwidth;

        public static int[] horizwall = new int[WolfConstants.MAXWALLTILES];
        public static int[] vertwall = new int[WolfConstants.MAXWALLTILES];

        public static int pwallpos;

        // WL_AGENT
        public static bool running;
        public static int thrustspeed;
        public static int plux, pluy;
        public static int anglefrac;
        public static int facecount;

        // WL_ACT1
        public static int[] doorposition = new int[WolfConstants.MAXDOORS];
        public static int pwallstate;
        public static int pwallx, pwally;
        public static int pwalldir;
        public static byte[,] areaconnect = new byte[WolfConstants.NUMAREAS, WolfConstants.NUMAREAS];
        public static bool[] areabyplayer = new bool[WolfConstants.NUMAREAS];

        // WL_SCALE
        public static t_compscale[] scaledirectory = new t_compscale[WolfConstants.MAXSCALEHEIGHT + 1];
        public static int maxscale, maxscaleshl2;
        public static bool insetupscaling;

        // ID_MM
        public static byte[] bufferseg;
        public static bool mmerror;

        // ID_CA
        public static string audioname = "AUDIO";
        public static byte[] tinf;
        public static int mapon;
        public static ushort[][] mapsegs = new ushort[WolfConstants.MAPPLANES][];
        public static maptype[] mapheaderseg_data = new maptype[WolfConstants.NUMMAPS];
        public static bool[] mapheaderseg_valid = new bool[WolfConstants.NUMMAPS];
        public static byte[][] audiosegs = new byte[AudioConstants.NUMSNDCHUNKS][];
        public static byte[][] grsegs = new byte[GfxConstants.NUMCHUNKS][];
        public static byte[] grneeded = new byte[GfxConstants.NUMCHUNKS];
        public static byte ca_levelbit, ca_levelnum;

        public static int[] grstarts;    // array of offsets in egagraph
        public static int[] audiostarts; // array of offsets in audio

        public static string extension = ".WL6";
        public static string gheadname = "VGAHEAD";
        public static string gfilename = "VGAGRAPH";
        public static string gdictname = "VGADICT";
        public static string mheadname = "MAPHEAD";
        public static string mfilename = "GAMEMAPS";
        public static string aheadname = "AUDIOHED";
        public static string afilename = "AUDIOT";

        // ID_VL globals
        public static IntPtr sdl_window = IntPtr.Zero;
        public static IntPtr sdl_renderer = IntPtr.Zero;
        public static IntPtr sdl_texture = IntPtr.Zero;
        public static byte[] sdl_screenbuf = new byte[320 * 200];
        public static byte[] sdl_palette = new byte[768];

        public static int bufferofs;
        public static int displayofs, pelpan;
        public static int screenseg = WolfConstants.SCREENSEG;
        public static int linewidth;
        public static int[] ylookup = new int[WolfConstants.MAXSCANLINES];
        public static bool screenfaded;
        public static int bordercolor;

        // ID_VH globals
        public static pictabletype[] pictable;
        public static int px, py;
        public static int fontnumber;
        public static int bufferwidth, bufferheight;

        // ID_IN globals
        public static bool[] Keyboard = new bool[WolfConstants.NumCodes];
        public static bool MousePresent;
        public static bool[] JoysPresent = new bool[WolfConstants.MaxJoys];
        public static bool Paused;
        public static char LastASCII;
        public static byte LastScan;
        public static KeyboardDef KbdDefs;
        public static JoystickDef[] JoyDefs = new JoystickDef[WolfConstants.MaxJoys];
        public static ControlType[] Controls = new ControlType[WolfConstants.MaxPlayers];
        public static Demo DemoMode;
        public static byte[] DemoBuffer;
        public static ushort DemoOffset, DemoSize;

        // ID_SD globals
        public static bool AdLibPresent;
        public static bool SoundSourcePresent;
        public static bool SoundBlasterPresent;
        public static bool NeedsMusic;
        public static bool SoundPositioned;
        public static SDMode SoundMode;
        public static SDSMode DigiMode;
        public static SMMode MusicMode;
        public static bool DigiPlaying;
        public static int[] DigiMap = new int[AudioConstants.NUMSOUNDS];
        public static int TimeCount;    // Global time in ticks

        // ID_US globals
        public static bool abortgame;
        public static string abortprogram;
        public static bool NoWait;
        public static bool HighScoresDirty;
        public static GameDiff restartgame;
        public static ushort PrintX, PrintY;
        public static ushort WindowX, WindowY, WindowW, WindowH;
        public static bool Button0, Button1, CursorBad;
        public static int CursorX, CursorY;
        public static HighScore[] Scores = new HighScore[WolfConstants.MaxScores];
        public static SaveGame[] Games = new SaveGame[WolfConstants.MaxSaveGames];

        // ID_PM globals
        public static bool XMSPresent, EMSPresent;
        public static ushort XMSPagesAvail, EMSPagesAvail;
        public static ushort ChunksInFile, PMSpriteStart, PMSoundStart;
        public static PageListStruct[] PMPages;
        public static string PageFileName = "VSWAP";
        public static byte[][] PMPageData;  // actual page data

        // Frame capture
        public static int capture_enabled;
        public static int capture_frame;
        public static int capture_limit;
        public static ulong quit_after_ms;
        public static ulong quit_after_start;
        public static int test_sequence_enabled;

        // WL_TEXT
        public static string helpfilename = "HELPART";
        public static string endfilename = "ENDART1";

        // Latch memory (from ID_VL.C)
        public const int LATCH_MEM_SIZE = (256 * 1024);
        public static byte[] latchmem = new byte[LATCH_MEM_SIZE];

        // Initialize arrays that need it
        static WL_Globals()
        {
            for (int i = 0; i < WolfConstants.MAXACTORS; i++)
                objlist[i] = new objtype();
            for (int i = 0; i < WolfConstants.MAXSTATS; i++)
                statobjlist[i] = new statobj_t();
            for (int i = 0; i < WolfConstants.MAXDOORS; i++)
                doorobjlist[i] = new doorobj_t();
            for (int i = 0; i < WolfConstants.MaxScores; i++)
                Scores[i] = new HighScore();
            for (int i = 0; i < WolfConstants.MaxSaveGames; i++)
                Games[i] = new SaveGame();

            // costable points into sintable at ANGLES/4
            // Will be initialized properly in BuildTables
        }
    }

    // =========================================================================
    //  Helper macros translated to methods
    // =========================================================================

    public static class WolfMacros
    {
        public static int MAPSPOT(int x, int y, int plane)
        {
            return WL_Globals.mapsegs[plane][WL_Globals.farmapylookup[y] + x];
        }

        public static void MAPSPOT_SET(int x, int y, int plane, ushort val)
        {
            WL_Globals.mapsegs[plane][WL_Globals.farmapylookup[y] + x] = val;
        }

        public static int SIGN(int x) { return x > 0 ? 1 : -1; }
        public static int ABS(int x) { return x > 0 ? x : -x; }

        public static void SETFONTCOLOR(byte f, byte b)
        {
            WL_Globals.fontcolor = f;
            WL_Globals.backcolor = b;
        }

        public static bool IN_KeyDown(byte code) { return WL_Globals.Keyboard[code]; }

        public static void IN_ClearKey(byte code)
        {
            WL_Globals.Keyboard[code] = false;
            if (code == WL_Globals.LastScan)
                WL_Globals.LastScan = ScanCodes.sc_None;
        }

        public static void CA_MarkGrChunk(int chunk)
        {
            WL_Globals.grneeded[chunk] |= WL_Globals.ca_levelbit;
        }

        public static void UNCACHEGRCHUNK(int chunk)
        {
            WL_Globals.grsegs[chunk] = null;
            WL_Globals.grneeded[chunk] &= (byte)~WL_Globals.ca_levelbit;
        }
    }
}
