// ID_CA.C

// this has been customized for WOLF

/*
=============================================================================

Id Software Caching Manager
---------------------------

Must be started BEFORE the memory manager, because it needs to get the headers
loaded into the data segment

=============================================================================
*/

#include "ID_HEADS.H"
// #pragma hdrstop  // Borland-specific, removed
// #pragma warn -pro // Borland-specific, removed
// #pragma warn -use // Borland-specific, removed

#define THREEBYTEGRSTARTS

/*
=============================================================================

						 LOCAL CONSTANTS

=============================================================================
*/

typedef struct
{
  uintptr_t bit0,bit1;	// 0-255 is a character, > is a pointer to a node
} huffnode;


// NOTE: This struct maps the on-disk MAPHEAD file layout
#pragma pack(push, 1)
typedef struct
{
	uint16_t	RLEWtag;
	int32_t		headeroffsets[100];
	byte		tileinfo[];
} mapfiletype;
#pragma pack(pop)


/*
=============================================================================

						 GLOBAL VARIABLES

=============================================================================
*/

byte 		*tinf;
int			mapon;

uint16_t	*mapsegs[MAPPLANES];
maptype		*mapheaderseg[NUMMAPS];
byte		*audiosegs[NUMSNDCHUNKS];
void		*grsegs[NUMCHUNKS];

byte		grneeded[NUMCHUNKS];
byte		ca_levelbit,ca_levelnum;

int			profilehandle,debughandle;

char		audioname[13]="AUDIO.";

/*
=============================================================================

						 LOCAL VARIABLES

=============================================================================
*/

#if defined(GRHEADERLINKED) || defined(AUDIOHEADERLINKED) || defined(MAPHEADERLINKED)
extern	long	CGAhead;
extern	long	EGAhead;
extern	byte	CGAdict;
extern	byte	EGAdict;
extern	byte	maphead;
extern	byte	mapdict;
extern	byte	audiohead;
extern	byte	audiodict;
#endif


char extension[5],	// Need a string, not constant to change cache files
     gheadname[10]=GREXT"HEAD.",
     gfilename[10]=GREXT"GRAPH.",
     gdictname[10]=GREXT"DICT.",
     mheadname[10]="MAPHEAD.",
     mfilename[10]="MAPTEMP.",
     aheadname[10]="AUDIOHED.",
     afilename[10]="AUDIOT.";

void CA_CannotOpen(char *string);

long		*grstarts;	// array of offsets in egagraph, -1 for sparse
long		*audiostarts;	// array of offsets in audio / audiot

#ifdef GRHEADERLINKED
huffnode	*grhuffman;
#else
huffnode	grhuffman[255];
#endif

#ifdef AUDIOHEADERLINKED
huffnode	*audiohuffman;
#else
huffnode	audiohuffman[255];
#endif


FILE		*grhandle;		// handle to EGAGRAPH
FILE		*maphandle;		// handle to MAPTEMP / GAMEMAPS
FILE		*audiohandle;	// handle to AUDIOT / AUDIO

long		chunkcomplen,chunkexplen;

SDMode		oldsoundmode;



void	CAL_CarmackExpand (uint16_t *source, uint16_t *dest,
		uint16_t length);


#ifdef THREEBYTEGRSTARTS
#define FILEPOSSIZE	3
//#define	GRFILEPOS(c) (*(long *)(((byte *)grstarts)+(c)*3)&0xffffff)
long GRFILEPOS(int c)
{
	long value;
	int	offset;

	offset = c*3;

	value = *(long *)(((byte *)grstarts)+offset);

	value &= 0x00ffffffl;

	if (value == 0xffffffl)
		value = -1;

	return value;
};
#else
#define FILEPOSSIZE	4
#define	GRFILEPOS(c) (grstarts[c])
#endif

/*
=============================================================================

					   LOW LEVEL ROUTINES

=============================================================================
*/

/*
============================
=
= CA_OpenDebug / CA_CloseDebug
=
= Opens a binary file with the handle "debughandle"
=
============================
*/

void CA_OpenDebug (void)
{
	remove ("DEBUG.TXT");
	// debughandle not used with FILE* approach - kept as stub
}

void CA_CloseDebug (void)
{
	// stub - debug file handling removed
}



