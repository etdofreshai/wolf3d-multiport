//
//	ID_PM.C
//	Id Engine's Page Manager v1.0
//	Primary coder: Jason Blochowiak
//

#include "ID_HEADS.H"

#ifndef MAXLONG
#define MAXLONG		0x7fffffffl
#endif

//	Main Mem specific variables
	boolean			MainPresent;
	memptr			MainMemPages[PMMaxMainMem];
	PMBlockAttr		MainMemUsed[PMMaxMainMem];
	int				MainPagesAvail;

//	EMS specific variables (kept for interface compat, always false/0)
	boolean			EMSPresent;
	word			EMSAvail,EMSPagesAvail,EMSHandle,
					EMSPageFrame,EMSPhysicalPage;
	EMSListStruct	EMSList[EMSFrameCount];

//	XMS specific variables (kept for interface compat, always false/0)
	boolean			XMSPresent;
	word			XMSAvail,XMSPagesAvail,XMSHandle;
	int				XMSProtectPage = -1;

//	File specific variables
	char			PageFileName[13] = {"VSWAP."};
	int				PageFile = -1;
	word			ChunksInFile;
	word			PMSpriteStart,PMSoundStart;

//	General usage variables
	boolean			PMStarted,
					PMPanicMode,
					PMThrashing;
	word			XMSPagesUsed,
					EMSPagesUsed,
					MainPagesUsed,
					PMNumBlocks;
	long			PMFrameCount;
	PageListStruct	*PMPages;

//	Page data - all pages loaded into memory at startup
	byte			**PMPageData;		// array of pointers to page data

static	char		*ParmStrings[] = {"nomain","noems","noxms",nil};

/////////////////////////////////////////////////////////////////////////////
//
//	File management code
//
/////////////////////////////////////////////////////////////////////////////

//
//	PML_ReadFromFile() - Reads some data in from the page file
//
void
PML_ReadFromFile(byte *buf,long offset,word length)
{
	if (!buf)
		Quit("PML_ReadFromFile: Null pointer");
	if (!offset)
		Quit("PML_ReadFromFile: Zero offset");
	if (lseek(PageFile,offset,SEEK_SET) != offset)
		Quit("PML_ReadFromFile: Seek failed");
	if (read(PageFile,buf,length) != length)
		Quit("PML_ReadFromFile: Read failed");
}

//
//	PML_OpenPageFile() - Opens the page file and sets up the page info
//
void
PML_OpenPageFile(void)
{
	int				i;
	long			size;
	longword		*offsets;
	word			*lengths;
	PageListStruct	*page;

	PageFile = open(PageFileName,O_RDONLY | O_BINARY);
	if (PageFile == -1)
		Quit("PML_OpenPageFile: Unable to open page file");

	// Read in header variables
	read(PageFile,&ChunksInFile,sizeof(ChunksInFile));
	read(PageFile,&PMSpriteStart,sizeof(PMSpriteStart));
	read(PageFile,&PMSoundStart,sizeof(PMSoundStart));

	// Allocate and clear the page list
	PMNumBlocks = ChunksInFile;
	PMPages = (PageListStruct *)malloc(sizeof(PageListStruct) * PMNumBlocks);
	if (!PMPages)
		Quit("PML_OpenPageFile: Failed to allocate page list");
	memset(PMPages,0,sizeof(PageListStruct) * PMNumBlocks);

	// Read in the chunk offsets
	size = sizeof(longword) * ChunksInFile;
	offsets = (longword *)malloc(size);
	if (!offsets)
		Quit("PML_OpenPageFile: Failed to allocate offset buffer");
	if (read(PageFile,offsets,size) != size)
		Quit("PML_OpenPageFile: Offset read failed");
	for (i = 0,page = PMPages;i < ChunksInFile;i++,page++)
		page->offset = offsets[i];
	free(offsets);

	// Read in the chunk lengths
	size = sizeof(word) * ChunksInFile;
	lengths = (word *)malloc(size);
	if (!lengths)
		Quit("PML_OpenPageFile: Failed to allocate length buffer");
	if (read(PageFile,lengths,size) != size)
		Quit("PML_OpenPageFile: Length read failed");
	for (i = 0,page = PMPages;i < ChunksInFile;i++,page++)
		page->length = lengths[i];
	free(lengths);

	// Allocate the page data pointer array
	PMPageData = (byte **)calloc(ChunksInFile, sizeof(byte *));
	if (!PMPageData)
		Quit("PML_OpenPageFile: Failed to allocate page data array");

	// Load all pages into memory
	for (i = 0,page = PMPages;i < ChunksInFile;i++,page++)
	{
		if (page->offset && page->length)
		{
			PMPageData[i] = (byte *)malloc(page->length);
			if (!PMPageData[i])
				Quit("PML_OpenPageFile: Failed to allocate page data");
			PML_ReadFromFile(PMPageData[i], page->offset, page->length);
			page->mainPage = 0;	// mark as present
		}
		else
		{
			PMPageData[i] = NULL;
			page->mainPage = -1;
		}
		page->emsPage = -1;
		page->xmsPage = -1;
		page->locked = pml_Unlocked;
		page->lastHit = 0;
	}
}

