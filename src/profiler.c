/* Profiler implementation.

Copyright (C) 2012 Free Software Foundation, Inc.

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

#include <config.h>
#include "lisp.h"
#include "syssignal.h"
#include "systime.h"

/* Return A + B, but return the maximum fixnum if the result would overflow.
   Assume A and B are nonnegative and in fixnum range.  */

static EMACS_INT
saturated_add (EMACS_INT a, EMACS_INT b)
{
  return min (a + b, MOST_POSITIVE_FIXNUM);
}

/* Logs.  */

typedef struct Lisp_Hash_Table log_t;

static Lisp_Object
make_log (int heap_size, int max_stack_depth)
{
  /* We use a standard Elisp hash-table object, but we use it in
     a special way.  This is OK as long as the object is not exposed
     to Elisp, i.e. until it is returned by *-profiler-log, after which
     it can't be used any more.  */
  Lisp_Object log = make_hash_table (Qequal, make_number (heap_size),
				     make_float (DEFAULT_REHASH_SIZE),
				     make_float (DEFAULT_REHASH_THRESHOLD),
				     Qnil, Qnil, Qnil);
  struct Lisp_Hash_Table *h = XHASH_TABLE (log);

  /* What is special about our hash-tables is that the keys are pre-filled
     with the vectors we'll put in them.  */
  int i = ASIZE (h->key_and_value) / 2;
  while (0 < i)
    set_hash_key_slot (h, --i,
		       Fmake_vector (make_number (max_stack_depth), Qnil));
  return log;
}

/* Evict the least used half of the hash_table.

   When the table is full, we have to evict someone.
   The easiest and most efficient is to evict the value we're about to add
   (i.e. once the table is full, stop sampling).

   We could also pick the element with the lowest count and evict it,
   but finding it is O(N) and for that amount of work we get very
   little in return: for the next sample, this latest sample will have
   count==1 and will hence be a prime candidate for eviction :-(

   So instead, we take O(N) time to eliminate more or less half of the
   entries (the half with the lowest counts).  So we get an amortized
   cost of O(1) and we get O(N) time for a new entry to grow larger
   than the other least counts before a new round of eviction.  */

static EMACS_INT approximate_median (log_t *log,
				     ptrdiff_t start, ptrdiff_t size)
{
  eassert (size > 0);
  if (size < 2)
    return XINT (HASH_VALUE (log, start));
  if (size < 3)
    /* Not an actual median, but better for our application than
       choosing either of the two numbers.  */
    return ((XINT (HASH_VALUE (log, start))
	     + XINT (HASH_VALUE (log, start + 1)))
	    / 2);
  else
    {
      ptrdiff_t newsize = size / 3;
      ptrdiff_t start2 = start + newsize;
      EMACS_INT i1 = approximate_median (log, start, newsize);
      EMACS_INT i2 = approximate_median (log, start2, newsize);
      EMACS_INT i3 = approximate_median (log, start2 + newsize,
					 size - 2 * newsize);
      return (i1 < i2
	      ? (i2 < i3 ? i2 : (i1 < i3 ? i3 : i1))
	      : (i1 < i3 ? i1 : (i2 < i3 ? i3 : i2)));
    }
}

static void evict_lower_half (log_t *log)
{
  ptrdiff_t size = ASIZE (log->key_and_value) / 2;
  EMACS_INT median = approximate_median (log, 0, size);
  ptrdiff_t i;

  for (i = 0; i < size; i++)
    /* Evict not only values smaller but also values equal to the median,
       so as to make sure we evict something no matter what.  */
    if (XINT (HASH_VALUE (log, i)) <= median)
      {
	Lisp_Object key = HASH_KEY (log, i);
	{ /* FIXME: we could make this more efficient.  */
	  Lisp_Object tmp;
	  XSET_HASH_TABLE (tmp, log); /* FIXME: Use make_lisp_ptr.  */
	  Fremhash (key, tmp);
	}
	eassert (EQ (log->next_free, make_number (i)));
	{
	  int j;
	  eassert (VECTORP (key));
	  for (j = 0; j < ASIZE (key); j++)
	    ASET (key, j, Qnil);
	}
	set_hash_key_slot (log, i, key);
      }
}

/* Record the current backtrace in LOG.  COUNT is the weight of this
   current backtrace: milliseconds for CPU counts, and the allocation
   size for memory logs.  */

