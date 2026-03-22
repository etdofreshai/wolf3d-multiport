// ID_VH.C
// Ported from DOS/VGA to SDL3

#include "ID_HEADS.H"

#define CHARWIDTH		2
#define TILEWIDTH		4
#define GRPLANES		4
#define BYTEPIXELS		4

#define SCREENXMASK		(~3)
#define SCREENXPLUS		(3)
#define SCREENXDIV		(4)

#define VIEWWIDTH		80

#define PIXTOBLOCK		4		// 16 pixels to an update block

#define UNCACHEGRCHUNK(chunk)	{MM_FreePtr(&grsegs[chunk]);grneeded[chunk]&=~ca_levelbit;}

// update[] is defined in WL_PLAY.C
extern byte	update[];

//==========================================================================

pictabletype	*pictable;


int	px,py;
byte	fontcolor,backcolor;
int	fontnumber;
int bufferwidth,bufferheight;


//==========================================================================

void	VWL_UpdateScreenBlocks (void);

//==========================================================================

void VW_DrawPropString (char *string)
{
	fontstruct	*font;
	int		width,step,height;
	byte	*source;
	byte	ch;
	int		startpx;

	font = (fontstruct *)grsegs[STARTFONT+fontnumber];
	height = bufferheight = font->height;
	startpx = px;

	while ((ch = *string++)!=0)
	{
		width = step = font->width[ch];
		source = ((byte *)font)+font->location[ch];
		while (width--)
		{
			int row;
			for (row = 0; row < height; row++)
			{
				byte val = source[row * step];
				if (val)
				{
					// draw pixel at (px, py+row) with fontcolor
					if (px >= 0 && px < 320 && (py+row) >= 0 && (py+row) < 200)
						sdl_screenbuf[(py+row)*320 + px] = fontcolor;
				}
			}
			source++;
			px++;
		}
	}
	bufferheight = height;
	bufferwidth = px - startpx;
}


void VW_DrawColorPropString (char *string)
{
	fontstruct	*font;
	int		width,step,height;
	byte	*source;
	byte	ch;
	byte	color;
	int		startpx;

	font = (fontstruct *)grsegs[STARTFONT+fontnumber];
	height = bufferheight = font->height;
	color = fontcolor;
	startpx = px;

	while ((ch = *string++)!=0)
	{
		width = step = font->width[ch];
		source = ((byte *)font)+font->location[ch];
		while (width--)
		{
			int row;
			byte curcolor = color;
			for (row = 0; row < height; row++)
			{
				byte val = source[row * step];
				if (val)
				{
					if (px >= 0 && px < 320 && (py+row) >= 0 && (py+row) < 200)
						sdl_screenbuf[(py+row)*320 + px] = curcolor;
				}
				// increment color every other row (original checked loop counter parity)
				// counter = height - row; increment when counter is even
				if (!(( height - row) & 1))
					curcolor++;
			}
			source++;
			px++;
		}
	}
	bufferheight = height;
	bufferwidth = px - startpx;
}


//==========================================================================


/*
=================
=
= VL_MungePic
=
=================
*/

void VL_MungePic (byte *source, unsigned width, unsigned height)
{
	unsigned	x,y,plane,size,pwidth;
	byte		*temp, *dest, *srcline;

	size = width*height;

	if (width&3)
		MS_Quit ("VL_MungePic: Not divisable by 4!");

//
// copy the pic to a temp buffer
//
	MM_GetPtr ((memptr *)&temp,size);
	memcpy (temp,source,size);

//
// munge it back into the original buffer
//
	dest = source;
	pwidth = width/4;

	for (plane=0;plane<4;plane++)
	{
		srcline = temp;
		for (y=0;y<height;y++)
		{
			for (x=0;x<pwidth;x++)
				*dest++ = *(srcline+x*4+plane);
			srcline+=width;
		}
	}

	MM_FreePtr ((memptr *)&temp);
}

void VWL_MeasureString (char *string, word *width, word *height
	, fontstruct *font)
{
	*height = font->height;
	for (*width = 0;*string;string++)
		*width += font->width[*((byte *)string)];	// proportional width
}

