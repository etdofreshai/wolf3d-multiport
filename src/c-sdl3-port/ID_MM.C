// NEWMM.C

/*
=============================================================================

		   ID software memory manager
		   --------------------------

Primary coder: John Carmack

RELIES ON
---------
Quit (char *error) function


WORK TO DO
----------
MM_SizePtr to change the size of a given pointer

Multiple purge levels utilized

EMS / XMS unmanaged routines

=============================================================================
*/

#include "ID_HEADS.H"

/*
=============================================================================

							LOCAL INFO

=============================================================================
*/

#define LOCKBIT		0x80	// if set in attributes, block cannot be moved
#define PURGEBITS	3		// 0-3 level, 0= unpurgable, 3= purge first
#define PURGEMASK	0xfffc
#define BASEATTRIBUTES	0	// unlocked, non purgable

typedef struct mmblockstruct
{
	unsigned long	start;		// byte offset (was paragraph in DOS)
	unsigned long	length;		// size in bytes (was paragraphs in DOS)
	unsigned	attributes;
	memptr		*useptr;	// pointer to the segment start
	struct mmblockstruct *next;
} mmblocktype;


#define GETNEWBLOCK {if(!mmfree)MML_ClearBlock();mmnew=mmfree;mmfree=mmfree->next;}

#define FREEBLOCK(x) {*x->useptr=NULL;x->next=mmfree;mmfree=x;}

/*
=============================================================================

						 GLOBAL VARIABLES

=============================================================================
*/

mminfotype	mminfo;
memptr		bufferseg;
boolean		mmerror;

void		(* beforesort) (void);
void		(* aftersort) (void);

/*
=============================================================================

						 LOCAL VARIABLES

=============================================================================
*/

boolean		mmstarted;

mmblocktype	mmblocks[MAXBLOCKS]
			,*mmhead,*mmfree,*mmrover,*mmnew;

boolean		bombonerror;

//==========================================================================

//
// local prototypes
//

void 		MML_ClearBlock (void);

//==========================================================================

/*
====================
=
= MML_ClearBlock
=
= We are out of blocks, so free a purgable block
=
====================
*/

void MML_ClearBlock (void)
{
	mmblocktype *scan,*last;

	scan = mmhead->next;

	while (scan)
	{
		if (!(scan->attributes&LOCKBIT) && (scan->attributes&PURGEBITS) )
		{
			MM_FreePtr(scan->useptr);
			return;
		}
		scan = scan->next;
	}

	Quit ("MM_ClearBlock: No purgable blocks!");
}


//==========================================================================

/*
===================
=
= MM_Startup
=
= Grabs all space from turbo with malloc/farmalloc
= Allocates bufferseg misc buffer
=
===================
*/

void MM_Startup (void)
{
	int i;

	if (mmstarted)
		MM_Shutdown ();


	mmstarted = true;
	bombonerror = true;
//
// set up the linked list (everything in the free list;
//
	mmhead = NULL;
	mmfree = &mmblocks[0];
	for (i=0;i<MAXBLOCKS-1;i++)
		mmblocks[i].next = &mmblocks[i+1];
	mmblocks[i].next = NULL;

//
// locked block of all memory until we punch out free space
//
	GETNEWBLOCK;
	mmhead = mmnew;				// this will allways be the first node
	mmnew->start = 0;
	mmnew->length = 0;
	mmnew->attributes = LOCKBIT;
	mmnew->next = NULL;
	mmrover = mmhead;

	mminfo.nearheap = 0;
	mminfo.farheap = 0;
	mminfo.mainmem = 16 * 1024 * 1024;		// report 16 MB available
	mminfo.EMSmem = 0;
	mminfo.XMSmem = 0;

//
// allocate the misc buffer
//
	MM_GetPtr (&bufferseg,BUFFERSIZE);
}

//==========================================================================

/*
====================
=
= MM_Shutdown
=
= Frees all conventional, EMS, and XMS allocated
=
====================
*/