static void
record_backtrace (log_t *log, EMACS_INT count)
{
  struct backtrace *backlist = backtrace_list;
  Lisp_Object backtrace;
  ptrdiff_t index, i = 0;
  ptrdiff_t asize;

  if (!INTEGERP (log->next_free))
    /* FIXME: transfer the evicted counts to a special entry rather
       than dropping them on the floor.  */
    evict_lower_half (log);
  index = XINT (log->next_free);

  /* Get a "working memory" vector.  */
  backtrace = HASH_KEY (log, index);
  asize = ASIZE (backtrace);

  /* Copy the backtrace contents into working memory.  */
  for (; i < asize && backlist; i++, backlist = backlist->next)
    /* FIXME: For closures we should ignore the environment.  */
    ASET (backtrace, i, backlist->function);

  /* Make sure that unused space of working memory is filled with nil.  */
  for (; i < asize; i++)
    ASET (backtrace, i, Qnil);

  { /* We basically do a `gethash+puthash' here, except that we have to be
       careful to avoid memory allocation since we're in a signal
       handler, and we optimize the code to try and avoid computing the
       hash+lookup twice.  See fns.c:Fputhash for reference.  */
    EMACS_UINT hash;
    ptrdiff_t j = hash_lookup (log, backtrace, &hash);
    if (j >= 0)
      {
	EMACS_INT old_val = XINT (HASH_VALUE (log, j));
	EMACS_INT new_val = saturated_add (old_val, count);
	set_hash_value_slot (log, j, make_number (new_val));
      }
    else
      { /* BEWARE!  hash_put in general can allocate memory.
	   But currently it only does that if log->next_free is nil.  */
	int j;
	eassert (!NILP (log->next_free));
	j = hash_put (log, backtrace, make_number (count), hash);
	/* Let's make sure we've put `backtrace' right where it
	   already was to start with.  */
	eassert (index == j);

	/* FIXME: If the hash-table is almost full, we should set
	   some global flag so that some Elisp code can offload its
	   data elsewhere, so as to avoid the eviction code.
	   There are 2 ways to do that, AFAICT:
	   - Set a flag checked in QUIT, such that QUIT can then call
	     Fprofiler_cpu_log and stash the full log for later use.
	   - Set a flag check in post-gc-hook, so that Elisp code can call
	     profiler-cpu-log.  That gives us more flexibility since that
	     Elisp code can then do all kinds of fun stuff like write
	     the log to disk.  Or turn it right away into a call tree.
	   Of course, using Elisp is generally preferable, but it may
	   take longer until we get a chance to run the Elisp code, so
	   there's more risk that the table will get full before we
	   get there.  */
      }
  }
}

/* Sample profiler.  */

#ifdef PROFILER_CPU_SUPPORT

/* The profiler timer and whether it was properly initialized, if
   POSIX timers are available.  */
#ifdef HAVE_TIMER_SETTIME
static timer_t profiler_timer;
static bool profiler_timer_ok;
#endif

/* Status of sampling profiler.  */
static enum profiler_cpu_running
  { NOT_RUNNING, TIMER_SETTIME_RUNNING, SETITIMER_RUNNING }
  profiler_cpu_running;

/* Hash-table log of CPU profiler.  */
static Lisp_Object cpu_log;

/* Separate counter for the time spent in the GC.  */
static EMACS_INT cpu_gc_count;

/* The current sample interval in milliseconds.  */
static EMACS_INT current_sample_interval;

/* Signal handler for sample profiler.  */

static void
handle_profiler_signal (int signal)
{
  if (backtrace_list && EQ (backtrace_list->function, Qautomatic_gc))
    /* Special case the time-count inside GC because the hash-table
       code is not prepared to be used while the GC is running.
       More specifically it uses ASIZE at many places where it does
       not expect the ARRAY_MARK_FLAG to be set.  We could try and
       harden the hash-table code, but it doesn't seem worth the
       effort.  */
    cpu_gc_count = saturated_add (cpu_gc_count, current_sample_interval);
  else
    {
      eassert (HASH_TABLE_P (cpu_log));
      record_backtrace (XHASH_TABLE (cpu_log), current_sample_interval);
    }
}

static void
deliver_profiler_signal (int signal)
{
  deliver_process_signal (signal, handle_profiler_signal);
}

