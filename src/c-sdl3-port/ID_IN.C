//
//	ID Engine
//	ID_IN.c - Input Manager
//	v1.0d1
//	By Jason Blochowiak
//	Ported to SDL3
//

//
//	This module handles dealing with the various input devices
//
//	Depends on: Memory Mgr (for demo recording), Sound Mgr (for timing stuff),
//				User Mgr (for command line parms)
//
//	Globals:
//		LastScan - The keyboard scan code of the last key pressed
//		LastASCII - The ASCII value of the last key pressed
//	DEBUG - there are more globals
//

#include "ID_HEADS.H"
#pragma	hdrstop

//
// joystick constants
//
#define	JoyScaleMax		32768
#define	JoyScaleShift	8
#define	MaxJoyValue		5000

/*
=============================================================================

					GLOBAL VARIABLES

=============================================================================
*/

//
// configuration variables
//
boolean			MousePresent;
boolean			JoysPresent[MaxJoys];
boolean			JoyPadPresent;


// 	Global variables
		boolean		Keyboard[NumCodes];
		boolean		Paused;
		char		LastASCII;
		ScanCode	LastScan;

		KeyboardDef	KbdDefs = {0x1d,0x38,0x47,0x48,0x49,0x4b,0x4d,0x4f,0x50,0x51};
		JoystickDef	JoyDefs[MaxJoys];
		ControlType	Controls[MaxPlayers];

		longword	MouseDownCount;

		Demo		DemoMode = demo_Off;
		byte		*DemoBuffer;
		word		DemoOffset,DemoSize;

/*
=============================================================================

					LOCAL VARIABLES

=============================================================================
*/
static	byte        ASCIINames[] =		// Unshifted ASCII for scan codes
					{
//	 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	0  ,27 ,'1','2','3','4','5','6','7','8','9','0','-','=',8  ,9  ,	// 0
	'q','w','e','r','t','y','u','i','o','p','[',']',13 ,0  ,'a','s',	// 1
	'd','f','g','h','j','k','l',';',39 ,'`',0  ,92 ,'z','x','c','v',	// 2
	'b','n','m',',','.','/',0  ,'*',0  ,' ',0  ,0  ,0  ,0  ,0  ,0  ,	// 3
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,'7','8','9','-','4','5','6','+','1',	// 4
	'2','3','0',127,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 5
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 6
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0		// 7
					},
					ShiftNames[] =		// Shifted ASCII for scan codes
					{
//	 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	0  ,27 ,'!','@','#','$','%','^','&','*','(',')','_','+',8  ,9  ,	// 0
	'Q','W','E','R','T','Y','U','I','O','P','{','}',13 ,0  ,'A','S',	// 1
	'D','F','G','H','J','K','L',':',34 ,'~',0  ,'|','Z','X','C','V',	// 2
	'B','N','M','<','>','?',0  ,'*',0  ,' ',0  ,0  ,0  ,0  ,0  ,0  ,	// 3
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,'7','8','9','-','4','5','6','+','1',	// 4
	'2','3','0',127,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 5
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 6
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0   	// 7
					},
					SpecialNames[] =	// ASCII for 0xe0 prefixed codes
					{
//	 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 0
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,13 ,0  ,0  ,0  ,	// 1
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 2
	0  ,0  ,0  ,0  ,0  ,'/',0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 3
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 4
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 5
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,	// 6
	0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0   	// 7
					};


static	boolean		IN_Started;
static	boolean		CapsLock;
static	ScanCode	CurCode,LastCode;

static	Direction	DirTable[] =		// Quick lookup for total direction
					{
						dir_NorthWest,	dir_North,	dir_NorthEast,
						dir_West,		dir_None,	dir_East,
						dir_SouthWest,	dir_South,	dir_SouthEast
					};

static	void			(*INL_KeyHook)(void);

static	char			*ParmStrings[] = {"nojoys","nomouse",nil};

//
// SDL3 joystick handles
//
static	SDL_Joystick	*sdl_joysticks[MaxJoys];

