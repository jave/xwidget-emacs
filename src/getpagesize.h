/* Emulate getpagesize on systems that lack it.  */

#ifndef HAVE_GETPAGESIZE

# ifdef VMS
#  define getpagesize() 512
# endif

# ifdef HAVE_UNISTD_H
#  include <unistd.h>
# endif

# ifdef _SC_PAGESIZE
#  define getpagesize() sysconf(_SC_PAGESIZE)
# else
#  include <sys/param.h>
#  ifdef EXEC_PAGESIZE
#   define getpagesize() EXEC_PAGESIZE
#  else /* no EXEC_PAGESIZE */
#   ifdef NBPG
#    define getpagesize() NBPG * CLSIZE
#    ifndef CLSIZE
#     define CLSIZE 1
#    endif /* no CLSIZE */
#   else /* no NBPG */
#    ifdef NBPC
#     define getpagesize() NBPC
#    else /* no NBPC */
#     ifdef PAGESIZE
#      define getpagesize() PAGESIZE
#     endif /* PAGESIZE */
#    endif /* no NBPC */
#   endif /* no NBPG */
#  endif /* no EXEC_PAGESIZE */
# endif /* no _SC_PAGESIZE */

#endif /* no HAVE_GETPAGESIZE */