void	VW_MeasurePropString (char *string, word *width, word *height)
{
	VWL_MeasureString(string,width,height,(fontstruct *)grsegs[STARTFONT+fontnumber]);
}

void	VW_MeasureMPropString  (char *string, word *width, word *height)
{
	VWL_MeasureString(string,width,height,(fontstruct *)grsegs[STARTFONTM+fontnumber]);
}



/*
=============================================================================

				Double buffer management routines

=============================================================================
*/


/*
=======================
=
= VW_MarkUpdateBlock
=
= Takes a pixel bounded block and marks the tiles in bufferblocks
= Returns 0 if the entire block is off the buffer screen
=
=======================
*/

int VW_MarkUpdateBlock (int x1, int y1, int x2, int y2)
{
	int	x,y,xt1,yt1,xt2,yt2,nextline;
	byte *mark;

	xt1 = x1>>PIXTOBLOCK;
	yt1 = y1>>PIXTOBLOCK;

	xt2 = x2>>PIXTOBLOCK;
	yt2 = y2>>PIXTOBLOCK;

	if (xt1<0)
		xt1=0;
	else if (xt1>=UPDATEWIDE)
		return 0;

	if (yt1<0)
		yt1=0;
	else if (yt1>UPDATEHIGH)
		return 0;

	if (xt2<0)
		return 0;
	else if (xt2>=UPDATEWIDE)
		xt2 = UPDATEWIDE-1;

	if (yt2<0)
		return 0;
	else if (yt2>=UPDATEHIGH)
		yt2 = UPDATEHIGH-1;

	mark = updateptr + uwidthtable[yt1] + xt1;
	nextline = UPDATEWIDE - (xt2-xt1) - 1;

	for (y=yt1;y<=yt2;y++)
	{
		for (x=xt1;x<=xt2;x++)
			*mark++ = 1;			// this tile will need to be updated

		mark += nextline;
	}

	return 1;
}

void VWB_DrawTile8 (int x, int y, int tile)
{
	if (VW_MarkUpdateBlock (x,y,x+7,y+7))
		LatchDrawChar(x,y,tile);
}

void VWB_DrawTile8M (int x, int y, int tile)
{
	if (VW_MarkUpdateBlock (x,y,x+7,y+7))
		VL_MemToScreen (((byte *)grsegs[STARTTILE8M])+tile*64,8,8,x,y);
}


void VWB_DrawPic (int x, int y, int chunknum)
{
	int	picnum = chunknum - STARTPICS;
	unsigned width,height;

	x &= ~7;

	width = pictable[picnum].width;
	height = pictable[picnum].height;

	if (VW_MarkUpdateBlock (x,y,x+width-1,y+height-1))
		VL_MemToScreen (grsegs[chunknum],width,height,x,y);
}



void VWB_DrawPropString	 (char *string)
{
	int x;
	x=px;
	VW_DrawPropString (string);
	VW_MarkUpdateBlock(x,py,px-1,py+bufferheight-1);
}


void VWB_Bar (int x, int y, int width, int height, int color)
{
	if (VW_MarkUpdateBlock (x,y,x+width,y+height-1) )
		VW_Bar (x,y,width,height,color);
}

void VWB_Plot (int x, int y, int color)
{
	if (VW_MarkUpdateBlock (x,y,x,y))
		VW_Plot(x,y,color);
}

void VWB_Hlin (int x1, int x2, int y, int color)
{
	if (VW_MarkUpdateBlock (x1,y,x2,y))
		VW_Hlin(x1,x2,y,color);
}

void VWB_Vlin (int y1, int y2, int x, int color)
{
	if (VW_MarkUpdateBlock (x,y1,x,y2))
		VW_Vlin(y1,y2,x,color);
}

/*
=================
=
= VH_UpdateScreen
=
= Upload the screenbuf to the SDL texture and present.
= This replaces the original ASM tile-copy VH_UpdateScreen.
=
=================
*/

void VH_UpdateScreen (void)
{
	VL_UpdateScreen();
}

void VW_UpdateScreen (void)
{
	VH_UpdateScreen ();
}


/*
=============================================================================

						WOLFENSTEIN STUFF

=============================================================================
*/

/*
=====================
=
= LatchDrawPic
=
=====================
*/

