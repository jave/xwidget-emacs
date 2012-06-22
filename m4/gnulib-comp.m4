# DO NOT EDIT! GENERATED AUTOMATICALLY!
# Copyright (C) 2002-2012 Free Software Foundation, Inc.
#
# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
#
# As a special exception to the GNU General Public License,
# this file may be distributed as part of a program that
# contains a configuration script generated by Autoconf, under
# the same distribution terms as the rest of that program.
#
# Generated by gnulib-tool.
#
# This file represents the compiled summary of the specification in
# gnulib-cache.m4. It lists the computed macro invocations that need
# to be invoked from configure.ac.
# In projects that use version control, this file can be treated like
# other built files.


# This macro should be invoked from ./configure.in, in the section
# "Checks for programs", right after AC_PROG_CC, and certainly before
# any checks for libraries, header files, types and library functions.
AC_DEFUN([gl_EARLY],
[
  m4_pattern_forbid([^gl_[A-Z]])dnl the gnulib macro namespace
  m4_pattern_allow([^gl_ES$])dnl a valid locale name
  m4_pattern_allow([^gl_LIBOBJS$])dnl a variable
  m4_pattern_allow([^gl_LTLIBOBJS$])dnl a variable
  AC_REQUIRE([gl_PROG_AR_RANLIB])
  # Code from module alloca-opt:
  # Code from module allocator:
  # Code from module careadlinkat:
  # Code from module clock-time:
  # Code from module crypto/md5:
  # Code from module crypto/sha1:
  # Code from module crypto/sha256:
  # Code from module crypto/sha512:
  # Code from module dosname:
  # Code from module dtoastr:
  # Code from module dtotimespec:
  # Code from module dup2:
  # Code from module extensions:
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])
  # Code from module filemode:
  # Code from module getloadavg:
  # Code from module getopt-gnu:
  # Code from module getopt-posix:
  # Code from module gettext-h:
  # Code from module gettime:
  # Code from module gettimeofday:
  # Code from module ignore-value:
  # Code from module include_next:
  # Code from module intprops:
  # Code from module inttypes-incomplete:
  # Code from module largefile:
  AC_REQUIRE([AC_SYS_LARGEFILE])
  # Code from module lstat:
  # Code from module manywarnings:
  # Code from module mktime:
  # Code from module multiarch:
  # Code from module nocrash:
  # Code from module pathmax:
  # Code from module pselect:
  # Code from module pthread_sigmask:
  # Code from module readlink:
  # Code from module signal-h:
  # Code from module snippet/_Noreturn:
  # Code from module snippet/arg-nonnull:
  # Code from module snippet/c++defs:
  # Code from module snippet/warn-on-use:
  # Code from module socklen:
  # Code from module ssize_t:
  # Code from module stat:
  # Code from module stat-time:
  # Code from module stdalign:
  # Code from module stdarg:
  dnl Some compilers (e.g., AIX 5.3 cc) need to be in c99 mode
  dnl for the builtin va_copy to work.  With Autoconf 2.60 or later,
  dnl gl_PROG_CC_C99 arranges for this.  With older Autoconf gl_PROG_CC_C99
  dnl shouldn't hurt, though installers are on their own to set c99 mode.
  gl_PROG_CC_C99
  # Code from module stdbool:
  # Code from module stddef:
  # Code from module stdint:
  # Code from module stdio:
  # Code from module stdlib:
  # Code from module strftime:
  # Code from module strtoimax:
  # Code from module strtoll:
  # Code from module strtoull:
  # Code from module strtoumax:
  # Code from module symlink:
  # Code from module sys_select:
  # Code from module sys_stat:
  # Code from module sys_time:
  # Code from module time:
  # Code from module time_r:
  # Code from module timespec:
  # Code from module timespec-add:
  # Code from module timespec-sub:
  # Code from module u64:
  # Code from module unistd:
  # Code from module utimens:
  # Code from module verify:
  # Code from module warnings:
])

