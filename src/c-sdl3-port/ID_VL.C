// ID_VL.C
// Ported from DOS/VGA to SDL3

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <SDL3/SDL.h>
#include "ID_HEAD.H"
#include "ID_VL.H"

//
// SC_INDEX is expected to stay at SC_MAPMASK for proper operation
//

unsigned	bufferofs;
unsigned	displayofs,pelpan;

unsigned	screenseg=SCREENSEG;		// kept for compat, not used

unsigned	linewidth;
unsigned	ylookup[MAXSCANLINES];

boolean		screenfaded;
unsigned	bordercolor;

boolean		fastpalette;				// not used with SDL3

byte		palette1[256][3], palette2[256][3];

//===========================================================================
// Frame capture globals
//===========================================================================

int		capture_enabled = 0;
int		capture_frame = 0;
int		capture_limit = 0;		// 0 = unlimited
Uint64	quit_after_ms = 0;		// 0 = disabled
Uint64	quit_after_start = 0;	// SDL_GetTicks() at first VL_UpdateScreen

//===========================================================================
// Test sequence: automated key injection for testing UI flow
//===========================================================================

int		test_sequence_enabled = 0;

typedef struct {
	Uint64		time_ms;		// milliseconds after test start
	SDL_Scancode scancode;
	int		is_press;		// 1 = key down, 0 = key up
} TestEvent;

// The test sequence injects key presses at specific times.
// Each key press is a down event followed by an up event 200ms later.
static TestEvent test_events[] = {
	// ~1s: Press SPACE (acknowledge signon "Press a key")
	{  1000, SDL_SCANCODE_SPACE, 1 },
	{  1200, SDL_SCANCODE_SPACE, 0 },
	// ~4s: Press SPACE (acknowledge PC-13 screen)
	{  4000, SDL_SCANCODE_SPACE, 1 },
	{  4200, SDL_SCANCODE_SPACE, 0 },
	// ~9s: Press SPACE (dismiss title, should go to menu)
	{  9000, SDL_SCANCODE_SPACE, 1 },
	{  9200, SDL_SCANCODE_SPACE, 0 },
	// ~13s: Press RETURN (select "New Game" in menu)
	{ 13000, SDL_SCANCODE_RETURN, 1 },
	{ 13200, SDL_SCANCODE_RETURN, 0 },
	// ~16s: Press RETURN (select episode)
	{ 16000, SDL_SCANCODE_RETURN, 1 },
	{ 16200, SDL_SCANCODE_RETURN, 0 },
	// ~19s: Press RETURN (select difficulty)
	{ 19000, SDL_SCANCODE_RETURN, 1 },
	{ 19200, SDL_SCANCODE_RETURN, 0 },
	// Sentinel
	{     0, SDL_SCANCODE_UNKNOWN, 0 }
};

static Uint64	test_start_time = 0;
static int		test_next_event = 0;

void VL_CheckTestSequence(void)
{
	Uint64 now, elapsed;

	if (!test_sequence_enabled)
		return;

	if (test_start_time == 0)
		test_start_time = SDL_GetTicks();

	now = SDL_GetTicks();
	elapsed = now - test_start_time;

	while (test_events[test_next_event].time_ms > 0 ||
	       test_events[test_next_event].scancode != SDL_SCANCODE_UNKNOWN)
	{
		if (test_events[test_next_event].time_ms > elapsed)
			break;

		{
			SDL_Event ev;
			memset(&ev, 0, sizeof(ev));
			if (test_events[test_next_event].is_press)
			{
				ev.type = SDL_EVENT_KEY_DOWN;
				ev.key.scancode = test_events[test_next_event].scancode;
				ev.key.key = SDL_GetKeyFromScancode(test_events[test_next_event].scancode, SDL_KMOD_NONE, false);
				ev.key.down = true;
				ev.key.repeat = false;
			}
			else
			{
				ev.type = SDL_EVENT_KEY_UP;
				ev.key.scancode = test_events[test_next_event].scancode;
				ev.key.key = SDL_GetKeyFromScancode(test_events[test_next_event].scancode, SDL_KMOD_NONE, false);
				ev.key.down = false;
				ev.key.repeat = false;
			}
			SDL_PushEvent(&ev);
		}
		test_next_event++;
	}
}

//===========================================================================
// SDL3 globals
//===========================================================================