/*
============================
=
= CAL_GetGrChunkLength
=
= Gets the length of an explicit length chunk (not tiles)
= The file pointer is positioned so the compressed data can be read in next.
=
============================
*/

void CAL_GetGrChunkLength (int chunk)
{
	fseek(grhandle,GRFILEPOS(chunk),SEEK_SET);
	fread(&chunkexplen,sizeof(chunkexplen),1,grhandle);
	chunkcomplen = GRFILEPOS(chunk+1)-GRFILEPOS(chunk)-4;
}


/*
==========================
=
= CA_FarRead
=
= Read from a file to a pointer
=
==========================
*/

boolean CA_FarRead (FILE *handle, byte *dest, long length)
{
	long bytesread;

	bytesread = (long)fread(dest, 1, length, handle);
	if (bytesread != length)
	{
		return	false;
	}
	return	true;
}


/*
==========================
=
= CA_FarWrite
=
= Write from a pointer to a file
=
==========================
*/

boolean CA_FarWrite (FILE *handle, byte *source, long length)
{
	long byteswritten;

	byteswritten = (long)fwrite(source, 1, length, handle);
	if (byteswritten != length)
	{
		return	false;
	}
	return	true;
}


/*
==========================
=
= CA_ReadFile
=
= Reads a file into an allready allocated buffer
=
==========================
*/

boolean CA_ReadFile (char *filename, memptr *ptr)
{
	FILE *handle;
	long size;

	if ((handle = fopen(filename,"rb")) == NULL)
		return false;

	fseek(handle, 0, SEEK_END);
	size = ftell(handle);
	fseek(handle, 0, SEEK_SET);

	if (!CA_FarRead (handle,*ptr,size))
	{
		fclose (handle);
		return false;
	}
	fclose (handle);
	return true;
}


/*
==========================
=
= CA_WriteFile
=
= Writes a file from a memory buffer
=
==========================
*/

boolean CA_WriteFile (char *filename, void *ptr, long length)
{
	FILE *handle;

	handle = fopen(filename,"wb");

	if (handle == NULL)
		return false;

	if (!CA_FarWrite (handle,ptr,length))
	{
		fclose (handle);
		return false;
	}
	fclose (handle);
	return true;
}



/*
==========================
=
= CA_LoadFile
=
= Allocate space for and load a file
=
==========================
*/

boolean CA_LoadFile (char *filename, memptr *ptr)
{
	FILE *handle;
	long size;

	if ((handle = fopen(filename,"rb")) == NULL)
		return false;

	fseek(handle, 0, SEEK_END);
	size = ftell(handle);
	fseek(handle, 0, SEEK_SET);

	MM_GetPtr (ptr,size);
	if (!CA_FarRead (handle,*ptr,size))
	{
		fclose (handle);
		return false;
	}
	fclose (handle);
	return true;
}

/*
============================================================================

		COMPRESSION routines, see JHUFF.C for more

============================================================================
*/



/*
===============
=
= CAL_OptimizeNodes
=
= Goes through a huffman table and changes the 256-511 node numbers to the
= actural address of the node.  Must be called before CAL_HuffExpand
=
===============
*/

void CAL_OptimizeNodes (huffnode *table)
{
  huffnode *node;
  int i;

  node = table;

  for (i=0;i<255;i++)
  {
	if (node->bit0 >= 256)
	  node->bit0 = (uintptr_t)(table+(node->bit0-256));
	if (node->bit1 >= 256)
	  node->bit1 = (uintptr_t)(table+(node->bit1-256));
	node++;
  }
}



/*
======================
=
= CAL_HuffExpand
=
= Length is the length of the EXPANDED data
= If screenhack, the data is decompressed in four planes directly
= to the screen
=
======================
*/

void CAL_HuffExpand (byte *source, byte *dest,
  long length,huffnode *hufftable, boolean screenhack)
{
  huffnode *headptr;
  huffnode *nodeon;
  byte srcbyte;
  int srcbit;
  byte *srcptr;
  byte *destptr;
  byte *endptr;

  headptr = hufftable+254;	// head node is allways node 254

  // screenhack is not applicable in SDL3 - VGA plane writing removed
  // Just decompress linearly
  (void)screenhack;

  srcptr = source;
  destptr = dest;
  endptr = dest + length;

  srcbyte = *srcptr++;
  srcbit = 1;

  nodeon = headptr;

  while (destptr < endptr)
  {
	uintptr_t val;

	if (srcbyte & srcbit)
		val = nodeon->bit1;
	else
		val = nodeon->bit0;

	srcbit <<= 1;
	if (srcbit == 256)
	{
		srcbyte = *srcptr++;
		srcbit = 1;
	}

	if (val < 256)
	{
		// it's a byte value, not a node pointer
		*destptr++ = (byte)val;
		nodeon = headptr;
	}
	else
	{
		// it's a pointer to the next node
		nodeon = (huffnode *)val;
	}
  }
}


