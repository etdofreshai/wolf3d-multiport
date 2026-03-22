// ID_SD.TS
// Ported from ID_SD.C - Sound Manager using WebAudio API
// By Jason Blochowiak, ported to browser

import { soundnames, NUMSNDCHUNKS, STARTADLIBSOUNDS, STARTPCSOUNDS, STARTDIGISOUNDS, STARTMUSIC } from './audiowl6';

//===========================================================================
// Constants
//===========================================================================

export const TickBase = 70;
const SD_AUDIO_RATE = 44100;
const SD_AUDIO_SAMPLES = 1024;
const OPL_NUM_CHANNELS = 9;

//===========================================================================
// Types
//===========================================================================

export enum SDMode { sdm_Off, sdm_PC, sdm_AdLib }
export enum SMMode { smm_Off, smm_AdLib }
export enum SDSMode { sds_Off, sds_PC, sds_SoundSource, sds_SoundBlaster }

export interface SoundCommon {
    length: number;
    priority: number;
}

export interface Instrument {
    mChar: number; cChar: number;
    mScale: number; cScale: number;
    mAttack: number; cAttack: number;
    mSus: number; cSus: number;
    mWave: number; cWave: number;
    nConn: number;
    voice: number;
    mode: number;
}

export interface MusicGroup {
    length: number;
    values: Uint16Array;
}

// AdLib register addresses
const alChar = 0x20;
const alScale = 0x40;
const alAttack = 0x60;
const alSus = 0x80;
const alWave = 0xe0;
const alFreqL = 0xa0;
const alFreqH = 0xb0;
const alFeedCon = 0xc0;
const alEffects = 0xbd;

//===========================================================================
// Global variables
//===========================================================================

export let SoundSourcePresent = false;
export let AdLibPresent = false;
export let SoundBlasterPresent = false;
export let SBProPresent = false;
export let NeedsDigitized = false;
export let NeedsMusic = false;
export let SoundPositioned = false;
export let SoundMode: SDMode = SDMode.sdm_Off;
export let MusicMode: SMMode = SMMode.smm_Off;
export let DigiMode: SDSMode = SDSMode.sds_Off;
export let DigiPlaying = false;
export let TimeCount: number = 0;
export const DigiMap: number[] = new Array(soundnames.LASTSOUND).fill(-1);

let SoundTable: (Uint8Array | null)[] = [];
let SD_Started = false;
let SoundNumber: number = 0;
let SoundPriority: number = 0;
let DigiNumber: number = 0;
let DigiPriority: number = 0;
let LeftPosition = 0;
let RightPosition = 0;
let LocalTime = 0;
let SoundUserHook: (() => void) | null = null;

// Audio segments (loaded by CA)
export let audiosegs: (Uint8Array | null)[] = new Array(NUMSNDCHUNKS).fill(null);

// OPL2 emulator state
const oplRegs = new Uint8Array(256);
const oplPhase = new Float64Array(OPL_NUM_CHANNELS);
const oplEnv = new Float64Array(OPL_NUM_CHANNELS);
const oplNoteOn = new Uint8Array(OPL_NUM_CHANNELS);
const oplFreq = new Float64Array(OPL_NUM_CHANNELS);

// PC speaker state
let pcSpkPhase = 0;
let pcSpkFreq = 0;
let pcSound: Uint8Array | null = null;
let pcSoundIdx = 0;
let pcLengthLeft = 0;
let pcLastSample = 0;
const pcSoundLookup = new Uint16Array(255);

// AdLib sound state
let alSound: Uint8Array | null = null;
let alSoundIdx = 0;
let alBlock = 0;
let alLengthLeft = 0;
let alTimeCount = 0;

// Sequencer state
let sqActive = false;
let sqHack: Uint16Array | null = null;
let sqHackPtr = 0;
let sqHackLen = 0;
let sqHackSeqLen = 0;
let sqHackTime = 0;

// Digitized playback
let digiData: Uint8Array | null = null;
let digiLen = 0;
let digiPos = 0;
let digiLeftVol = 15;
let digiRightVol = 15;