SDL_Window		*sdl_window = NULL;
SDL_Renderer	*sdl_renderer = NULL;
SDL_Texture		*sdl_texture = NULL;
byte			sdl_screenbuf[320*200];		// linear 8-bit framebuffer
byte			sdl_palette[768];			// current palette R,G,B triples

// Internal latch memory - simulates VGA latch planes as linear pixel buffer.
// The original code used VGA write mode 1 to copy between VGA memory regions.
// Latch offsets from the game are in planar bytes. Each planar byte = 4 pixels.
// We store linear pixels at index (planar_offset * 4).
// So the array needs to be 4x the original VGA memory size.
#define LATCH_MEM_SIZE	(256*1024)
static byte		latchmem[LATCH_MEM_SIZE];

//===========================================================================

// Formerly in ASM - now implemented here as C functions

int	 VL_VideoID (void)
{
	return 5;	// Always report VGA present
}

void VL_SetCRTC (int crtc)
{
	// No-op for SDL3 - CRTC start address not relevant
	(void)crtc;
}

void VL_SetScreen (int crtc, int pel)
{
	// No-op for SDL3 - screen panning via CRTC not relevant
	displayofs = crtc;
	pelpan = pel;
	(void)crtc;
	(void)pel;
}

void VL_WaitVBL (int vbls)
{
	// Original waits for vertical blank retrace.
	// Approximate at ~70Hz (14ms per frame)
	if (vbls > 0)
		SDL_Delay(vbls * 14);

	// Check auto-quit timer here too, since VL_UpdateScreen may not be
	// called during menu/input-wait phases
	if (quit_after_ms > 0 && quit_after_start > 0)
	{
		if (SDL_GetTicks() - quit_after_start >= quit_after_ms)
		{
			VL_Shutdown();
			exit(0);
		}
	}
}

//===========================================================================


/*
=======================
=
= VL_QuitTimerCallback
=
= SDL timer callback for --quit-after: fires once and exits the process.
=
=======================
*/

// Timer-based quit removed: _exit() from a timer thread is unsafe (can
// corrupt stdio, mask crashes with clean exit).  Quit is now poll-based
// in VL_WaitVBL, VL_UpdateScreen, and CalcTics.


/*
=======================
=
= VL_Startup
=
=======================
*/

void	VL_Startup (void)
{
	// Idempotent: if already initialized, don't re-create everything
	if (sdl_window)
		return;

	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO))
	{
		Quit("SDL_Init(VIDEO|AUDIO) failed!");
	}

	sdl_window = SDL_CreateWindow("Wolfenstein 3-D",
		320*3, 200*3, 0);
	if (!sdl_window)
		Quit("SDL_CreateWindow failed!");

	sdl_renderer = SDL_CreateRenderer(sdl_window, NULL);
	if (!sdl_renderer)
		Quit("SDL_CreateRenderer failed!");

	SDL_SetRenderLogicalPresentation(sdl_renderer, 320, 200,
		SDL_LOGICAL_PRESENTATION_LETTERBOX);

	sdl_texture = SDL_CreateTexture(sdl_renderer,
		SDL_PIXELFORMAT_XRGB8888, SDL_TEXTUREACCESS_STREAMING,
		320, 200);
	if (!sdl_texture)
		Quit("SDL_CreateTexture failed!");

	SDL_SetTextureScaleMode(sdl_texture, SDL_SCALEMODE_NEAREST);

	memset(sdl_screenbuf, 0, sizeof(sdl_screenbuf));
	memset(sdl_palette, 0, sizeof(sdl_palette));

	// Start the auto-quit epoch now that SDL is initialized
	if (quit_after_ms > 0)
	{
		quit_after_start = SDL_GetTicks();
		// NOTE: timer-based _exit removed; quit is now poll-based only
		// (checked in VL_UpdateScreen, VL_WaitVBL, and CalcTics)
	}
}



/*
=======================
=
= VL_Shutdown
=
=======================
*/

void	VL_Shutdown (void)
{
	if (sdl_texture)
	{
		SDL_DestroyTexture(sdl_texture);
		sdl_texture = NULL;
	}
	if (sdl_renderer)
	{
		SDL_DestroyRenderer(sdl_renderer);
		sdl_renderer = NULL;
	}
	if (sdl_window)
	{
		SDL_DestroyWindow(sdl_window);
		sdl_window = NULL;
	}
	SDL_Quit();
}