/*
======================
=
= CAL_CarmackExpand
=
= Length is the length of the EXPANDED data
=
======================
*/

#define NEARTAG	0xa7
#define FARTAG	0xa8

void CAL_CarmackExpand (uint16_t *source, uint16_t *dest, uint16_t length)
{
	uint16_t	ch,chhigh,count,offset;
	uint16_t	*copyptr, *outptr;
	byte		*inptr;

	length/=2;

	inptr = (byte *)source;
	outptr = dest;

	while (length)
	{
		ch = *(uint16_t *)inptr;
		inptr += 2;
		chhigh = ch>>8;
		if (chhigh == NEARTAG)
		{
			count = ch&0xff;
			if (!count)
			{				// have to insert a word containing the tag byte
				ch |= *inptr++;
				*outptr++ = ch;
				length--;
			}
			else
			{
				offset = *inptr++;
				copyptr = outptr - offset;
				length -= count;
				while (count--)
					*outptr++ = *copyptr++;
			}
		}
		else if (chhigh == FARTAG)
		{
			count = ch&0xff;
			if (!count)
			{				// have to insert a word containing the tag byte
				ch |= *inptr++;
				*outptr++ = ch;
				length --;
			}
			else
			{
				offset = *(uint16_t *)inptr;
				inptr += 2;
				copyptr = dest + offset;
				length -= count;
				while (count--)
					*outptr++ = *copyptr++;
			}
		}
		else
		{
			*outptr++ = ch;
			length --;
		}
	}
}



/*
======================
=
= CA_RLEWcompress
=
======================
*/

long CA_RLEWCompress (uint16_t *source, long length, uint16_t *dest,
  uint16_t rlewtag)
{
  long complength;
  uint16_t value,count,i;
  uint16_t *start,*end;

  start = dest;

  end = source + (length+1)/2;

//
// compress it
//
  do
  {
	count = 1;
	value = *source++;
	while (*source == value && source<end)
	{
	  count++;
	  source++;
	}
	if (count>3 || value == rlewtag)
	{
    //
    // send a tag / count / value string
    //
      *dest++ = rlewtag;
      *dest++ = count;
      *dest++ = value;
    }
    else
    {
    //
    // send word without compressing
    //
      for (i=1;i<=count;i++)
	*dest++ = value;
	}

  } while (source<end);

  complength = 2*(dest-start);
  return complength;
}


/*
======================
=
= CA_RLEWexpand
= length is EXPANDED length
=
======================
*/

void CA_RLEWexpand (uint16_t *source, uint16_t *dest,long length,
  uint16_t rlewtag)
{
  uint16_t value,count,i;
  uint16_t *end;

//
// expand it
//
  end = dest + (length)/2;

  do
  {
	value = *source++;
	if (value != rlewtag)
	//
	// uncompressed
	//
	  *dest++=value;
	else
	{
	//
	// compressed string
	//
	  count = *source++;
	  value = *source++;
	  for (i=1;i<=count;i++)
	*dest++ = value;
	}
  } while (dest<end);
}



/*
=============================================================================

					 CACHE MANAGER ROUTINES

=============================================================================
*/


/*
======================
=
= CAL_SetupGrFile
=
======================
*/