void MM_Shutdown (void)
{
	mmblocktype *scan,*next;

	if (!mmstarted)
		return;

	scan = mmhead;
	while (scan)
	{
		next = scan->next;
		if (scan->useptr && *scan->useptr)
		{
			free(*scan->useptr);
			*scan->useptr = NULL;
		}
		scan = next;
	}

	mmstarted = false;
}

//==========================================================================

/*
====================
=
= MM_GetPtr
=
= Allocates an unlocked, unpurgable block
=
====================
*/

void MM_GetPtr (memptr *baseptr,unsigned long size)
{
	if (!size)
		size = 1;		// minimum allocation

	GETNEWBLOCK;
	mmnew->length = size;
	mmnew->useptr = baseptr;
	mmnew->attributes = BASEATTRIBUTES;
	mmnew->start = 0;

	*baseptr = malloc(size);
	if (!*baseptr)
	{
		if (bombonerror)
		{
extern char configname[];
extern	boolean	insetupscaling;
extern	int	viewsize;
boolean SetViewSize (unsigned width, unsigned height);
#define HEIGHTRATIO		0.50
//
// wolf hack -- size the view down
//
			if (!insetupscaling && viewsize>10)
			{
mmblocktype	*savedmmnew;
				savedmmnew = mmnew;
				viewsize -= 2;
				SetViewSize (viewsize*16,viewsize*16*HEIGHTRATIO);
				mmnew = savedmmnew;
				// retry allocation
				*baseptr = malloc(size);
				if (*baseptr)
				{
					// insert block into list after mmrover
					mmnew->next = mmrover->next;
					mmrover->next = mmnew;
					mmrover = mmnew;
					return;
				}
			}

			Quit ("MM_GetPtr: Out of memory!");
		}
		else
		{
			mmerror = true;
			// put block back on free list
			mmnew->next = mmfree;
			mmfree = mmnew;
			return;
		}
	}

	// insert block into list after mmrover
	mmnew->next = mmrover->next;
	mmrover->next = mmnew;
	mmrover = mmnew;
}

//==========================================================================

/*
====================
=
= MM_FreePtr
=
= Deallocates an unlocked, purgable block
=
====================
*/

void MM_FreePtr (memptr *baseptr)
{
	mmblocktype *scan,*last;

	last = mmhead;
	scan = last->next;

	if (baseptr == mmrover->useptr)	// removed the last allocated block
		mmrover = mmhead;

	while (scan && scan->useptr != baseptr)
	{
		last = scan;
		scan = scan->next;
	}

	if (!scan)
		Quit ("MM_FreePtr: Block not found!");

	last->next = scan->next;

	if (*baseptr)
		free(*baseptr);
	*baseptr = NULL;

	scan->next = mmfree;
	mmfree = scan;
}
//==========================================================================

/*
=====================
=
= MM_SetPurge
=
= Sets the purge level for a block (locked blocks cannot be made purgable)
=
=====================
*/

void MM_SetPurge (memptr *baseptr, int purge)
{
	mmblocktype *start;

	start = mmrover;

	do
	{
		if (mmrover->useptr == baseptr)
			break;

		mmrover = mmrover->next;

		if (!mmrover)
			mmrover = mmhead;
		else if (mmrover == start)
			Quit ("MM_SetPurge: Block not found!");

	} while (1);

	mmrover->attributes &= ~PURGEBITS;
	mmrover->attributes |= purge;
}

//==========================================================================

/*
=====================
=
= MM_SetLock
=
= Locks / unlocks the block
=
=====================
*/

void MM_SetLock (memptr *baseptr, boolean locked)
{
	mmblocktype *start;

	start = mmrover;

	do
	{
		if (mmrover->useptr == baseptr)
			break;

		mmrover = mmrover->next;

		if (!mmrover)
			mmrover = mmhead;
		else if (mmrover == start)
			Quit ("MM_SetLock: Block not found!");

	} while (1);

	mmrover->attributes &= ~LOCKBIT;
	mmrover->attributes |= locked*LOCKBIT;
}

//==========================================================================

/*
=====================
=
= MM_SortMem
=
= Throws out all purgable stuff and compresses movable blocks
=
=====================
*/

