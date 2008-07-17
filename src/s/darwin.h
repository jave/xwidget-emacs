/* System description header file for Darwin (Mac OS X).
   Copyright (C) 2001, 2002, 2003, 2004, 2005, 2006, 2007,
                 2008 Free Software Foundation, Inc.

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


/*
 *	Define symbols to identify the version of Unix this is.
 *	Define all the symbols that apply correctly.
 */

#define BSD4_2
/* BSD4_3 and BSD4_4 are already defined in sys/param.h */
#define BSD_SYSTEM
/* #define VMS */

/* MAC_OS is used to conditionally compile code common to both MAC_OS8
   and MAC_OSX.  */
#ifdef MAC_OSX
#ifdef HAVE_CARBON
#define MAC_OS
/* We need a little extra space, see ../../lisp/loadup.el. */
#define SYSTEM_PURESIZE_EXTRA 30000

#endif
#endif

/* SYSTEM_TYPE should indicate the kind of system you are using.
 It sets the Lisp variable system-type.  */

#define SYSTEM_TYPE "darwin"

/* Emacs can read input using SIGIO and buffering characters itself,
   or using CBREAK mode and making C-g cause SIGINT.
   The choice is controlled by the variable interrupt_input.

   Define INTERRUPT_INPUT to make interrupt_input = 1 the default (use SIGIO)

   Emacs uses the presence or absence of the SIGIO and BROKEN_SIGIO macros
   to indicate whether or not signal-driven I/O is possible.  It uses
   INTERRUPT_INPUT to decide whether to use it by default.

   SIGIO can be used only on systems that implement it (4.2 and 4.3).
   CBREAK mode has two disadvantages
     1) At least in 4.2, it is impossible to handle the Meta key properly.
        I hear that in system V this problem does not exist.
     2) Control-G causes output to be discarded.
        I do not know whether this can be fixed in system V.

   Another method of doing input is planned but not implemented.
   It would have Emacs fork off a separate process
   to read the input and send it to the true Emacs process
   through a pipe. */

#define INTERRUPT_INPUT

/* Letter to use in finding device name of first pty,
  if system supports pty's.  'a' means it is /dev/ptya0  */

#define FIRST_PTY_LETTER 'p'

/*
 *	Define HAVE_TERMIOS if the system provides POSIX-style
 *	functions and macros for terminal control.
 *
 *	Define HAVE_TERMIO if the system provides sysV-style ioctls
 *	for terminal control.
 *
 *	Do not define both.  HAVE_TERMIOS is preferred, if it is
 *	supported on your system.
 */

#define HAVE_TERMIOS
/* #define HAVE_TERMIO */

#define NO_TERMIO

/*
 *	Define HAVE_PTYS if the system supports pty devices.
 *      Note: PTYs are broken on darwin <6.  Use at your own risk.
 */

#define HAVE_PTYS

/**
 * PTYs only work correctly on Darwin 7 or higher.  So make the
 * default for process-connection-type dependent on the kernel
 * version.
 */
#define MIN_PTY_KERNEL_VERSION '7'

/* Define this symbol if your system has the functions bcopy, etc. */

#define BSTRING

/* subprocesses should be defined if you want to
   have code for asynchronous subprocesses
   (as used in M-x compile and M-x shell).
   This is generally OS dependent, and not supported
   under most USG systems. */

#define subprocesses

/* define MAIL_USE_FLOCK if the mailer uses flock
   to interlock access to /usr/spool/mail/$USER.
   The alternative is that a lock file named
   /usr/spool/mail/$USER.lock.  */

#define MAIL_USE_FLOCK

/* Define CLASH_DETECTION if you want lock files to be written
   so that Emacs can tell instantly when you try to modify
   a file that someone else has modified in his Emacs.  */

#define CLASH_DETECTION

/* ============================================================ */

/* Here, add any special hacks needed
   to make Emacs work on this system.  For example,
   you might define certain system call names that don't
   exist on your system, or that do different things on
   your system and must be used only through an encapsulation
   (Which you should place, by convention, in sysdep.c).  */

/* ============================================================ */

/* After adding support for a new system, modify the large case
   statement in the `configure' script to recognize reasonable
   configuration names, and add a description of the system to
   `etc/MACHINES'.

   If you've just fixed a problem in an existing configuration file,
   you should also check `etc/MACHINES' to make sure its descriptions
   of known problems in that configuration should be updated.  */


/* Avoid the use of the name init_process (process.c) because it is
   also the name of a Mach system call.  */
#define init_process emacs_init_process

/* Used in dispnew.c.  Copied from freebsd.h. */
#define PENDING_OUTPUT_COUNT(FILE) ((FILE)->_p - (FILE)->_bf._base)

/* System uses OXTABS instead of the expected TAB3.  (Copied from
   bsd386.h.)  */
#define TAB3 OXTABS

/* Darwin ld insists on the use of malloc routines in the System
   framework.  */
#define SYSTEM_MALLOC

/* Define HAVE_SOCKETS if system supports 4.2-compatible sockets.  */
#define HAVE_SOCKETS

/* In Carbon, asynchronous I/O (using SIGIO) can't be used for window
   events because they don't come from sockets, even though it works
   fine on tty's.  */
/* This seems to help in Ctrl-G detection under Cocoa, however at the cost
   of some quirks that may or may not bother a given user. */
#if defined (HAVE_CARBON) || defined (COCOA_EXPERIMENTAL_CTRL_G)
#define NO_SOCK_SIGIO
#endif