void CAL_SetupGrFile (void)
{
	char fname[13];
	FILE *handle;
	memptr compseg;

#ifdef GRHEADERLINKED

	grhuffman = (huffnode *)&EGAdict;
	grstarts = (long *)FP_SEG(&EGAhead);

	CAL_OptimizeNodes (grhuffman);

#else

//
// load ???dict.ext (huffman dictionary for graphics files)
//

	strcpy(fname,gdictname);
	strcat(fname,extension);

	if ((handle = fopen(fname, "rb")) == NULL)
		CA_CannotOpen(fname);

	{
		// On-disk huffman nodes use 16-bit unsigned fields
		// Our in-memory huffnode uses uintptr_t, so read and expand
		struct { unsigned short bit0, bit1; } disknode[255];
		int hi;
		fread(disknode, sizeof(disknode), 1, handle);
		for (hi = 0; hi < 255; hi++)
		{
			grhuffman[hi].bit0 = disknode[hi].bit0;
			grhuffman[hi].bit1 = disknode[hi].bit1;
		}
	}
	fclose(handle);
	CAL_OptimizeNodes (grhuffman);
//
// load the data offsets from ???head.ext
//
	MM_GetPtr ((memptr *)&grstarts,(NUMCHUNKS+1)*FILEPOSSIZE);

	strcpy(fname,gheadname);
	strcat(fname,extension);

	if ((handle = fopen(fname, "rb")) == NULL)
		CA_CannotOpen(fname);

	CA_FarRead(handle, (byte *)grstarts, (NUMCHUNKS+1)*FILEPOSSIZE);

	fclose(handle);


#endif

//
// Open the graphics file, leaving it open until the game is finished
//
	strcpy(fname,gfilename);
	strcat(fname,extension);

	grhandle = fopen(fname, "rb");
	if (grhandle == NULL)
		CA_CannotOpen(fname);


//
// load the pic and sprite headers into the arrays in the data segment
//
	MM_GetPtr((memptr *)&pictable,NUMPICS*sizeof(pictabletype));
	CAL_GetGrChunkLength(STRUCTPIC);		// position file pointer
	MM_GetPtr(&compseg,chunkcomplen);
	CA_FarRead (grhandle,compseg,chunkcomplen);
	CAL_HuffExpand (compseg, (byte *)pictable,NUMPICS*sizeof(pictabletype),grhuffman,false);
	MM_FreePtr(&compseg);
}

//==========================================================================


/*
======================
=
= CAL_SetupMapFile
=
======================
*/

void CAL_SetupMapFile (void)
{
	int	i;
	FILE *handle;
	long length,pos;
	char fname[13];

//
// load maphead.ext (offsets and tileinfo for map file)
//
#ifndef MAPHEADERLINKED
	strcpy(fname,mheadname);
	strcat(fname,extension);

	if ((handle = fopen(fname, "rb")) == NULL)
		CA_CannotOpen(fname);

	fseek(handle, 0, SEEK_END);
	length = ftell(handle);
	fseek(handle, 0, SEEK_SET);

	MM_GetPtr ((memptr *)&tinf,length);
	CA_FarRead(handle, tinf, length);
	fclose(handle);
#else

	tinf = (byte *)FP_SEG(&maphead);

#endif

//
// open the data file
//
#ifdef CARMACIZED
	strcpy(fname,"GAMEMAPS.");
	strcat(fname,extension);

	if ((maphandle = fopen(fname, "rb")) == NULL)
		CA_CannotOpen(fname);
#else
	strcpy(fname,mfilename);
	strcat(fname,extension);

	if ((maphandle = fopen(fname, "rb")) == NULL)
		CA_CannotOpen(fname);
#endif

//
// load all map header
//
	for (i=0;i<NUMMAPS;i++)
	{
		pos = ((mapfiletype	*)tinf)->headeroffsets[i];
		if (pos<0)						// $FFFFFFFF start is a sparse map
			continue;

		MM_GetPtr((memptr *)&mapheaderseg[i],sizeof(maptype));
		MM_SetLock((memptr *)&mapheaderseg[i],true);
		fseek(maphandle,pos,SEEK_SET);
		CA_FarRead (maphandle,(byte *)mapheaderseg[i],sizeof(maptype));
	}

//
// allocate space for 3 64*64 planes
//
	for (i=0;i<MAPPLANES;i++)
	{
		MM_GetPtr ((memptr *)&mapsegs[i],64*64*2);
		MM_SetLock ((memptr *)&mapsegs[i],true);
	}
}


//==========================================================================


/*
======================
=
= CAL_SetupAudioFile
=
======================
*/