void MM_SortMem (void)
{
	mmblocktype *scan,*last,*next;
	int			playing;

	//
	// lock down a currently playing sound
	//
	playing = SD_SoundPlaying ();
	if (playing)
	{
		switch (SoundMode)
		{
		case sdm_PC:
			playing += STARTPCSOUNDS;
			break;
		case sdm_AdLib:
			playing += STARTADLIBSOUNDS;
			break;
		}
		MM_SetLock((memptr *)&audiosegs[playing],true);
	}


	SD_StopSound();

	if (beforesort)
		beforesort();

	scan = mmhead;

	last = NULL;		// shut up compiler warning

	while (scan)
	{
		if (scan->attributes & LOCKBIT)
		{
		//
		// block is locked, skip it
		//
		}
		else
		{
			if (scan->attributes & PURGEBITS)
			{
			//
			// throw out the purgable block
			//
				next = scan->next;
				if (scan->useptr && *scan->useptr)
				{
					free(*scan->useptr);
				}
				FREEBLOCK(scan);
				last->next = next;
				scan = next;
				continue;
			}
			//
			// non-purgable, non-locked block: leave in place
			// (no memory compaction needed on modern systems)
			//
		}

		last = scan;
		scan = scan->next;		// go to next block
	}

	mmrover = mmhead;

	if (aftersort)
		aftersort();

	if (playing)
		MM_SetLock((memptr *)&audiosegs[playing],false);
}


//==========================================================================

/*
=====================
=
= MM_ShowMemory
=
=====================
*/

void MM_ShowMemory (void)
{
	// No-op on modern systems (was DOS VGA memory visualization)
}

//==========================================================================

/*
=====================
=
= MM_DumpData
=
=====================
*/

void MM_DumpData (void)
{
	mmblocktype *scan,*best;
	long	lowest,oldlowest;
	unsigned long	owner;
	char	lock,purge;
	FILE	*dumpfile;


	dumpfile = fopen ("MMDUMP.TXT","w");
	if (!dumpfile)
		Quit ("MM_DumpData: Couldn't open MMDUMP.TXT!");

	lowest = -1;
	do
	{
		oldlowest = lowest;
		lowest = 0xffff;

		scan = mmhead;
		while (scan)
		{
			owner = (unsigned long)(uintptr_t)scan->useptr;

			if (owner && owner<(unsigned long)lowest && owner > (unsigned long)oldlowest)
			{
				best = scan;
				lowest = owner;
			}

			scan = scan->next;
		}

		if (lowest != 0xffff)
		{
			if (best->attributes & PURGEBITS)
				purge = 'P';
			else
				purge = '-';
			if (best->attributes & LOCKBIT)
				lock = 'L';
			else
				lock = '-';
			fprintf (dumpfile,"0x%p (%c%c) = %lu\n"
			,(void *)(uintptr_t)lowest,lock,purge,best->length);
		}

	} while (lowest != 0xffff);

	fclose (dumpfile);
	Quit ("MMDUMP.TXT created.");
}

//==========================================================================


/*
======================
=
= MM_UnusedMemory
=
= Returns the total free space without purging
=
======================
*/

long MM_UnusedMemory (void)
{
	// On modern systems, return a large value
	// Real available memory is essentially unlimited compared to DOS
	return 16 * 1024 * 1024;	// 16 MB
}

//==========================================================================


/*
======================
=
= MM_TotalFree
=
= Returns the total free space with purging
=
======================
*/

long MM_TotalFree (void)
{
	// On modern systems, return a large value
	return 16 * 1024 * 1024;	// 16 MB
}

//==========================================================================

/*
=====================
=
= MM_BombOnError
=
=====================
*/

void MM_BombOnError (boolean bomb)
{
	bombonerror = bomb;
}

//==========================================================================

/*
=====================
=
= MM_MapEMS
=
= No-op on modern systems (no EMS)
=
=====================
*/

void MM_MapEMS (void)
{
	// No-op
}

//==========================================================================

/*
=====================
=
= MML_UseSpace
=
= No-op on modern systems (was DOS segment reclamation)
=
=====================
*/

void MML_UseSpace (unsigned segstart, unsigned seglength)
{
	(void)segstart;
	(void)seglength;
	// No-op - DOS segment management not needed
}
