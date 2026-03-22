;
;	ID_SD_A.ASM
;	Id Sound Manager assembly stuff
;
;	ORIGINAL FILE - NO LONGER USED
;
;	All timer ISR and low-level sound routines have been replaced by
;	C equivalents in ID_SD.C using SDL3 audio.
;
;	The following functions from this file are no longer needed:
;		SDL_SetDS            - was: save DS for ISR context
;		SDL_IndicatePC       - was: flag for PC speaker digitized mode
;		SDL_t0ExtremeAsmService - was: 7000Hz timer ISR for PC digitized
;		SDL_t0FastAsmService - was: 700Hz timer ISR for music/sound
;		SDL_t0SlowAsmService - was: 140Hz timer ISR for basic sound
;
;	All sound update logic is now driven by the SDL3 audio callback
;	in ID_SD.C (SD_AudioCallback).
;
