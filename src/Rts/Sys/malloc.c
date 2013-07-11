/* Copyright 1998 Lars T Hansen.
 *
 * $Id: malloc.c 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Larceny run-time system -- malloc wrappers
 */

#include <stdlib.h>
#include "larceny.h"

/* Hacks to obtain reliable, albeit very low-level, allocation stats.
 * (Actually, the count is not reliable because it does not take into
 * account realloc. --lars)
 */

static int bytes_allocated_by_malloc = 0;

void *must_malloc( unsigned bytes )
{
  void *p;

#ifdef __MWERKS__
  /* Default CodeWarrior behavior is to return NULL if malloc is
     called with 0.  (Not ANSI compliant; stupid; etc.) */
  bytes = max( bytes, 1 );
#endif /* __MWERKS__ */

 again:
  p = malloc( bytes );
  bytes_allocated_by_malloc += bytes;
#if 0
  supremely_annoyingmsg( "Allocating %u bytes; total = %u bytes",
                         bytes, bytes_allocated_by_malloc);
#endif
  if (p == 0) {
    memfail( MF_MALLOC, "Could not allocate RTS-internal data." );
    goto again;
  }
  return p;
}


void *must_realloc( void *ptr, unsigned bytes )
{
  void *p;

 again:
  p = realloc( ptr, bytes );
#if 0
  supremely_annoyingmsg( "Re-allocating %u bytes", bytes);
#endif
  if (p == 0) {
    memfail( MF_REALLOC, "Could not allocate RTS-internal data." );
    goto again;
  }
  return p;
}

/* eof */
