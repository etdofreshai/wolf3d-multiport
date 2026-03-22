// ID_VL_A.C
//
// Replaces ID_VL_A.ASM - Video low-level assembly routines converted to C + SDL3.
//
// Original ASM contained:
//   VL_WaitVBL - Wait for vertical blank retrace
//   VL_SetCRTC - Set CRTC start address
//   VL_SetScreen - Set CRTC start + pel pan
//   VL_ScreenToScreen - Block copy within VGA memory
//   VL_VideoID - Detect video subsystem type
//
// All of these are now implemented in ID_VL.C as part of the SDL3 port.
// This file is kept as a placeholder; the original ASM is no longer needed.
//
// The functions VL_WaitVBL, VL_SetCRTC, VL_SetScreen, VL_ScreenToScreen,
// and VL_VideoID are defined in ID_VL.C.
