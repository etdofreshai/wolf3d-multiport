// WL_SCALE.C
//
// SDL3 port: compiled scalers replaced with lookup-table-based C scaling.
// The original code generated x86 machine code at runtime to scale texture
// columns. We replace that with simple C scaling loops that draw to the
// linear 320x200 sdl_screenbuf.
//

#include "WL_DEF.H"
#include <string.h>

/*
=============================================================================

						  GLOBALS

=============================================================================
*/

t_compscale *scaledirectory[MAXSCALEHEIGHT+1];
long			fullscalefarcall[MAXSCALEHEIGHT+1];

int			maxscale,maxscaleshl2;

boolean	insetupscaling;

/*
=============================================================================

						  LOCALS

=============================================================================
*/

int			stepbytwo;

//===========================================================================

/*
==============
=
= BadScale
=
==============
*/

void BadScale (void)
{
	Quit ("BadScale called!");
}


/*
==========================
=
= SetupScaling
=
= Builds lookup tables for scaling. In the original code this built
= "compiled scalers" (runtime-generated x86 code). We just build
= width[] and codeofs[] tables that ScaleLine uses to know how many
= screen pixels each source pixel maps to.
=
==========================
*/

void SetupScaling (int maxscaleheight)
{
	int		i;

	insetupscaling = true;

	maxscaleheight /= 2;			// one scaler every two pixels

	maxscale = maxscaleheight-1;
	maxscaleshl2 = maxscale<<2;

//
// free up old scalers
//
	for (i = 1; i < MAXSCALEHEIGHT; i++)
	{
		if (scaledirectory[i])
		{
			// Avoid double-free: when stepbytwo aliasing is used,
			// entries i+1 and i+2 may point to the same allocation as i
			if (i+1 < MAXSCALEHEIGHT+1 && scaledirectory[i+1] == scaledirectory[i])
				scaledirectory[i+1] = NULL;
			if (i+2 < MAXSCALEHEIGHT+1 && scaledirectory[i+2] == scaledirectory[i])
				scaledirectory[i+2] = NULL;
			free(scaledirectory[i]);
			scaledirectory[i] = NULL;
		}
		if (i >= stepbytwo)
			i += 2;
	}
	memset(scaledirectory, 0, sizeof(scaledirectory));

//
// build the scaling lookup tables
//
	stepbytwo = viewheight / 2;		// save space by double stepping

	for (i = 1; i <= maxscaleheight; i++)
	{
		int height = i * 2;
		long step = ((long)height << 16) / 64;
		long fix = 0;
		int src, startpix, endpix, toppix;
		t_compscale *sc;

		sc = (t_compscale *)malloc(sizeof(t_compscale));
		if (!sc)
			Quit("SetupScaling: out of memory!");
		memset(sc, 0, sizeof(t_compscale));

		toppix = (viewheight - height) / 2;

		for (src = 0; src <= 64; src++)
		{
			startpix = fix >> 16;
			fix += step;
			endpix = fix >> 16;

			if (endpix > startpix)
				sc->width[src] = endpix - startpix;
			else
				sc->width[src] = 0;

			// codeofs stores the starting screen row for this source pixel
			sc->codeofs[src] = startpix + toppix;
		}

		scaledirectory[i] = sc;

		if (i >= stepbytwo)
		{
			scaledirectory[i+1] = sc;
			scaledirectory[i+2] = sc;
			i += 2;
		}
	}

	scaledirectory[0] = scaledirectory[1];

	insetupscaling = false;
}

//===========================================================================

/*
=======================
=
= ScaleLine
=
= Draws a single vertical column of a sprite, scaled to the screen.
= Uses the lookup tables built by SetupScaling.
=
= Globals used:
=   slinex      - screen x position to draw at
=   slinewidth  - number of screen pixels wide (usually 1)
=   linecmds    - pointer to the shape column's command list
=   linescale   - (uintptr_t) pointer to the t_compscale table
=   shape_seg   - base pointer to the shape data (set before calling)
=
= The command list format for each column of the shape:
=   [end_texel*2] [source_offset] [start_texel*2]  (repeat)
=   [0] terminates
=
= end_texel*2 and start_texel*2 are byte offsets into codeofs[]
= (each codeofs entry is 2 bytes, so divide by 2 to get the texel index).
= source_offset is the byte offset from the start of the shape to the
= corrected source pixel data for this segment.
=
=======================
*/

// Set before ScaleLine is called - base of the shape data
static byte *scaleline_shape_base;

// SDL3: viewport pixel offsets (computed from screenofs)
#define VIEWYOFS	(screenofs / SCREENWIDTH)
#define VIEWXOFS	((screenofs % SCREENWIDTH) * 4)

extern	int			slinex,slinewidth;
extern	uint16_t	*linecmds;
extern	t_compscale	*linescale;
extern	unsigned	maskword;