/*
=======================
=
= VL_SetVGAPlaneMode
=
=======================
*/

void	VL_SetVGAPlaneMode (void)
{
	// Original set mode 13h then de-planed VGA.
	// For SDL3 we ensure the window is created, then set up the linear framebuffer.
	if (!sdl_window)
		VL_Startup();
	VL_DePlaneVGA ();
	VL_SetLineWidth (40);
}


/*
=======================
=
= VL_SetVGAPlane
=
=======================
*/

void	VL_SetVGAPlane (void)
{
	// No-op for SDL3 - VGA plane selection not relevant
}


/*
=======================
=
= VL_SetTextMode
=
=======================
*/

void	VL_SetTextMode (void)
{
	// No-op for SDL3 - no text mode to switch to
}

//===========================================================================

/*
=================
=
= VL_ClearVideo
=
= Fill the entire video buffer with a given color
=
=================
*/

void VL_ClearVideo (byte color)
{
	memset(sdl_screenbuf, color, sizeof(sdl_screenbuf));
	memset(latchmem, color, sizeof(latchmem));
}


/*
=============================================================================

			VGA REGISTER MANAGEMENT ROUTINES

=============================================================================
*/


/*
=================
=
= VL_DePlaneVGA
=
=================
*/

void VL_DePlaneVGA (void)
{
	// Original de-planed the VGA for mode-X style access.
	// For SDL3 we use a linear framebuffer, so just clear it.
	VL_ClearVideo (0);
}

//===========================================================================

/*
====================
=
= VL_SetLineWidth
=
= Line witdh is in WORDS, 40 words is normal width for vgaplanegr
=
====================
*/

void VL_SetLineWidth (unsigned width)
{
	int i,offset;

//
// set up lookup tables
// In original code, linewidth was in bytes for planar VGA (width*2).
// For our linear framebuffer, we use 320 pixels per line.
// However, many parts of the code use linewidth for offset calculations,
// so we keep the original calculation for compatibility with latch operations.
//
	linewidth = width*2;

	offset = 0;

	for (i=0;i<MAXSCANLINES;i++)
	{
		ylookup[i]=offset;
		offset += linewidth;
	}
}

/*
====================
=
= VL_SetSplitScreen
=
====================
*/

void VL_SetSplitScreen (int linenum)
{
	// No-op for SDL3 - VGA split screen not used
	(void)linenum;
}


/*
=============================================================================

						PALETTE OPS

		To avoid snow, do a WaitVBL BEFORE calling these

=============================================================================
*/


/*
=================
=
= VL_FillPalette
=
=================
*/

void VL_FillPalette (int red, int green, int blue)
{
	int	i;

	for (i=0;i<256;i++)
	{
		sdl_palette[i*3+0] = red;
		sdl_palette[i*3+1] = green;
		sdl_palette[i*3+2] = blue;
	}
}

//===========================================================================

/*
=================
=
= VL_SetColor
=
=================
*/

void VL_SetColor	(int color, int red, int green, int blue)
{
	sdl_palette[color*3+0] = red;
	sdl_palette[color*3+1] = green;
	sdl_palette[color*3+2] = blue;
}

//===========================================================================

/*
=================
=
= VL_GetColor
=
=================
*/

void VL_GetColor	(int color, int *red, int *green, int *blue)
{
	*red   = sdl_palette[color*3+0];
	*green = sdl_palette[color*3+1];
	*blue  = sdl_palette[color*3+2];
}

//===========================================================================

/*
=================
=
= VL_SetPalette
=
=================
*/

void VL_SetPalette (byte *palette)
{
	memcpy(sdl_palette, palette, 768);
}


//===========================================================================

/*
=================
=
= VL_GetPalette
=
=================
*/

void VL_GetPalette (byte *palette)
{
	memcpy(palette, sdl_palette, 768);
}


//===========================================================================

/*
=================
=
= VL_FadeOut
=
= Fades the current palette to the given color in the given number of steps
=
=================
*/

