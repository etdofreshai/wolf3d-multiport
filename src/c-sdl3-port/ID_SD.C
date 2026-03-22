//
//	ID Engine
//	ID_SD.c - Sound Manager for Wolfenstein 3D
//	v1.2
//	By Jason Blochowiak
//
//	Ported to SDL3 audio. All DOS port I/O, DMA, interrupt handlers, and
//	inline ASM removed. OPL2 emulated with a minimal register-level approach.
//	PC speaker sounds generate square waves. Digitized sounds play as PCM.
//

//
//	This module handles dealing with generating sound on the appropriate
//		hardware
//
//	Depends on: User Mgr (for parm checking)
//
//	Globals:
//		For User Mgr:
//			SoundSourcePresent - Sound Source thingie present?
//			SoundBlasterPresent - SoundBlaster card present?
//			AdLibPresent - AdLib card present?
//			SoundMode - What device is used for sound effects
//				(Use SM_SetSoundMode() to set)
//			MusicMode - What device is used for music
//				(Use SM_SetMusicMode() to set)
//			DigiMode - What device is used for digitized sound effects
//				(Use SM_SetDigiDevice() to set)
//
//		For Cache Mgr:
//			NeedsDigitized - load digitized sounds?
//			NeedsMusic - load music?
//

#ifdef	_MUSE_      // Will be defined in ID_Types.h
#include "ID_SD.h"
#else
#include "ID_HEADS.H"
#endif

#include <SDL3/SDL.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#ifdef	nil
#undef	nil
#endif
#define	nil	0

#define	SDL_SoundFinished()	{SoundNumber = SoundPriority = 0;}

//	Global variables
	boolean		SoundSourcePresent,
			AdLibPresent,
			SoundBlasterPresent,SBProPresent,
			NeedsDigitized,NeedsMusic,
			SoundPositioned;
	SDMode		SoundMode;
	SMMode		MusicMode;
	SDSMode		DigiMode;
	longword	TimeCount;
	word		HackCount;
	byte		**SoundTable;	// Pointer into audiosegs[] array
	boolean		ssIsTandy;
	word		ssPort = 2;
	int		DigiMap[LASTSOUND];

//	Internal variables
static	boolean			SD_Started;
	boolean			nextsoundpos;
	longword		TimerDivisor,TimerCount;
static	char			*ParmStrings[] =
					{
						"noal",
						"nosb",
						"nopro",
						"noss",
						"sst",
						"ss1",
						"ss2",
						"ss3",
						nil
					};
static	void			(*SoundUserHook)(void);
	soundnames		SoundNumber,DigiNumber;
	word			SoundPriority,DigiPriority;
	int			LeftPosition,RightPosition;
	long			LocalTime;
	word			TimerRate;

	word			NumDigi,DigiLeft,DigiPage;
	word			*DigiList;
	word			DigiLastStart,DigiLastEnd;
	boolean			DigiPlaying;
static	boolean			DigiMissed,DigiLastSegment;
static	memptr			DigiNextAddr;
static	word			DigiNextLen;

//	SoundBlaster variables (kept for interface compatibility)
static	boolean					sbNoCheck,sbNoProCheck;
static	volatile boolean		sbSamplePlaying;
static	volatile byte			*sbNextSegPtr;
static	int					sbLocation = -1,sbInterrupt = 7;
static	volatile longword		sbNextSegLen;

//	SoundSource variables
	boolean				ssNoCheck;
	boolean				ssActive;
	word				ssControl,ssStatus,ssData;
	byte				ssOn,ssOff;
	volatile byte		*ssSample;
	volatile longword	ssLengthLeft;

//	PC Sound variables
	volatile byte	pcLastSample,*pcSound;
	longword		pcLengthLeft;
	word			pcSoundLookup[255];

//	AdLib variables
	boolean			alNoCheck;
	byte			*alSound;
	word			alBlock;
	longword		alLengthLeft;
	longword		alTimeCount;
	Instrument		alZeroInst;

// This table maps channel numbers to carrier and modulator op cells
static	byte			carriers[9] =  { 3, 4, 5,11,12,13,19,20,21},
					modifiers[9] = { 0, 1, 2, 8, 9,10,16,17,18},
// This table maps percussive voice numbers to op cells
					pcarriers[5] = {19,0xff,0xff,0xff,0xff},
					pmodifiers[5] = {16,17,18,20,21};

//	Sequencer variables
	boolean			sqActive;
static	word			alFXReg;
static	ActiveTrack		*tracks[sqMaxTracks],
					mytracks[sqMaxTracks];
static	word			sqMode,sqFadeStep;
	word			*sqHack,*sqHackPtr;
	word			sqHackLen,sqHackSeqLen;
	long			sqHackTime;

//	Internal routines
	void			SDL_DigitizedDone(void);

//=========================================================================
//
//	SDL3 Audio Backend
//
//=========================================================================

#define	SD_AUDIO_RATE		44100
#define	SD_AUDIO_SAMPLES	1024

//
//	Minimal OPL2 emulator state
//	We track register writes and synthesize output from them.
//
#define OPL_NUM_CHANNELS	9
#define OPL_NUM_OPERATORS	22		// indices 0-21 used by the OPL2

typedef struct {
	byte	regs[256];		// Full OPL2 register file

	// Per-channel derived state
	double	phase[OPL_NUM_CHANNELS];		// current phase accumulator
	double	env[OPL_NUM_CHANNELS];			// simple envelope (0..1)
	int	noteOn[OPL_NUM_CHANNELS];		// key-on flag
	double	freq[OPL_NUM_CHANNELS];			// frequency in Hz
} OPL2State;