//
//  PML_ClosePageFile() - Closes the page file
//
void
PML_ClosePageFile(void)
{
	int i;

	if (PageFile != -1)
	{
		close(PageFile);
		PageFile = -1;
	}

	if (PMPageData)
	{
		for (i = 0; i < ChunksInFile; i++)
		{
			if (PMPageData[i])
			{
				free(PMPageData[i]);
				PMPageData[i] = NULL;
			}
		}
		free(PMPageData);
		PMPageData = NULL;
	}

	if (PMPages)
	{
		free(PMPages);
		PMPages = NULL;
	}
}

/////////////////////////////////////////////////////////////////////////////
//
//	Main memory / allocation code
//
/////////////////////////////////////////////////////////////////////////////

//
//	PM_SetMainMemPurge() - Sets the purge level for all allocated main memory
//		blocks. This shouldn't be called directly - the PM_LockMainMem() and
//		PM_UnlockMainMem() macros should be used instead.
//
void
PM_SetMainMemPurge(int level)
{
	int	i;

	for (i = 0;i < PMMaxMainMem;i++)
		if (MainMemPages[i])
			MM_SetPurge(&MainMemPages[i],level);
}

//
//	PM_CheckMainMem() - If something besides the Page Mgr makes requests of
//		the Memory Mgr, some of the Page Mgr's blocks may have been purged,
//		so this function runs through the block list and checks to see if
//		any of the blocks have been purged. If so, it marks the corresponding
//		page as purged & unlocked, then goes through the block list and
//		tries to reallocate any blocks that have been purged.
//
void
PM_CheckMainMem(void)
{
	boolean			allocfailed;
	int				i,n;
	memptr			*p;
	PMBlockAttr		*used;
	PageListStruct	*page;

	if (!MainPresent)
		return;

	for (i = 0,page = PMPages;i < ChunksInFile;i++,page++)
	{
		n = page->mainPage;
		if (n != -1)						// Is the page using main memory?
		{
			if (!MainMemPages[n])			// Yep, was the block purged?
			{
				page->mainPage = -1;		// Yes, mark page as purged & unlocked
				page->locked = pml_Unlocked;
			}
		}
	}

	// Prevent allocation attempts from purging any of our other blocks
	PM_LockMainMem();
	allocfailed = false;
	for (i = 0,p = MainMemPages,used = MainMemUsed;i < PMMaxMainMem;i++,p++,used++)
	{
		if (!*p)							// If the page got purged
		{
			if (*used & pmba_Allocated)		// If it was allocated
			{
				*used &= ~pmba_Allocated;	// Mark as unallocated
				MainPagesAvail--;			// and decrease available count
			}

			if (*used & pmba_Used)			// If it was used
			{
				*used &= ~pmba_Used;		// Mark as unused
				MainPagesUsed--;			// and decrease used count
			}

			if (!allocfailed)
			{
				MM_BombOnError(false);
				MM_GetPtr(p,PMPageSize);		// Try to reallocate
				if (mmerror)					// If it failed,
					allocfailed = true;			//  don't try any more allocations
				else							// If it worked,
				{
					*used |= pmba_Allocated;	// Mark as allocated
					MainPagesAvail++;			// and increase available count
				}
				MM_BombOnError(true);
			}
		}
	}
	if (mmerror)
		mmerror = false;
}

//
//	PML_StartupMainMem() - Allocates as much main memory as is possible for
//		the Page Mgr. The memory is allocated as non-purgeable, so if it's
//		necessary to make requests of the Memory Mgr, PM_UnlockMainMem()
//		needs to be called.
//
void
PML_StartupMainMem(void)
{
	int		i,n;
	memptr	*p;

	MainPagesAvail = 0;
	MM_BombOnError(false);
	for (i = 0,p = MainMemPages;i < PMMaxMainMem;i++,p++)
	{
		MM_GetPtr(p,PMPageSize);
		if (mmerror)
			break;

		MainPagesAvail++;
		MainMemUsed[i] = pmba_Allocated;
	}
	MM_BombOnError(true);
	if (mmerror)
		mmerror = false;
	if (MainPagesAvail < PMMinMainMem)
		Quit("PM_SetupMainMem: Not enough main memory");
	MainPresent = true;
}