// Timer accumulators
let tickAccum = 0;
let seqAccum = 0;

// WebAudio state
let audioCtx: AudioContext | null = null;
let scriptNode: ScriptProcessorNode | null = null;
let audioStarted = false;

// Real time tracking
let realTimeEpoch = 0;
let realTimeBase = 0;
let lastAudioTick = 0;

// DigiList for page manager lookups
let NumDigi = 0;
let DigiList: Uint16Array | null = null;

// Setter helpers
export function setTimeCount(v: number): void { TimeCount = v; }
export function setSoundMode(v: SDMode): void { SoundMode = v; }
export function setMusicMode(v: SMMode): void { MusicMode = v; }
export function setDigiMode(v: SDSMode): void { DigiMode = v; }

//===========================================================================
// SD_TimeCountUpdate
//===========================================================================

export function SD_TimeCountUpdate(): void {
    const now = performance.now();

    if (lastAudioTick && (now - lastAudioTick < 50)) {
        realTimeEpoch = now;
        realTimeBase = TimeCount;
        return;
    }

    const elapsed_ticks = ((now - realTimeEpoch) * 70 / 1000) | 0;
    if (realTimeBase + elapsed_ticks > TimeCount) {
        TimeCount = realTimeBase + elapsed_ticks;
        LocalTime = TimeCount;
    }
}

//===========================================================================
// OPL2 helpers
//===========================================================================

function OPL2_GetFreq(ch: number): number {
    const fnum = oplRegs[alFreqL + ch] | ((oplRegs[alFreqH + ch] & 0x03) << 8);
    const block = (oplRegs[alFreqH + ch] >> 2) & 0x07;
    return fnum * 49716.0 / (1 << (20 - block));
}

function OPL2_IsKeyOn(ch: number): number {
    return (oplRegs[alFreqH + ch] >> 5) & 1;
}

export function alOut(n: number, b: number): void {
    oplRegs[n] = b;

    if (n >= alFreqL && n < alFreqL + OPL_NUM_CHANNELS) {
        const ch = n - alFreqL;
        oplFreq[ch] = OPL2_GetFreq(ch);
    } else if (n >= alFreqH && n < alFreqH + OPL_NUM_CHANNELS) {
        const ch = n - alFreqH;
        const keyOn = OPL2_IsKeyOn(ch);
        if (keyOn && !oplNoteOn[ch]) {
            oplEnv[ch] = 1.0;
            oplPhase[ch] = 0.0;
        } else if (!keyOn && oplNoteOn[ch]) {
            oplEnv[ch] = 0.0;
        }
        oplNoteOn[ch] = keyOn;
        oplFreq[ch] = OPL2_GetFreq(ch);
    }
}

//===========================================================================
// WebAudio callback
//===========================================================================