static OPL2State	opl2;
static SDL_AudioStream	*sd_stream;
static SDL_Mutex	*sd_mutex;

// PC speaker square wave state
static double		pcSpkPhase;
static double		pcSpkFreq;		// current frequency (0 = silent)

// Digitized sound playback state
static byte		*sd_digiData;
static longword		sd_digiLen;
static longword		sd_digiPos;
static int		sd_digiLeftVol;		// 0-15
static int		sd_digiRightVol;	// 0-15

// Timer tick accumulator for the audio callback
static double		sd_tickAccum;
static double		sd_seqAccum;	// Accumulator for 700Hz sequencer rate

// Timestamp (SDL_GetTicks) of last audio callback TimeCount increment.
// Used by SD_TimeCountUpdate to decide whether to drive TimeCount from
// real time.
static volatile Uint64	sd_audioLastTick;

// Real-time epoch (SDL_GetTicks at the last point TimeCount was synced)
static Uint64	sd_realTimeEpoch;
static longword	sd_realTimeBase;	// TimeCount value at that epoch

//
// SD_TimeCountUpdate - call this from any poll / wait loop.
// If the audio callback has been advancing TimeCount (recently), do nothing.
// Otherwise, compute TimeCount from real elapsed time so the game never hangs.
//
void SD_TimeCountUpdate(void)
{
	Uint64 now;
	longword elapsed_ticks;

	// If the audio callback has been active within the last 50ms, let it
	// drive TimeCount and keep our epoch in sync.
	if (sd_audioLastTick && (SDL_GetTicks() - sd_audioLastTick < 50))
	{
		sd_realTimeEpoch = SDL_GetTicks();
		sd_realTimeBase = TimeCount;
		return;
	}

	// Audio callback is NOT driving TimeCount -- advance from real time.
	now = SDL_GetTicks();
	elapsed_ticks = (longword)((now - sd_realTimeEpoch) * 70 / 1000);
	if (sd_realTimeBase + elapsed_ticks > TimeCount)
	{
		TimeCount = sd_realTimeBase + elapsed_ticks;
		LocalTime = TimeCount;
	}
}

//
// OPL2 frequency derivation from register values
//
static double OPL2_GetFreq(int ch)
{
	int fnum = opl2.regs[alFreqL + ch] | ((opl2.regs[alFreqH + ch] & 0x03) << 8);
	int block = (opl2.regs[alFreqH + ch] >> 2) & 0x07;
	// OPL2 formula: freq = fnum * 49716 / (1 << (20 - block))
	return (double)fnum * 49716.0 / (double)(1 << (20 - block));
}

static int OPL2_IsKeyOn(int ch)
{
	return (opl2.regs[alFreqH + ch] >> 5) & 1;
}

//
//	alOut(n,b) - Puts b in the OPL2 emulator register n
//	Replaces the original port I/O version
//
void
alOut(byte n,byte b)
{
	if (sd_mutex)
		SDL_LockMutex(sd_mutex);

	opl2.regs[n] = b;

	// Update derived state for channel registers
	if (n >= alFreqL && n < alFreqL + OPL_NUM_CHANNELS)
	{
		int ch = n - alFreqL;
		opl2.freq[ch] = OPL2_GetFreq(ch);
	}
	else if (n >= alFreqH && n < alFreqH + OPL_NUM_CHANNELS)
	{
		int ch = n - alFreqH;
		int keyOn = OPL2_IsKeyOn(ch);
		if (keyOn && !opl2.noteOn[ch])
		{
			// Note on - reset envelope
			opl2.env[ch] = 1.0;
			opl2.phase[ch] = 0.0;
		}
		else if (!keyOn && opl2.noteOn[ch])
		{
			// Note off - start release
			opl2.env[ch] = 0.0;
		}
		opl2.noteOn[ch] = keyOn;
		opl2.freq[ch] = OPL2_GetFreq(ch);
	}

	if (sd_mutex)
		SDL_UnlockMutex(sd_mutex);
}