void ScaleLine (void)
{
	t_compscale *comptable = linescale;
	uint16_t *cmds = linecmds;
	int x;
	int yofs = VIEWYOFS;
	int xofs = VIEWXOFS;

	if (!comptable || !cmds || !scaleline_shape_base)
		return;

	// Process each segment in the command list
	while (*cmds)
	{
		unsigned end_ofs = *cmds++;			// end of segment (texel*2, byte offset into codeofs)
		unsigned src_offset = *cmds++;		// source data offset from shape base
		unsigned start_ofs = *cmds++;		// start of segment (texel*2, byte offset into codeofs)

		// Convert byte offsets to texel indices
		int texel_start = start_ofs / 2;
		int texel_end = end_ofs / 2;
		int texel;

		if (texel_start > 64) texel_start = 64;
		if (texel_end > 64) texel_end = 64;

		// For each source texel in this segment, draw the scaled pixels
		for (texel = texel_start; texel < texel_end; texel++)
		{
			int width_pix = comptable->width[texel];
			int screen_y_start = comptable->codeofs[texel];
			byte color;
			int dy;

			if (width_pix <= 0)
				continue;

			// Get the source pixel color from shape data
			// src_offset is already corrected for this segment's position
			color = scaleline_shape_base[src_offset + texel];

			if (color == 0)
				continue;		// transparent (color 0 = background)

			// Draw the scaled pixels for this texel
			for (dy = 0; dy < width_pix; dy++)
			{
				int sy = screen_y_start + dy;
				int screen_y;
				if (sy < 0 || sy >= viewheight)
					continue;

				screen_y = sy + yofs;
				if (screen_y < 0 || screen_y >= 200)
					continue;

				for (x = slinex; x < slinex + slinewidth && (x + xofs) < 320; x++)
				{
					if ((x + xofs) >= 0)
						sdl_screenbuf[screen_y * 320 + x + xofs] = color;
				}
			}
		}
	}
}


/*
=======================
=
= ScaleShape
=
= Draws a compiled shape at [scale] pixels high
=
= each vertical line of the shape has a pointer to segment data:
= 	end of segment pixel*2 (0 terminates line) used to patch rtl in scaler
= 	top of virtual line with segment in proper place
=	start of segment pixel*2, used to jsl into compiled scaler
=	<repeat>
=
=======================
*/

void ScaleShape (int xcenter, int shapenum, unsigned height)
{
	t_compshape	*shape;
	t_compscale *comptable;
	unsigned	scale,srcx,stopx,tempx;
	int			t;
	uint16_t	*cmdptr;
	boolean		leftvis,rightvis;


	shape = (t_compshape *)PM_GetSpritePage (shapenum);

	scale = height>>3;						// low three bits are fractional
	if (!scale || scale>maxscale)
		return;								// too close or far away
	comptable = scaledirectory[scale];

	if (!comptable)
		return;

	linescale = comptable;
	scaleline_shape_base = (byte *)shape;	// set base for ScaleLine

//
// scale to the left (from pixel 31 to shape->leftpix)
//
	srcx = 32;
	slinex = xcenter;
	stopx = shape->leftpix;
	cmdptr = &shape->dataofs[31-stopx];

	while ( --srcx >=stopx && slinex>0)
	{
		linecmds = (uint16_t *)((byte *)shape + *cmdptr--);
		if ( !(slinewidth = comptable->width[srcx]) )
			continue;

		if (slinewidth == 1)
		{
			slinex--;
			if (slinex<viewwidth)
			{
				if (wallheight[slinex] >= height)
					continue;		// obscured by closer wall
				ScaleLine ();
			}
			continue;
		}

		//
		// handle multi pixel lines
		//
		if (slinex>viewwidth)
		{
			slinex -= slinewidth;
			slinewidth = viewwidth-slinex;
			if (slinewidth<1)
				continue;		// still off the right side
		}
		else
		{
			if (slinewidth>slinex)
				slinewidth = slinex;
			slinex -= slinewidth;
		}


		leftvis = (wallheight[slinex] < height);
		rightvis = (wallheight[slinex+slinewidth-1] < height);

		if (leftvis)
		{
			if (rightvis)
				ScaleLine ();
			else
			{
				while (wallheight[slinex+slinewidth-1] >= height)
					slinewidth--;
				ScaleLine ();
			}
		}
		else
		{
			if (!rightvis)
				continue;		// totally obscured

			while (wallheight[slinex] >= height)
			{
				slinex++;
				slinewidth--;
			}
			ScaleLine ();
			break;			// the rest of the shape is gone
		}
	}


//
// scale to the right
//
	slinex = xcenter;
	stopx = shape->rightpix;
	if (shape->leftpix<31)
	{
		srcx = 31;
		cmdptr = &shape->dataofs[32-shape->leftpix];
	}
	else
	{
		srcx = shape->leftpix-1;
		cmdptr = &shape->dataofs[0];
	}
	slinewidth = 0;

	while ( ++srcx <= stopx && (slinex+=slinewidth)<viewwidth)
	{
		linecmds = (uint16_t *)((byte *)shape + *cmdptr++);
		if ( !(slinewidth = comptable->width[srcx]) )
			continue;

		if (slinewidth == 1)
		{
			if (slinex>=0 && wallheight[slinex] < height)
			{
				ScaleLine ();
			}
			continue;
		}

		//
		// handle multi pixel lines
		//
		if (slinex<0)
		{
			if (slinewidth <= -slinex)
				continue;		// still off the left edge

			slinewidth += slinex;
			slinex = 0;
		}
		else
		{
			if (slinex + slinewidth > viewwidth)
				slinewidth = viewwidth-slinex;
		}


		leftvis = (wallheight[slinex] < height);
		rightvis = (wallheight[slinex+slinewidth-1] < height);

		if (leftvis)
		{
			if (rightvis)
			{
				ScaleLine ();
			}
			else
			{
				while (wallheight[slinex+slinewidth-1] >= height)
					slinewidth--;
				ScaleLine ();
				break;			// the rest of the shape is gone
			}
		}
		else
		{
			if (rightvis)
			{
				while (wallheight[slinex] >= height)
				{
					slinex++;
					slinewidth--;
				}
				ScaleLine ();
			}
			else
				continue;		// totally obscured
		}
	}
}



