-- audiowl6.lua
-- Audio header for .WL6 (ported from AUDIOWL6.H)

local audio = {}

audio.NUMSOUNDS    = 87
audio.NUMSNDCHUNKS = 288

-- Sound names & indexes
audio.HITWALLSND         = 0
audio.SELECTWPNSND       = 1
audio.SELECTITEMSND      = 2
audio.HEARTBEATSND       = 3
audio.MOVEGUN2SND        = 4
audio.MOVEGUN1SND        = 5
audio.NOWAYSND           = 6
audio.NAZIHITPLAYERSND   = 7
audio.SCHABBSTHROWSND    = 8
audio.PLAYERDEATHSND     = 9
audio.DOGDEATHSND        = 10
audio.ATKGATLINGSND      = 11
audio.GETKEYSND          = 12
audio.NOITEMSND          = 13
audio.WALK1SND           = 14
audio.WALK2SND           = 15
audio.TAKEDAMAGESND      = 16
audio.GAMEOVERSND        = 17
audio.OPENDOORSND        = 18
audio.CLOSEDOORSND       = 19
audio.DONOTHINGSND       = 20
audio.HALTSND            = 21
audio.DEATHSCREAM2SND    = 22
audio.ATKKNIFESND        = 23
audio.ATKPISTOLSND       = 24
audio.DEATHSCREAM3SND    = 25
audio.ATKMACHINEGUNSND   = 26
audio.HITENEMYSND        = 27
audio.SHOOTDOORSND       = 28
audio.DEATHSCREAM1SND    = 29
audio.GETMACHINESND      = 30
audio.GETAMMOSND         = 31
audio.SHOOTSND           = 32
audio.HEALTH1SND         = 33
audio.HEALTH2SND         = 34
audio.BONUS1SND          = 35
audio.BONUS2SND          = 36
audio.BONUS3SND          = 37
audio.GETGATLINGSND      = 38
audio.ESCPRESSEDSND      = 39
audio.LEVELDONESND       = 40
audio.DOGBARKSND         = 41
audio.ENDBONUS1SND       = 42
audio.ENDBONUS2SND       = 43
audio.BONUS1UPSND        = 44
audio.BONUS4SND          = 45
audio.PUSHWALLSND        = 46
audio.NOBONUSSND         = 47
audio.PERCENT100SND      = 48
audio.BOSSACTIVESND      = 49
audio.MUTTISND           = 50
audio.SCHUTZADSND        = 51
audio.AHHHGSND           = 52
audio.DIESND             = 53
audio.EVASND             = 54
audio.GUTENTAGSND        = 55
audio.LEBENSND           = 56
audio.SCHEISTSND         = 57
audio.NAZIFIRESND        = 58
audio.BOSSFIRESND        = 59
audio.SSFIRESND          = 60
audio.SLURPIESND         = 61
audio.TOT_HUNDSND        = 62
audio.MEINGOTTSND        = 63
audio.SCHABBSHASND       = 64
audio.HITLERHASND        = 65
audio.SPIONSND           = 66
audio.NEINSOVASSND       = 67
audio.DOGATTACKSND       = 68
audio.FLAMETHROWERSND    = 69
audio.MECHSTEPSND        = 70
audio.GOOBSSND           = 71
audio.YEAHSND            = 72
audio.DEATHSCREAM4SND    = 73
audio.DEATHSCREAM5SND    = 74
audio.DEATHSCREAM6SND    = 75
audio.DEATHSCREAM7SND    = 76
audio.DEATHSCREAM8SND    = 77
audio.DEATHSCREAM9SND    = 78
audio.DONNERSND          = 79
audio.EINESND            = 80
audio.ERLAUBENSND        = 81
audio.KEINSND            = 82
audio.MEINSND            = 83
audio.ROSESND            = 84
audio.MISSILEFIRESND     = 85
audio.MISSILEHITSND      = 86
audio.LASTSOUND          = 87

-- Base offsets
audio.STARTPCSOUNDS     = 0
audio.STARTADLIBSOUNDS  = 87
audio.STARTDIGISOUNDS   = 174
audio.STARTMUSIC        = 261

-- Music names & indexes
audio.CORNER_MUS    = 0
audio.DUNGEON_MUS   = 1
audio.WARMARCH_MUS  = 2
audio.GETTHEM_MUS   = 3
audio.HEADACHE_MUS  = 4
audio.HITLWLTZ_MUS  = 5
audio.INTROCW3_MUS  = 6
audio.NAZI_NOR_MUS  = 7
audio.NAZI_OMI_MUS  = 8
audio.POW_MUS       = 9
audio.SALUTE_MUS    = 10
audio.SEARCHN_MUS   = 11
audio.SUSPENSE_MUS  = 12
audio.VICTORS_MUS   = 13
audio.WONDERIN_MUS  = 14
audio.FUNKYOU_MUS   = 15
audio.ENDLEVEL_MUS  = 16
audio.GOINGAFT_MUS  = 17
audio.PREGNANT_MUS  = 18
audio.ULTIMATE_MUS  = 19
audio.NAZI_RAP_MUS  = 20
audio.ZEROHOUR_MUS  = 21
audio.TWELFTH_MUS   = 22
audio.ROSTER_MUS    = 23
audio.URAHERO_MUS   = 24
audio.VICMARCH_MUS  = 25
audio.PACMAN_MUS    = 26
audio.LASTMUSIC     = 27

-- INTROSONG alias used by DemoLoop
audio.INTROSONG = audio.INTROCW3_MUS

return audio
