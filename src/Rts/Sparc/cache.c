/* Copyright 1998 Lars T Hansen.
 *
 * $Id: cache.c 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Cache management for the SPARC
 */

#include "larceny.h"

extern int test_cache( void );	/* See cache0.s */

/* Configure Larceny's cache logic */
void cache_setup( void )
{
#if defined( FLUSH_ALWAYS )
  globals[ G_CACHE_FLUSH ] = 1;
#elif defined( FLUSH_NEVER )
  globals[ G_CACHE_FLUSH ] = 0;
#else
  globals[ G_CACHE_FLUSH ] = (test_cache() > 0);
#endif
}

/* eof */