# This macro should be invoked from ./configure.in, in the section
# "Check for header files, types and library functions".
AC_DEFUN([gl_INIT],
[
  AM_CONDITIONAL([GL_COND_LIBTOOL], [false])
  gl_cond_libtool=false
  gl_libdeps=
  gl_ltlibdeps=
  gl_m4_base='m4'
  m4_pushdef([AC_LIBOBJ], m4_defn([gl_LIBOBJ]))
  m4_pushdef([AC_REPLACE_FUNCS], m4_defn([gl_REPLACE_FUNCS]))
  m4_pushdef([AC_LIBSOURCES], m4_defn([gl_LIBSOURCES]))
  m4_pushdef([gl_LIBSOURCES_LIST], [])
  m4_pushdef([gl_LIBSOURCES_DIR], [])
  gl_COMMON
  gl_source_base='lib'
gl_FUNC_ALLOCA
AC_CHECK_FUNCS_ONCE([readlinkat])
gl_CLOCK_TIME
gl_MD5
gl_SHA1
gl_SHA256
gl_SHA512
AC_REQUIRE([gl_C99_STRTOLD])
gl_FUNC_DUP2
if test $HAVE_DUP2 = 0 || test $REPLACE_DUP2 = 1; then
  AC_LIBOBJ([dup2])
  gl_PREREQ_DUP2
fi
gl_UNISTD_MODULE_INDICATOR([dup2])
gl_FILEMODE
gl_GETLOADAVG
if test $HAVE_GETLOADAVG = 0; then
  AC_LIBOBJ([getloadavg])
  gl_PREREQ_GETLOADAVG
fi
gl_STDLIB_MODULE_INDICATOR([getloadavg])
gl_FUNC_GETOPT_GNU
if test $REPLACE_GETOPT = 1; then
  AC_LIBOBJ([getopt])
  AC_LIBOBJ([getopt1])
  gl_PREREQ_GETOPT
  dnl Arrange for unistd.h to include getopt.h.
  GNULIB_GL_UNISTD_H_GETOPT=1
fi
AC_SUBST([GNULIB_GL_UNISTD_H_GETOPT])
gl_MODULE_INDICATOR_FOR_TESTS([getopt-gnu])
gl_FUNC_GETOPT_POSIX
if test $REPLACE_GETOPT = 1; then
  AC_LIBOBJ([getopt])
  AC_LIBOBJ([getopt1])
  gl_PREREQ_GETOPT
  dnl Arrange for unistd.h to include getopt.h.
  GNULIB_GL_UNISTD_H_GETOPT=1
fi
AC_SUBST([GNULIB_GL_UNISTD_H_GETOPT])
gl_GETTIME
gl_FUNC_GETTIMEOFDAY
if test $HAVE_GETTIMEOFDAY = 0 || test $REPLACE_GETTIMEOFDAY = 1; then
  AC_LIBOBJ([gettimeofday])
  gl_PREREQ_GETTIMEOFDAY
fi
gl_SYS_TIME_MODULE_INDICATOR([gettimeofday])
AC_REQUIRE([AC_C_INLINE])
gl_INTTYPES_INCOMPLETE
AC_REQUIRE([gl_LARGEFILE])
gl_FUNC_LSTAT
if test $REPLACE_LSTAT = 1; then
  AC_LIBOBJ([lstat])
  gl_PREREQ_LSTAT
fi
gl_SYS_STAT_MODULE_INDICATOR([lstat])
gl_FUNC_MKTIME
if test $REPLACE_MKTIME = 1; then
  AC_LIBOBJ([mktime])
  gl_PREREQ_MKTIME
fi
gl_TIME_MODULE_INDICATOR([mktime])
gl_MULTIARCH
gl_FUNC_PSELECT
if test $HAVE_PSELECT = 0 || test $REPLACE_PSELECT = 1; then
  AC_LIBOBJ([pselect])
fi
gl_SYS_SELECT_MODULE_INDICATOR([pselect])
gl_FUNC_PTHREAD_SIGMASK
if test $HAVE_PTHREAD_SIGMASK = 0 || test $REPLACE_PTHREAD_SIGMASK = 1; then
  AC_LIBOBJ([pthread_sigmask])
  gl_PREREQ_PTHREAD_SIGMASK
fi
gl_SIGNAL_MODULE_INDICATOR([pthread_sigmask])
gl_FUNC_READLINK
if test $HAVE_READLINK = 0 || test $REPLACE_READLINK = 1; then
  AC_LIBOBJ([readlink])
  gl_PREREQ_READLINK
fi
gl_UNISTD_MODULE_INDICATOR([readlink])
gl_SIGNAL_H
gl_TYPE_SOCKLEN_T
gt_TYPE_SSIZE_T
gl_STAT_TIME
gl_STAT_BIRTHTIME
gl_STDALIGN_H
gl_STDARG_H
AM_STDBOOL_H
gl_STDDEF_H
gl_STDINT_H
gl_STDIO_H
gl_STDLIB_H
gl_FUNC_GNU_STRFTIME
gl_FUNC_STRTOIMAX
if test $HAVE_STRTOIMAX = 0 || test $REPLACE_STRTOIMAX = 1; then
  AC_LIBOBJ([strtoimax])
  gl_PREREQ_STRTOIMAX
fi
gl_INTTYPES_MODULE_INDICATOR([strtoimax])
gl_FUNC_STRTOUMAX
if test $ac_cv_func_strtoumax = no; then
  AC_LIBOBJ([strtoumax])
  gl_PREREQ_STRTOUMAX
fi
gl_INTTYPES_MODULE_INDICATOR([strtoumax])
gl_FUNC_SYMLINK
if test $HAVE_SYMLINK = 0 || test $REPLACE_SYMLINK = 1; then
  AC_LIBOBJ([symlink])
fi
gl_UNISTD_MODULE_INDICATOR([symlink])
gl_HEADER_SYS_SELECT
AC_PROG_MKDIR_P
gl_HEADER_SYS_STAT_H
AC_PROG_MKDIR_P
gl_HEADER_SYS_TIME_H
AC_PROG_MKDIR_P
gl_HEADER_TIME_H
gl_TIME_R
if test $HAVE_LOCALTIME_R = 0 || test $REPLACE_LOCALTIME_R = 1; then
  AC_LIBOBJ([time_r])
  gl_PREREQ_TIME_R
fi
gl_TIME_MODULE_INDICATOR([time_r])
gl_TIMESPEC
AC_REQUIRE([AC_C_INLINE])
gl_UNISTD_H
gl_UTIMENS
  gl_gnulib_enabled_dosname=false
  gl_gnulib_enabled_be453cec5eecf5731a274f2de7f2db36=false
  gl_gnulib_enabled_pathmax=false
  gl_gnulib_enabled_stat=false
  gl_gnulib_enabled_strtoll=false
  gl_gnulib_enabled_strtoull=false
  gl_gnulib_enabled_verify=false
  func_gl_gnulib_m4code_dosname ()
  {
    if ! $gl_gnulib_enabled_dosname; then
      gl_gnulib_enabled_dosname=true
    fi
  }
  func_gl_gnulib_m4code_be453cec5eecf5731a274f2de7f2db36 ()
  {
    if ! $gl_gnulib_enabled_be453cec5eecf5731a274f2de7f2db36; then
AC_SUBST([LIBINTL])
AC_SUBST([LTLIBINTL])
      gl_gnulib_enabled_be453cec5eecf5731a274f2de7f2db36=true
    fi
  }
  func_gl_gnulib_m4code_pathmax ()
  {
    if ! $gl_gnulib_enabled_pathmax; then
gl_PATHMAX
      gl_gnulib_enabled_pathmax=true
    fi
  }
  func_gl_gnulib_m4code_stat ()
  {
    if ! $gl_gnulib_enabled_stat; then
gl_FUNC_STAT
if test $REPLACE_STAT = 1; then
  AC_LIBOBJ([stat])
  gl_PREREQ_STAT
fi
gl_SYS_STAT_MODULE_INDICATOR([stat])
      gl_gnulib_enabled_stat=true
      if test $REPLACE_STAT = 1; then
        func_gl_gnulib_m4code_dosname
      fi
      if test $REPLACE_STAT = 1; then
        func_gl_gnulib_m4code_pathmax
      fi
      if test $REPLACE_STAT = 1; then
        func_gl_gnulib_m4code_verify
      fi
    fi
  }
  func_gl_gnulib_m4code_strtoll ()
  {
    if ! $gl_gnulib_enabled_strtoll; then
gl_FUNC_STRTOLL
if test $HAVE_STRTOLL = 0; then
  AC_LIBOBJ([strtoll])
  gl_PREREQ_STRTOLL
fi
gl_STDLIB_MODULE_INDICATOR([strtoll])
      gl_gnulib_enabled_strtoll=true
    fi
  }
  func_gl_gnulib_m4code_strtoull ()
  {
    if ! $gl_gnulib_enabled_strtoull; then
gl_FUNC_STRTOULL
if test $HAVE_STRTOULL = 0; then
  AC_LIBOBJ([strtoull])
  gl_PREREQ_STRTOULL
fi
gl_STDLIB_MODULE_INDICATOR([strtoull])
      gl_gnulib_enabled_strtoull=true
    fi
  }
  func_gl_gnulib_m4code_verify ()
  {
    if ! $gl_gnulib_enabled_verify; then
      gl_gnulib_enabled_verify=true
    fi
  }
  if test $REPLACE_GETOPT = 1; then
    func_gl_gnulib_m4code_be453cec5eecf5731a274f2de7f2db36
  fi
  if test $REPLACE_LSTAT = 1; then
    func_gl_gnulib_m4code_dosname
  fi
  if test $REPLACE_LSTAT = 1; then
    func_gl_gnulib_m4code_stat
  fi
  if test $HAVE_READLINK = 0 || test $REPLACE_READLINK = 1; then
    func_gl_gnulib_m4code_stat
  fi
  if { test $HAVE_STRTOIMAX = 0 || test $REPLACE_STRTOIMAX = 1; } && test $ac_cv_type_long_long_int = yes; then
    func_gl_gnulib_m4code_strtoll
  fi
  if test $HAVE_STRTOIMAX = 0 || test $REPLACE_STRTOIMAX = 1; then
    func_gl_gnulib_m4code_verify
  fi
  if test $ac_cv_func_strtoumax = no && test $ac_cv_type_unsigned_long_long_int = yes; then
    func_gl_gnulib_m4code_strtoull
  fi
  if test $ac_cv_func_strtoumax = no; then
    func_gl_gnulib_m4code_verify
  fi
  m4_pattern_allow([^gl_GNULIB_ENABLED_])
  AM_CONDITIONAL([gl_GNULIB_ENABLED_dosname], [$gl_gnulib_enabled_dosname])
  AM_CONDITIONAL([gl_GNULIB_ENABLED_be453cec5eecf5731a274f2de7f2db36], [$gl_gnulib_enabled_be453cec5eecf5731a274f2de7f2db36])
  AM_CONDITIONAL([gl_GNULIB_ENABLED_pathmax], [$gl_gnulib_enabled_pathmax])
  AM_CONDITIONAL([gl_GNULIB_ENABLED_stat], [$gl_gnulib_enabled_stat])
  AM_CONDITIONAL([gl_GNULIB_ENABLED_strtoll], [$gl_gnulib_enabled_strtoll])
  AM_CONDITIONAL([gl_GNULIB_ENABLED_strtoull], [$gl_gnulib_enabled_strtoull])
  AM_CONDITIONAL([gl_GNULIB_ENABLED_verify], [$gl_gnulib_enabled_verify])
  # End of code from modules
  m4_ifval(gl_LIBSOURCES_LIST, [
    m4_syscmd([test ! -d ]m4_defn([gl_LIBSOURCES_DIR])[ ||
      for gl_file in ]gl_LIBSOURCES_LIST[ ; do
        if test ! -r ]m4_defn([gl_LIBSOURCES_DIR])[/$gl_file ; then
          echo "missing file ]m4_defn([gl_LIBSOURCES_DIR])[/$gl_file" >&2
          exit 1
        fi
      done])dnl
      m4_if(m4_sysval, [0], [],
        [AC_FATAL([expected source file, required through AC_LIBSOURCES, not found])])
  ])
  m4_popdef([gl_LIBSOURCES_DIR])
  m4_popdef([gl_LIBSOURCES_LIST])
  m4_popdef([AC_LIBSOURCES])
  m4_popdef([AC_REPLACE_FUNCS])
  m4_popdef([AC_LIBOBJ])
  AC_CONFIG_COMMANDS_PRE([
    gl_libobjs=
    gl_ltlibobjs=
    if test -n "$gl_LIBOBJS"; then
      # Remove the extension.
      sed_drop_objext='s/\.o$//;s/\.obj$//'
      for i in `for i in $gl_LIBOBJS; do echo "$i"; done | sed -e "$sed_drop_objext" | sort | uniq`; do
        gl_libobjs="$gl_libobjs $i.$ac_objext"
        gl_ltlibobjs="$gl_ltlibobjs $i.lo"
      done
    fi
    AC_SUBST([gl_LIBOBJS], [$gl_libobjs])
    AC_SUBST([gl_LTLIBOBJS], [$gl_ltlibobjs])
  ])
  gltests_libdeps=
  gltests_ltlibdeps=
  m4_pushdef([AC_LIBOBJ], m4_defn([gltests_LIBOBJ]))
  m4_pushdef([AC_REPLACE_FUNCS], m4_defn([gltests_REPLACE_FUNCS]))
  m4_pushdef([AC_LIBSOURCES], m4_defn([gltests_LIBSOURCES]))
  m4_pushdef([gltests_LIBSOURCES_LIST], [])
  m4_pushdef([gltests_LIBSOURCES_DIR], [])
  gl_COMMON
  gl_source_base='tests'
changequote(,)dnl
  gltests_WITNESS=IN_`echo "${PACKAGE-$PACKAGE_TARNAME}" | LC_ALL=C tr abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ | LC_ALL=C sed -e 's/[^A-Z0-9_]/_/g'`_GNULIB_TESTS
changequote([, ])dnl
  AC_SUBST([gltests_WITNESS])
  gl_module_indicator_condition=$gltests_WITNESS
  m4_pushdef([gl_MODULE_INDICATOR_CONDITION], [$gl_module_indicator_condition])
  m4_pattern_allow([^gl_GNULIB_ENABLED_])
  m4_popdef([gl_MODULE_INDICATOR_CONDITION])
  m4_ifval(gltests_LIBSOURCES_LIST, [
    m4_syscmd([test ! -d ]m4_defn([gltests_LIBSOURCES_DIR])[ ||
      for gl_file in ]gltests_LIBSOURCES_LIST[ ; do
        if test ! -r ]m4_defn([gltests_LIBSOURCES_DIR])[/$gl_file ; then
          echo "missing file ]m4_defn([gltests_LIBSOURCES_DIR])[/$gl_file" >&2
          exit 1
        fi
      done])dnl
      m4_if(m4_sysval, [0], [],
        [AC_FATAL([expected source file, required through AC_LIBSOURCES, not found])])
  ])
  m4_popdef([gltests_LIBSOURCES_DIR])
  m4_popdef([gltests_LIBSOURCES_LIST])
  m4_popdef([AC_LIBSOURCES])
  m4_popdef([AC_REPLACE_FUNCS])
  m4_popdef([AC_LIBOBJ])
  AC_CONFIG_COMMANDS_PRE([
    gltests_libobjs=
    gltests_ltlibobjs=
    if test -n "$gltests_LIBOBJS"; then
      # Remove the extension.
      sed_drop_objext='s/\.o$//;s/\.obj$//'
      for i in `for i in $gltests_LIBOBJS; do echo "$i"; done | sed -e "$sed_drop_objext" | sort | uniq`; do
        gltests_libobjs="$gltests_libobjs $i.$ac_objext"
        gltests_ltlibobjs="$gltests_ltlibobjs $i.lo"
      done
    fi
    AC_SUBST([gltests_LIBOBJS], [$gltests_libobjs])
    AC_SUBST([gltests_LTLIBOBJS], [$gltests_ltlibobjs])
  ])
  LIBGNU_LIBDEPS="$gl_libdeps"
  AC_SUBST([LIBGNU_LIBDEPS])
  LIBGNU_LTLIBDEPS="$gl_ltlibdeps"
  AC_SUBST([LIBGNU_LTLIBDEPS])
])

