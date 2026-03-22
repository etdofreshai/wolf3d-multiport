// WL_ASM.C
//
// Replaces WL_ASM.ASM (JABHACK.ASM) - CPU detection and runtime patching
// converted to C stubs for SDL3 port.
//
// Original ASM contained:
//   _CheckIs386 - Detect if CPU is 386 or better
//   _jabhack2   - Patch the LDIV runtime to optimize for 386
//
// Neither is needed on modern systems. We always report 386+ present
// and the jabhack patch is a no-op.
//

#include "WL_DEF.H"

/*
====================
=
= CheckIs386
=
= Always returns 1 (386 or better) on modern systems
=
====================
*/

int CheckIs386 (void)
{
	return 1;	// Always 386+ on modern systems
}


/*
====================
=
= jabhack2
=
= Runtime patching of LDIV for 386 optimization - no-op on modern systems
=
====================
*/

void jabhack2 (void)
{
	// No-op: the Borland C long division runtime patching is not needed
}