void CAL_SetupAudioFile (void)
{
	FILE *handle;
	long length;
	char fname[13];

//
// load maphead.ext (offsets and tileinfo for map file)
//
#ifndef AUDIOHEADERLINKED
	strcpy(fname,aheadname);
	strcat(fname,extension);

	if ((handle = fopen(fname, "rb")) == NULL)
		CA_CannotOpen(fname);

	fseek(handle, 0, SEEK_END);
	length = ftell(handle);
	fseek(handle, 0, SEEK_SET);

	MM_GetPtr ((memptr *)&audiostarts,length);
	CA_FarRead(handle, (byte *)audiostarts, length);
	fclose(handle);
#else
	audiohuffman = (huffnode *)&audiodict;
	CAL_OptimizeNodes (audiohuffman);
	audiostarts = (long *)FP_SEG(&audiohead);
#endif

//
// open the data file
//
#ifndef AUDIOHEADERLINKED
	strcpy(fname,afilename);
	strcat(fname,extension);

	if ((audiohandle = fopen(fname, "rb")) == NULL)
		CA_CannotOpen(fname);
#else
	if ((audiohandle = fopen("AUDIO."EXTENSION, "rb")) == NULL)
		Quit ("Can't open AUDIO."EXTENSION"!");
#endif
}

//==========================================================================


/*
======================
=
= CA_Startup
=
= Open all files and load in headers
=
======================
*/

void CA_Startup (void)
{
#ifdef PROFILE
	remove ("PROFILE.TXT");
	// profilehandle not used with FILE* approach
#endif

	CAL_SetupMapFile ();
	CAL_SetupGrFile ();
	CAL_SetupAudioFile ();

	mapon = -1;
	ca_levelbit = 1;
	ca_levelnum = 0;

}

//==========================================================================


/*
======================
=
= CA_Shutdown
=
= Closes all files
=
======================
*/

void CA_Shutdown (void)
{
#ifdef PROFILE
	// profile file handling removed
#endif

	if (maphandle) fclose (maphandle);
	if (grhandle) fclose (grhandle);
	if (audiohandle) fclose (audiohandle);
}

//===========================================================================

/*
======================
=
= CA_CacheAudioChunk
=
======================
*/

void CA_CacheAudioChunk (int chunk)
{
	long	pos,compressed;
#ifdef AUDIOHEADERLINKED
	long	expanded;
	memptr	bigbufferseg;
	byte	*source;
#endif

	if (audiosegs[chunk])
	{
		MM_SetPurge ((memptr *)&audiosegs[chunk],0);
		return;							// allready in memory
	}

//
// load the chunk into a buffer, either the miscbuffer if it fits, or allocate
// a larger buffer
//
	pos = audiostarts[chunk];
	compressed = audiostarts[chunk+1]-pos;

	fseek(audiohandle,pos,SEEK_SET);

#ifndef AUDIOHEADERLINKED

	MM_GetPtr ((memptr *)&audiosegs[chunk],compressed);
	if (mmerror)
		return;

	CA_FarRead(audiohandle,audiosegs[chunk],compressed);

#else

	if (compressed<=BUFFERSIZE)
	{
		CA_FarRead(audiohandle,bufferseg,compressed);
		source = bufferseg;
	}
	else
	{
		MM_GetPtr(&bigbufferseg,compressed);
		if (mmerror)
			return;
		MM_SetLock (&bigbufferseg,true);
		CA_FarRead(audiohandle,bigbufferseg,compressed);
		source = bigbufferseg;
	}

	expanded = *(long *)source;
	source += 4;			// skip over length
	MM_GetPtr ((memptr *)&audiosegs[chunk],expanded);
	if (mmerror)
		goto done;
	CAL_HuffExpand (source,audiosegs[chunk],expanded,audiohuffman,false);

done:
	if (compressed>BUFFERSIZE)
		MM_FreePtr(&bigbufferseg);
#endif
}

//===========================================================================

/*
======================
=
= CA_LoadAllSounds
=
= Purges all sounds, then loads all new ones (mode switch)
=
======================
*/