void LatchDrawPic (unsigned x, unsigned y, unsigned picnum)
{
	unsigned wide, height, source;

	wide = pictable[picnum-STARTPICS].width;
	height = pictable[picnum-STARTPICS].height;
	source = latchpics[2+picnum-LATCHPICS_LUMP_START];

	VL_LatchToScreen (source,wide/4,height,x*8,y);
}


//==========================================================================

/*
===================
=
= LoadLatchMem
=
===================
*/

void LoadLatchMem (void)
{
	int	i,j,p,m,width,height,start,end;
	byte	*src;
	unsigned	destoff;

//
// tile 8s
//
	latchpics[0] = freelatch;
	CA_CacheGrChunk (STARTTILE8);
	src = (byte *)grsegs[STARTTILE8];
	destoff = freelatch;

	for (i=0;i<NUMTILE8;i++)
	{
		VL_MemToLatch (src,8,8,destoff);
		src += 64;
		destoff +=16;
	}
	UNCACHEGRCHUNK (STARTTILE8);

#if 0	// ran out of latch space!
//
// tile 16s
//
	src = (byte *)grsegs[STARTTILE16];
	latchpics[1] = destoff;

	for (i=0;i<NUMTILE16;i++)
	{
		CA_CacheGrChunk (STARTTILE16+i);
		src = (byte *)grsegs[STARTTILE16+i];
		VL_MemToLatch (src,16,16,destoff);
		destoff+=64;
		if (src)
			UNCACHEGRCHUNK (STARTTILE16+i);
	}
#endif

//
// pics
//
	start = LATCHPICS_LUMP_START;
	end = LATCHPICS_LUMP_END;

	for (i=start;i<=end;i++)
	{
		latchpics[2+i-start] = destoff;
		CA_CacheGrChunk (i);
		width = pictable[i-STARTPICS].width;
		height = pictable[i-STARTPICS].height;
		VL_MemToLatch (grsegs[i],width,height,destoff);
		destoff += width/4 *height;
		UNCACHEGRCHUNK(i);
	}

	EGAMAPMASK(15);
}

//==========================================================================

/*
===================
=
= FizzleFade
=
= returns true if aborted
=
= Reimplemented without inline ASM. Uses LFSR to generate pseudo-random
= pixel visitation order.
=
===================
*/

extern	ControlInfo	c;

boolean FizzleFade (unsigned source, unsigned dest,
	unsigned width,unsigned height, unsigned frames, boolean abortable)
{
	int			pixperframe;
	unsigned	x,y,p,frame;
	long		rndval;
	static byte	fizzle_src[320*200];	// snapshot of the source screen

	// Take a snapshot of the current screenbuf as the "source" image.
	// The game renders the new frame to screenbuf (at bufferofs), then
	// fizzle-copies it onto the display. Since we only have one screenbuf,
	// we save it first, then clear to the old display, and copy pixels
	// from the snapshot progressively.
	memcpy(fizzle_src, sdl_screenbuf, 320*200);

	rndval = 1;
	pixperframe = 64000/(int)frames;

	IN_StartAck ();

	TimeCount=frame=0;
	do	// while (1)
	{
		if (abortable && IN_CheckAck () )
			return true;

		for (p=0;p<pixperframe;p++)
		{
			//
			// seperate random value into x/y pair
			//
			y = (rndval & 0xFF) - 1;
			x = ((rndval >> 8) & 0x1FF);

			//
			// advance to next random element (LFSR)
			//
			{
				long carry = rndval & 1;
				rndval >>= 1;
				if (carry)
				{
					rndval ^= 0x00012000;
				}
			}

			if (x>width || y>height)
				continue;

			//
			// copy one pixel from saved source to screenbuf
			//
			if (x < 320 && y < 200)
			{
				sdl_screenbuf[y * 320 + x] = fizzle_src[y * 320 + x];
			}

			if (rndval == 1)		// entire sequence has been completed
			{
				memcpy(sdl_screenbuf, fizzle_src, 320*200);
				VL_UpdateScreen();
				return false;
			}
		}
		frame++;
		VL_UpdateScreen();
		while (TimeCount<frame)		// don't go too fast
		{ SD_TimeCountUpdate(); SDL_Delay(1); }
	} while (1);
}
