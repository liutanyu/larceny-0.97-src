/* Copyright 1998 Lars T Hansen.
 *
 * $Id: mtime.c 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Return modification time of a file.
 */

#include <sys/types.h>
#include <sys/stat.h>

unsigned mtime( fn )
char *fn;
{
  struct stat buf;

  if (stat( fn, &buf ) == -1)
    return 0;
  return buf.st_mtime;
}

