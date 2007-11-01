/* machine description file for Sun's 386-based RoadRunner.  This file borrows heavily from
   "sun2.h", but since that file is heavily cpu-specific, it was easier
   not to include it.

   Copyright (C) 1988, 2001, 2002, 2003, 2004, 2005,
                 2006, 2007  Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301, USA.  */

/* The following line tells the configuration script what sort of
   operating system this machine is likely to run.
   USUAL-OPSYS="note"

NOTE-START
  Use s-sunos4-0.h for operating system version 4.0, and s-sunos4-1.h
  for later versions.  See the file share-lib/SUNBUG for how to solve
  problems caused by bugs in the "export" version of SunOS 4.
NOTE-END  */

/* Say this machine is a bird */
#ifndef roadrunner
#define roadrunner
#endif

/* Actual cpu-specific defs */
#include "intel386.h"

/* Data type of load average, as read out of kmem.  */

#define LOAD_AVE_TYPE long

/* Convert that into an integer that is 100 for a load average of 1.0  */

#define LOAD_AVE_CVT(x) (int) (((double) (x)) * 100.0 / FSCALE)

/* Underscores are not prepended to C symbols on this machine.  */
#undef LDAV_SYMBOL
#define LDAV_SYMBOL "avenrun"

/* Must use the system's termcap.  It does special things.  */

#define LIBS_TERMCAP -ltermcap

/* Roadrunner uses 'COFF' format */
#define COFF

#define C_SWITCH_MACHINE -Bstatic       /* avoid dynamic linking */
#define LD_SWITCH_MACHINE -n -Bstatic
/* Get rid of the -e __start that s-sunos4.h does.  */
#undef LD_SWITCH_SYSTEM

#ifdef USG
/* USG detects Solaris.  j.w.hawtin@lut.ac.uk says Solaris 2.1
   on the 386 needs this.  */
#define LIBS_MACHINE -lkvm
#endif

/* arch-tag: 861af4b4-ce5f-475e-876e-ebff6436a1fe
   (do not change this comment) */
