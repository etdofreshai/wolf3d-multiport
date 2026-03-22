// WOLFHACK.C
//
// SDL3 port: This file originally contained VGA Mode-Y floor/ceiling casting
// code with direct VGA register manipulation (outportb), far pointers, and
// calls to the MapRow ASM routine (WHACK_A.ASM). None of this applies to the
// SDL3 port which uses a linear framebuffer. The floor/ceiling rendering is
// handled differently in the SDL3 port.
//
// Original functions: DrawSpans, SetPlaneViewSize, DrawPlanes, FixedMul
// Original data: planepics, spanstart, stepscale, basedist, planeylookup, etc.
//
// This file is kept as a stub for reference. See the original source in the
// wolf3d/WOLFSRC/ directory for the DOS version.