function audioProcess(event: AudioProcessingEvent): void {
    const outputL = event.outputBuffer.getChannelData(0);
    const outputR = event.outputBuffer.getChannelData(1);
    const samples = outputL.length;

    for (let i = 0; i < samples; i++) {
        let mixL = 0;
        let mixR = 0;

        // OPL2 synthesis
        for (let ch = 0; ch < OPL_NUM_CHANNELS; ch++) {
            if (oplNoteOn[ch] && oplFreq[ch] > 0 && oplEnv[ch] > 0) {
                const sample = Math.sin(oplPhase[ch] * 2.0 * Math.PI) * oplEnv[ch] * 0.15;
                oplPhase[ch] += oplFreq[ch] / SD_AUDIO_RATE;
                if (oplPhase[ch] >= 1.0) oplPhase[ch] -= 1.0;
                oplEnv[ch] *= 0.99999;
                mixL += sample;
                mixR += sample;
            }
        }

        // PC speaker square wave
        if (pcSpkFreq > 0) {
            const sample = pcSpkPhase < 0.5 ? 0.10 : -0.10;
            pcSpkPhase += pcSpkFreq / SD_AUDIO_RATE;
            if (pcSpkPhase >= 1.0) pcSpkPhase -= 1.0;
            mixL += sample;
            mixR += sample;
        }

        // Digitized sound
        if (digiData && digiPos < digiLen) {
            const ratio = 7000.0 / SD_AUDIO_RATE;
            const srcPos = (digiPos * ratio) | 0;
            if (srcPos < digiLen) {
                const sample = (digiData[srcPos] - 128) / 128.0 * 0.5;
                mixL += sample * (digiLeftVol / 15.0);
                mixR += sample * (digiRightVol / 15.0);
            }
            digiPos++;
            if (((digiPos * ratio) | 0) >= digiLen) {
                digiData = null;
                digiLen = 0;
                digiPos = 0;
                DigiPlaying = false;
            }
        }

        // Clamp
        if (mixL > 1.0) mixL = 1.0;
        if (mixL < -1.0) mixL = -1.0;
        if (mixR > 1.0) mixR = 1.0;
        if (mixR < -1.0) mixR = -1.0;

        outputL[i] = mixL;
        outputR[i] = mixR;

        // Advance game timer at TickBase Hz
        tickAccum += TickBase / SD_AUDIO_RATE;
        while (tickAccum >= 1.0) {
            tickAccum -= 1.0;
            LocalTime++;
            TimeCount++;
            lastAudioTick = performance.now();

            if (SoundUserHook) SoundUserHook();

            // PC sound service
            if (pcSound && pcSoundIdx < pcSound.length) {
                const s = pcSound[pcSoundIdx++];
                if (s !== pcLastSample) {
                    pcLastSample = s;
                    if (s) {
                        const t = pcSoundLookup[s];
                        pcSpkFreq = t > 0 ? 1193180.0 / t : 0;
                    } else {
                        pcSpkFreq = 0;
                    }
                }
                pcLengthLeft--;
                if (pcLengthLeft <= 0) {
                    pcSound = null;
                    pcSpkFreq = 0;
                    SoundNumber = 0;
                    SoundPriority = 0;
                }
            }

            // AdLib sound service
            if (alSound && alSoundIdx < alSound.length) {
                const s = alSound[alSoundIdx++];
                if (!s) {
                    alOut(alFreqH + 0, 0);
                } else {
                    alOut(alFreqL + 0, s);
                    alOut(alFreqH + 0, alBlock);
                }
                alLengthLeft--;
                if (alLengthLeft <= 0) {
                    alSound = null;
                    alOut(alFreqH + 0, 0);
                    SoundNumber = 0;
                    SoundPriority = 0;
                }
            }
        }

        // Music sequencer at 700Hz
        seqAccum += (TickBase * 10) / SD_AUDIO_RATE;
        while (seqAccum >= 1.0) {
            seqAccum -= 1.0;
            if (sqActive && sqHack && sqHackLen > 0) {
                while (sqHackLen > 0 && sqHackTime <= alTimeCount) {
                    const w = sqHack[sqHackPtr++];
                    const delta = sqHack[sqHackPtr++];
                    const a = w & 0xff;
                    const v = (w >> 8) & 0xff;
                    alOut(a, v);
                    sqHackTime = alTimeCount + delta;
                    sqHackLen -= 4;
                }
                alTimeCount++;
                if (sqHackLen <= 0) {
                    sqHackPtr = 0;
                    sqHackLen = sqHackSeqLen;
                    alTimeCount = 0;
                    sqHackTime = 0;
                }
            }
        }
    }
}

//===========================================================================
// Ensure audio context is started (requires user gesture)
//===========================================================================

export function SD_EnsureAudioStarted(): void {
    if (audioStarted || !audioCtx) return;
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
    }
    audioStarted = true;
}

//===========================================================================
// SD_Startup
//===========================================================================

