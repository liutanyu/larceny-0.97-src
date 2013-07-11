/* Copyright 1998 Lars T Hansen.
 * 
 * $Id: callback.c 4000 2007-02-15 19:45:47Z pnkfelix $
 *
 * Larceny run-time-system -- call-in to Scheme mode
 */

#include "larceny.h"

#define FRAMESIZE 24

void larceny_call( word proc, int argc, word *argv, word *result )
{
  int i, fresh_stack;
  word *p;

  /* Allocate and setup a stack frame */

  if ((globals[ G_STKP ]-SCE_BUFFER)-FRAMESIZE < globals[ G_ETOP ]) {
    hardconsolemsg( "Callback failed -- stack overflow." );
    /* Fixme: need to indicate error */
    /* Fixme: in general, we must recover from this problem! */
    *result = UNDEFINED_CONST;
    return;
  }
  fresh_stack = globals[ G_STKP ] == globals[ G_STKBOT ];
  globals[ G_STKP ] -= FRAMESIZE;
  p = (word*)globals[ G_STKP ];
  p[STK_CONTSIZE] = 5*sizeof(word);       /* size in bytes */
  p[STK_RETADDR] = 0;                    /* return address -- set by scheme_start() */
  if (fresh_stack)
    p[STK_DYNLINK] = globals[ G_CONT ];  /* dynamic link */
  else
    p[STK_DYNLINK] = 0;                  /* random */
  p[STK_PROC] = 0;                    /* procedure pointer (fixed) */
  p[4] = globals[ G_REG0 ];
  p[5] = globals[ G_RETADDR ];


  /* Setup arguments in registers -- this gcprotects them */

  globals[ G_REG0 ] = proc;
  for ( i=0 ; i < argc ; i++ ) /* FIXME: guard against argc > #regs */
    globals[ G_REG1+i ] = argv[i];
  globals[ G_RESULT ] = fixnum(argc);

  /* Check the type and invoke the procedure */

  if (tagof( globals[ G_REG0 ] ) != PROC_TAG) {
    hardconsolemsg( "Callback failed -- not a procedure." );
    /* Fixme: need to indicate error */
    *result = UNDEFINED_CONST;
    return;
  }

  scheme_start( globals );

  *result = globals[ G_RESULT ];

  /* Pop the frame */
  p = (word*)globals[ G_STKP ];
  globals[ G_REG0 ] = p[4];
  globals[ G_RETADDR ] = p[5];
  globals[ G_STKP ] += FRAMESIZE;
}

/* eof */
