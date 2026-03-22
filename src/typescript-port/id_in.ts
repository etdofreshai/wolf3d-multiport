// ID_IN.TS
// Ported from ID_IN.C - Input Manager using DOM events
// By Jason Blochowiak, ported to browser

import { SD_TimeCountUpdate, TimeCount } from './id_sd';

//===========================================================================
// Constants
//===========================================================================

export const MaxPlayers = 4;
export const MaxKbds = 2;
export const MaxJoys = 2;
export const NumCodes = 128;

export type ScanCode = number;

export const sc_None = 0;
export const sc_Bad = 0xff;
export const sc_Return = 0x1c;
export const sc_Enter = sc_Return;
export const sc_Escape = 0x01;
export const sc_Space = 0x39;
export const sc_BackSpace = 0x0e;
export const sc_Tab = 0x0f;
export const sc_Alt = 0x38;
export const sc_Control = 0x1d;
export const sc_CapsLock = 0x3a;
export const sc_LShift = 0x2a;
export const sc_RShift = 0x36;
export const sc_UpArrow = 0x48;
export const sc_DownArrow = 0x50;
export const sc_LeftArrow = 0x4b;
export const sc_RightArrow = 0x4d;
export const sc_Insert = 0x52;
export const sc_Delete = 0x53;
export const sc_Home = 0x47;
export const sc_End = 0x4f;
export const sc_PgUp = 0x49;
export const sc_PgDn = 0x51;
export const sc_F1 = 0x3b;
export const sc_F2 = 0x3c;
export const sc_F3 = 0x3d;
export const sc_F4 = 0x3e;
export const sc_F5 = 0x3f;
export const sc_F6 = 0x40;
export const sc_F7 = 0x41;
export const sc_F8 = 0x42;
export const sc_F9 = 0x43;
export const sc_F10 = 0x44;
export const sc_F11 = 0x57;
export const sc_F12 = 0x59;

export const sc_1 = 0x02;
export const sc_2 = 0x03;
export const sc_3 = 0x04;
export const sc_4 = 0x05;
export const sc_5 = 0x06;
export const sc_6 = 0x07;
export const sc_7 = 0x08;
export const sc_8 = 0x09;
export const sc_9 = 0x0a;
export const sc_0 = 0x0b;

export const sc_A = 0x1e;
export const sc_B = 0x30;
export const sc_C = 0x2e;
export const sc_D = 0x20;
export const sc_E = 0x12;
export const sc_F = 0x21;
export const sc_G = 0x22;
export const sc_H = 0x23;
export const sc_I = 0x17;
export const sc_J = 0x24;
export const sc_K = 0x25;
export const sc_L = 0x26;
export const sc_M = 0x32;
export const sc_N = 0x31;
export const sc_O = 0x18;
export const sc_P = 0x19;
export const sc_Q = 0x10;
export const sc_R = 0x13;
export const sc_S = 0x1f;
export const sc_T = 0x14;
export const sc_U = 0x16;
export const sc_V = 0x2f;
export const sc_W = 0x11;
export const sc_X = 0x2d;
export const sc_Y = 0x15;
export const sc_Z = 0x2c;

export const key_None = 0;
export const key_Return = 0x0d;
export const key_Enter = key_Return;
export const key_Escape = 0x1b;
export const key_Space = 0x20;
export const key_BackSpace = 0x08;
export const key_Tab = 0x09;
export const key_Delete = 0x7f;

//===========================================================================
// Types
//===========================================================================

export enum Demo { demo_Off, demo_Record, demo_Playback, demo_PlayDone }
export enum ControlType { ctrl_Keyboard, ctrl_Keyboard1 = 0, ctrl_Keyboard2, ctrl_Joystick, ctrl_Joystick1 = 2, ctrl_Joystick2, ctrl_Mouse }
export enum Motion { motion_Left = -1, motion_Up = -1, motion_None = 0, motion_Right = 1, motion_Down = 1 }
export enum Direction { dir_North, dir_NorthEast, dir_East, dir_SouthEast, dir_South, dir_SouthWest, dir_West, dir_NorthWest, dir_None }

export interface CursorInfo {
    button0: boolean;
    button1: boolean;
    button2: boolean;
    button3: boolean;
    x: number;
    y: number;
    xaxis: number;
    yaxis: number;
    dir: Direction;
}
export type ControlInfo = CursorInfo;