static enum profiler_cpu_running
setup_cpu_timer (Lisp_Object sample_interval)
{
  struct sigaction action;
  struct itimerval timer;
  struct timespec interval;

  if (! RANGED_INTEGERP (1, sample_interval,
			 (TYPE_MAXIMUM (time_t) < EMACS_INT_MAX / 1000
			  ? (EMACS_INT) TYPE_MAXIMUM (time_t) * 1000 + 999
			  : EMACS_INT_MAX)))
    return NOT_RUNNING;

  current_sample_interval = XINT (sample_interval);
  interval = make_emacs_time (current_sample_interval / 1000,
			      current_sample_interval % 1000 * 1000000);
  emacs_sigaction_init (&action, deliver_profiler_signal);
  sigaction (SIGPROF, &action, 0);

#ifdef HAVE_TIMER_SETTIME
  if (! profiler_timer_ok)
    {
      /* System clocks to try, in decreasing order of desirability.  */
      static clockid_t const system_clock[] = {
#ifdef CLOCK_THREAD_CPUTIME_ID
	CLOCK_THREAD_CPUTIME_ID,
#endif
#ifdef CLOCK_PROCESS_CPUTIME_ID
	CLOCK_PROCESS_CPUTIME_ID,
#endif
#ifdef CLOCK_MONOTONIC
	CLOCK_MONOTONIC,
#endif
	CLOCK_REALTIME
      };
      int i;
      struct sigevent sigev;
      sigev.sigev_value.sival_ptr = &profiler_timer;
      sigev.sigev_signo = SIGPROF;
      sigev.sigev_notify = SIGEV_SIGNAL;

      for (i = 0; i < sizeof system_clock / sizeof *system_clock; i++)
	if (timer_create (system_clock[i], &sigev, &profiler_timer) == 0)
	  {
	    profiler_timer_ok = 1;
	    break;
	  }
    }

  if (profiler_timer_ok)
    {
      struct itimerspec ispec;
      ispec.it_value = ispec.it_interval = interval;
      timer_settime (profiler_timer, 0, &ispec, 0);
      return TIMER_SETTIME_RUNNING;
    }
#endif

  timer.it_value = timer.it_interval = make_timeval (interval);
  setitimer (ITIMER_PROF, &timer, 0);
  return SETITIMER_RUNNING;
}

DEFUN ("profiler-cpu-start", Fprofiler_cpu_start, Sprofiler_cpu_start,
       1, 1, 0,
       doc: /* Start or restart the cpu profiler.
It takes call-stack samples each SAMPLE-INTERVAL milliseconds.
See also `profiler-log-size' and `profiler-max-stack-depth'.  */)
  (Lisp_Object sample_interval)
{
  if (profiler_cpu_running)
    error ("Sample profiler is already running");

  if (NILP (cpu_log))
    {
      cpu_gc_count = 0;
      cpu_log = make_log (profiler_log_size,
			  profiler_max_stack_depth);
    }

  profiler_cpu_running = setup_cpu_timer (sample_interval);
  if (! profiler_cpu_running)
    error ("Invalid sample interval");

  return Qt;
}

DEFUN ("profiler-cpu-stop", Fprofiler_cpu_stop, Sprofiler_cpu_stop,
       0, 0, 0,
       doc: /* Stop the cpu profiler.  The profiler log is not affected.
Return non-nil if the profiler was running.  */)
  (void)
{
  switch (profiler_cpu_running)
    {
    case NOT_RUNNING:
      return Qnil;

#ifdef HAVE_TIMER_SETTIME
    case TIMER_SETTIME_RUNNING:
      {
	struct itimerspec disable;
	memset (&disable, 0, sizeof disable);
	timer_settime (profiler_timer, 0, &disable, 0);
      }
      break;
#endif

    case SETITIMER_RUNNING:
      {
	struct itimerval disable;
	memset (&disable, 0, sizeof disable);
	setitimer (ITIMER_PROF, &disable, 0);
      }
      break;
    }

  signal (SIGPROF, SIG_IGN);
  profiler_cpu_running = NOT_RUNNING;
  return Qt;
}

DEFUN ("profiler-cpu-running-p",
       Fprofiler_cpu_running_p, Sprofiler_cpu_running_p,
       0, 0, 0,
       doc: /* Return non-nil iff cpu profiler is running.  */)
  (void)
{
  return profiler_cpu_running ? Qt : Qnil;
}