///////////////////////////////////////////////////////////////////////////
//
//	INL_SDLScanCodeToScanCode() - Maps an SDL scancode to the game's
//		internal scan code values (which match the original DOS scan codes)
//
///////////////////////////////////////////////////////////////////////////
static ScanCode
INL_SDLScanCodeToScanCode(SDL_Scancode sdl_sc)
{
	switch (sdl_sc)
	{
	case SDL_SCANCODE_ESCAPE:		return sc_Escape;
	case SDL_SCANCODE_1:			return sc_1;
	case SDL_SCANCODE_2:			return sc_2;
	case SDL_SCANCODE_3:			return sc_3;
	case SDL_SCANCODE_4:			return sc_4;
	case SDL_SCANCODE_5:			return sc_5;
	case SDL_SCANCODE_6:			return sc_6;
	case SDL_SCANCODE_7:			return sc_7;
	case SDL_SCANCODE_8:			return sc_8;
	case SDL_SCANCODE_9:			return sc_9;
	case SDL_SCANCODE_0:			return sc_0;
	case SDL_SCANCODE_MINUS:		return 0x0c;
	case SDL_SCANCODE_EQUALS:		return 0x0d;
	case SDL_SCANCODE_BACKSPACE:	return sc_BackSpace;
	case SDL_SCANCODE_TAB:			return sc_Tab;
	case SDL_SCANCODE_Q:			return sc_Q;
	case SDL_SCANCODE_W:			return sc_W;
	case SDL_SCANCODE_E:			return sc_E;
	case SDL_SCANCODE_R:			return sc_R;
	case SDL_SCANCODE_T:			return sc_T;
	case SDL_SCANCODE_Y:			return sc_Y;
	case SDL_SCANCODE_U:			return sc_U;
	case SDL_SCANCODE_I:			return sc_I;
	case SDL_SCANCODE_O:			return sc_O;
	case SDL_SCANCODE_P:			return sc_P;
	case SDL_SCANCODE_LEFTBRACKET:	return 0x1a;
	case SDL_SCANCODE_RIGHTBRACKET:	return 0x1b;
	case SDL_SCANCODE_RETURN:		return sc_Return;
	case SDL_SCANCODE_LCTRL:		return sc_Control;
	case SDL_SCANCODE_RCTRL:		return sc_Control;
	case SDL_SCANCODE_A:			return sc_A;
	case SDL_SCANCODE_S:			return sc_S;
	case SDL_SCANCODE_D:			return sc_D;
	case SDL_SCANCODE_F:			return sc_F;
	case SDL_SCANCODE_G:			return sc_G;
	case SDL_SCANCODE_H:			return sc_H;
	case SDL_SCANCODE_J:			return sc_J;
	case SDL_SCANCODE_K:			return sc_K;
	case SDL_SCANCODE_L:			return sc_L;
	case SDL_SCANCODE_SEMICOLON:	return 0x27;
	case SDL_SCANCODE_APOSTROPHE:	return 0x28;
	case SDL_SCANCODE_GRAVE:		return 0x29;
	case SDL_SCANCODE_LSHIFT:		return sc_LShift;
	case SDL_SCANCODE_BACKSLASH:	return 0x2b;
	case SDL_SCANCODE_Z:			return sc_Z;
	case SDL_SCANCODE_X:			return sc_X;
	case SDL_SCANCODE_C:			return sc_C;
	case SDL_SCANCODE_V:			return sc_V;
	case SDL_SCANCODE_B:			return sc_B;
	case SDL_SCANCODE_N:			return sc_N;
	case SDL_SCANCODE_M:			return sc_M;
	case SDL_SCANCODE_COMMA:		return 0x33;
	case SDL_SCANCODE_PERIOD:		return 0x34;
	case SDL_SCANCODE_SLASH:		return 0x35;
	case SDL_SCANCODE_RSHIFT:		return sc_RShift;
	case SDL_SCANCODE_KP_MULTIPLY:	return 0x37;
	case SDL_SCANCODE_LALT:			return sc_Alt;
	case SDL_SCANCODE_RALT:			return sc_Alt;
	case SDL_SCANCODE_SPACE:		return sc_Space;
	case SDL_SCANCODE_CAPSLOCK:		return sc_CapsLock;
	case SDL_SCANCODE_F1:			return sc_F1;
	case SDL_SCANCODE_F2:			return sc_F2;
	case SDL_SCANCODE_F3:			return sc_F3;
	case SDL_SCANCODE_F4:			return sc_F4;
	case SDL_SCANCODE_F5:			return sc_F5;
	case SDL_SCANCODE_F6:			return sc_F6;
	case SDL_SCANCODE_F7:			return sc_F7;
	case SDL_SCANCODE_F8:			return sc_F8;
	case SDL_SCANCODE_F9:			return sc_F9;
	case SDL_SCANCODE_F10:			return sc_F10;
	case SDL_SCANCODE_NUMLOCKCLEAR:	return 0x45;
	case SDL_SCANCODE_SCROLLLOCK:	return 0x46;
	case SDL_SCANCODE_KP_7:			return sc_Home;
	case SDL_SCANCODE_KP_8:			return sc_UpArrow;
	case SDL_SCANCODE_KP_9:			return sc_PgUp;
	case SDL_SCANCODE_KP_MINUS:		return 0x4a;
	case SDL_SCANCODE_KP_4:			return sc_LeftArrow;
	case SDL_SCANCODE_KP_5:			return 0x4c;
	case SDL_SCANCODE_KP_6:			return sc_RightArrow;
	case SDL_SCANCODE_KP_PLUS:		return 0x4e;
	case SDL_SCANCODE_KP_1:			return sc_End;
	case SDL_SCANCODE_KP_2:			return sc_DownArrow;
	case SDL_SCANCODE_KP_3:			return sc_PgDn;
	case SDL_SCANCODE_KP_0:			return sc_Insert;
	case SDL_SCANCODE_KP_PERIOD:	return sc_Delete;
	case SDL_SCANCODE_F11:			return sc_F11;
	case SDL_SCANCODE_F12:			return sc_F12;
	case SDL_SCANCODE_KP_ENTER:		return sc_Return;
	case SDL_SCANCODE_HOME:			return sc_Home;
	case SDL_SCANCODE_UP:			return sc_UpArrow;
	case SDL_SCANCODE_PAGEUP:		return sc_PgUp;
	case SDL_SCANCODE_LEFT:			return sc_LeftArrow;
	case SDL_SCANCODE_RIGHT:		return sc_RightArrow;
	case SDL_SCANCODE_END:			return sc_End;
	case SDL_SCANCODE_DOWN:			return sc_DownArrow;
	case SDL_SCANCODE_PAGEDOWN:		return sc_PgDn;
	case SDL_SCANCODE_INSERT:		return sc_Insert;
	case SDL_SCANCODE_DELETE:		return sc_Delete;
	case SDL_SCANCODE_PAUSE:		return 0;	// handled specially
	default:						return sc_None;
	}
}