export interface KeyboardDef {
    button0: ScanCode;
    button1: ScanCode;
    upleft: ScanCode;
    up: ScanCode;
    upright: ScanCode;
    left: ScanCode;
    right: ScanCode;
    downleft: ScanCode;
    down: ScanCode;
    downright: ScanCode;
}

export interface JoystickDef {
    joyMinX: number; joyMinY: number;
    threshMinX: number; threshMinY: number;
    threshMaxX: number; threshMaxY: number;
    joyMaxX: number; joyMaxY: number;
    joyMultXL: number; joyMultYL: number;
    joyMultXH: number; joyMultYH: number;
}

//===========================================================================
// Global variables
//===========================================================================

export const Keyboard: boolean[] = new Array(NumCodes).fill(false);
export let MousePresent = false;
export const JoysPresent: boolean[] = [false, false];
export let Paused = false;
export let LastASCII = 0;
export let LastScan: ScanCode = sc_None;

export const KbdDefs: KeyboardDef = {
    button0: 0x1d, button1: 0x38,
    upleft: 0x47, up: 0x48, upright: 0x49,
    left: 0x4b, right: 0x4d,
    downleft: 0x4f, down: 0x50, downright: 0x51,
};

export const JoyDefs: JoystickDef[] = [
    { joyMinX: 0, joyMinY: 0, threshMinX: 0, threshMinY: 0, threshMaxX: 0, threshMaxY: 0, joyMaxX: 0, joyMaxY: 0, joyMultXL: 0, joyMultYL: 0, joyMultXH: 0, joyMultYH: 0 },
    { joyMinX: 0, joyMinY: 0, threshMinX: 0, threshMinY: 0, threshMaxX: 0, threshMaxY: 0, joyMaxX: 0, joyMaxY: 0, joyMultXL: 0, joyMultYL: 0, joyMultXH: 0, joyMultYH: 0 },
];

export const Controls: ControlType[] = new Array(MaxPlayers).fill(ControlType.ctrl_Keyboard);

export let DemoMode: Demo = Demo.demo_Off;
export let DemoBuffer: Uint8Array = new Uint8Array(0);
export let DemoOffset = 0;
export let DemoSize = 0;

// Setter helpers
export function setLastScan(v: ScanCode): void { LastScan = v; }
export function setLastASCII(v: number): void { LastASCII = v; }
export function setPaused(v: boolean): void { Paused = v; }
export function setDemoMode(v: Demo): void { DemoMode = v; }
export function setDemoBuffer(v: Uint8Array): void { DemoBuffer = v; }
export function setDemoOffset(v: number): void { DemoOffset = v; }
export function setDemoSize(v: number): void { DemoSize = v; }

//===========================================================================
// Macros as functions
//===========================================================================

export function IN_KeyDown(code: ScanCode): boolean { return Keyboard[code] || false; }
export function IN_ClearKey(code: ScanCode): void {
    Keyboard[code] = false;
    if (code === LastScan) LastScan = sc_None;
}

//===========================================================================
// Local variables
//===========================================================================

const ASCIINames: number[] = [
    // 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    0  ,27 ,49 ,50 ,51 ,52 ,53 ,54 ,55 ,56 ,57 ,48 ,45 ,61 ,8  ,9  ,  // 0
    113,119,101,114,116,121,117,105,111,112,91 ,93 ,13 ,0  ,97 ,115,  // 1
    100,102,103,104,106,107,108,59 ,39 ,96 ,0  ,92 ,122,120,99 ,118,  // 2
    98 ,110,109,44 ,46 ,47 ,0  ,42 ,0  ,32 ,0  ,0  ,0  ,0  ,0  ,0  ,  // 3
    0  ,0  ,0  ,0  ,0  ,0  ,0  ,55 ,56 ,57 ,45 ,52 ,53 ,54 ,43 ,49 ,  // 4
    50 ,51 ,48 ,127,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,  // 5
    0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,  // 6
    0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0    // 7
];

const ShiftNames: number[] = [
    // 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
    0  ,27 ,33 ,64 ,35 ,36 ,37 ,94 ,38 ,42 ,40 ,41 ,95 ,43 ,8  ,9  ,  // 0
    81 ,87 ,69 ,82 ,84 ,89 ,85 ,73 ,79 ,80 ,123,125,13 ,0  ,65 ,83 ,  // 1
    68 ,70 ,71 ,72 ,74 ,75 ,76 ,58 ,34 ,126,0  ,124,90 ,88 ,67 ,86 ,  // 2
    66 ,78 ,77 ,60 ,62 ,63 ,0  ,42 ,0  ,32 ,0  ,0  ,0  ,0  ,0  ,0  ,  // 3
    0  ,0  ,0  ,0  ,0  ,0  ,0  ,55 ,56 ,57 ,45 ,52 ,53 ,54 ,43 ,49 ,  // 4
    50 ,51 ,48 ,127,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,  // 5
    0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,  // 6
    0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0    // 7
];

