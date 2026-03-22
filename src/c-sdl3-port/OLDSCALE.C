// OLDSCALE.C (WL_SCALE.C variant - MM_GetPtr-based scaler version)
//
// SDL3 port: This file originally contained an alternate version of the
// compiled sprite/wall scaling system that used the Memory Manager (MM_GetPtr,
// MM_FreePtr, MM_SetLock, MM_SortMem) instead of contiguous far memory.
// Like CONTIGSC.C, it used VGA Mode-Y plane masking, compiled scalers
// (machine code generation), Borland C far/_seg pointer arithmetic, and
// extensive inline assembly for the ScaleLine routine.
//
// The SDL3 port uses a completely different software rendering approach with
// a linear framebuffer, so none of this code applies.
//
// Original functions: SetupScaling, BuildCompScale, ScaleLine (inline ASM),
//                     ScaleShape, SimpleScaleShape, BadScale
// Original data: scaledirectory, fullscalefarcall, mapmasks1/2/3, wordmasks
//
// This file is kept as a stub for reference. See the original source in the
// wolf3d/WOLFSRC/ directory for the DOS version.
