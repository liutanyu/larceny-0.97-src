/* Copyright 1998 Lars T Hansen.
 *
 * $Id: asmmacro.h 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Some macros for portability.
 */

/* The macro EXTNAME(x) produces an identifier which is a valid external
 * (i.e., C-type) name for the OS in question. 
 */

#if defined(SUNOS5) || defined(DEBIAN_SPARC)
/* On solaris external names are not prefixed by _, for some
 * reason. Seems to me this breaks all the assembly code in
 * existence, but who am I to argue...
 */
#define EXTNAME(x)  x
#endif

#ifdef SUNOS4
/* On Sunos all external names start with an underscore, and we have
 * to perform token pasting.
 */
#ifdef __STDC__
#define EXTNAME(x)  _##x
#else
#define EXTNAME(x)  _/**/x
#endif
#endif

/* Experiment */

#define CLEAR_GLOBALS   1

/* eof */
