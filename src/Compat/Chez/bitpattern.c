/* Copyright 1998 Lars T Hansen.
 *
 * $Id: bitpattern.c 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Chez Scheme compatibility code -- get bitpattern from flonum.
 */
unsigned bitpattern( i, f )
int i;
double f;
{
  if (i == 0)
    return *( (unsigned *) &f);
  else
    return *( (unsigned *) &f + 1);
}