void VL_FadeOut (int start, int end, int red, int green, int blue, int steps)
{
	int		i,j,orig,delta;
	byte	*origptr, *newptr;

	VL_WaitVBL(1);
	VL_GetPalette (&palette1[0][0]);
	memcpy (palette2,palette1,768);

//
// fade through intermediate frames
//
	for (i=0;i<steps;i++)
	{
		origptr = &palette1[start][0];
		newptr = &palette2[start][0];
		for (j=start;j<=end;j++)
		{
			orig = *origptr++;
			delta = red-orig;
			*newptr++ = orig + delta * i / steps;
			orig = *origptr++;
			delta = green-orig;
			*newptr++ = orig + delta * i / steps;
			orig = *origptr++;
			delta = blue-orig;
			*newptr++ = orig + delta * i / steps;
		}

		VL_WaitVBL(1);
		VL_SetPalette (&palette2[0][0]);
		VL_UpdateScreen();
	}

//
// final color
//
	VL_FillPalette (red,green,blue);

	screenfaded = true;
}


/*
=================
=
= VL_FadeIn
=
=================
*/

void VL_FadeIn (int start, int end, byte *palette, int steps)
{
	int		i,j,delta;

	VL_WaitVBL(1);
	VL_GetPalette (&palette1[0][0]);
	memcpy (&palette2[0][0],&palette1[0][0],sizeof(palette1));

	start *= 3;
	end = end*3+2;

//
// fade through intermediate frames
//
	for (i=0;i<steps;i++)
	{
		for (j=start;j<=end;j++)
		{
			delta = palette[j]-palette1[0][j];
			palette2[0][j] = palette1[0][j] + delta * i / steps;
		}

		VL_WaitVBL(1);
		VL_SetPalette (&palette2[0][0]);
		VL_UpdateScreen();
	}

//
// final color
//
	VL_SetPalette (palette);
	screenfaded = false;
}



/*
=================
=
= VL_TestPaletteSet
=
= Sets the palette with outsb, then reads it in and compares
= If it compares ok, fastpalette is set to true.
=
=================
*/

void VL_TestPaletteSet (void)
{
	// Always fast with SDL3
	fastpalette = true;
}


/*
==================
=
= VL_ColorBorder
=
==================
*/

void VL_ColorBorder (int color)
{
	// No-op for SDL3 - VGA border color not relevant
	bordercolor = color;
}



/*
=============================================================================

							PIXEL OPS

=============================================================================
*/

/*
=================
=
= VL_Plot
=
= Plot a pixel into the linear screenbuf
=
=================
*/

void VL_Plot (int x, int y, int color)
{
	if (x >= 0 && x < 320 && y >= 0 && y < 200)
		sdl_screenbuf[y*320+x] = color;
}


/*
=================
=
= VL_Hlin
=
=================
*/

void VL_Hlin (unsigned x, unsigned y, unsigned width, unsigned color)
{
	if (y >= 200) return;
	if (x >= 320) return;
	if (x + width > 320) width = 320 - x;
	memset(&sdl_screenbuf[y*320+x], color, width);
}


/*
=================
=
= VL_Vlin
=
=================
*/

void VL_Vlin (int x, int y, int height, int color)
{
	byte *dest;

	if (x < 0 || x >= 320) return;
	if (y < 0) { height += y; y = 0; }
	if (y + height > 200) height = 200 - y;

	dest = &sdl_screenbuf[y*320+x];

	while (height-- > 0)
	{
		*dest = color;
		dest += 320;
	}
}


/*
=================
=
= VL_Bar
=
=================
*/

void VL_Bar (int x, int y, int width, int height, int color)
{
	byte *dest;

	if (x < 0) { width += x; x = 0; }
	if (y < 0) { height += y; y = 0; }
	if (x + width > 320) width = 320 - x;
	if (y + height > 200) height = 200 - y;
	if (width <= 0 || height <= 0) return;

	dest = &sdl_screenbuf[y*320+x];

	while (height--)
	{
		memset(dest, color, width);
		dest += 320;
	}
}

/*
============================================================================

							MEMORY OPS

============================================================================
*/

/*
=================
=
= VL_MemToLatch
=
= Copy de-planed source data into latch memory.
= The source data is in plane-separated format (plane0, plane1, plane2, plane3).
= We interleave the planes back into linear pixel data in latchmem.
=
=================
*/