const DirTable: Direction[] = [
    Direction.dir_NorthWest, Direction.dir_North, Direction.dir_NorthEast,
    Direction.dir_West, Direction.dir_None, Direction.dir_East,
    Direction.dir_SouthWest, Direction.dir_South, Direction.dir_SouthEast
];

let INL_KeyHook: (() => void) | null = null;
let IN_Started = false;
let CapsLock = false;

// Mouse state
let mouseButtonState = 0;
let mouseDeltaX = 0;
let mouseDeltaY = 0;

//===========================================================================
// DOM Key to ScanCode mapping
//===========================================================================

const keyCodeToScanCode: Record<string, ScanCode> = {
    'Escape': sc_Escape,
    'Digit1': sc_1, 'Digit2': sc_2, 'Digit3': sc_3, 'Digit4': sc_4,
    'Digit5': sc_5, 'Digit6': sc_6, 'Digit7': sc_7, 'Digit8': sc_8,
    'Digit9': sc_9, 'Digit0': sc_0,
    'Minus': 0x0c, 'Equal': 0x0d,
    'Backspace': sc_BackSpace, 'Tab': sc_Tab,
    'KeyQ': sc_Q, 'KeyW': sc_W, 'KeyE': sc_E, 'KeyR': sc_R,
    'KeyT': sc_T, 'KeyY': sc_Y, 'KeyU': sc_U, 'KeyI': sc_I,
    'KeyO': sc_O, 'KeyP': sc_P,
    'BracketLeft': 0x1a, 'BracketRight': 0x1b,
    'Enter': sc_Return, 'NumpadEnter': sc_Return,
    'ControlLeft': sc_Control, 'ControlRight': sc_Control,
    'KeyA': sc_A, 'KeyS': sc_S, 'KeyD': sc_D, 'KeyF': sc_F,
    'KeyG': sc_G, 'KeyH': sc_H, 'KeyJ': sc_J, 'KeyK': sc_K,
    'KeyL': sc_L,
    'Semicolon': 0x27, 'Quote': 0x28, 'Backquote': 0x29,
    'ShiftLeft': sc_LShift, 'Backslash': 0x2b,
    'KeyZ': sc_Z, 'KeyX': sc_X, 'KeyC': sc_C, 'KeyV': sc_V,
    'KeyB': sc_B, 'KeyN': sc_N, 'KeyM': sc_M,
    'Comma': 0x33, 'Period': 0x34, 'Slash': 0x35,
    'ShiftRight': sc_RShift,
    'NumpadMultiply': 0x37,
    'AltLeft': sc_Alt, 'AltRight': sc_Alt,
    'Space': sc_Space, 'CapsLock': sc_CapsLock,
    'F1': sc_F1, 'F2': sc_F2, 'F3': sc_F3, 'F4': sc_F4,
    'F5': sc_F5, 'F6': sc_F6, 'F7': sc_F7, 'F8': sc_F8,
    'F9': sc_F9, 'F10': sc_F10, 'F11': sc_F11, 'F12': sc_F12,
    'Numpad7': sc_Home, 'Numpad8': sc_UpArrow, 'Numpad9': sc_PgUp,
    'NumpadSubtract': 0x4a,
    'Numpad4': sc_LeftArrow, 'Numpad5': 0x4c, 'Numpad6': sc_RightArrow,
    'NumpadAdd': 0x4e,
    'Numpad1': sc_End, 'Numpad2': sc_DownArrow, 'Numpad3': sc_PgDn,
    'Numpad0': sc_Insert, 'NumpadDecimal': sc_Delete,
    'Home': sc_Home, 'ArrowUp': sc_UpArrow, 'PageUp': sc_PgUp,
    'ArrowLeft': sc_LeftArrow, 'ArrowRight': sc_RightArrow,
    'End': sc_End, 'ArrowDown': sc_DownArrow, 'PageDown': sc_PgDn,
    'Insert': sc_Insert, 'Delete': sc_Delete,
};

//===========================================================================
// DOM event handlers
//===========================================================================

