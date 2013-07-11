/* Copyright 1998 Lars T Hansen.
 *
 * $Id: ffi-dummy.c 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Stand-in procedures for the dynamic linking library functions.
 */

int dlopen(void);
int dlsym(void);
int dlerror(void);

int dlopen(void)
{
  abort();
}

int dlsym(void)
{
  abort();
}

int dlerror(void)
{
  abort();
}