void VL_MemToLatch (byte *source, int width, int height, unsigned dest)
{
	int		x, y, plane;
	int		pwidth;
	unsigned linearbase;

	pwidth = (width + 3) / 4;

	// dest is a planar byte offset. Convert to linear pixel offset.
	linearbase = dest * 4;

	// Clear the destination area
	if (linearbase + width * height <= LATCH_MEM_SIZE)
		memset(&latchmem[linearbase], 0, width * height);

	// Source data is in plane-separated format: all of plane0, then plane1, etc.
	// Each plane has pwidth bytes per row, height rows.
	for (plane = 0; plane < 4; plane++)
	{
		for (y = 0; y < height; y++)
		{
			for (x = 0; x < pwidth; x++)
			{
				int px = x * 4 + plane;
				unsigned idx = linearbase + y * width + px;
				if (px < width && idx < LATCH_MEM_SIZE)
					latchmem[idx] = *source;
				source++;
			}
		}
	}
}


//===========================================================================


/*
=================
=
= VL_MemToScreen
=
= Draws a block of data to the screen.
= Source data is in plane-separated format.
= We de-interleave the 4 planes into the linear screenbuf.
=
=================
*/

void VL_MemToScreen (byte *source, int width, int height, int x, int y)
{
	int		plane, px, py;
	int		pwidth;
	byte	*src;
	int		startplane;

	pwidth = width >> 2;
	src = source;
	startplane = x & 3;

	// Source data is de-planed (via VL_MungePic): plane 0, plane 1, plane 2, plane 3.
	// Each plane has pwidth bytes per row, height rows.
	// The mask starts at startplane and wraps: startplane, startplane+1, ..., 3, 0, 1, ...
	// In VGA, writing byte[i] at VGA addr (dest+i) with plane p -> pixel at (dest+i)*4 + p.
	// dest = (x>>2), so pixel = (x>>2 + i)*4 + p = x - (x&3) + i*4 + p

	for (plane = 0; plane < 4; plane++)
	{
		int curplane = (startplane + plane) & 3;
		for (py = 0; py < height; py++)
		{
			for (px = 0; px < pwidth; px++)
			{
				// VGA address = (x>>2) + px
				// pixel column = ((x>>2) + px) * 4 + curplane
				int screenx = ((x >> 2) + px) * 4 + curplane;
				int screeny = y + py;
				if (screenx >= 0 && screenx < 320 && screeny >= 0 && screeny < 200)
					sdl_screenbuf[screeny * 320 + screenx] = src[px];
			}
			src += pwidth;
		}
	}
}

//==========================================================================


/*
=================
=
= VL_MaskedToScreen
=
= Masks a block of main memory to the screen.
= Source data is in plane-separated format.
= Pixel value 0 is treated as transparent (mask).
=
=================
*/

void VL_MaskedToScreen (byte *source, int width, int height, int x, int y)
{
	int		plane, px, py;
	int		pwidth;
	byte	*src;
	int		startplane;

	pwidth = width >> 2;
	src = source;
	startplane = x & 3;

	for (plane = 0; plane < 4; plane++)
	{
		int curplane = (startplane + plane) & 3;
		for (py = 0; py < height; py++)
		{
			for (px = 0; px < pwidth; px++)
			{
				int screenx = ((x >> 2) + px) * 4 + curplane;
				int screeny = y + py;
				byte val = src[px];
				if (val != 0 && screenx >= 0 && screenx < 320 && screeny >= 0 && screeny < 200)
					sdl_screenbuf[screeny * 320 + screenx] = val;
			}
			src += pwidth;
		}
	}
}

//==========================================================================

/*
=================
=
= VL_LatchToScreen
=
= Copy from latch memory to screen buffer.
= In original, this used VGA write mode 1 to copy between VGA memory regions.
= Width is in bytes (original planar width), so actual pixel width = width * 4.
= However, we stored latch data as linear pixels, so width param here represents
= the number of bytes per line in planar format.
=
=================
*/

void VL_LatchToScreen (unsigned source, int width, int height, int x, int y)
{
	int		sy, sx;
	byte	*src;
	byte	*dest;
	int		pixwidth = width * 4;  // convert from planar byte width to pixel width
	unsigned linearbase;
	unsigned within_page;
	int		buf_y, buf_x;

	// source is a planar byte offset. Convert to linear pixel offset.
	linearbase = source * 4;
	src = &latchmem[linearbase];

	// In the original DOS code, the destination was:
	//   bufferofs + ylookup[y] + (x >> 2)
	// bufferofs encodes the VGA page offset plus any row offset (e.g. for status bar).
	// Strip the page offset (SCREENSIZE = SCREENWIDTH * 208 = 16640) and convert
	// the within-page offset to pixel coordinates.
	within_page = bufferofs % (SCREENWIDTH * 208);
	buf_y = within_page / linewidth;
	buf_x = (within_page % linewidth) * 4;

	x += buf_x;
	y += buf_y;

	for (sy = 0; sy < height; sy++)
	{
		int screeny = y + sy;
		if (screeny < 0 || screeny >= 200)
		{
			src += pixwidth;
			continue;
		}
		dest = &sdl_screenbuf[screeny * 320 + x];
		for (sx = 0; sx < pixwidth && (x + sx) < 320; sx++)
		{
			if (x + sx >= 0)
				dest[sx] = src[sx];
		}
		src += pixwidth;
	}
}


