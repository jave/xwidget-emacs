/* machine description file for vax.

Copyright (C) 1985, 1986, 2001, 2002, 2003, 2004, 2005, 2006, 2007,
                 2008, 2009, 2010, 2011  Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.  */


/* #define vax    -- appears to be done automatically  */

/* USG systems I know of running on Vaxes do not actually
   support the load average, so disable it for them.  */

/* Data type of load average, as read out of kmem.  */
#define LOAD_AVE_TYPE double

/* Convert that into an integer that is 100 for a load average of 1.0  */
#define LOAD_AVE_CVT(x) ((int) ((x) * 100.0))

#define HAVE_FTIME

