/* System description file for hpux version 9.  */

#include "hpux8.h"

#define HPUX9

/* If Emacs doesn't seem to work when built to use GNU malloc, you
   probably need to get the latest patches to the HP/UX compiler.
   See `etc/MACHINES' for more information.  */
#if 0
#define SYSTEM_MALLOC 1
#undef GNU_MALLOC
#undef REL_ALLOC
#endif

/* Make room for enough symbols, so dispnew.c does not fail.  */
#define C_SWITCH_SYSTEM -Wp,-H200000
