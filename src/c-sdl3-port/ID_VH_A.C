// ID_VH_A.C
//
// Replaces ID_VH_A.ASM - Video hardware assembly routines converted to C + SDL3.
//
// Original ASM contained:
//   VH_UpdateScreen - Copy dirty tiles from buffer to display using VGA write mode 1
//
// This is now implemented in ID_VH.C as VH_UpdateScreen() which calls VL_UpdateScreen()
// to upload the screenbuf to the SDL texture and present.
//
// This file is kept as a placeholder; the original ASM is no longer needed.
