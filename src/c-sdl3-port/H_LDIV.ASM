; H_LDIV.ASM
;
; SDL3 port: This file originally contained 16-bit long division, modulo,
; and unsigned division helper routines for the Borland C runtime on 8086/286.
; It also contained a 386-optimized path using the 32-bit IDIV instruction
; that was patched in at runtime by JABHACK.ASM when a 386+ was detected.
;
; Modern compilers (MSVC/GCC/Clang) natively handle 32-bit and 64-bit
; integer division, so this file is not needed.
;
; Original functions: LDIV@, LUDIV@, LMOD@, LUMOD@ (and F_/N_ variants)
;
; This file is kept as a stub for reference. See the original source in the
; wolf3d/WOLFSRC/ directory for the DOS version.