DEFUN ("profiler-cpu-log", Fprofiler_cpu_log, Sprofiler_cpu_log,
       0, 0, 0,
       doc: /* Return the current cpu profiler log.
The log is a hash-table mapping backtraces to counters which represent
the amount of time spent at those points.  Every backtrace is a vector
of functions, where the last few elements may be nil.
Before returning, a new log is allocated for future samples.  */)
  (void)
{
  Lisp_Object result = cpu_log;
  /* Here we're making the log visible to Elisp, so it's not safe any
     more for our use afterwards since we can't rely on its special
     pre-allocated keys anymore.  So we have to allocate a new one.  */
  cpu_log = (profiler_cpu_running
	     ? make_log (profiler_log_size, profiler_max_stack_depth)
	     : Qnil);
  Fputhash (Fmake_vector (make_number (1), Qautomatic_gc),
	    make_number (cpu_gc_count),
	    result);
  cpu_gc_count = 0;
  return result;
}
#endif /* PROFILER_CPU_SUPPORT */

/* Memory profiler.  */

/* True if memory profiler is running.  */
bool profiler_memory_running;

static Lisp_Object memory_log;

DEFUN ("profiler-memory-start", Fprofiler_memory_start, Sprofiler_memory_start,
       0, 0, 0,
       doc: /* Start/restart the memory profiler.
The memory profiler will take samples of the call-stack whenever a new
allocation takes place.  Note that most small allocations only trigger
the profiler occasionally.
See also `profiler-log-size' and `profiler-max-stack-depth'.  */)
  (void)
{
  if (profiler_memory_running)
    error ("Memory profiler is already running");

  if (NILP (memory_log))
    memory_log = make_log (profiler_log_size,
			   profiler_max_stack_depth);

  profiler_memory_running = true;

  return Qt;
}

DEFUN ("profiler-memory-stop",
       Fprofiler_memory_stop, Sprofiler_memory_stop,
       0, 0, 0,
       doc: /* Stop the memory profiler.  The profiler log is not affected.
Return non-nil if the profiler was running.  */)
  (void)
{
  if (!profiler_memory_running)
    return Qnil;
  profiler_memory_running = false;
  return Qt;
}

DEFUN ("profiler-memory-running-p",
       Fprofiler_memory_running_p, Sprofiler_memory_running_p,
       0, 0, 0,
       doc: /* Return non-nil if memory profiler is running.  */)
  (void)
{
  return profiler_memory_running ? Qt : Qnil;
}

DEFUN ("profiler-memory-log",
       Fprofiler_memory_log, Sprofiler_memory_log,
       0, 0, 0,
       doc: /* Return the current memory profiler log.
The log is a hash-table mapping backtraces to counters which represent
the amount of memory allocated at those points.  Every backtrace is a vector
of functions, where the last few elements may be nil.
Before returning, a new log is allocated for future samples.  */)
  (void)
{
  Lisp_Object result = memory_log;
  /* Here we're making the log visible to Elisp , so it's not safe any
     more for our use afterwards since we can't rely on its special
     pre-allocated keys anymore.  So we have to allocate a new one.  */
  memory_log = (profiler_memory_running
		? make_log (profiler_log_size, profiler_max_stack_depth)
		: Qnil);
  return result;
}


/* Signals and probes.  */

/* Record that the current backtrace allocated SIZE bytes.  */
void
malloc_probe (size_t size)
{
  eassert (HASH_TABLE_P (memory_log));
  record_backtrace (XHASH_TABLE (memory_log), min (size, MOST_POSITIVE_FIXNUM));
}

void
syms_of_profiler (void)
{
  DEFVAR_INT ("profiler-max-stack-depth", profiler_max_stack_depth,
	      doc: /* Number of elements from the call-stack recorded in the log.  */);
  profiler_max_stack_depth = 16;
  DEFVAR_INT ("profiler-log-size", profiler_log_size,
	      doc: /* Number of distinct call-stacks that can be recorded in a profiler log.
If the log gets full, some of the least-seen call-stacks will be evicted
to make room for new entries.  */);
  profiler_log_size = 10000;

#ifdef PROFILER_CPU_SUPPORT
  profiler_cpu_running = NOT_RUNNING;
  cpu_log = Qnil;
  staticpro (&cpu_log);
  defsubr (&Sprofiler_cpu_start);
  defsubr (&Sprofiler_cpu_stop);
  defsubr (&Sprofiler_cpu_running_p);
  defsubr (&Sprofiler_cpu_log);
#endif
  profiler_memory_running = false;
  memory_log = Qnil;
  staticpro (&memory_log);
  defsubr (&Sprofiler_memory_start);
  defsubr (&Sprofiler_memory_stop);
  defsubr (&Sprofiler_memory_running_p);
  defsubr (&Sprofiler_memory_log);
}
