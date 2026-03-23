// WL_MAIN.C -> WlMain.cs
// Main entry point and initialization for Wolfenstein 3D

using System;
using System.IO;
using System.Runtime.InteropServices;

namespace Wolf3D
{
    public static class WlMain
    {
        // Original global _argc/_argv
        private static int saved_argc;
        private static string[] saved_argv;

        // =========================================================================
        //  Quit
        // =========================================================================

        public static void Quit(string error)
        {
            if (!string.IsNullOrEmpty(error))
            {
                Console.Error.WriteLine(error);
            }

            ShutdownId();
            Environment.Exit(string.IsNullOrEmpty(error) ? 0 : 1);
        }

        // =========================================================================
        //  ShutdownId
        // =========================================================================

        public static void ShutdownId()
        {
            IdSd.SD_Shutdown();
            IdIn.IN_Shutdown();
            IdVl.VL_Shutdown();
            IdCa.CA_Shutdown();
            IdPm.PM_Shutdown();
            IdMm.MM_Shutdown();
        }

        // =========================================================================
        //  InitGame
        // =========================================================================

        public static void InitGame()
        {
            // Set extension based on version
            WL_Globals.extension = ".WL6";

            // Start subsystems
            IdMm.MM_Startup();

            // Check for game data files
            SignonScreen();

            IdVl.VL_Startup();
            IdVl.VL_SetVGAPlaneMode();
            IdVl.VL_TestPaletteSet();
            IdVh.VH_SetDefaultColors();

            IdSd.SD_Startup();
            IdIn.IN_Startup();
            IdUs.US_Startup();

            // Set default controls
            WL_Globals.dirscan[0] = ScanCodes.sc_UpArrow;
            WL_Globals.dirscan[1] = ScanCodes.sc_RightArrow;
            WL_Globals.dirscan[2] = ScanCodes.sc_DownArrow;
            WL_Globals.dirscan[3] = ScanCodes.sc_LeftArrow;

            WL_Globals.buttonscan[0] = ScanCodes.sc_Control;
            WL_Globals.buttonscan[1] = ScanCodes.sc_Alt;
            WL_Globals.buttonscan[2] = ScanCodes.sc_RShift;
            WL_Globals.buttonscan[3] = ScanCodes.sc_Space;

            WL_Globals.buttonmouse[0] = WolfConstants.bt_attack;
            WL_Globals.buttonmouse[1] = WolfConstants.bt_strafe;
            WL_Globals.buttonmouse[2] = WolfConstants.bt_use;
            WL_Globals.buttonmouse[3] = WolfConstants.bt_nobutton;

            WL_Globals.viewsize = 15;

            WL_Globals.mouseadjustment = 5;
            WL_Globals.mouseenabled = true;

            // Load configuration
            ReadConfig();

            // Cache system
            IdCa.CA_Startup();
            IdPm.PM_Startup();

            // Set up graphics
            SetViewSize(WL_Globals.viewsize * 16, (int)(WL_Globals.viewsize * 16 * WolfConstants.HEIGHTRATIO));

            IdVh.LoadLatchMem();
        }

        // =========================================================================
        //  Signon screen
        // =========================================================================

        private static void SignonScreen()
        {
            // In the original, this displays the startup signon bitmap
            // For SDL3, we just clear the screen
        }

        // =========================================================================
        //  Config file
        // =========================================================================

        private static void ReadConfig()
        {
            // Try to read CONFIG.WL6 - use defaults if not found
            WL_Globals.SoundMode = SDMode.sdm_AdLib;
            WL_Globals.MusicMode = SMMode.smm_AdLib;
            WL_Globals.DigiMode = SDSMode.sds_SoundBlaster;
            WL_Globals.mouseenabled = true;
            WL_Globals.joystickenabled = false;
            WL_Globals.viewsize = 15;
            WL_Globals.mouseadjustment = 5;
        }

        private static void WriteConfig()
        {
            // Save configuration - stub
        }

        // =========================================================================
        //  View size calculation
        // =========================================================================

        public static bool SetViewSize(int width, int height)
        {
            WL_Globals.viewwidth = width;
            WL_Globals.viewheight = height;
            WL_Globals.centerx = width / 2 - 1;
            WL_Globals.shootdelta = width / 10;

            WL_Globals.screenofs = WolfConstants.PAGE1START + (200 - WolfConstants.STATUSLINES - height) / 2 *
                                   WL_Globals.linewidth + (320 - width) / 8;

            CalcProjection(0x5700);

            return true;
        }

        public static void NewViewSize(int width)
        {
            WL_Globals.viewsize = width;
            SetViewSize(width * 16, (int)(width * 16 * WolfConstants.HEIGHTRATIO));
        }

        public static void ShowViewSize(int width)
        {
            int viewwidth = width * 16;
            int viewheight = (int)(width * 16 * WolfConstants.HEIGHTRATIO);
            int x = (320 - viewwidth) / 2;
            int y = (200 - WolfConstants.STATUSLINES - viewheight) / 2;

            IdVl.VL_Bar(x, y, viewwidth, viewheight, WolfConstants.BORDERCOLOR);
        }

        // =========================================================================
        //  Projection tables
        // =========================================================================