//
//	SDL3 audio callback -- called by the audio stream to generate samples
//
static void SDLCALL
SD_AudioCallback(void *userdata, SDL_AudioStream *stream, int additional_amount, int total_amount)
{
	int samples_needed = additional_amount / (2 * sizeof(Sint16)); // stereo
	Sint16 *buf;
	int i;

	(void)userdata;
	(void)total_amount;

	if (samples_needed <= 0)
		return;

	buf = (Sint16 *)SDL_malloc(additional_amount);
	if (!buf)
		return;

	SDL_LockMutex(sd_mutex);

	for (i = 0; i < samples_needed; i++)
	{
		double mixL = 0.0, mixR = 0.0;

		// --- OPL2 music/sound synthesis ---
		{
			int ch;
			for (ch = 0; ch < OPL_NUM_CHANNELS; ch++)
			{
				if (opl2.noteOn[ch] && opl2.freq[ch] > 0.0 && opl2.env[ch] > 0.0)
				{
					// Simple sine wave approximation of FM synthesis
					double sample = sin(opl2.phase[ch] * 2.0 * M_PI) * opl2.env[ch] * 0.15;
					opl2.phase[ch] += opl2.freq[ch] / (double)SD_AUDIO_RATE;
					if (opl2.phase[ch] >= 1.0)
						opl2.phase[ch] -= 1.0;

					// Simple exponential envelope decay
					opl2.env[ch] *= 0.99999;

					mixL += sample;
					mixR += sample;
				}
			}
		}

		// --- PC speaker square wave ---
		if (pcSpkFreq > 0.0)
		{
			double sample = (pcSpkPhase < 0.5) ? 0.10 : -0.10;
			pcSpkPhase += pcSpkFreq / (double)SD_AUDIO_RATE;
			if (pcSpkPhase >= 1.0)
				pcSpkPhase -= 1.0;
			mixL += sample;
			mixR += sample;
		}

		// --- Digitized sound playback ---
		if (sd_digiData && sd_digiPos < sd_digiLen)
		{
			// Original data is unsigned 8-bit PCM at ~7000 Hz
			// We upsample by simple nearest-neighbor
			double ratio = 7000.0 / (double)SD_AUDIO_RATE;
			longword srcPos = (longword)(sd_digiPos * ratio);
			if (srcPos < sd_digiLen)
			{
				double sample = ((double)sd_digiData[srcPos] - 128.0) / 128.0 * 0.5;
				double lv = (double)sd_digiLeftVol / 15.0;
				double rv = (double)sd_digiRightVol / 15.0;
				mixL += sample * lv;
				mixR += sample * rv;
			}
			sd_digiPos++;
			// Check if done (account for resampling)
			if ((longword)(sd_digiPos * ratio) >= sd_digiLen)
			{
				sd_digiData = NULL;
				sd_digiLen = 0;
				sd_digiPos = 0;
				sbSamplePlaying = false;
				SDL_DigitizedDone();
			}
		}

		// Clamp
		if (mixL > 1.0) mixL = 1.0;
		if (mixL < -1.0) mixL = -1.0;
		if (mixR > 1.0) mixR = 1.0;
		if (mixR < -1.0) mixR = -1.0;

		buf[i * 2 + 0] = (Sint16)(mixL * 32767.0);
		buf[i * 2 + 1] = (Sint16)(mixR * 32767.0);

		// --- Advance game timer ---
		// The original ran at TickBase (70) Hz from the timer interrupt
		sd_tickAccum += (double)TickBase / (double)SD_AUDIO_RATE;
		while (sd_tickAccum >= 1.0)
		{
			sd_tickAccum -= 1.0;
			LocalTime++;
			TimeCount++;
			sd_audioLastTick = SDL_GetTicks();	// tell fallback timer we're alive
			if (SoundUserHook)
				SoundUserHook();

			// --- Sound effect service (runs at ~140 Hz in original, we run per tick) ---
			// PC sound effect service
			if (pcSound)
			{
				byte s = *pcSound++;
				if (s != pcLastSample)
				{
					pcLastSample = s;
					if (s)
					{
						word t = pcSoundLookup[s];
						if (t > 0)
							pcSpkFreq = 1193180.0 / (double)t;
						else
							pcSpkFreq = 0.0;
					}
					else
					{
						pcSpkFreq = 0.0;
					}
				}
				if (!(--pcLengthLeft))
				{
					pcSound = 0;
					pcSpkFreq = 0.0;
					SDL_SoundFinished();
				}
			}

			// AdLib sound effect service
			if (alSound)
			{
				byte s = *alSound++;
				if (!s)
					alOut(alFreqH + 0, 0);
				else
				{
					alOut(alFreqL + 0, s);
					alOut(alFreqH + 0, (byte)alBlock);
				}
				if (!(--alLengthLeft))
				{
					alSound = 0;
					alOut(alFreqH + 0, 0);
					SDL_SoundFinished();
				}
			}

		}

		// --- Music sequencer runs at 700Hz (TickBase * 10) ---
		sd_seqAccum += (double)(TickBase * 10) / (double)SD_AUDIO_RATE;
		while (sd_seqAccum >= 1.0)
		{
			sd_seqAccum -= 1.0;
			if (sqActive)
			{
				if (sqHackLen)
				{
					while (sqHackLen && (sqHackTime <= (long)alTimeCount))
					{
						word w = *sqHackPtr++;
						word delta = *sqHackPtr++;
						byte a = (byte)(w & 0xff);
						byte v = (byte)(w >> 8);
						alOut(a, v);
						sqHackTime = alTimeCount + delta;
						sqHackLen -= 4;
					}
				}
				alTimeCount++;
				if (!sqHackLen)
				{
					sqHackPtr = sqHack;
					sqHackLen = sqHackSeqLen;
					alTimeCount = sqHackTime = 0;
				}
			}
		}
	}

	SDL_UnlockMutex(sd_mutex);

	SDL_PutAudioStreamData(stream, buf, additional_amount);
	SDL_free(buf);
}

//=========================================================================
//
//	Original functions, ported
//
//=========================================================================

///////////////////////////////////////////////////////////////////////////
//
//	SDL_SetTimerSpeed() - In the original this reprogrammed the PIT and
//		changed the ISR. Now it's a no-op since we use the audio callback.
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_SetTimerSpeed(void)
{
	// Timer speed is now handled by the SDL3 audio callback
}

//
//	SoundBlaster code - now uses SDL3 audio for digitized playback
//