/*
=======================
=
= SimpleScaleShape
=
= NO CLIPPING, height in pixels
=
= Draws a compiled shape at [scale] pixels high
=
=======================
*/

void SimpleScaleShape (int xcenter, int shapenum, unsigned height)
{
	t_compshape	*shape;
	t_compscale *comptable;
	unsigned	scale,srcx,stopx,tempx;
	int			t;
	uint16_t	*cmdptr;
	boolean		leftvis,rightvis;


	shape = (t_compshape *)PM_GetSpritePage (shapenum);

	scale = height>>1;
	if (!scale || scale > maxscale)
		return;
	comptable = scaledirectory[scale];

	linescale = comptable;
	scaleline_shape_base = (byte *)shape;	// set base for ScaleLine

//
// scale to the left (from pixel 31 to shape->leftpix)
//
	srcx = 32;
	slinex = xcenter;
	stopx = shape->leftpix;
	cmdptr = &shape->dataofs[31-stopx];

	while ( --srcx >=stopx )
	{
		linecmds = (uint16_t *)((byte *)shape + *cmdptr--);
		if ( !(slinewidth = comptable->width[srcx]) )
			continue;

		slinex -= slinewidth;
		ScaleLine ();
	}


//
// scale to the right
//
	slinex = xcenter;
	stopx = shape->rightpix;
	if (shape->leftpix<31)
	{
		srcx = 31;
		cmdptr = &shape->dataofs[32-shape->leftpix];
	}
	else
	{
		srcx = shape->leftpix-1;
		cmdptr = &shape->dataofs[0];
	}
	slinewidth = 0;

	while ( ++srcx <= stopx )
	{
		linecmds = (uint16_t *)((byte *)shape + *cmdptr++);
		if ( !(slinewidth = comptable->width[srcx]) )
			continue;

		ScaleLine ();
		slinex+=slinewidth;
	}
}




//
// bit mask tables for drawing scaled strips up to eight pixels wide
//
// These were used for VGA plane masking. Kept for compatibility but
// not used in the SDL3 linear framebuffer rendering.
//

byte	mapmasks1[4][8] = {
{1 ,3 ,7 ,15,15,15,15,15},
{2 ,6 ,14,14,14,14,14,14},
{4 ,12,12,12,12,12,12,12},
{8 ,8 ,8 ,8 ,8 ,8 ,8 ,8} };

byte	mapmasks2[4][8] = {
{0 ,0 ,0 ,0 ,1 ,3 ,7 ,15},
{0 ,0 ,0 ,1 ,3 ,7 ,15,15},
{0 ,0 ,1 ,3 ,7 ,15,15,15},
{0 ,1 ,3 ,7 ,15,15,15,15} };

byte	mapmasks3[4][8] = {
{0 ,0 ,0 ,0 ,0 ,0 ,0 ,0},
{0 ,0 ,0 ,0 ,0 ,0 ,0 ,1},
{0 ,0 ,0 ,0 ,0 ,0 ,1 ,3},
{0 ,0 ,0 ,0 ,0 ,1 ,3 ,7} };


unsigned	wordmasks[8][8] = {
{0x0080,0x00c0,0x00e0,0x00f0,0x00f8,0x00fc,0x00fe,0x00ff},
{0x0040,0x0060,0x0070,0x0078,0x007c,0x007e,0x007f,0x807f},
{0x0020,0x0030,0x0038,0x003c,0x003e,0x003f,0x803f,0xc03f},
{0x0010,0x0018,0x001c,0x001e,0x001f,0x801f,0xc01f,0xe01f},
{0x0008,0x000c,0x000e,0x000f,0x800f,0xc00f,0xe00f,0xf00f},
{0x0004,0x0006,0x0007,0x8007,0xc007,0xe007,0xf007,0xf807},
{0x0002,0x0003,0x8003,0xc003,0xe003,0xf003,0xf803,0xfc03},
{0x0001,0x8001,0xc001,0xe001,0xf001,0xf801,0xfc01,0xfe01} };

int			slinex,slinewidth;
uint16_t	*linecmds;
t_compscale	*linescale;
unsigned	maskword;