function handleKeyDown(event: KeyboardEvent): void {
    event.preventDefault();
    if (event.repeat) return;

    const k = keyCodeToScanCode[event.code] ?? sc_None;

    if (event.code === 'Pause') {
        Paused = true;
        return;
    }

    if (k !== sc_None && k < NumCodes) {
        LastScan = k;
        Keyboard[k] = true;

        if (k === sc_CapsLock) {
            CapsLock = !CapsLock;
        }

        let c: number;
        if (Keyboard[sc_LShift] || Keyboard[sc_RShift]) {
            c = ShiftNames[k] || 0;
            if (c >= 65 && c <= 90 && CapsLock)  // A-Z
                c += 32;
        } else {
            c = ASCIINames[k] || 0;
            if (c >= 97 && c <= 122 && CapsLock)  // a-z
                c -= 32;
        }
        if (c) LastASCII = c;
    }

    if (INL_KeyHook) INL_KeyHook();
}

function handleKeyUp(event: KeyboardEvent): void {
    event.preventDefault();
    const k = keyCodeToScanCode[event.code] ?? sc_None;
    if (k !== sc_None && k < NumCodes) {
        Keyboard[k] = false;
    }
    if (INL_KeyHook) INL_KeyHook();
}

function handleMouseDown(event: MouseEvent): void {
    if (event.button === 0) mouseButtonState |= 1;
    if (event.button === 2) mouseButtonState |= 2;
    if (event.button === 1) mouseButtonState |= 4;
}

function handleMouseUp(event: MouseEvent): void {
    if (event.button === 0) mouseButtonState &= ~1;
    if (event.button === 2) mouseButtonState &= ~2;
    if (event.button === 1) mouseButtonState &= ~4;
}

function handleMouseMove(event: MouseEvent): void {
    mouseDeltaX += event.movementX;
    mouseDeltaY += event.movementY;
}

function handleContextMenu(event: Event): void {
    event.preventDefault();
}

//===========================================================================
// IN_ProcessEvents - polls and updates state (called every frame)
//===========================================================================

export function IN_ProcessEvents(): void {
    // In browser, events are handled asynchronously via DOM listeners.
    // This function just ensures TimeCount stays updated.
    SD_TimeCountUpdate();
}

//===========================================================================
// IN_WaitAndProcessEvents
//===========================================================================

export function IN_WaitAndProcessEvents(): Promise<void> {
    return new Promise(resolve => {
        setTimeout(() => {
            IN_ProcessEvents();
            resolve();
        }, 1);
    });
}

//===========================================================================
// Mouse functions
//===========================================================================

export function IN_GetMouseDelta(): { x: number; y: number } {
    const dx = mouseDeltaX;
    const dy = mouseDeltaY;
    mouseDeltaX = 0;
    mouseDeltaY = 0;
    return { x: dx, y: dy };
}

export function IN_MouseButtons(): number {
    if (MousePresent) return mouseButtonState;
    return 0;
}

//===========================================================================
// Joystick (stub - no gamepad API integration for now)
//===========================================================================

export function IN_GetJoyAbs(_joy: number): { x: number; y: number } {
    return { x: 0, y: 0 };
}

export function IN_JoyButtons(): number {
    return 0;
}

export function IN_GetJoyButtonsDB(_joy: number): number {
    return 0;
}

export function INL_GetJoyDelta(_joy: number): { dx: number; dy: number } {
    return { dx: 0, dy: 0 };
}

export function IN_SetupJoy(_joy: number, _minx: number, _maxx: number, _miny: number, _maxy: number): void {
    // Stub
}

//===========================================================================
// IN_Startup
//===========================================================================

export function IN_Startup(): void {
    if (IN_Started) return;

    IN_ClearKeysDown();

    // Set up DOM event listeners
    document.addEventListener('keydown', handleKeyDown);
    document.addEventListener('keyup', handleKeyUp);
    document.addEventListener('mousedown', handleMouseDown);
    document.addEventListener('mouseup', handleMouseUp);
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('contextmenu', handleContextMenu);

    MousePresent = true;  // Browser always has mouse

    IN_Started = true;
}

//===========================================================================
// IN_Default
//===========================================================================

export function IN_Default(gotit: boolean, type: ControlType): void {
    let ct = type;
    if (!gotit ||
        (ct === ControlType.ctrl_Joystick1 && !JoysPresent[0]) ||
        (ct === ControlType.ctrl_Joystick2 && !JoysPresent[1]) ||
        (ct === ControlType.ctrl_Mouse && !MousePresent)) {
        ct = ControlType.ctrl_Keyboard1;
    }
    IN_SetControlType(0, ct);
}

//===========================================================================
// IN_Shutdown
//===========================================================================

