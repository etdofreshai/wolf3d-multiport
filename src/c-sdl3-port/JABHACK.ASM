; JABHACK.ASM
;
; SDL3 port: This file originally contained two routines:
;   - CheckIs386: CPU detection (checks if running on 386 or better)
;   - jabhack2: Runtime patching of the long division routine (H_LDIV.ASM)
;     to use 386 IDIV instruction instead of the 8086 shift-and-subtract loop.
;     It hooked INT 60h to redirect division calls to the faster 386 code.
;
; Modern compilers natively generate optimal division instructions for the
; target CPU, so this runtime patching hack is not needed.
;
; This file is kept as a stub for reference. See the original source in the
; wolf3d/WOLFSRC/ directory for the DOS version.
