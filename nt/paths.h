/* Copyright (C) 1993, 1995, 1997, 1999, 2001
   Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */


/* The default search path for Lisp function "load".
   This sets load-path.  */
/* #define PATH_LOADSEARCH "/usr/local/lib/emacs/lisp" */
#define PATH_LOADSEARCH "C:/emacs/lisp"

/* Like PATH_LOADSEARCH, but used only when Emacs is dumping.  This
   path is usually identical to PATH_LOADSEARCH except that the entry
   for the directory containing the installed lisp files has been
   replaced with ../lisp.  */
#define PATH_DUMPLOADSEARCH "../lisp"

/* The extra search path for programs to invoke.  This is appended to
   whatever the PATH environment variable says to set the Lisp
   variable exec-path and the first file name in it sets the Lisp
   variable exec-directory.  exec-directory is used for finding
   executables and other architecture-dependent files.  */
/* #define PATH_EXEC "/usr/local/lib/emacs/etc" */
#define PATH_EXEC "C:/emacs/bin"

/* Where Emacs should look for its architecture-independent data
   files, like the NEWS file.  The lisp variable data-directory
   is set to this value.  */
/* #define PATH_DATA "/usr/local/lib/emacs/data" */
#define PATH_DATA "C:/emacs/data"

/* Where Emacs should look for its docstring file.  The lisp variable
   doc-directory is set to this value.  */
#define PATH_DOC "C:/emacs/etc"

/* The name of the directory that contains lock files with which we
   record what files are being modified in Emacs.  This directory
   should be writable by everyone.  THE STRING MUST END WITH A
   SLASH!!!  */
/* #define PATH_LOCK "/usr/local/lib/emacs/lock/" */
#define PATH_LOCK "C:/emacs/lock/"

/* Where the configuration process believes the info tree lives.  The
   lisp variable configure-info-directory gets its value from this
   macro, and is then used to set the Info-default-directory-list.  */
/* #define PATH_INFO "/usr/local/info" */
#define PATH_INFO "C:/emacs/info"