        public static void CalcProjection(int focal)
        {
            WL_Globals.focallength = focal;

            WL_Globals.scale = WL_Globals.viewwidth / 2;
            WL_Globals.heightnumerator = (WolfConstants.TILEGLOBAL * WL_Globals.scale) >> 6;

            WL_Globals.mindist = WL_Globals.scale * 2;
            WL_Globals.minheightdiv = WL_Globals.viewwidth < 1 ? 1 : WL_Globals.viewwidth;

            // Build pixel angle table
            for (int i = 0; i < WL_Globals.viewwidth; i++)
            {
                double tang = (double)(i - WL_Globals.viewwidth / 2 + 0.5) / (double)focal;
                double angle = Math.Atan(tang);
                int intang = (int)(angle * WolfConstants.FINEANGLES / (2 * Math.PI));
                WL_Globals.pixelangle[i] = intang;
            }

            // Build fine tangent table
            for (int i = 0; i < WolfConstants.FINEANGLES / 4; i++)
            {
                double tang = Math.Tan((i + 0.5) / WolfConstants.FINEANGLES * 2 * Math.PI);
                WL_Globals.finetangent[i] = (int)(tang * WolfConstants.TILEGLOBAL);
            }
        }

        // =========================================================================
        //  NewGame
        // =========================================================================

        public static void NewGame(int difficulty, int episode)
        {
            WL_Globals.gamestate = new gametype();
            WL_Globals.gamestate.difficulty = difficulty;
            WL_Globals.gamestate.weapon = weapontype.wp_pistol;
            WL_Globals.gamestate.bestweapon = weapontype.wp_pistol;
            WL_Globals.gamestate.chosenweapon = weapontype.wp_pistol;
            WL_Globals.gamestate.health = 100;
            WL_Globals.gamestate.ammo = WolfConstants.STARTAMMO;
            WL_Globals.gamestate.lives = 3;
            WL_Globals.gamestate.nextextra = WolfConstants.EXTRAPOINTS;
            WL_Globals.gamestate.episode = episode;
            WL_Globals.gamestate.mapon = episode * 10;

            WL_Globals.startgame = true;
        }

        // =========================================================================
        //  MS_CheckParm
        // =========================================================================

        public static bool MS_CheckParm(string parm)
        {
            for (int i = 1; i < WL_Globals._argc; i++)
            {
                if (WL_Globals._argv[i].Equals(parm, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }

        // =========================================================================
        //  BuildTables - initialize sine/cosine tables
        // =========================================================================

        public static void BuildTables()
        {
            // Build sine table (ANGLES + ANGLES/4 + 1 entries)
            for (int i = 0; i <= WolfConstants.ANGLES + WolfConstants.ANGLES / 4; i++)
            {
                double angle = (double)i / WolfConstants.ANGLES * 2 * Math.PI;
                WL_Globals.sintable[i] = (int)(Math.Sin(angle) * WolfConstants.GLOBAL1);
            }

            // costable points into sintable at offset ANGLES/4
            // In C# we can't alias arrays, so we use a helper
            WL_Globals.costable = new int[WolfConstants.ANGLES + 1];
            for (int i = 0; i <= WolfConstants.ANGLES; i++)
                WL_Globals.costable[i] = WL_Globals.sintable[i + WolfConstants.ANGLEQUAD];
        }

        // =========================================================================
        //  Save / Load game stubs
        // =========================================================================

        public static bool LoadTheGame(FileStream file, int x, int y)
        {
            // Load game state from file - stub
            return false;
        }

        public static bool SaveTheGame(FileStream file, int x, int y)
        {
            // Save game state to file - stub
            return false;
        }

        // =========================================================================
        //  DemoLoop - Main game loop before gameplay starts
        // =========================================================================

        public static void DemoLoop()
        {
            // Main demo/title loop
            while (true)
            {
                // Title page
                IdCa.CA_CacheScreen(96);  // Corrected: actual fullscreen chunk in data files (TITLEPIC enum=87 doesn't match)
                // Load game palette
                if (WL_Globals.grsegs[GfxConstants.STARTPICS] != null)
                {
                    // gamepal would be loaded from the palette chunk
                }

                IdVl.VL_UpdateScreen();
                IdVl.VL_FadeIn(0, 255, WL_Globals.sdl_palette, 30);

                if (IdIn.IN_UserInput(WolfConstants.TickBase * 15))
                {
                }

                // Go to menu
                WlMenu.US_ControlPanel(0);

                if (WL_Globals.startgame || WL_Globals.loadedgame)
                {
                    WlGame.GameLoop();
                    // After game, continue demo loop
                    WL_Globals.startgame = false;
                    WL_Globals.loadedgame = false;
                }
            }
        }

        // =========================================================================
        //  Entry point
        // =========================================================================

        public static void Main(string[] args)
        {
            WL_Globals._argc = args.Length + 1;
            WL_Globals._argv = new string[args.Length + 1];
            WL_Globals._argv[0] = "wolf3d";
            for (int i = 0; i < args.Length; i++)
                WL_Globals._argv[i + 1] = args[i];

            Console.WriteLine("Wolfenstein 3-D C# SDL3 Port");
            Console.WriteLine("============================");

            // Parse command line
            for (int i = 1; i < WL_Globals._argc; i++)
            {
                string arg = WL_Globals._argv[i];
                if (arg == "--quit-after" && i + 1 < WL_Globals._argc)
                {
                    WL_Globals.quit_after_ms = ulong.Parse(WL_Globals._argv[++i]);
                }
                else if (arg == "--capture")
                {
                    WL_Globals.capture_enabled = 1;
                }
            }

            BuildTables();
            InitGame();

            DemoLoop();

            Quit(null);
        }

        // =========================================================================
        //  HelpScreens / OrderingInfo / TEDDeath stubs
        // =========================================================================

        public static void HelpScreens() { }
        public static void OrderingInfo() { }
        public static void TEDDeath() { }
    }
}