//===========================================================================

/*
=================
=
= VL_ScreenToScreen
=
= Copy one region of the screen buffer to another.
= Width is in planar bytes, so pixel width = width * 4.
= Source and dest are byte offsets in the original planar VGA space.
= For our linear buffer, we convert: planar offset -> (x,y) -> linear offset.
=
=================
*/

void VL_ScreenToScreen (unsigned source, unsigned dest, int width, int height)
{
	int y;
	// source/dest are planar byte offsets in VGA memory.
	// width is in planar bytes (e.g., 80 = full screen width = 320 pixels).
	// linewidth is the planar stride per row (80 for 320-pixel mode).
	//
	// Convert planar offsets to linear pixel positions:
	//   planar_offset = row * linewidth + col_bytes
	//   linear = row * 320 + col_bytes * 4

	for (y = 0; y < height; y++)
	{
		unsigned src_planar = source + y * linewidth;
		unsigned dst_planar = dest + y * linewidth;

		int src_row = src_planar / linewidth;
		int src_col = src_planar % linewidth;
		int dst_row = dst_planar / linewidth;
		int dst_col = dst_planar % linewidth;

		int src_linear = src_row * 320 + src_col * 4;
		int dst_linear = dst_row * 320 + dst_col * 4;
		int pixwidth = width * 4;

		if (src_linear >= 0 && dst_linear >= 0 &&
			src_linear + pixwidth <= 320*200 &&
			dst_linear + pixwidth <= 320*200)
		{
			memmove(&sdl_screenbuf[dst_linear], &sdl_screenbuf[src_linear], pixwidth);
		}
	}
}


/*
=============================================================================

						STRING OUTPUT ROUTINES

=============================================================================
*/




/*
===================
=
= VL_DrawTile8String
=
= Draw 8x8 tile-based string to the screen.
= tile8ptr points to tile data in plane-separated format (64 bytes per char).
= Each character: 4 planes x 2 bytes x 8 rows = 64 bytes
=
===================
*/

void VL_DrawTile8String (char *str, char *tile8ptr, int printx, int printy)
{
	int		plane, row;
	byte	*src;

	while (*str)
	{
		src = (byte *)(tile8ptr + (*str << 6));  // 64 bytes per char

		// Tile data is in plane-separated format:
		// 4 planes x (8 rows x 2 bytes/row) = 64 bytes total.
		// In planar VGA, 2 bytes per row covers 8 pixels (each byte = 4 pixels).
		// Plane 0 -> pixel columns 0, 4
		// Plane 1 -> pixel columns 1, 5
		// Plane 2 -> pixel columns 2, 6
		// Plane 3 -> pixel columns 3, 7
		for (plane = 0; plane < 4; plane++)
		{
			for (row = 0; row < 8; row++)
			{
				int screeny = printy + row;
				if (screeny >= 0 && screeny < 200)
				{
					// Byte 0: pixel at column (plane + 0)
					// Byte 1: pixel at column (plane + 4)
					int x0 = printx + plane;
					int x1 = printx + plane + 4;

					if (x0 >= 0 && x0 < 320)
						sdl_screenbuf[screeny * 320 + x0] = src[0];
					if (x1 >= 0 && x1 < 320)
						sdl_screenbuf[screeny * 320 + x1] = src[1];
				}
				src += 2;  // word per row (sizeof(unsigned) in original 16-bit code)
			}
		}

		str++;
		printx += 8;
	}
}



/*
===================
=
= VL_DrawLatch8String
=
= Draw 8x8 string from latch memory
=
===================
*/