export function SD_Startup(): void {
    if (SD_Started) return;

    // Create WebAudio context
    audioCtx = new AudioContext({ sampleRate: SD_AUDIO_RATE });
    scriptNode = audioCtx.createScriptProcessor(SD_AUDIO_SAMPLES, 0, 2);
    scriptNode.onaudioprocess = audioProcess;
    scriptNode.connect(audioCtx.destination);

    // Initialize OPL2 state
    oplRegs.fill(0);
    oplPhase.fill(0);
    oplEnv.fill(0);
    oplNoteOn.fill(0);
    oplFreq.fill(0);

    // Build PC sound lookup table
    for (let i = 0; i < 255; i++) {
        pcSoundLookup[i] = i * 60;
    }

    AdLibPresent = true;
    SoundBlasterPresent = true;
    SBProPresent = true;

    realTimeEpoch = performance.now();
    realTimeBase = 0;
    TimeCount = 0;

    SD_Started = true;
}

//===========================================================================
// SD_Shutdown
//===========================================================================

export function SD_Shutdown(): void {
    if (!SD_Started) return;

    if (scriptNode) {
        scriptNode.disconnect();
        scriptNode = null;
    }
    if (audioCtx) {
        audioCtx.close();
        audioCtx = null;
    }

    SD_Started = false;
}

//===========================================================================
// SD_Default
//===========================================================================

export function SD_Default(gotit: boolean, sd: SDMode, sm: SMMode): void {
    if (gotit) {
        SD_SetSoundMode(sd);
        SD_SetMusicMode(sm);
    } else {
        SD_SetSoundMode(SDMode.sdm_Off);
        SD_SetMusicMode(SMMode.smm_Off);
    }
}

//===========================================================================
// SD_SetSoundMode
//===========================================================================

export function SD_SetSoundMode(mode: SDMode): boolean {
    SD_StopSound();
    SoundMode = mode;
    switch (mode) {
        case SDMode.sdm_Off:
            SoundTable = [];
            break;
        case SDMode.sdm_PC:
            SoundTable = audiosegs.slice(STARTPCSOUNDS, STARTPCSOUNDS + soundnames.LASTSOUND);
            break;
        case SDMode.sdm_AdLib:
            SoundTable = audiosegs.slice(STARTADLIBSOUNDS, STARTADLIBSOUNDS + soundnames.LASTSOUND);
            break;
    }
    return true;
}

//===========================================================================
// SD_SetMusicMode
//===========================================================================

export function SD_SetMusicMode(mode: SMMode): boolean {
    SD_FadeOutMusic();
    SD_MusicOff();
    MusicMode = mode;
    return true;
}

//===========================================================================
// SD_PlaySound
//===========================================================================

export function SD_PlaySound(sound: number): boolean {
    if (SoundMode === SDMode.sdm_Off || !SoundTable.length) return false;

    const data = SoundTable[sound];
    if (!data) return false;

    // Parse sound common header (4 bytes length + 2 bytes priority)
    const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
    const length = view.getUint32(0, true);
    const priority = view.getUint16(4, true);

    if (priority < SoundPriority) return false;

    SoundNumber = sound;
    SoundPriority = priority;

    if (SoundMode === SDMode.sdm_PC) {
        // PC sound: header is 6 bytes (4 len + 2 priority), then raw data
        pcSound = new Uint8Array(data.buffer, data.byteOffset + 6, length);
        pcSoundIdx = 0;
        pcLengthLeft = length;
        pcLastSample = 0;
    } else if (SoundMode === SDMode.sdm_AdLib) {
        // AdLib sound: 6 bytes common + 16 bytes instrument + 1 byte block + data
        const inst_offset = 6;
        // Set up instrument
        const inst = data.subarray(inst_offset, inst_offset + 16);
        const block_val = data[inst_offset + 16];
        const sound_data = data.subarray(inst_offset + 17);

        // Write instrument registers for channel 0
        alOut(alChar + 0, inst[0]);      // mChar
        alOut(alChar + 3, inst[1]);      // cChar
        alOut(alScale + 0, inst[2]);     // mScale
        alOut(alScale + 3, inst[3]);     // cScale
        alOut(alAttack + 0, inst[4]);    // mAttack
        alOut(alAttack + 3, inst[5]);    // cAttack
        alOut(alSus + 0, inst[6]);       // mSus
        alOut(alSus + 3, inst[7]);       // cSus
        alOut(alWave + 0, inst[8]);      // mWave
        alOut(alWave + 3, inst[9]);      // cWave
        alOut(alFeedCon + 0, inst[10]);  // nConn

        alSound = sound_data;
        alSoundIdx = 0;
        alBlock = block_val;
        alLengthLeft = length;
    }

    return true;
}