# Like AC_LIBOBJ, except that the module name goes
# into gl_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([gl_LIBOBJ], [
  AS_LITERAL_IF([$1], [gl_LIBSOURCES([$1.c])])dnl
  gl_LIBOBJS="$gl_LIBOBJS $1.$ac_objext"
])

# Like AC_REPLACE_FUNCS, except that the module name goes
# into gl_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([gl_REPLACE_FUNCS], [
  m4_foreach_w([gl_NAME], [$1], [AC_LIBSOURCES(gl_NAME[.c])])dnl
  AC_CHECK_FUNCS([$1], , [gl_LIBOBJ($ac_func)])
])

# Like AC_LIBSOURCES, except the directory where the source file is
# expected is derived from the gnulib-tool parameterization,
# and alloca is special cased (for the alloca-opt module).
# We could also entirely rely on EXTRA_lib..._SOURCES.
AC_DEFUN([gl_LIBSOURCES], [
  m4_foreach([_gl_NAME], [$1], [
    m4_if(_gl_NAME, [alloca.c], [], [
      m4_define([gl_LIBSOURCES_DIR], [lib])
      m4_append([gl_LIBSOURCES_LIST], _gl_NAME, [ ])
    ])
  ])
])

# Like AC_LIBOBJ, except that the module name goes
# into gltests_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([gltests_LIBOBJ], [
  AS_LITERAL_IF([$1], [gltests_LIBSOURCES([$1.c])])dnl
  gltests_LIBOBJS="$gltests_LIBOBJS $1.$ac_objext"
])

