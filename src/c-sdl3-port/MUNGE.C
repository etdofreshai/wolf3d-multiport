// MUNGE.C
//
// SDL3 port: This file originally contained VL_MungePic which rearranged
// graphics data into VGA Mode-Y planar format (interleaving pixels across
// 4 bitplanes). It used farmalloc, _fmemcpy, and far pointers.
//
// The SDL3 port uses linear pixel buffers, so planar munging is not needed.
// If graphics data needs to be de-planarized when loading from the original
// asset files, that conversion is handled in the asset loading code (ID_CA.C).
//
// Original functions: VL_MungePic
//
// This file is kept as a stub for reference. See the original source in the
// wolf3d/WOLFSRC/ directory for the DOS version.