void CA_LoadAllSounds (void)
{
	unsigned	start,i;

	switch (oldsoundmode)
	{
	case sdm_Off:
		goto cachein;
	case sdm_PC:
		start = STARTPCSOUNDS;
		break;
	case sdm_AdLib:
		start = STARTADLIBSOUNDS;
		break;
	}

	for (i=0;i<NUMSOUNDS;i++,start++)
		if (audiosegs[start])
			MM_SetPurge ((memptr *)&audiosegs[start],3);		// make purgable

cachein:

	switch (SoundMode)
	{
	case sdm_Off:
		return;
	case sdm_PC:
		start = STARTPCSOUNDS;
		break;
	case sdm_AdLib:
		start = STARTADLIBSOUNDS;
		break;
	}

	for (i=0;i<NUMSOUNDS;i++,start++)
		CA_CacheAudioChunk (start);

	oldsoundmode = SoundMode;
}

//===========================================================================


/*
======================
=
= CAL_ExpandGrChunk
=
= Does whatever is needed with a pointer to a compressed chunk
=
======================
*/

void CAL_ExpandGrChunk (int chunk, byte *source)
{
	long	expanded;


	if (chunk >= STARTTILE8 && chunk < STARTEXTERNS)
	{
	//
	// expanded sizes of tile8/16/32 are implicit
	//

#define BLOCK		64
#define MASKBLOCK	128

		if (chunk<STARTTILE8M)			// tile 8s are all in one chunk!
			expanded = BLOCK*NUMTILE8;
		else if (chunk<STARTTILE16)
			expanded = MASKBLOCK*NUMTILE8M;
		else if (chunk<STARTTILE16M)	// all other tiles are one/chunk
			expanded = BLOCK*4;
		else if (chunk<STARTTILE32)
			expanded = MASKBLOCK*4;
		else if (chunk<STARTTILE32M)
			expanded = BLOCK*16;
		else
			expanded = MASKBLOCK*16;
	}
	else
	{
	//
	// everything else has an explicit size longword
	//
		expanded = *(long *)source;
		source += 4;			// skip over length
	}

//
// allocate final space, decompress it, and free bigbuffer
// Sprites need to have shifts made and various other junk
//
	MM_GetPtr (&grsegs[chunk],expanded);
	if (mmerror)
		return;
	CAL_HuffExpand (source,grsegs[chunk],expanded,grhuffman,false);
}


/*
======================
=
= CA_CacheGrChunk
=
= Makes sure a given chunk is in memory, loadiing it if needed
=
======================
*/

void CA_CacheGrChunk (int chunk)
{
	long	pos,compressed;
	memptr	bigbufferseg;
	byte	*source;
	int		next;

	grneeded[chunk] |= ca_levelbit;		// make sure it doesn't get removed
	if (grsegs[chunk])
	{
		MM_SetPurge (&grsegs[chunk],0);
		return;							// allready in memory
	}

//
// load the chunk into a buffer, either the miscbuffer if it fits, or allocate
// a larger buffer
//
	pos = GRFILEPOS(chunk);
	if (pos<0)							// $FFFFFFFF start is a sparse tile
	  return;

	next = chunk +1;
	while (GRFILEPOS(next) == -1)		// skip past any sparse tiles
		next++;

	compressed = GRFILEPOS(next)-pos;

	fseek(grhandle,pos,SEEK_SET);

	if (compressed<=BUFFERSIZE)
	{
		CA_FarRead(grhandle,bufferseg,compressed);
		source = bufferseg;
	}
	else
	{
		MM_GetPtr(&bigbufferseg,compressed);
		MM_SetLock (&bigbufferseg,true);
		CA_FarRead(grhandle,bigbufferseg,compressed);
		source = bigbufferseg;
	}

	CAL_ExpandGrChunk (chunk,source);

	if (compressed>BUFFERSIZE)
		MM_FreePtr(&bigbufferseg);
}



//==========================================================================

/*
======================
=
= CA_CacheScreen
=
= Decompresses a chunk from disk straight onto the screen
=
======================
*/