void VL_DrawLatch8String (char *str, unsigned tile8ptr, int printx, int printy)
{
	// Each character is 16 planar latch bytes = 8x8 pixels
	// tile8ptr + (*str << 4) gives the planar byte offset
	// Multiply by 4 to get linear pixel offset in latchmem

	while (*str)
	{
		unsigned planar_src = tile8ptr + (*str << 4);  // 16 planar bytes per char
		unsigned linear_src = planar_src * 4;
		int row;

		for (row = 0; row < 8; row++)
		{
			int screeny = printy + row;
			if (screeny >= 0 && screeny < 200)
			{
				int col;
				for (col = 0; col < 8; col++)
				{
					int screenx = printx + col;
					if (screenx >= 0 && screenx < 320)
					{
						unsigned idx = linear_src + row * 8 + col;
						if (idx < LATCH_MEM_SIZE)
							sdl_screenbuf[screeny * 320 + screenx] = latchmem[idx];
					}
				}
			}
		}

		str++;
		printx += 8;
	}
}


/*
===================
=
= VL_SizeTile8String
=
===================
*/

void VL_SizeTile8String (char *str, int *width, int *height)
{
	*height = 8;
	*width = 8*strlen(str);
}


/*
=================
=
= VL_UpdateScreen
=
= Upload sdl_screenbuf to SDL texture and present
=
=================
*/

void VL_UpdateScreen (void)
{
	void *rawpixels;
	int pitch;
	int x, y;

	if (!sdl_texture || !sdl_renderer)
		return;

	if (!SDL_LockTexture(sdl_texture, NULL, &rawpixels, &pitch))
		return;

	// Convert 8-bit indexed color to XRGB8888
	// pitch may not equal 320*4 due to padding, so iterate row by row
	for (y = 0; y < 200; y++)
	{
		Uint32 *row = (Uint32 *)((byte *)rawpixels + y * pitch);
		byte *src = &sdl_screenbuf[y * 320];
		for (x = 0; x < 320; x++)
		{
			byte idx = src[x];
			// VGA palette values are 6-bit (0-63), scale to 8-bit (0-255)
			byte r = (byte)(sdl_palette[idx*3+0] * 255 / 63);
			byte g = (byte)(sdl_palette[idx*3+1] * 255 / 63);
			byte b = (byte)(sdl_palette[idx*3+2] * 255 / 63);
			row[x] = ((Uint32)r << 16) | ((Uint32)g << 8) | (Uint32)b;
		}
	}

	SDL_UnlockTexture(sdl_texture);
	SDL_RenderClear(sdl_renderer);
	SDL_RenderTexture(sdl_renderer, sdl_texture, NULL, NULL);
	SDL_RenderPresent(sdl_renderer);

	//
	// Frame capture: save current frame as BMP if enabled
	//
	if (capture_enabled)
	{
		SDL_Surface *surf = SDL_CreateSurface(320, 200, SDL_PIXELFORMAT_XRGB8888);
		if (surf)
		{
			Uint32 *dst;
			int sx, sy;

			SDL_LockSurface(surf);
			for (sy = 0; sy < 200; sy++)
			{
				dst = (Uint32 *)((byte *)surf->pixels + sy * surf->pitch);
				for (sx = 0; sx < 320; sx++)
				{
					byte idx = sdl_screenbuf[sy * 320 + sx];
					byte cr = (byte)(sdl_palette[idx*3+0] * 255 / 63);
					byte cg = (byte)(sdl_palette[idx*3+1] * 255 / 63);
					byte cb = (byte)(sdl_palette[idx*3+2] * 255 / 63);
					dst[sx] = ((Uint32)cr << 16) | ((Uint32)cg << 8) | (Uint32)cb;
				}
			}
			SDL_UnlockSurface(surf);

			{
				char path[256];
				sprintf(path, "captures/frame_%05d.bmp", capture_frame);
				SDL_SaveBMP(surf, path);
			}
			SDL_DestroySurface(surf);

			if (capture_limit > 0 && (capture_frame + 1) >= capture_limit)
			{
				capture_frame++;
				VL_Shutdown();
				exit(0);
			}
		}
	}

	// Always increment frame counter
	capture_frame++;

	// Inject test sequence key events (time-based)
	VL_CheckTestSequence();

	//
	// Auto-quit timer
	//
	if (quit_after_ms > 0)
	{
		if (quit_after_start == 0)
			quit_after_start = SDL_GetTicks();
		else if (SDL_GetTicks() - quit_after_start >= quit_after_ms)
		{
			VL_Shutdown();
			exit(0);
		}
	}
}
