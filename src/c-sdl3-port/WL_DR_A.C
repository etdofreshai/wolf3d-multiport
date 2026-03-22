// WL_DR_A.C
//
// Replaces WL_DR_A.ASM - Raycaster core loop converted from assembly to C.
//
// Original ASM contained:
//   AsmRefresh - Core ray casting loop that traces rays for each pixel column
//
// The ray tracing logic is a direct translation of the original 16-bit assembly.
// All global variables (tilemap, spotvis, finetangent, etc.) are accessed identically.
//

#include "WL_DEF.H"

#define DEG90		900
#define DEG180		1800
#define DEG270		2700
#define DEG360		3600

// These are declared in WL_DRAW.C and WL_DEF.H
extern	int		midangle;
extern	unsigned	pixx;
extern	int		focaltx, focalty;
extern	int		xtilestep, ytilestep;
extern	unsigned	xpartialup, xpartialdown, ypartialup, ypartialdown;
extern	long	xstep, ystep;
extern	long	xintercept, yintercept;
extern	int		xtile, ytile;
extern	unsigned	tilehit;
extern	int		viewwidth;
extern	byte	tilemap[MAPSIZE][MAPSIZE];
extern	byte	spotvis[MAPSIZE][MAPSIZE];
extern	int		pixelangle[];
extern	long	finetangent[];
extern	unsigned	doorposition[];
extern	unsigned	pwallpos;

extern	void	HitVertWall(void);
extern	void	HitHorizWall(void);
extern	void	HitVertDoor(void);
extern	void	HitHorizDoor(void);
extern	void	HitVertPWall(void);
extern	void	HitHorizPWall(void);


/*
============================

 xpartialbyystep

 multiplies 32-bit ystep by 16-bit xpartial
 The result is the 32-bit (16.16 fixed) product >> 16

============================
*/

static long xpartialbyystep(unsigned xpartial)
{
	long long result = (long long)ystep * (long long)xpartial;
	return (long)(result >> 16);
}

/*
============================

 ypartialbyxstep

 multiplies 32-bit xstep by 16-bit ypartial
 The result is the 32-bit (16.16 fixed) product >> 16

============================
*/

static long ypartialbyxstep(unsigned ypartial)
{
	long long result = (long long)xstep * (long long)ypartial;
	return (long)(result >> 16);
}


/*
============================

 AsmRefresh

 Core ray casting loop.
 For each pixel column, traces a ray until it hits a wall.

 Register mapping from original ASM:
   BX -> xt (xtile for vertical checks)
   BP -> yt (ytile for horizontal checks)
   CX -> xint_hi (high word of xintercept)
   DX -> yint_hi (high word of yintercept)
   SI -> xspot (xt<<6 + yint_hi) - index into tilemap/spotvis
   DI -> yspot (xint_hi<<6 + yt) - index into tilemap/spotvis

============================
*/

