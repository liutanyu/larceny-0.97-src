/* Copyright 1998 Lars T Hansen.
 *
 * $Id: syscall2.c 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Petit Larceny -- private syscalls.
 */

#include "larceny.h"
#include "petit-instr.h"

extern cont_t *twobit_load_table[];

void larceny_segment_code_address( word w_id, word w_number )
{
  globals[G_RESULT] = 
      ENCODE_CODEPTR(twobit_load_table[nativeuint(w_id)][nativeuint(w_number)]);
}

/* eof */
