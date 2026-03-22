// CONTIGSC.C (WL_SCALE.C variant - contiguous scaler memory version)
//
// SDL3 port: This file originally contained the compiled sprite/wall scaling
// system for DOS using contiguous far memory allocation, VGA Mode-Y plane
// masking, compiled scalers (machine code generation), and Borland C far/huge
// pointer arithmetic (FP_SEG, FP_OFF, MK_FP, _seg, far, huge).
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