# Like AC_REPLACE_FUNCS, except that the module name goes
# into gltests_LIBOBJS instead of into LIBOBJS.
AC_DEFUN([gltests_REPLACE_FUNCS], [
  m4_foreach_w([gl_NAME], [$1], [AC_LIBSOURCES(gl_NAME[.c])])dnl
  AC_CHECK_FUNCS([$1], , [gltests_LIBOBJ($ac_func)])
])

# Like AC_LIBSOURCES, except the directory where the source file is
# expected is derived from the gnulib-tool parameterization,
# and alloca is special cased (for the alloca-opt module).
# We could also entirely rely on EXTRA_lib..._SOURCES.
AC_DEFUN([gltests_LIBSOURCES], [
  m4_foreach([_gl_NAME], [$1], [
    m4_if(_gl_NAME, [alloca.c], [], [
      m4_define([gltests_LIBSOURCES_DIR], [tests])
      m4_append([gltests_LIBSOURCES_LIST], _gl_NAME, [ ])
    ])
  ])
])

# This macro records the list of files which have been installed by
# gnulib-tool and may be removed by future gnulib-tool invocations.
AC_DEFUN([gl_FILE_LIST], [
  build-aux/snippet/_Noreturn.h
  build-aux/snippet/arg-nonnull.h
  build-aux/snippet/c++defs.h
  build-aux/snippet/warn-on-use.h
  lib/alloca.in.h
  lib/allocator.c
  lib/allocator.h
  lib/careadlinkat.c
  lib/careadlinkat.h
  lib/dosname.h
  lib/dtoastr.c
  lib/dtotimespec.c
  lib/dup2.c
  lib/filemode.c
  lib/filemode.h
  lib/ftoastr.c
  lib/ftoastr.h
  lib/getloadavg.c
  lib/getopt.c
  lib/getopt.in.h
  lib/getopt1.c
  lib/getopt_int.h
  lib/gettext.h
  lib/gettime.c
  lib/gettimeofday.c
  lib/ignore-value.h
  lib/intprops.h
  lib/inttypes.in.h
  lib/lstat.c
  lib/md5.c
  lib/md5.h
  lib/mktime-internal.h
  lib/mktime.c
  lib/pathmax.h
  lib/pselect.c
  lib/pthread_sigmask.c
  lib/readlink.c
  lib/sha1.c
  lib/sha1.h
  lib/sha256.c
  lib/sha256.h
  lib/sha512.c
  lib/sha512.h
  lib/signal.in.h
  lib/stat-time.h
  lib/stat.c
  lib/stdalign.in.h
  lib/stdarg.in.h
  lib/stdbool.in.h
  lib/stddef.in.h
  lib/stdint.in.h
  lib/stdio.in.h
  lib/stdlib.in.h
  lib/strftime.c
  lib/strftime.h
  lib/strtoimax.c
  lib/strtol.c
  lib/strtoll.c
  lib/strtoul.c
  lib/strtoull.c
  lib/strtoumax.c
  lib/symlink.c
  lib/sys_select.in.h
  lib/sys_stat.in.h
  lib/sys_time.in.h
  lib/time.in.h
  lib/time_r.c
  lib/timespec-add.c
  lib/timespec-sub.c
  lib/timespec.h
  lib/u64.h
  lib/unistd.in.h
  lib/utimens.c
  lib/utimens.h
  lib/verify.h
  m4/00gnulib.m4
  m4/alloca.m4
  m4/c-strtod.m4
  m4/clock_time.m4
  m4/dup2.m4
  m4/extensions.m4
  m4/filemode.m4
  m4/getloadavg.m4
  m4/getopt.m4
  m4/gettime.m4
  m4/gettimeofday.m4
  m4/gnulib-common.m4
  m4/include_next.m4
  m4/inttypes.m4
  m4/largefile.m4
  m4/longlong.m4
  m4/lstat.m4
  m4/manywarnings.m4
  m4/md5.m4
  m4/mktime.m4
  m4/multiarch.m4
  m4/nocrash.m4
  m4/off_t.m4
  m4/pathmax.m4
  m4/pselect.m4
  m4/pthread_sigmask.m4
  m4/readlink.m4
  m4/sha1.m4
  m4/sha256.m4
  m4/sha512.m4
  m4/signal_h.m4
  m4/socklen.m4
  m4/ssize_t.m4
  m4/st_dm_mode.m4
  m4/stat-time.m4
  m4/stat.m4
  m4/stdalign.m4
  m4/stdarg.m4
  m4/stdbool.m4
  m4/stddef_h.m4
  m4/stdint.m4
  m4/stdio_h.m4
  m4/stdlib_h.m4
  m4/strftime.m4
  m4/strtoimax.m4
  m4/strtoll.m4
  m4/strtoull.m4
  m4/strtoumax.m4
  m4/symlink.m4
  m4/sys_select_h.m4
  m4/sys_socket_h.m4
  m4/sys_stat_h.m4
  m4/sys_time_h.m4
  m4/time_h.m4
  m4/time_r.m4
  m4/timespec.m4
  m4/tm_gmtoff.m4
  m4/unistd_h.m4
  m4/utimbuf.m4
  m4/utimens.m4
  m4/utimes.m4
  m4/warn-on-use.m4
  m4/warnings.m4
  m4/wchar_t.m4
])