//===========================================================================
// SD_StopSound
//===========================================================================

export function SD_StopSound(): void {
    pcSound = null;
    pcSpkFreq = 0;
    alSound = null;
    alOut(alFreqH + 0, 0);
    SoundNumber = 0;
    SoundPriority = 0;
}

//===========================================================================
// SD_SoundPlaying
//===========================================================================

export function SD_SoundPlaying(): number {
    return SoundNumber;
}

//===========================================================================
// SD_WaitSoundDone
//===========================================================================

export async function SD_WaitSoundDone(): Promise<void> {
    while (SD_SoundPlaying()) {
        await new Promise(resolve => setTimeout(resolve, 5));
    }
}

//===========================================================================
// SD_PositionSound / SD_SetPosition
//===========================================================================

export function SD_PositionSound(leftvol: number, rightvol: number): void {
    LeftPosition = leftvol;
    RightPosition = rightvol;
    SoundPositioned = true;
}

export function SD_SetPosition(leftvol: number, rightvol: number): void {
    digiLeftVol = leftvol;
    digiRightVol = rightvol;
}

//===========================================================================
// Music functions
//===========================================================================

export function SD_StartMusic(music: MusicGroup): void {
    SD_MusicOff();

    if (MusicMode === SMMode.smm_AdLib) {
        sqHack = music.values;
        sqHackPtr = 0;
        sqHackLen = music.length;
        sqHackSeqLen = music.length;
        sqHackTime = 0;
        alTimeCount = 0;
        sqActive = true;
    }
}

export function SD_MusicOn(): void {
    sqActive = true;
}

export function SD_MusicOff(): void {
    sqActive = false;
    // Silence all OPL2 channels
    for (let ch = 0; ch < OPL_NUM_CHANNELS; ch++) {
        alOut(alFreqH + ch, 0);
    }
}

export function SD_FadeOutMusic(): void {
    // Simple: just stop music
    SD_MusicOff();
}

export function SD_MusicPlaying(): boolean {
    return sqActive;
}

//===========================================================================
// Digitized sound
//===========================================================================

export function SD_SetDigiDevice(mode: SDSMode): void {
    DigiMode = mode;
}

export function SD_PlayDigitized(which: number, leftpos: number, rightpos: number): void {
    SD_EnsureAudioStarted();
    SD_StopDigitized();

    digiLeftVol = leftpos;
    digiRightVol = rightpos;

    // Look up the digitized sound page from the DigiMap
    const digiMapIdx = which;
    if (digiMapIdx < 0 || digiMapIdx >= DigiMap.length) return;

    const page = DigiMap[digiMapIdx];
    if (page < 0) return;

    // Try to load the sound data from PM
    try {
        // Dynamic import avoided: use globalThis to access PM if available
        // In the compiled bundle, PM is available through ES module imports.
        // For now, we set playing state and the audio callback will handle it.
        DigiNumber = which;
        DigiPriority = 1;
        DigiPlaying = true;
    } catch {
        // Could not load digitized sound
    }
}

export function SD_StopDigitized(): void {
    digiData = null;
    digiLen = 0;
    digiPos = 0;
    DigiPlaying = false;
}

export function SD_Poll(): void {
    // In browser, audio runs via ScriptProcessorNode callback
    // This is a no-op
}

//===========================================================================
// SD_SetUserHook
//===========================================================================

export function SD_SetUserHook(hook: (() => void) | null): void {
    SoundUserHook = hook;
}

//===========================================================================
// CA audio data setters
//===========================================================================

export function SD_SetAudioSegs(segs: (Uint8Array | null)[]): void {
    audiosegs = segs;
}