void AsmRefresh (void)
{
	int		angle_ray;
	int		xspot, yspot;
	int		xt, yt;
	int		xint_hi, yint_hi;
	unsigned xpar, ypar;

	for (pixx = 0; pixx < (unsigned)viewwidth; pixx++)
	{
		angle_ray = midangle + pixelangle[pixx];

		//
		// Normalize angle to 0..FINEANGLES-1
		//
		if (angle_ray < 0)
			angle_ray += FINEANGLES;
		if (angle_ray >= FINEANGLES)
			angle_ray -= FINEANGLES;

		//
		// Setup based on which quadrant the ray is in
		//
		if (angle_ray < DEG90)
		{
			// 0-89 degrees
			xtilestep = 1;
			ytilestep = -1;
			xstep = finetangent[DEG90-1-angle_ray];
			ystep = -finetangent[angle_ray];
			xpar = xpartialup;
			ypar = ypartialdown;
		}
		else if (angle_ray < DEG180)
		{
			// 90-179 degrees
			xtilestep = -1;
			ytilestep = -1;
			xstep = -finetangent[angle_ray-DEG90];
			ystep = -finetangent[DEG180-1-angle_ray];
			xpar = xpartialdown;
			ypar = ypartialdown;
		}
		else if (angle_ray < DEG270)
		{
			// 180-269 degrees
			xtilestep = -1;
			ytilestep = 1;
			xstep = -finetangent[DEG270-1-angle_ray];
			ystep = finetangent[angle_ray-DEG180];
			xpar = xpartialdown;
			ypar = ypartialup;
		}
		else if (angle_ray < DEG360)
		{
			// 270-359 degrees
			xtilestep = 1;
			ytilestep = 1;
			xstep = finetangent[angle_ray-DEG270];
			ystep = finetangent[DEG360-1-angle_ray];
			xpar = xpartialup;
			ypar = ypartialup;
		}
		else
		{
			// 360+ wraps to 0-89
			angle_ray -= FINEANGLES;
			xtilestep = 1;
			ytilestep = -1;
			xstep = finetangent[DEG90-1-angle_ray];
			ystep = -finetangent[angle_ray];
			xpar = xpartialup;
			ypar = ypartialdown;
		}

		//
		// initialise variables for intersection testing
		//
		yintercept = viewy + xpartialbyystep(xpar);
		xt = focaltx + xtilestep;
		xtile = xt;
		yint_hi = (int)(yintercept >> 16);
		xspot = (xt << 6) + yint_hi;

		xintercept = viewx + ypartialbyxstep(ypar);
		yt = focalty + ytilestep;
		xint_hi = (int)(xintercept >> 16);
		yspot = (xint_hi << 6) + yt;

		//
		// Trace along this angle until we hit a wall
		//
		for (;;)
		{
			int do_vert;

			//
			// The original ASM alternates between vertical and horizontal
			// checks based on which intercept is closer. The comparison
			// determines which wall face the ray reaches first.
			//

			// vertcheck: compare yint_hi against yt
			if (ytilestep == -1)
				do_vert = (yint_hi > yt);		// jle skips to horiz when yint_hi <= yt
			else
				do_vert = (yint_hi < yt);		// jge skips to horiz when yint_hi >= yt

			if (do_vert)
			{
				// ---------- Check vertical wall ----------
				byte tile = *((byte *)tilemap + xspot);
				if (tile)
				{
					tilehit = tile;
					if (tile & 0x80)
					{
						// Door or pushwall
						int save_xt = xt;
						int save_yint_hi = yint_hi;

						if (tile & 0x40)
						{
							// Pushable wall
							long long tmp = (long long)ystep * (long long)pwallpos;
							long partial = (long)(tmp >> 6);	// divide by 64
							long newy = yintercept + partial;
							int newhi = (int)(newy >> 16);

							if (newhi != save_yint_hi)
								goto vert_pass;		// hit side, not pushwall face

							yintercept = newy;
							xintercept = ((long)xt << 16);
							HitVertPWall();
							goto nextpix;
						}
						else
						{
							// Vertical door
							int doornum_local = tile & 0x7f;
							long halfstep = ystep >> 1;
							long newy = yintercept + halfstep;
							int newhi = (int)(newy >> 16);

							if (newhi != (int)(yintercept >> 16))
								goto vert_pass;		// midpoint outside tile

							if ((unsigned)(newy & 0xFFFF) < doorposition[doornum_local])
								goto vert_pass;		// door open past this point

							yintercept = newy;
							xintercept = ((long)xt << 16) | 0x8000;
							HitVertDoor();
							goto nextpix;
						}
					}
					else
					{
						// Solid wall
						xintercept = ((long)xt << 16);
						xtile = xt;
						yintercept = (yintercept & 0xFFFF) | ((long)yint_hi << 16);
						ytile = yint_hi;
						HitVertWall();
						goto nextpix;
					}
				}
			vert_pass:
				// Mark visible and advance vertical
				*((byte *)spotvis + xspot) = 1;
				xt += xtilestep;
				yintercept += ystep;
				yint_hi = (int)(yintercept >> 16);
				xspot = (xt << 6) + yint_hi;
				continue;
			}

			// horizcheck: compare xint_hi against xt
			{
				int do_horiz;
				if (xtilestep == -1)
					do_horiz = (xint_hi > xt);		// jle skips to vert when xint_hi <= xt
				else
					do_horiz = (xint_hi < xt);		// jge skips to vert when xint_hi >= xt

				if (do_horiz)
				{
					// ---------- Check horizontal wall ----------
					byte tile = *((byte *)tilemap + yspot);
					if (tile)
					{
						tilehit = tile;
						if (tile & 0x80)
						{
							// Door or pushwall
							int save_xt = xt;
							int save_yint_hi = yint_hi;

							if (tile & 0x40)
							{
								// Pushable wall
								long long tmp = (long long)xstep * (long long)pwallpos;
								long partial = (long)(tmp >> 6);
								long newx = xintercept + partial;
								int newhi = (int)(newx >> 16);

								if (newhi != xint_hi)
								{
									xt = save_xt;
									yint_hi = save_yint_hi;
									goto horiz_pass;
								}

								xintercept = newx;
								yintercept = ((long)yt << 16);
								HitHorizPWall();
								goto nextpix;
							}
							else
							{
								// Horizontal door
								int doornum_local = tile & 0x7f;
								long halfstep = xstep >> 1;
								long newx = xintercept + halfstep;
								int newhi = (int)(newx >> 16);

								if (newhi != xint_hi)
								{
									xt = save_xt;
									yint_hi = save_yint_hi;
									goto horiz_pass;
								}

								if ((unsigned)(newx & 0xFFFF) < doorposition[doornum_local])
								{
									xt = save_xt;
									yint_hi = save_yint_hi;
									goto horiz_pass;
								}

								xintercept = newx;
								yintercept = ((long)yt << 16) | 0x8000;
								HitHorizDoor();
								goto nextpix;
							}
						}
						else
						{
							// Solid wall
							xintercept = (xintercept & 0xFFFF) | ((long)xint_hi << 16);
							xtile = xint_hi;
							yintercept = ((long)yt << 16);
							ytile = yt;
							HitHorizWall();
							goto nextpix;
						}
					}
				horiz_pass:
					// Mark visible and advance horizontal
					*((byte *)spotvis + yspot) = 1;
					yt += ytilestep;
					xintercept += xstep;
					xint_hi = (int)(xintercept >> 16);
					yspot = (xint_hi << 6) + yt;
					continue;
				}

				//
				// Both comparisons say to check the other direction.
				// This means the intercepts are at the same tile boundary.
				// Check vertical first (matching original ASM fall-through).
				//
				{
					byte tile = *((byte *)tilemap + xspot);
					if (tile)
					{
						tilehit = tile;
						if (tile & 0x80)
						{
							if (tile & 0x40)
							{
								long long tmp = (long long)ystep * (long long)pwallpos;
								long partial = (long)(tmp >> 6);
								long newy = yintercept + partial;
								int newhi = (int)(newy >> 16);

								if (newhi != yint_hi)
									goto tiebreak_vert_pass;

								yintercept = newy;
								xintercept = ((long)xt << 16);
								HitVertPWall();
								goto nextpix;
							}
							else
							{
								int doornum_local = tile & 0x7f;
								long halfstep = ystep >> 1;
								long newy = yintercept + halfstep;
								int newhi = (int)(newy >> 16);

								if (newhi != (int)(yintercept >> 16))
									goto tiebreak_vert_pass;
								if ((unsigned)(newy & 0xFFFF) < doorposition[doornum_local])
									goto tiebreak_vert_pass;

								yintercept = newy;
								xintercept = ((long)xt << 16) | 0x8000;
								HitVertDoor();
								goto nextpix;
							}
						}
						else
						{
							xintercept = ((long)xt << 16);
							xtile = xt;
							yintercept = (yintercept & 0xFFFF) | ((long)yint_hi << 16);
							ytile = yint_hi;
							HitVertWall();
							goto nextpix;
						}
					}
				tiebreak_vert_pass:
					*((byte *)spotvis + xspot) = 1;
					xt += xtilestep;
					yintercept += ystep;
					yint_hi = (int)(yintercept >> 16);
					xspot = (xt << 6) + yint_hi;
				}
			}
		}

	nextpix:
		;	// continue to next pixel column
	}
}