void CA_CacheScreen (int chunk)
{
	long	pos,compressed,expanded;
	memptr	bigbufferseg;
	byte	*source;
	int		next;

//
// load the chunk into a buffer
//
	pos = GRFILEPOS(chunk);
	next = chunk +1;
	while (GRFILEPOS(next) == -1)		// skip past any sparse tiles
		next++;
	compressed = GRFILEPOS(next)-pos;

	fseek(grhandle,pos,SEEK_SET);

	MM_GetPtr(&bigbufferseg,compressed);
	MM_SetLock (&bigbufferseg,true);
	CA_FarRead(grhandle,bigbufferseg,compressed);
	source = bigbufferseg;

	expanded = *(long *)source;
	source += 4;			// skip over length

//
// allocate final space, decompress it, and free bigbuffer
// Sprites need to have shifts made and various other junk
//
	// In SDL3, we decompress to a temporary buffer, then draw to screen.
	// The decompressed data is already in plane-separated format (the art
	// tools pre-munged it for direct VGA mode-X writes). VL_MemToScreen
	// expects plane-separated data, so we pass it directly -- no VL_MungePic.
	{
		byte *tempbuf = malloc(expanded);
		if (tempbuf)
		{
			CAL_HuffExpand (source, tempbuf, expanded, grhuffman, false);
			VL_MemToScreen (tempbuf, 320, 200, 0, 0);
			free(tempbuf);
		}
	}
	VW_MarkUpdateBlock (0,0,319,199);
	MM_FreePtr(&bigbufferseg);
}

//==========================================================================

/*
======================
=
= CA_CacheMap
=
= WOLF: This is specialized for a 64*64 map size
=
======================
*/

void CA_CacheMap (int mapnum)
{
	long	pos,compressed;
	int		plane;
	memptr	*dest,bigbufferseg;
	unsigned	size;
	uint16_t	*source;
#ifdef CARMACIZED
	memptr	buffer2seg;
	long	expanded;
#endif

	mapon = mapnum;

//
// load the planes into the allready allocated buffers
//
	size = 64*64*2;

	for (plane = 0; plane<MAPPLANES; plane++)
	{
		pos = mapheaderseg[mapnum]->planestart[plane];
		compressed = mapheaderseg[mapnum]->planelength[plane];

		dest = (memptr *)&mapsegs[plane];

		fseek(maphandle,pos,SEEK_SET);
		if (compressed<=BUFFERSIZE)
			source = bufferseg;
		else
		{
			MM_GetPtr(&bigbufferseg,compressed);
			MM_SetLock (&bigbufferseg,true);
			source = bigbufferseg;
		}

		CA_FarRead(maphandle,(byte *)source,compressed);
#ifdef CARMACIZED
		//
		// unhuffman, then unRLEW
		// The huffman'd chunk has a two byte expanded length first
		// The resulting RLEW chunk also does, even though it's not really
		// needed
		//
		expanded = *source;
		source++;
		MM_GetPtr (&buffer2seg,expanded);
		CAL_CarmackExpand (source, (uint16_t *)buffer2seg,expanded);
		CA_RLEWexpand (((uint16_t *)buffer2seg)+1,*dest,size,
		((mapfiletype *)tinf)->RLEWtag);
		MM_FreePtr (&buffer2seg);

#else
		//
		// unRLEW, skipping expanded length
		//
		CA_RLEWexpand (source+1, *dest,size,
		((mapfiletype *)tinf)->RLEWtag);
#endif

		if (compressed>BUFFERSIZE)
			MM_FreePtr(&bigbufferseg);
	}
}

//===========================================================================

/*
======================
=
= CA_UpLevel
=
= Goes up a bit level in the needed lists and clears it out.
= Everything is made purgable
=
======================
*/

void CA_UpLevel (void)
{
	int	i;

	if (ca_levelnum==7)
		Quit ("CA_UpLevel: Up past level 7!");

	for (i=0;i<NUMCHUNKS;i++)
		if (grsegs[i])
			MM_SetPurge ((memptr *)&grsegs[i],3);
	ca_levelbit<<=1;
	ca_levelnum++;
}

//===========================================================================

/*
======================
=
= CA_DownLevel
=
= Goes down a bit level in the needed lists and recaches
= everything from the lower level
=
======================
*/

void CA_DownLevel (void)
{
	if (!ca_levelnum)
		Quit ("CA_DownLevel: Down past level 0!");
	ca_levelbit>>=1;
	ca_levelnum--;
	CA_CacheMarks();
}

//===========================================================================

/*
======================
=
= CA_ClearMarks
=
= Clears out all the marks at the current level
=
======================
*/

void CA_ClearMarks (void)
{
	int i;

	for (i=0;i<NUMCHUNKS;i++)
		grneeded[i]&=~ca_levelbit;
}


//===========================================================================

/*
======================
=
= CA_ClearAllMarks
=
= Clears out all the marks on all the levels
=
======================
*/