///////////////////////////////////////////////////////////////////////////
//
//	SDL_SBStopSample() - Stops any active sampled sound
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_SBStopSample(void)
{
	if (sd_mutex) SDL_LockMutex(sd_mutex);

	sbSamplePlaying = false;
	sd_digiData = NULL;
	sd_digiLen = 0;
	sd_digiPos = 0;

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_SBPlaySample() - Plays a sampled sound through SDL3 audio
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_SBPlaySample(byte *data,longword len)
{
	SDL_SBStopSample();

	if (sd_mutex) SDL_LockMutex(sd_mutex);

	sd_digiData = data;
	sd_digiLen = len;
	sd_digiPos = 0;
	sbSamplePlaying = true;

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_PositionSBP() - Sets the attenuation levels for the left and right
//		channels. Original programmed the SB Pro mixer chip.
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_PositionSBP(int leftpos,int rightpos)
{
	if (!SBProPresent)
		return;

	if (sd_mutex) SDL_LockMutex(sd_mutex);
	sd_digiLeftVol = leftpos;
	sd_digiRightVol = rightpos;
	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_SBSetDMA() - Kept for interface compatibility, no-op now
//
///////////////////////////////////////////////////////////////////////////
void
SDL_SBSetDMA(byte channel)
{
	if (channel > 3)
		Quit("SDL_SBSetDMA() - invalid SoundBlaster DMA channel");
	// No-op in SDL3 port
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_StartSB() - Starts up the SoundBlaster (now a no-op, SDL3 handles audio)
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_StartSB(void)
{
	SBProPresent = true;	// Always claim SB Pro for stereo positioning
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_ShutSB() - Turns off the SoundBlaster
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_ShutSB(void)
{
	SDL_SBStopSample();
}

//	Sound Source Code - stubbed out, Sound Source hardware doesn't exist anymore

///////////////////////////////////////////////////////////////////////////
//
//	SDL_SSStopSample() - Stops a sample playing on the Sound Source
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_SSStopSample(void)
{
	ssSample = 0;
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_SSPlaySample() - Plays the specified sample on the Sound Source
//	(Now routes through SDL3 digitized playback)
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_SSPlaySample(byte *data,longword len)
{
	// Route through the SDL3 digitized playback
	SDL_SBPlaySample(data, len);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_StartSS() - Sets up for and turns on the Sound Source (stubbed)
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_StartSS(void)
{
	// Sound Source hardware not available - no-op
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_ShutSS() - Turns off the Sound Source (stubbed)
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_ShutSS(void)
{
	// Sound Source hardware not available - no-op
}

//
//	PC Sound code
//

///////////////////////////////////////////////////////////////////////////
//
//	SDL_PCPlaySample() - Plays the specified sample on the PC speaker
//	(Routes through SDL3 digitized playback)
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_PCPlaySample(byte *data,longword len)
{
	// Route through the SDL3 digitized playback
	SDL_SBPlaySample(data, len);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_PCStopSample() - Stops a sample playing on the PC speaker
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_PCStopSample(void)
{
	if (sd_mutex) SDL_LockMutex(sd_mutex);

	pcSound = 0;
	pcSpkFreq = 0.0;

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_PCPlaySound() - Plays the specified sound on the PC speaker
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_PCPlaySound(PCSound *sound)
{
	if (sd_mutex) SDL_LockMutex(sd_mutex);

	pcLastSample = -1;
	pcLengthLeft = sound->common.length;
	pcSound = sound->data;

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_PCStopSound() - Stops the current sound playing on the PC Speaker
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_PCStopSound(void)
{
	if (sd_mutex) SDL_LockMutex(sd_mutex);

	pcSound = 0;
	pcSpkFreq = 0.0;

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_ShutPC() - Turns off the pc speaker
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_ShutPC(void)
{
	if (sd_mutex) SDL_LockMutex(sd_mutex);

	pcSound = 0;
	pcSpkFreq = 0.0;

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

//
//	Stuff for digitized sounds
//
memptr
SDL_LoadDigiSegment(word page)
{
	memptr	addr;

	addr = PM_GetSoundPage(page);
	PM_SetPageLock(PMSoundStart + page,pml_Locked);

	return(addr);
}

void
SDL_PlayDigiSegment(memptr addr,word len)
{
	switch (DigiMode)
	{
	case sds_PC:
    	SDL_PCPlaySample(addr,len);
		break;
	case sds_SoundSource:
		SDL_SSPlaySample(addr,len);
		break;
	case sds_SoundBlaster:
		SDL_SBPlaySample(addr,len);
		break;
	}
}

void
SD_StopDigitized(void)
{
	int	i;

	DigiLeft = 0;
	DigiNextAddr = nil;
	DigiNextLen = 0;
	DigiMissed = false;
	DigiPlaying = false;
	DigiNumber = DigiPriority = 0;
	SoundPositioned = false;
	if ((DigiMode == sds_PC) && (SoundMode == sdm_PC))
		SDL_SoundFinished();

	switch (DigiMode)
	{
	case sds_PC:
		SDL_PCStopSample();
		break;
	case sds_SoundSource:
		SDL_SSStopSample();
		break;
	case sds_SoundBlaster:
		SDL_SBStopSample();
		break;
	}

	for (i = DigiLastStart;i < DigiLastEnd;i++)
		PM_SetPageLock(i + PMSoundStart,pml_Unlocked);
	DigiLastStart = 1;
	DigiLastEnd = 0;
}

void
SD_Poll(void)
{
	if (DigiLeft && !DigiNextAddr)
	{
		DigiNextLen = (DigiLeft >= PMPageSize)? PMPageSize : (DigiLeft % PMPageSize);
		DigiLeft -= DigiNextLen;
		if (!DigiLeft)
			DigiLastSegment = true;
		DigiNextAddr = SDL_LoadDigiSegment(DigiPage++);
	}
	if (DigiMissed && DigiNextAddr)
	{
		SDL_PlayDigiSegment(DigiNextAddr,DigiNextLen);
		DigiNextAddr = nil;
		DigiMissed = false;
		if (DigiLastSegment)
		{
			DigiPlaying = false;
			DigiLastSegment = false;
		}
	}
	SDL_SetTimerSpeed();
}

void
SD_SetPosition(int leftpos,int rightpos)
{
	if
	(
		(leftpos < 0)
	||	(leftpos > 15)
	||	(rightpos < 0)
	||	(rightpos > 15)
	||	((leftpos == 15) && (rightpos == 15))
	)
		Quit("SD_SetPosition: Illegal position");

	switch (DigiMode)
	{
	case sds_SoundBlaster:
		SDL_PositionSBP(leftpos,rightpos);
		break;
	}
}

void
SD_PlayDigitized(word which,int leftpos,int rightpos)
{
	word	len;
	memptr	addr;

	if (!DigiMode)
		return;

	SD_StopDigitized();
	if (which >= NumDigi)
		Quit("SD_PlayDigitized: bad sound number");

	SD_SetPosition(leftpos,rightpos);

	DigiPage = DigiList[(which * 2) + 0];
	DigiLeft = DigiList[(which * 2) + 1];

	DigiLastStart = DigiPage;
	DigiLastEnd = DigiPage + ((DigiLeft + (PMPageSize - 1)) / PMPageSize);

	len = (DigiLeft >= PMPageSize)? PMPageSize : (DigiLeft % PMPageSize);
	addr = SDL_LoadDigiSegment(DigiPage++);

	DigiPlaying = true;
	DigiLastSegment = false;

	SDL_PlayDigiSegment(addr,len);
	DigiLeft -= len;
	if (!DigiLeft)
		DigiLastSegment = true;

	SD_Poll();
}

void
SDL_DigitizedDone(void)
{
	if (DigiNextAddr)
	{
		SDL_PlayDigiSegment(DigiNextAddr,DigiNextLen);
		DigiNextAddr = nil;
		DigiMissed = false;
	}
	else
	{
		if (DigiLastSegment)
		{
			DigiPlaying = false;
			DigiLastSegment = false;
			if ((DigiMode == sds_PC) && (SoundMode == sdm_PC))
			{
				SDL_SoundFinished();
			}
			else
				DigiNumber = DigiPriority = 0;
			SoundPositioned = false;
		}
		else
			DigiMissed = true;
	}
}

void
SD_SetDigiDevice(SDSMode mode)
{
	boolean	devicenotpresent;

	if (mode == DigiMode)
		return;

	SD_StopDigitized();

	devicenotpresent = false;
	switch (mode)
	{
	case sds_SoundBlaster:
		if (!SoundBlasterPresent)
		{
			if (SoundSourcePresent)
				mode = sds_SoundSource;
			else
				devicenotpresent = true;
		}
		break;
	case sds_SoundSource:
		if (!SoundSourcePresent)
			devicenotpresent = true;
		break;
	}

	if (!devicenotpresent)
	{
		if (DigiMode == sds_SoundSource)
			SDL_ShutSS();

		DigiMode = mode;

		if (mode == sds_SoundSource)
			SDL_StartSS();

		SDL_SetTimerSpeed();
	}
}

void
SDL_SetupDigi(void)
{
	memptr	list;
	word	*p;
	word	pg;
	int	i;

	PM_UnlockMainMem();
	MM_GetPtr(&list,PMPageSize);
	PM_CheckMainMem();
	p = (word *)PM_GetPage(ChunksInFile - 1);
	memcpy(list, p, PMPageSize);
	pg = PMSoundStart;
	for (i = 0;i < PMPageSize / (sizeof(word) * 2);i++,p += 2)
	{
		if (pg >= ChunksInFile - 1)
			break;
		pg += (p[1] + (PMPageSize - 1)) / PMPageSize;
	}
	PM_UnlockMainMem();
	MM_GetPtr((memptr *)&DigiList,i * sizeof(word) * 2);
	memcpy(DigiList, list, i * sizeof(word) * 2);
	MM_FreePtr(&list);
	NumDigi = i;

	for (i = 0;i < LASTSOUND;i++)
		DigiMap[i] = -1;
}

// 	AdLib Code

///////////////////////////////////////////////////////////////////////////
//
//	SDL_AlSetFXInst() - Puts an instrument into the AdLib sound effect channel
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_AlSetFXInst(Instrument *inst)
{
	byte		c,m;

	m = modifiers[0];
	c = carriers[0];
	alOut(m + alChar,inst->mChar);
	alOut(m + alScale,inst->mScale);
	alOut(m + alAttack,inst->mAttack);
	alOut(m + alSus,inst->mSus);
	alOut(m + alWave,inst->mWave);
	alOut(c + alChar,inst->cChar);
	alOut(c + alScale,inst->cScale);
	alOut(c + alAttack,inst->cAttack);
	alOut(c + alSus,inst->cSus);
	alOut(c + alWave,inst->cWave);

	// Note: Switch commenting on these lines for old MUSE compatibility
//	alOut(alFeedCon,inst->nConn);
	alOut(alFeedCon,0);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_ALStopSound() - Turns off any sound effects playing through the
//		AdLib card
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_ALStopSound(void)
{
	if (sd_mutex) SDL_LockMutex(sd_mutex);

	alSound = 0;
	alOut(alFreqH + 0,0);

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_ALPlaySound() - Plays the specified sound on the AdLib card
//
///////////////////////////////////////////////////////////////////////////
#ifdef	_MUSE_
void
#else
static void
#endif
SDL_ALPlaySound(AdLibSound *sound)
{
	Instrument	*inst;
	byte		*data;

	SDL_ALStopSound();

	if (sd_mutex) SDL_LockMutex(sd_mutex);

	alLengthLeft = sound->common.length;
	data = sound->data;
	alSound = data;
	alBlock = ((sound->block & 7) << 2) | 0x20;
	inst = &sound->inst;

	if (!(inst->mSus | inst->cSus))
	{
		if (sd_mutex) SDL_UnlockMutex(sd_mutex);
		Quit("SDL_ALPlaySound() - Bad instrument");
	}

	SDL_AlSetFXInst(&alZeroInst);	// DEBUG
	SDL_AlSetFXInst(inst);

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_ShutAL() - Shuts down the AdLib card for sound effects
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_ShutAL(void)
{
	if (sd_mutex) SDL_LockMutex(sd_mutex);

	alOut(alEffects,0);
	alOut(alFreqH + 0,0);
	SDL_AlSetFXInst(&alZeroInst);
	alSound = 0;

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_CleanAL() - Totally shuts down the AdLib card
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_CleanAL(void)
{
	int	i;

	if (sd_mutex) SDL_LockMutex(sd_mutex);

	alOut(alEffects,0);
	for (i = 1;i < 0xf5;i++)
		alOut(i,0);

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_StartAL() - Starts up the AdLib card for sound effects
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_StartAL(void)
{
	alFXReg = 0;
	alOut(alEffects,alFXReg);
	SDL_AlSetFXInst(&alZeroInst);
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_DetectAdLib() - Always returns true in SDL3 port since we emulate OPL2
//
///////////////////////////////////////////////////////////////////////////
static boolean
SDL_DetectAdLib(void)
{
	int i;

	// Initialize OPL2 emulator
	memset(&opl2, 0, sizeof(opl2));

	for (i = 1;i <= 0xf5;i++)	// Zero all the registers
		alOut(i,0);

	alOut(1,0x20);	// Set WSE=1
	alOut(8,0);		// Set CSM=0 & SEL=0

	return(true);
}

////////////////////////////////////////////////////////////////////////////
//
//	SDL_ShutDevice() - turns off whatever device was being used for sound fx
//
////////////////////////////////////////////////////////////////////////////
static void
SDL_ShutDevice(void)
{
	switch (SoundMode)
	{
	case sdm_PC:
		SDL_ShutPC();
		break;
	case sdm_AdLib:
		SDL_ShutAL();
		break;
	}
	SoundMode = sdm_Off;
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_CleanDevice() - totally shuts down all sound devices
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_CleanDevice(void)
{
	if ((SoundMode == sdm_AdLib) || (MusicMode == smm_AdLib))
		SDL_CleanAL();
}

///////////////////////////////////////////////////////////////////////////
//
//	SDL_StartDevice() - turns on whatever device is to be used for sound fx
//
///////////////////////////////////////////////////////////////////////////
static void
SDL_StartDevice(void)
{
	switch (SoundMode)
	{
	case sdm_AdLib:
		SDL_StartAL();
		break;
	}
	SoundNumber = SoundPriority = 0;
}

//	Public routines

///////////////////////////////////////////////////////////////////////////
//
//	SD_SetSoundMode() - Sets which sound hardware to use for sound effects
//
///////////////////////////////////////////////////////////////////////////
boolean
SD_SetSoundMode(SDMode mode)
{
	boolean	result = false;
	word	tableoffset;

	SD_StopSound();

#ifndef	_MUSE_
	if ((mode == sdm_AdLib) && !AdLibPresent)
		mode = sdm_PC;

	switch (mode)
	{
	case sdm_Off:
		NeedsDigitized = false;
		result = true;
		break;
	case sdm_PC:
		tableoffset = STARTPCSOUNDS;
		NeedsDigitized = false;
		result = true;
		break;
	case sdm_AdLib:
		if (AdLibPresent)
		{
			tableoffset = STARTADLIBSOUNDS;
			NeedsDigitized = false;
			result = true;
		}
		break;
	}
#else
	result = true;
#endif

	if (result && (mode != SoundMode))
	{
		SDL_ShutDevice();
		SoundMode = mode;
#ifndef	_MUSE_
		SoundTable = (byte **)(&audiosegs[tableoffset]);
#endif
		SDL_StartDevice();
	}

	SDL_SetTimerSpeed();

	return(result);
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_SetMusicMode() - sets the device to use for background music
//
///////////////////////////////////////////////////////////////////////////
boolean
SD_SetMusicMode(SMMode mode)
{
	boolean	result = false;

	SD_FadeOutMusic();
	while (SD_MusicPlaying())
		;

	switch (mode)
	{
	case smm_Off:
		NeedsMusic = false;
		result = true;
		break;
	case smm_AdLib:
		if (AdLibPresent)
		{
			NeedsMusic = true;
			result = true;
		}
		break;
	}

	if (result)
		MusicMode = mode;

	SDL_SetTimerSpeed();

	return(result);
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_Startup() - starts up the Sound Mgr
//		Detects all additional sound hardware and installs my ISR
//
///////////////////////////////////////////////////////////////////////////
void
SD_Startup(void)
{
	int	i;
	SDL_AudioSpec spec;

	if (SD_Started)
		return;

	ssIsTandy = false;
	ssNoCheck = false;
	alNoCheck = false;
	sbNoCheck = false;
	sbNoProCheck = false;
#ifndef	_MUSE_
	for (i = 1;i < _argc;i++)
	{
		switch (US_CheckParm(_argv[i],ParmStrings))
		{
		case 0:						// No AdLib detection
			alNoCheck = true;
			break;
		case 1:						// No SoundBlaster detection
			sbNoCheck = true;
			break;
		case 2:						// No SoundBlaster Pro detection
			sbNoProCheck = true;
			break;
		case 3:
			ssNoCheck = true;		// No Sound Source detection
			break;
		case 4:						// Tandy Sound Source handling
			ssIsTandy = true;
			break;
		case 5:						// Sound Source present at LPT1
			ssPort = 1;
			ssNoCheck = SoundSourcePresent = true;
			break;
		case 6:                     // Sound Source present at LPT2
			ssPort = 2;
			ssNoCheck = SoundSourcePresent = true;
			break;
		case 7:                     // Sound Source present at LPT3
			ssPort = 3;
			ssNoCheck = SoundSourcePresent = true;
			break;
		}
	}
#endif

	SoundUserHook = 0;

	LocalTime = TimeCount = alTimeCount = 0;

	SD_SetSoundMode(sdm_Off);
	SD_SetMusicMode(smm_Off);

	// In SDL3 port, always detect AdLib (we emulate OPL2)
	AdLibPresent = SDL_DetectAdLib();

	// In SDL3 port, always claim SoundBlaster present (we use SDL3 audio)
	SoundBlasterPresent = true;
	SBProPresent = true;

	for (i = 0;i < 255;i++)
		pcSoundLookup[i] = i * 60;

	SDL_StartSB();

	SDL_SetupDigi();

	// --- Initialize SDL3 audio ---
	sd_mutex = SDL_CreateMutex();

	spec.freq = SD_AUDIO_RATE;
	spec.format = SDL_AUDIO_S16;
	spec.channels = 2;

	sd_stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, SD_AudioCallback, NULL);
	if (sd_stream)
	{
		SDL_ResumeAudioStreamDevice(sd_stream);
	}

	// Initialize the real-time fallback for TimeCount.
	// SD_TimeCountUpdate() is called from polling/wait loops and will
	// advance TimeCount from real elapsed time if the audio callback
	// isn't actively driving it.
	sd_audioLastTick = 0;
	sd_realTimeEpoch = SDL_GetTicks();
	sd_realTimeBase = 0;

	sd_tickAccum = 0.0;
	sd_seqAccum = 0.0;
	pcSpkPhase = 0.0;
	pcSpkFreq = 0.0;
	sd_digiData = NULL;
	sd_digiLen = 0;
	sd_digiPos = 0;
	sd_digiLeftVol = 15;
	sd_digiRightVol = 15;

	SD_Started = true;
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_Default() - Sets up the default behaviour for the Sound Mgr whether
//		the config file was present or not.
//
///////////////////////////////////////////////////////////////////////////
void
SD_Default(boolean gotit,SDMode sd,SMMode sm)
{
	boolean	gotsd,gotsm;

	gotsd = gotsm = gotit;

	if (gotsd)	// Make sure requested sound hardware is available
	{
		switch (sd)
		{
		case sdm_AdLib:
			gotsd = AdLibPresent;
			break;
		}
	}
	if (!gotsd)
	{
		if (AdLibPresent)
			sd = sdm_AdLib;
		else
			sd = sdm_PC;
	}
	if (sd != SoundMode)
		SD_SetSoundMode(sd);


	if (gotsm)	// Make sure requested music hardware is available
	{
		switch (sm)
		{
		case sdm_AdLib:
			gotsm = AdLibPresent;
			break;
		}
	}
	if (!gotsm)
	{
		if (AdLibPresent)
			sm = smm_AdLib;
	}
	if (sm != MusicMode)
		SD_SetMusicMode(sm);
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_Shutdown() - shuts down the Sound Mgr
//		Removes sound ISR and turns off whatever sound hardware was active
//
///////////////////////////////////////////////////////////////////////////
void
SD_Shutdown(void)
{
	if (!SD_Started)
		return;

	SD_MusicOff();
	SD_StopSound();
	SDL_ShutDevice();
	SDL_CleanDevice();

	SDL_ShutSB();

	// --- Shut down SDL3 audio ---
	if (sd_stream)
	{
		SDL_DestroyAudioStream(sd_stream);
		sd_stream = NULL;
	}
	if (sd_mutex)
	{
		SDL_DestroyMutex(sd_mutex);
		sd_mutex = NULL;
	}

	SD_Started = false;
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_SetUserHook() - sets the routine that the Sound Mgr calls every 1/70th
//		of a second from its timer 0 ISR
//
///////////////////////////////////////////////////////////////////////////
void
SD_SetUserHook(void (* hook)(void))
{
	SoundUserHook = hook;
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_PositionSound() - Sets up a stereo imaging location for the next
//		sound to be played. Each channel ranges from 0 to 15.
//
///////////////////////////////////////////////////////////////////////////
void
SD_PositionSound(int leftvol,int rightvol)
{
	LeftPosition = leftvol;
	RightPosition = rightvol;
	nextsoundpos = true;
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_PlaySound() - plays the specified sound on the appropriate hardware
//
///////////////////////////////////////////////////////////////////////////
boolean
SD_PlaySound(soundnames sound)
{
	boolean		ispos;
	SoundCommon	*s;
	int	lp,rp;

	lp = LeftPosition;
	rp = RightPosition;
	LeftPosition = 0;
	RightPosition = 0;

	ispos = nextsoundpos;
	nextsoundpos = false;

	if (sound == (soundnames)-1)
		return(false);

	s = (SoundCommon *)(SoundTable[sound]);
	if ((SoundMode != sdm_Off) && !s)
		Quit("SD_PlaySound() - Uncached sound");

	if ((DigiMode != sds_Off) && (DigiMap[sound] != -1))
	{
		if ((DigiMode == sds_PC) && (SoundMode == sdm_PC))
		{
			if (s->priority < SoundPriority)
				return(false);

			SDL_PCStopSound();

			SD_PlayDigitized(DigiMap[sound],lp,rp);
			SoundPositioned = ispos;
			SoundNumber = sound;
			SoundPriority = s->priority;
		}
		else
		{
			if (DigiPriority && !DigiNumber)
			{
				Quit("SD_PlaySound: Priority without a sound");
			}

			if (s->priority < DigiPriority)
				return(false);

			SD_PlayDigitized(DigiMap[sound],lp,rp);
			SoundPositioned = ispos;
			DigiNumber = sound;
			DigiPriority = s->priority;
		}

		return(true);
	}

	if (SoundMode == sdm_Off)
		return(false);
	if (!s->length)
		Quit("SD_PlaySound() - Zero length sound");
	if (s->priority < SoundPriority)
		return(false);

	switch (SoundMode)
	{
	case sdm_PC:
		SDL_PCPlaySound((void *)s);
		break;
	case sdm_AdLib:
		SDL_ALPlaySound((void *)s);
		break;
	}

	SoundNumber = sound;
	SoundPriority = s->priority;

	return(false);
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_SoundPlaying() - returns the sound number that's playing, or 0 if
//		no sound is playing
//
///////////////////////////////////////////////////////////////////////////
word
SD_SoundPlaying(void)
{
	boolean	result = false;

	switch (SoundMode)
	{
	case sdm_PC:
		result = pcSound? true : false;
		break;
	case sdm_AdLib:
		result = alSound? true : false;
		break;
	}

	if (result)
		return(SoundNumber);
	else
		return(false);
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_StopSound() - if a sound is playing, stops it
//
///////////////////////////////////////////////////////////////////////////
void
SD_StopSound(void)
{
	if (DigiPlaying)
		SD_StopDigitized();

	switch (SoundMode)
	{
	case sdm_PC:
		SDL_PCStopSound();
		break;
	case sdm_AdLib:
		SDL_ALStopSound();
		break;
	}

	SoundPositioned = false;

	SDL_SoundFinished();
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_WaitSoundDone() - waits until the current sound is done playing
//
///////////////////////////////////////////////////////////////////////////
void
SD_WaitSoundDone(void)
{
	while (SD_SoundPlaying())
		SDL_Delay(1);	// Don't busy-wait, yield to OS
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_MusicOn() - turns on the sequencer
//
///////////////////////////////////////////////////////////////////////////
void
SD_MusicOn(void)
{
	sqActive = true;
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_MusicOff() - turns off the sequencer and any playing notes
//
///////////////////////////////////////////////////////////////////////////
void
SD_MusicOff(void)
{
	word	i;


	switch (MusicMode)
	{
	case smm_AdLib:
		alFXReg = 0;
		alOut(alEffects,0);
		for (i = 0;i < sqMaxTracks;i++)
			alOut(alFreqH + i + 1,0);
		break;
	}
	sqActive = false;
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_StartMusic() - starts playing the music pointed to
//
///////////////////////////////////////////////////////////////////////////
void
SD_StartMusic(MusicGroup *music)
{
	SD_MusicOff();

	if (sd_mutex) SDL_LockMutex(sd_mutex);

	if (MusicMode == smm_AdLib)
	{
		sqHackPtr = sqHack = music->values;
		sqHackSeqLen = sqHackLen = music->length;
		sqHackTime = 0;
		alTimeCount = 0;
		SD_MusicOn();
	}

	if (sd_mutex) SDL_UnlockMutex(sd_mutex);
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_FadeOutMusic() - starts fading out the music. Call SD_MusicPlaying()
//		to see if the fadeout is complete
//
///////////////////////////////////////////////////////////////////////////
void
SD_FadeOutMusic(void)
{
	switch (MusicMode)
	{
	case smm_AdLib:
		// DEBUG - quick hack to turn the music off
		SD_MusicOff();
		break;
	}
}

///////////////////////////////////////////////////////////////////////////
//
//	SD_MusicPlaying() - returns true if music is currently playing, false if
//		not
//
///////////////////////////////////////////////////////////////////////////
boolean
SD_MusicPlaying(void)
{
	boolean	result;

	switch (MusicMode)
	{
	case smm_AdLib:
		result = false;
		// DEBUG - not written
		break;
	default:
		result = false;
	}

	return(result);
}
