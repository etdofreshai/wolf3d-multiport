; C0.ASM
;
; SDL3 port: This file originally contained the Borland C++ startup code
; for DOS real-mode programs. It handled:
;   - CPU detection (8088 vs 286+)
;   - DOS memory model setup (segment registers, stack, heap)
;   - Environment variable parsing
;   - BSS zeroing
;   - Calling main() and cleanup on exit
;   - Interrupt vector save/restore
;   - Zero-divide handler installation
;
; None of this is needed in the SDL3 port. The modern C runtime (MSVC/GCC/Clang)
; and SDL3 handle all program startup, and SDL_main serves as the entry point.
;
; This file is kept as a stub for reference. See the original source in the
; wolf3d/WOLFSRC/ directory for the DOS version.