//	Internal routines

///////////////////////////////////////////////////////////////////////////
//
//	IN_ProcessEvents() - Polls SDL events and updates keyboard/mouse state
//		This replaces the old INL_KeyService ISR
//
///////////////////////////////////////////////////////////////////////////
// Defined in ID_VL.C
void VL_CheckTestSequence(void);

void
IN_ProcessEvents(void)
{
	SDL_Event	event;
	ScanCode	k;
	byte		c;

	// Inject test sequence events (time-based) before polling
	VL_CheckTestSequence();

	while (SDL_PollEvent(&event))
	{
		switch (event.type)
		{
		case SDL_EVENT_KEY_DOWN:
			if (event.key.repeat)
				break;

			k = INL_SDLScanCodeToScanCode(event.key.scancode);

			if (event.key.scancode == SDL_SCANCODE_PAUSE)
			{
				Paused = true;
				break;
			}

			if (k != sc_None && k < NumCodes)
			{
				LastCode = CurCode;
				CurCode = LastScan = k;
				Keyboard[k] = true;

				if (k == sc_CapsLock)
				{
					CapsLock ^= true;
				}

				if (Keyboard[sc_LShift] || Keyboard[sc_RShift])	// If shifted
				{
					c = ShiftNames[k];
					if ((c >= 'A') && (c <= 'Z') && CapsLock)
						c += 'a' - 'A';
				}
				else
				{
					c = ASCIINames[k];
					if ((c >= 'a') && (c <= 'z') && CapsLock)
						c -= 'a' - 'A';
				}
				if (c)
					LastASCII = c;
			}

			if (INL_KeyHook)
				INL_KeyHook();
			break;

		case SDL_EVENT_KEY_UP:
			k = INL_SDLScanCodeToScanCode(event.key.scancode);
			if (k != sc_None && k < NumCodes)
			{
				Keyboard[k] = false;
			}

			if (INL_KeyHook)
				INL_KeyHook();
			break;

		case SDL_EVENT_QUIT:
			Quit(NULL);
			break;
		}
	}

	// Advance TimeCount from real time if the audio callback isn't doing it.
	// This prevents hangs in any wait loop that polls via IN_ProcessEvents.
	SD_TimeCountUpdate();
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_WaitAndProcessEvents() - Waits for an event, then processes all
//		pending events. Used by wait loops to avoid busy-spinning.
//
///////////////////////////////////////////////////////////////////////////
void
IN_WaitAndProcessEvents(void)
{
	SDL_Event	event;

	// Wait up to 1ms for an event so we don't hog the CPU
	if (SDL_WaitEventTimeout(&event, 1))
	{
		// Push the event back so IN_ProcessEvents handles it
		SDL_PushEvent(&event);
	}
	IN_ProcessEvents();
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_GetMouseDelta() - Gets the amount that the mouse has moved from the
//		mouse driver
//
///////////////////////////////////////////////////////////////////////////
static void
INL_GetMouseDelta(int *x,int *y)
{
	float fx, fy;
	SDL_GetRelativeMouseState(&fx, &fy);
	*x = (int)fx;
	*y = (int)fy;
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_GetMouseButtons() - Gets the status of the mouse buttons from the
//		mouse driver
//
///////////////////////////////////////////////////////////////////////////
static word
INL_GetMouseButtons(void)
{
	word	buttons = 0;
	SDL_MouseButtonFlags state;

	state = SDL_GetMouseState(NULL, NULL);
	if (state & SDL_BUTTON_LMASK)
		buttons |= 1;
	if (state & SDL_BUTTON_RMASK)
		buttons |= 2;
	if (state & SDL_BUTTON_MMASK)
		buttons |= 4;
	return(buttons);
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_GetJoyAbs() - Reads the absolute position of the specified joystick
//
///////////////////////////////////////////////////////////////////////////
void
IN_GetJoyAbs(word joy,word *xp,word *yp)
{
	*xp = 0;
	*yp = 0;

	if (joy >= MaxJoys || !sdl_joysticks[joy])
		return;

	// SDL joystick axes return -32768..32767, scale to 0..MaxJoyValue
	int raw_x = SDL_GetJoystickAxis(sdl_joysticks[joy], 0);
	int raw_y = SDL_GetJoystickAxis(sdl_joysticks[joy], 1);

	*xp = (word)((raw_x + 32768L) * (long)MaxJoyValue / 65535);
	*yp = (word)((raw_y + 32768L) * (long)MaxJoyValue / 65535);
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_GetJoyDelta() - Returns the relative movement of the specified
//		joystick (from +/-127)
//
///////////////////////////////////////////////////////////////////////////
void INL_GetJoyDelta(word joy,int *dx,int *dy)
{
	word		x,y;
	longword	time;
	JoystickDef	*def;
static	longword	lasttime;

	IN_GetJoyAbs(joy,&x,&y);
	def = JoyDefs + joy;

	if (x < def->threshMinX)
	{
		if (x < def->joyMinX)
			x = def->joyMinX;

		x = -(x - def->threshMinX);
		x *= def->joyMultXL;
		x >>= JoyScaleShift;
		*dx = (x > 127)? -127 : -x;
	}
	else if (x > def->threshMaxX)
	{
		if (x > def->joyMaxX)
			x = def->joyMaxX;

		x = x - def->threshMaxX;
		x *= def->joyMultXH;
		x >>= JoyScaleShift;
		*dx = (x > 127)? 127 : x;
	}
	else
		*dx = 0;

	if (y < def->threshMinY)
	{
		if (y < def->joyMinY)
			y = def->joyMinY;

		y = -(y - def->threshMinY);
		y *= def->joyMultYL;
		y >>= JoyScaleShift;
		*dy = (y > 127)? -127 : -y;
	}
	else if (y > def->threshMaxY)
	{
		if (y > def->joyMaxY)
			y = def->joyMaxY;

		y = y - def->threshMaxY;
		y *= def->joyMultYH;
		y >>= JoyScaleShift;
		*dy = (y > 127)? 127 : y;
	}
	else
		*dy = 0;

	lasttime = TimeCount;
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_GetJoyButtons() - Returns the button status of the specified
//		joystick
//
///////////////////////////////////////////////////////////////////////////
static word
INL_GetJoyButtons(word joy)
{
	word	result = 0;

	if (joy >= MaxJoys || !sdl_joysticks[joy])
		return 0;

	if (SDL_GetJoystickButton(sdl_joysticks[joy], 0))
		result |= 1;
	if (SDL_GetJoystickButton(sdl_joysticks[joy], 1))
		result |= 2;
	return(result);
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_GetJoyButtonsDB() - Returns the de-bounced button status of the
//		specified joystick
//
///////////////////////////////////////////////////////////////////////////
word
IN_GetJoyButtonsDB(word joy)
{
	longword	lasttime;
	word		result1,result2;

	do
	{
		result1 = INL_GetJoyButtons(joy);
		lasttime = TimeCount;
		while (TimeCount == lasttime)
			IN_ProcessEvents();
		result2 = INL_GetJoyButtons(joy);
	} while (result1 != result2);
	return(result1);
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_StartKbd() - Sets up my keyboard stuff for use
//
///////////////////////////////////////////////////////////////////////////
static void
INL_StartKbd(void)
{
	INL_KeyHook = NULL;			// no key hook routine

	IN_ClearKeysDown();

	// SDL handles keyboard events via event polling - no ISR needed
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_ShutKbd() - Restores keyboard control
//
///////////////////////////////////////////////////////////////////////////
static void
INL_ShutKbd(void)
{
	// Nothing to do for SDL - no ISR to restore
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_StartMouse() - Detects and sets up the mouse
//
///////////////////////////////////////////////////////////////////////////
static boolean
INL_StartMouse(void)
{
	// SDL always has mouse support if video is initialized
	// Enable relative mouse mode for FPS-style input
	return(true);
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_ShutMouse() - Cleans up after the mouse
//
///////////////////////////////////////////////////////////////////////////
static void
INL_ShutMouse(void)
{
}

//
//	INL_SetJoyScale() - Sets up scaling values for the specified joystick
//
static void
INL_SetJoyScale(word joy)
{
	JoystickDef	*def;

	def = &JoyDefs[joy];
	def->joyMultXL = JoyScaleMax / (def->threshMinX - def->joyMinX);
	def->joyMultXH = JoyScaleMax / (def->joyMaxX - def->threshMaxX);
	def->joyMultYL = JoyScaleMax / (def->threshMinY - def->joyMinY);
	def->joyMultYH = JoyScaleMax / (def->joyMaxY - def->threshMaxY);
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_SetupJoy() - Sets up thresholding values and calls INL_SetJoyScale()
//		to set up scaling values
//
///////////////////////////////////////////////////////////////////////////
void
IN_SetupJoy(word joy,word minx,word maxx,word miny,word maxy)
{
	word		d,r;
	JoystickDef	*def;

	def = &JoyDefs[joy];

	def->joyMinX = minx;
	def->joyMaxX = maxx;
	r = maxx - minx;
	d = r / 3;
	def->threshMinX = ((r / 2) - d) + minx;
	def->threshMaxX = ((r / 2) + d) + minx;

	def->joyMinY = miny;
	def->joyMaxY = maxy;
	r = maxy - miny;
	d = r / 3;
	def->threshMinY = ((r / 2) - d) + miny;
	def->threshMaxY = ((r / 2) + d) + miny;

	INL_SetJoyScale(joy);
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_StartJoy() - Detects & auto-configures the specified joystick
//					The auto-config assumes the joystick is centered
//
///////////////////////////////////////////////////////////////////////////
static boolean
INL_StartJoy(word joy)
{
	word		x,y;

	if (joy >= MaxJoys || !sdl_joysticks[joy])
		return(false);

	IN_GetJoyAbs(joy,&x,&y);

	if
	(
		((x == 0) || (x > MaxJoyValue - 10))
	||	((y == 0) || (y > MaxJoyValue - 10))
	)
		return(false);
	else
	{
		IN_SetupJoy(joy,0,x * 2,0,y * 2);
		return(true);
	}
}

///////////////////////////////////////////////////////////////////////////
//
//	INL_ShutJoy() - Cleans up the joystick stuff
//
///////////////////////////////////////////////////////////////////////////
static void
INL_ShutJoy(word joy)
{
	JoysPresent[joy] = false;
	if (joy < MaxJoys && sdl_joysticks[joy])
	{
		SDL_CloseJoystick(sdl_joysticks[joy]);
		sdl_joysticks[joy] = NULL;
	}
}


///////////////////////////////////////////////////////////////////////////
//
//	IN_Startup() - Starts up the Input Mgr
//
///////////////////////////////////////////////////////////////////////////
void
IN_Startup(void)
{
	boolean	checkjoys,checkmouse;
	word	i;
	int		num_joysticks;
	SDL_JoystickID *joystick_ids;

	if (IN_Started)
		return;

	checkjoys = true;
	checkmouse = true;
	for (i = 1;i < _argc;i++)
	{
		switch (US_CheckParm(_argv[i],ParmStrings))
		{
		case 0:
			checkjoys = false;
			break;
		case 1:
			checkmouse = false;
			break;
		}
	}

	INL_StartKbd();
	MousePresent = checkmouse? INL_StartMouse() : false;

	// Initialize SDL joystick subsystem
	for (i = 0; i < MaxJoys; i++)
		sdl_joysticks[i] = NULL;

	if (checkjoys)
	{
		joystick_ids = SDL_GetJoysticks(&num_joysticks);
		if (joystick_ids)
		{
			for (i = 0; i < MaxJoys && i < (word)num_joysticks; i++)
			{
				sdl_joysticks[i] = SDL_OpenJoystick(joystick_ids[i]);
			}
			SDL_free(joystick_ids);
		}
	}

	for (i = 0;i < MaxJoys;i++)
		JoysPresent[i] = checkjoys? INL_StartJoy(i) : false;

	IN_Started = true;
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_Default() - Sets up default conditions for the Input Mgr
//
///////////////////////////////////////////////////////////////////////////
void
IN_Default(boolean gotit,ControlType in)
{
	if
	(
		(!gotit)
	|| 	((in == ctrl_Joystick1) && !JoysPresent[0])
	|| 	((in == ctrl_Joystick2) && !JoysPresent[1])
	|| 	((in == ctrl_Mouse) && !MousePresent)
	)
		in = ctrl_Keyboard1;
	IN_SetControlType(0,in);
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_Shutdown() - Shuts down the Input Mgr
//
///////////////////////////////////////////////////////////////////////////
void
IN_Shutdown(void)
{
	word	i;

	if (!IN_Started)
		return;

	INL_ShutMouse();
	for (i = 0;i < MaxJoys;i++)
		INL_ShutJoy(i);
	INL_ShutKbd();

	IN_Started = false;
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_SetKeyHook() - Sets the routine that gets called by INL_KeyService()
//			everytime a real make/break code gets hit
//
///////////////////////////////////////////////////////////////////////////
void
IN_SetKeyHook(void (*hook)())
{
	INL_KeyHook = hook;
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_ClearKeysDown() - Clears the keyboard array
//
///////////////////////////////////////////////////////////////////////////
void
IN_ClearKeysDown(void)
{
	int	i;
	SDL_Event ev;

	LastScan = sc_None;
	LastASCII = key_None;
	memset (Keyboard,0,sizeof(Keyboard));

	// Drain any pending keyboard events from the SDL event queue
	// so they don't re-trigger keys on the next IN_ProcessEvents call.
	while (SDL_PollEvent(&ev))
	{
		// Keep non-keyboard events (like SDL_EVENT_QUIT)
		if (ev.type != SDL_EVENT_KEY_DOWN && ev.type != SDL_EVENT_KEY_UP)
			SDL_PushEvent(&ev);
	}
}


///////////////////////////////////////////////////////////////////////////
//
//	IN_ReadControl() - Reads the device associated with the specified
//		player and fills in the control info struct
//
///////////////////////////////////////////////////////////////////////////
void
IN_ReadControl(int player,ControlInfo *info)
{
			boolean		realdelta;
			byte		dbyte;
			word		buttons;
			int			dx,dy;
			Motion		mx,my;
			ControlType	type;
register	KeyboardDef	*def;

	dx = dy = 0;
	mx = my = motion_None;
	buttons = 0;

	// Process SDL events to update keyboard/mouse/joystick state
	IN_ProcessEvents();

	if (DemoMode == demo_Playback)
	{
		dbyte = DemoBuffer[DemoOffset + 1];
		my = (dbyte & 3) - 1;
		mx = ((dbyte >> 2) & 3) - 1;
		buttons = (dbyte >> 4) & 3;

		if (!(--DemoBuffer[DemoOffset]))
		{
			DemoOffset += 2;
			if (DemoOffset >= DemoSize)
				DemoMode = demo_PlayDone;
		}

		realdelta = false;
	}
	else if (DemoMode == demo_PlayDone)
		Quit("Demo playback exceeded");
	else
	{
		switch (type = Controls[player])
		{
		case ctrl_Keyboard:
			def = &KbdDefs;

			if (Keyboard[def->upleft])
				mx = motion_Left,my = motion_Up;
			else if (Keyboard[def->upright])
				mx = motion_Right,my = motion_Up;
			else if (Keyboard[def->downleft])
				mx = motion_Left,my = motion_Down;
			else if (Keyboard[def->downright])
				mx = motion_Right,my = motion_Down;

			if (Keyboard[def->up])
				my = motion_Up;
			else if (Keyboard[def->down])
				my = motion_Down;

			if (Keyboard[def->left])
				mx = motion_Left;
			else if (Keyboard[def->right])
				mx = motion_Right;

			if (Keyboard[def->button0])
				buttons += 1 << 0;
			if (Keyboard[def->button1])
				buttons += 1 << 1;
			realdelta = false;
			break;
		case ctrl_Joystick1:
		case ctrl_Joystick2:
			INL_GetJoyDelta(type - ctrl_Joystick,&dx,&dy);
			buttons = INL_GetJoyButtons(type - ctrl_Joystick);
			realdelta = true;
			break;
		case ctrl_Mouse:
			INL_GetMouseDelta(&dx,&dy);
			buttons = INL_GetMouseButtons();
			realdelta = true;
			break;
		}
	}

	if (realdelta)
	{
		mx = (dx < 0)? motion_Left : ((dx > 0)? motion_Right : motion_None);
		my = (dy < 0)? motion_Up : ((dy > 0)? motion_Down : motion_None);
	}
	else
	{
		dx = mx * 127;
		dy = my * 127;
	}

	info->x = dx;
	info->xaxis = mx;
	info->y = dy;
	info->yaxis = my;
	info->button0 = buttons & (1 << 0);
	info->button1 = buttons & (1 << 1);
	info->button2 = buttons & (1 << 2);
	info->button3 = buttons & (1 << 3);
	info->dir = DirTable[((my + 1) * 3) + (mx + 1)];

	if (DemoMode == demo_Record)
	{
		// Pack the control info into a byte
		dbyte = (buttons << 4) | ((mx + 1) << 2) | (my + 1);

		if
		(
			(DemoBuffer[DemoOffset + 1] == dbyte)
		&&	(DemoBuffer[DemoOffset] < 255)
		)
			(DemoBuffer[DemoOffset])++;
		else
		{
			if (DemoOffset || DemoBuffer[DemoOffset])
				DemoOffset += 2;

			if (DemoOffset >= DemoSize)
				Quit("Demo buffer overflow");

			DemoBuffer[DemoOffset] = 1;
			DemoBuffer[DemoOffset + 1] = dbyte;
		}
	}
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_SetControlType() - Sets the control type to be used by the specified
//		player
//
///////////////////////////////////////////////////////////////////////////
void
IN_SetControlType(int player,ControlType type)
{
	// DEBUG - check that requested type is present?
	Controls[player] = type;
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_WaitForKey() - Waits for a scan code, then clears LastScan and
//		returns the scan code
//
///////////////////////////////////////////////////////////////////////////
ScanCode
IN_WaitForKey(void)
{
	ScanCode	result;

	while (!(result = LastScan))
		IN_WaitAndProcessEvents();
	LastScan = 0;
	return(result);
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_WaitForASCII() - Waits for an ASCII char, then clears LastASCII and
//		returns the ASCII value
//
///////////////////////////////////////////////////////////////////////////
char
IN_WaitForASCII(void)
{
	char		result;

	while (!(result = LastASCII))
		IN_WaitAndProcessEvents();
	LastASCII = '\0';
	return(result);
}

///////////////////////////////////////////////////////////////////////////
//
//	IN_Ack() - waits for a button or key press.  If a button is down, upon
// calling, it must be released for it to be recognized
//
///////////////////////////////////////////////////////////////////////////

boolean	btnstate[8];

void IN_StartAck(void)
{
	unsigned	i,buttons;

//
// get initial state of everything
//
	IN_ClearKeysDown();
	memset (btnstate,0,sizeof(btnstate));

	buttons = IN_JoyButtons () << 4;
	if (MousePresent)
		buttons |= IN_MouseButtons ();

	for (i=0;i<8;i++,buttons>>=1)
		if (buttons&1)
			btnstate[i] = true;
}


boolean IN_CheckAck (void)
{
	unsigned	i,buttons;

//
// see if something has been pressed
//
	IN_ProcessEvents();

	if (LastScan)
		return true;

	buttons = IN_JoyButtons () << 4;
	if (MousePresent)
		buttons |= IN_MouseButtons ();

	for (i=0;i<8;i++,buttons>>=1)
		if ( buttons&1 )
		{
			if (!btnstate[i])
				return true;
		}
		else
			btnstate[i]=false;

	return false;
}


void IN_Ack (void)
{
	IN_StartAck ();

	while (!IN_CheckAck ())
		SDL_Delay(1);
}


///////////////////////////////////////////////////////////////////////////
//
//	IN_UserInput() - Waits for the specified delay time (in ticks) or the
//		user pressing a key or a mouse button. If the clear flag is set, it
//		then either clears the key or waits for the user to let the mouse
//		button up.
//
///////////////////////////////////////////////////////////////////////////
boolean IN_UserInput(longword delay)
{
	longword	lasttime;

	lasttime = TimeCount;
	IN_StartAck ();
	do
	{
		if (IN_CheckAck())
			return true;
		SDL_Delay(1);
	} while (TimeCount - lasttime < delay);
	return(false);
}

//===========================================================================

/*
===================
=
= IN_MouseButtons
=
===================
*/

byte	IN_MouseButtons (void)
{
	if (MousePresent)
	{
		return (byte)INL_GetMouseButtons();
	}
	else
		return 0;
}


/*
===================
=
= IN_GetMouseDelta
=
= Public wrapper for INL_GetMouseDelta.
= If x or y are NULL, the value is discarded (used to clear accumulated movement).
=
===================
*/

void IN_GetMouseDelta (int *x, int *y)
{
	int dx, dy;
	INL_GetMouseDelta(&dx, &dy);
	if (x) *x = dx;
	if (y) *y = dy;
}


/*
===================
=
= IN_JoyButtons
=
===================
*/

byte	IN_JoyButtons (void)
{
	word joybits = 0;

	if (JoysPresent[0])
		joybits |= INL_GetJoyButtons(0);
	if (JoysPresent[1])
		joybits |= INL_GetJoyButtons(1) << 2;

	return (byte)joybits;
}
