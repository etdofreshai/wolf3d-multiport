; WHACK_A.ASM (originally WOLFHACK.ASM)
;
; SDL3 port: This file originally contained the MapRow assembly routine used
; by WOLFHACK.C for floor/ceiling texture mapping. It used:
;   - 386 SHLD instruction for fast fixed-point texture coordinate calculation
;   - Direct VGA segment (0xA000) writes for Mode-Y rendering
;   - Far data segment for planepics (8KB ceiling+floor texture cache)
;   - Tight pixel loop with interleaved ceiling/floor writes
;
; The SDL3 port uses a linear framebuffer for all rendering, so this
; VGA-specific assembly routine is not needed.
;
; Original functions: MapRow
; Original data: planepics (8192 bytes far data)
;
; This file is kept as a stub for reference. See the original source in the
; wolf3d/WOLFSRC/ directory for the DOS version.