/* Extra initialization calls in main for Mac OS X system type.  */
#ifdef HAVE_CARBON
#define SYMS_SYSTEM syms_of_mac()
#endif

/* Definitions for how to dump.  Copied from nextstep.h.  */

#define UNEXEC unexmacosx.o

#define START_FILES pre-crt0.o

/* start_of_text isn't actually used, so make it compile without error.  */
#define TEXT_START (0)

/* This seems to be right for end_of_text, but it may not be used anyway.  */
#define TEXT_END get_etext()

/* This seems to be right for end_of_data, but it may not be used anyway.  */
#define DATA_END get_edata()

/* Definitions for how to compile & link.  */

/* This is for the Carbon port.  Under the NeXTstep port, this is still picked
   up during preprocessing, but is undone in config.in. */
#ifndef HAVE_NS
#define C_SWITCH_SYSTEM -fpascal-strings -DMAC_OSX
#endif

/* Link in the Carbon or AppKit lib. */
#ifdef HAVE_NS
/* XXX: lresolv is here because configure when testing #undefs res_init,
        a macro in /usr/include/resolv.h for res_9_init, not in stdc lib. */
#define LIBS_MACGUI -framework AppKit -lresolv
#define SYSTEM_PURESIZE_EXTRA 200000
#define HEADERPAD_EXTRA 6C8
#else
#define HEADERPAD_EXTRA 690

#ifdef HAVE_CARBON

#ifdef HAVE_AVAILABILITYMACROS_H
#include <AvailabilityMacros.h>
#endif

/* Whether to use the Image I/O framework for reading images.  */
#ifndef USE_MAC_IMAGE_IO
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1040 && (MAC_OS_X_VERSION_MIN_REQUIRED >= 1040 || MAC_OS_X_VERSION_MIN_REQUIRED < 1020)
#define USE_MAC_IMAGE_IO 1
#endif
#endif

/* If the Image I/O framework is not used, fall back on QuickTime.  */
#if USE_MAC_IMAGE_IO
#define LIBS_IMAGE
#else
#define LIBS_IMAGE -framework QuickTime
#endif

#endif	/* HAVE_CARBON */

/* Link in the Carbon lib. */
#ifdef HAVE_CARBON
#define LIBS_MACGUI -framework Carbon LIBS_IMAGE
#else
#define LIBS_MACGUI
#endif /* !HAVE_CARBON */
#endif /* !HAVE_NS */

/* The -headerpad option tells ld (see man page) to leave room at the
   end of the header for adding load commands.  Needed for dumping.
   0x690 is the total size of 30 segment load commands (at 56
   each); under Cocoa 31 commands are required.  */
#define LD_SWITCH_SYSTEM_TEMACS -prebind LIBS_MACGUI -Xlinker -headerpad -Xlinker HEADERPAD_EXTRA

#define C_SWITCH_SYSTEM_TEMACS -Dtemacs

/* The ncurses library has been moved out of the System framework in
   Mac OS X 10.2.  So if ./configure detects it, set the command-line
   option to use it.  */
#ifdef HAVE_LIBNCURSES
#define LIBS_TERMCAP -lncurses
/* This prevents crashes when running Emacs in Terminal.app under
   10.2.  */
#define TERMINFO
#endif

/* Link this program just by running cc.  */
#define ORDINARY_LINK

/* We don't have a g library, so override the -lg LIBS_DEBUG switch.  */
#define LIBS_DEBUG

/* Adding -lm confuses the dynamic linker, so omit it.  */
#define LIB_MATH

/* Tell src/Makefile.in to create files in the Mac OS X application
   bundle mac/Emacs.app.  */
#ifdef HAVE_CARBON
#define OTHER_FILES macosx-app
#endif

/* PENDING: can this target be specified in a clearer way? */
#ifdef HAVE_NS
#define OTHER_FILES ns-app
#endif


/* Define the following so emacs symbols will not conflict with those
   in the System framework.  Otherwise -prebind will not work.  */

/* Do not define abort in emacs.c.  */
#define NO_ABORT

/* Do not define matherr in floatfns.c.  */
#define NO_MATHERR


/* The following solves the problem that Emacs hangs when evaluating
   (make-comint "test0" "/nodir/nofile" nil "") when /nodir/nofile
   does not exist.  */
#undef HAVE_WORKING_VFORK
#define vfork fork

/* Don't close pty in process.c to make it as controlling terminal.
   It is already a controlling terminal of subprocess, because we did
   ioctl TIOCSCTTY.  */
#define DONT_REOPEN_PTY

#ifdef temacs
#define malloc unexec_malloc
#define realloc unexec_realloc
#define free unexec_free
#endif

/* This makes create_process in process.c save and restore signal
   handlers correctly.  Suggested by Nozomu Ando.*/
#define POSIX_SIGNALS

/* Reroute calls to SELECT to the version defined in mac.c to fix the
   problem of Emacs requiring an extra return to be typed to start
   working when started from the command line.  */
#if defined (HAVE_CARBON) && (defined (emacs) || defined (temacs))
#define select sys_select
#endif

/* Use the GC_MAKE_GCPROS_NOOPS (see lisp.h) method for marking the
   stack.  */
#define GC_MARK_STACK   GC_MAKE_GCPROS_NOOPS

/* arch-tag: 481d443d-4f89-43ea-b5fb-49706d95fa41
   (do not change this comment) */