//
//	PML_ShutdownMainMem() - Frees all of the main memory blocks used by the
//		Page Mgr.
//
void
PML_ShutdownMainMem(void)
{
	int		i;
	memptr	*p;

	// DEBUG - mark pages as unallocated & decrease page count as appropriate
	for (i = 0,p = MainMemPages;i < PMMaxMainMem;i++,p++)
		if (*p)
			MM_FreePtr(p);
}

/////////////////////////////////////////////////////////////////////////////
//
//	Page access code (simplified - all pages in memory)
//
/////////////////////////////////////////////////////////////////////////////

//
//	PM_GetPageAddress() - Returns the address of a given page
//		Returns nil if block isn't cached
//
memptr
PM_GetPageAddress(int pagenum)
{
	if (pagenum < 0 || pagenum >= ChunksInFile)
		return nil;
	return (memptr)PMPageData[pagenum];
}

//
//	PM_GetPage() - Returns the address of the page, loading it if necessary
//		All pages are in memory, so just return the pointer
//
memptr
PM_GetPage(int pagenum)
{
	memptr	result;

	if (pagenum >= ChunksInFile)
		Quit("PM_GetPage: Invalid page request");

	result = (memptr)PMPageData[pagenum];

	if (!result)
	{
		if (!PMPages[pagenum].offset)	// JDC: sparse page
			Quit ("Tried to load a sparse page!");

		// Page should have been loaded at startup; this shouldn't happen
		Quit("PM_GetPage: Page not in memory!");
	}

	PMPages[pagenum].lastHit = PMFrameCount;

	return(result);
}

//
//	PM_SetPageLock() - Sets the lock type on a given page
//		pml_Unlocked: Normal, page can be purged
//		pml_Locked: Cannot be purged
//
void
PM_SetPageLock(int pagenum,PMLockType lock)
{
	if (pagenum < PMSoundStart)
		Quit("PM_SetPageLock: Locking/unlocking non-sound page");

	PMPages[pagenum].locked = lock;
}

//
//	PM_Preload() - Loads as many pages as possible into all types of memory.
//		All pages are already in memory, so just call update to completion.
//
void
PM_Preload(boolean (*update)(word current,word total))
{
	// All pages already loaded at startup
	if (update)
		update(1,1);
}

/////////////////////////////////////////////////////////////////////////////
//
//	General code
//
/////////////////////////////////////////////////////////////////////////////

//
//	PM_NextFrame() - Increments the frame counter and adjusts the thrash
//		avoidence variables
//
void
PM_NextFrame(void)
{
	int	i;

	// Frame count overrun - kill the LRU hit entries & reset frame count
	if (++PMFrameCount >= MAXLONG - 4)
	{
		for (i = 0;i < PMNumBlocks;i++)
			PMPages[i].lastHit = 0;
		PMFrameCount = 0;
	}

	if (PMPanicMode)
	{
		// DEBUG - set border color
		if ((!PMThrashing) && (!--PMPanicMode))
		{
			// DEBUG - reset border color
		}
	}
	if (PMThrashing >= PMThrashThreshold)
		PMPanicMode = PMUnThrashThreshold;
	PMThrashing = false;
}

//
//	PM_Reset() - Sets up caching structures
//
void
PM_Reset(void)
{
	int				i;
	PageListStruct	*page;

	XMSPagesAvail = 0;
	EMSPagesAvail = 0;
	EMSPhysicalPage = 0;

	MainPagesUsed = EMSPagesUsed = XMSPagesUsed = 0;

	PMPanicMode = false;

	// Initialize page list
	for (i = 0,page = PMPages;i < PMNumBlocks;i++,page++)
	{
		if (PMPageData[i])
			page->mainPage = 0;	// present
		else
			page->mainPage = -1;
		page->emsPage = -1;
		page->xmsPage = -1;
		page->locked = false;
	}
}

//
//	PM_Startup() - Start up the Page Mgr
//
void
PM_Startup(void)
{
	boolean	nomain,noems,noxms;
	int		i;

	if (PMStarted)
		return;

	nomain = noems = noxms = false;
	for (i = 1;i < _argc;i++)
	{
		switch (US_CheckParm(_argv[i],ParmStrings))
		{
		case 0:
			nomain = true;
			break;
		case 1:
			noems = true;
			break;
		case 2:
			noxms = true;
			break;
		}
	}

	EMSPresent = false;
	XMSPresent = false;

	PML_OpenPageFile();
	PML_StartupMainMem();

	PM_Reset();

	PMStarted = true;
}

//
//	PM_Shutdown() - Shut down the Page Mgr
//
void
PM_Shutdown(void)
{
	if (!PMStarted)
		return;

	PML_ClosePageFile();
	PML_ShutdownMainMem();

	PMStarted = false;
}