export function IN_Shutdown(): void {
    if (!IN_Started) return;

    document.removeEventListener('keydown', handleKeyDown);
    document.removeEventListener('keyup', handleKeyUp);
    document.removeEventListener('mousedown', handleMouseDown);
    document.removeEventListener('mouseup', handleMouseUp);
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('contextmenu', handleContextMenu);

    IN_Started = false;
}

//===========================================================================
// IN_SetKeyHook
//===========================================================================

export function IN_SetKeyHook(hook: (() => void) | null): void {
    INL_KeyHook = hook;
}

//===========================================================================
// IN_ClearKeysDown
//===========================================================================

export function IN_ClearKeysDown(): void {
    LastScan = sc_None;
    LastASCII = key_None;
    Keyboard.fill(false);
}

//===========================================================================
// IN_ReadControl
//===========================================================================

export function IN_ReadControl(player: number, info: ControlInfo): void {
    let dx = 0, dy = 0;
    let mx: number = Motion.motion_None;
    let my: number = Motion.motion_None;
    let buttons = 0;
    let realdelta = false;

    IN_ProcessEvents();

    if (DemoMode === Demo.demo_Playback) {
        const dbyte = DemoBuffer[DemoOffset + 1];
        my = (dbyte & 3) - 1;
        mx = ((dbyte >> 2) & 3) - 1;
        buttons = (dbyte >> 4) & 3;

        DemoBuffer[DemoOffset]--;
        if (DemoBuffer[DemoOffset] === 0) {
            DemoOffset += 2;
            if (DemoOffset >= DemoSize)
                DemoMode = Demo.demo_PlayDone;
        }
        realdelta = false;
    } else if (DemoMode === Demo.demo_PlayDone) {
        throw new Error('Demo playback exceeded');
    } else {
        const type = Controls[player];
        switch (type) {
            case ControlType.ctrl_Keyboard:
            case ControlType.ctrl_Keyboard2: {
                const def = KbdDefs;
                if (Keyboard[def.upleft]) { mx = Motion.motion_Left; my = Motion.motion_Up; }
                else if (Keyboard[def.upright]) { mx = Motion.motion_Right; my = Motion.motion_Up; }
                else if (Keyboard[def.downleft]) { mx = Motion.motion_Left; my = Motion.motion_Down; }
                else if (Keyboard[def.downright]) { mx = Motion.motion_Right; my = Motion.motion_Down; }

                if (Keyboard[def.up]) my = Motion.motion_Up;
                else if (Keyboard[def.down]) my = Motion.motion_Down;

                if (Keyboard[def.left]) mx = Motion.motion_Left;
                else if (Keyboard[def.right]) mx = Motion.motion_Right;

                if (Keyboard[def.button0]) buttons += 1;
                if (Keyboard[def.button1]) buttons += 2;
                realdelta = false;
                break;
            }
            case ControlType.ctrl_Mouse: {
                const md = IN_GetMouseDelta();
                dx = md.x;
                dy = md.y;
                buttons = IN_MouseButtons();
                realdelta = true;
                break;
            }
        }
    }

    if (realdelta) {
        mx = dx < 0 ? Motion.motion_Left : dx > 0 ? Motion.motion_Right : Motion.motion_None;
        my = dy < 0 ? Motion.motion_Up : dy > 0 ? Motion.motion_Down : Motion.motion_None;
    } else {
        dx = mx * 127;
        dy = my * 127;
    }

    info.x = dx;
    info.xaxis = mx;
    info.y = dy;
    info.yaxis = my;
    info.button0 = !!(buttons & 1);
    info.button1 = !!(buttons & 2);
    info.button2 = !!(buttons & 4);
    info.button3 = !!(buttons & 8);
    info.dir = DirTable[(my + 1) * 3 + (mx + 1)];

    if (DemoMode === Demo.demo_Record) {
        const dbyte = (buttons << 4) | ((mx + 1) << 2) | (my + 1);
        if (DemoBuffer[DemoOffset + 1] === dbyte && DemoBuffer[DemoOffset] < 255) {
            DemoBuffer[DemoOffset]++;
        } else {
            if (DemoOffset || DemoBuffer[DemoOffset])
                DemoOffset += 2;
            if (DemoOffset >= DemoSize)
                throw new Error('Demo buffer overflow');
            DemoBuffer[DemoOffset] = 1;
            DemoBuffer[DemoOffset + 1] = dbyte;
        }
    }
}

//===========================================================================
// IN_SetControlType
//===========================================================================