void CA_ClearAllMarks (void)
{
	memset (grneeded,0,sizeof(grneeded));
	ca_levelbit = 1;
	ca_levelnum = 0;
}


//===========================================================================


/*
======================
=
= CA_FreeGraphics
=
======================
*/


void CA_SetGrPurge (void)
{
	int i;

//
// free graphics
//
	CA_ClearMarks ();

	for (i=0;i<NUMCHUNKS;i++)
		if (grsegs[i])
			MM_SetPurge ((memptr *)&grsegs[i],3);
}



/*
======================
=
= CA_SetAllPurge
=
= Make everything possible purgable
=
======================
*/

void CA_SetAllPurge (void)
{
	int i;


//
// free sounds
//
	for (i=0;i<NUMSNDCHUNKS;i++)
		if (audiosegs[i])
			MM_SetPurge ((memptr *)&audiosegs[i],3);

//
// free graphics
//
	CA_SetGrPurge ();
}


//===========================================================================

/*
======================
=
= CA_CacheMarks
=
======================
*/
#define MAXEMPTYREAD	1024

void CA_CacheMarks (void)
{
	int 	i,next,numcache;
	long	pos,endpos,nextpos,nextendpos,compressed;
	long	bufferstart,bufferend;	// file position of general buffer
	byte	*source;
	memptr	bigbufferseg;

	numcache = 0;
//
// go through and make everything not needed purgable
//
	for (i=0;i<NUMCHUNKS;i++)
		if (grneeded[i]&ca_levelbit)
		{
			if (grsegs[i])					// its allready in memory, make
				MM_SetPurge(&grsegs[i],0);	// sure it stays there!
			else
				numcache++;
		}
		else
		{
			if (grsegs[i])					// not needed, so make it purgeable
				MM_SetPurge(&grsegs[i],3);
		}

	if (!numcache)			// nothing to cache!
		return;


//
// go through and load in anything still needed
//
	bufferstart = bufferend = 0;		// nothing good in buffer now

	for (i=0;i<NUMCHUNKS;i++)
		if ( (grneeded[i]&ca_levelbit) && !grsegs[i])
		{
			pos = GRFILEPOS(i);
			if (pos<0)
				continue;

			next = i +1;
			while (GRFILEPOS(next) == -1)		// skip past any sparse tiles
				next++;

			compressed = GRFILEPOS(next)-pos;
			endpos = pos+compressed;

			if (compressed<=BUFFERSIZE)
			{
				if (bufferstart<=pos
				&& bufferend>= endpos)
				{
				// data is allready in buffer
					source = (byte *)bufferseg+(pos-bufferstart);
				}
				else
				{
				// load buffer with a new block from disk
				// try to get as many of the needed blocks in as possible
					while ( next < NUMCHUNKS )
					{
						while (next < NUMCHUNKS &&
						!(grneeded[next]&ca_levelbit && !grsegs[next]))
							next++;
						if (next == NUMCHUNKS)
							continue;

						nextpos = GRFILEPOS(next);
						while (GRFILEPOS(++next) == -1)	// skip past any sparse tiles
							;
						nextendpos = GRFILEPOS(next);
						if (nextpos - endpos <= MAXEMPTYREAD
						&& nextendpos-pos <= BUFFERSIZE)
							endpos = nextendpos;
						else
							next = NUMCHUNKS;			// read pos to posend
					}

					fseek(grhandle,pos,SEEK_SET);
					CA_FarRead(grhandle,bufferseg,endpos-pos);
					bufferstart = pos;
					bufferend = endpos;
					source = bufferseg;
				}
			}
			else
			{
			// big chunk, allocate temporary buffer
				MM_GetPtr(&bigbufferseg,compressed);
				if (mmerror)
					return;
				MM_SetLock (&bigbufferseg,true);
				fseek(grhandle,pos,SEEK_SET);
				CA_FarRead(grhandle,bigbufferseg,compressed);
				source = bigbufferseg;
			}

			CAL_ExpandGrChunk (i,source);
			if (mmerror)
				return;

			if (compressed>BUFFERSIZE)
				MM_FreePtr(&bigbufferseg);

		}
}

void CA_CannotOpen(char *string)
{
 char str[30];

 strcpy(str,"Can't open ");
 strcat(str,string);
 strcat(str,"!\n");
 Quit (str);
}