export function IN_SetControlType(player: number, type: ControlType): void {
    Controls[player] = type;
}

//===========================================================================
// IN_WaitForKey
//===========================================================================

export async function IN_WaitForKey(): Promise<ScanCode> {
    while (!LastScan) {
        await IN_WaitAndProcessEvents();
    }
    const result = LastScan;
    LastScan = sc_None;
    return result;
}

//===========================================================================
// IN_WaitForASCII
//===========================================================================

export async function IN_WaitForASCII(): Promise<number> {
    while (!LastASCII) {
        await IN_WaitAndProcessEvents();
    }
    const result = LastASCII;
    LastASCII = 0;
    return result;
}

//===========================================================================
// IN_Ack - wait for button or key press
//===========================================================================

const btnstate: boolean[] = new Array(8).fill(false);

export function IN_StartAck(): void {
    IN_ClearKeysDown();
    btnstate.fill(false);

    let buttons = IN_JoyButtons() << 4;
    if (MousePresent) buttons |= IN_MouseButtons();

    for (let i = 0; i < 8; i++) {
        if (buttons & (1 << i))
            btnstate[i] = true;
    }
}

export function IN_CheckAck(): boolean {
    IN_ProcessEvents();

    if (LastScan) return true;

    let buttons = IN_JoyButtons() << 4;
    if (MousePresent) buttons |= IN_MouseButtons();

    for (let i = 0; i < 8; i++) {
        if (buttons & (1 << i)) {
            if (!btnstate[i]) return true;
        } else {
            btnstate[i] = false;
        }
    }
    return false;
}

export async function IN_Ack(): Promise<void> {
    IN_StartAck();
    while (!IN_CheckAck()) {
        await new Promise(resolve => setTimeout(resolve, 1));
    }
}

//===========================================================================
// IN_UserInput
//===========================================================================

export async function IN_UserInput(delay: number): Promise<boolean> {
    const lasttime = TimeCount;
    IN_StartAck();
    while (true) {
        if (IN_CheckAck()) return true;
        await new Promise(resolve => setTimeout(resolve, 1));
        if (TimeCount - lasttime >= delay) break;
    }
    return false;
}

//===========================================================================
// IN_GetScanName
//===========================================================================

const ScanNames: Record<number, string> = {
    [sc_Escape]: 'Esc', [sc_1]: '1', [sc_2]: '2', [sc_3]: '3', [sc_4]: '4',
    [sc_5]: '5', [sc_6]: '6', [sc_7]: '7', [sc_8]: '8', [sc_9]: '9', [sc_0]: '0',
    [sc_BackSpace]: 'BkSp', [sc_Tab]: 'Tab', [sc_Return]: 'Return',
    [sc_Control]: 'Ctrl', [sc_LShift]: 'LShft', [sc_RShift]: 'RShft',
    [sc_Alt]: 'Alt', [sc_Space]: 'Space', [sc_CapsLock]: 'CpsLk',
    [sc_F1]: 'F1', [sc_F2]: 'F2', [sc_F3]: 'F3', [sc_F4]: 'F4',
    [sc_F5]: 'F5', [sc_F6]: 'F6', [sc_F7]: 'F7', [sc_F8]: 'F8',
    [sc_F9]: 'F9', [sc_F10]: 'F10', [sc_F11]: 'F11', [sc_F12]: 'F12',
    [sc_UpArrow]: 'Up', [sc_DownArrow]: 'Down', [sc_LeftArrow]: 'Left', [sc_RightArrow]: 'Right',
    [sc_Home]: 'Home', [sc_End]: 'End', [sc_PgUp]: 'PgUp', [sc_PgDn]: 'PgDn',
    [sc_Insert]: 'Ins', [sc_Delete]: 'Del',
};

export function IN_GetScanName(scan: ScanCode): string {
    return ScanNames[scan] || '?';
}

//===========================================================================
// IN_StopDemo / IN_FreeDemoBuffer
//===========================================================================

export function IN_StopDemo(): void {
    // stub
}

export function IN_FreeDemoBuffer(): void {
    DemoBuffer = new Uint8Array(0);
    DemoOffset = 0;
    DemoSize = 0;
}

export function IN_ReadCursor(info: CursorInfo): void {
    // Stub - not used in Wolf3D
    info.button0 = false;
    info.button1 = false;
    info.button2 = false;
    info.button3 = false;
    info.x = 0; info.y = 0;
    info.xaxis = 0; info.yaxis = 0;
    info.dir = Direction.dir_None;
}
