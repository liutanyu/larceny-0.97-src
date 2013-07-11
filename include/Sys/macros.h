/* Copyright 1998 Lars T Hansen.
 *
 * $Id: macros.h 5759 2008-08-15 12:17:33Z will $
 *
 * Larceny run-time system -- macros
 *
 * Machine and representation dependent (and independent) macros,
 * including tag definitions and tag masks, and interesting constants.
 *
 * For C-language routines.
 */

#ifndef INCLUDED_MACROS_H
#define INCLUDED_MACROS_H

#include <stdlib.h>             /* for abs() */

/* Various masks */
#define ISHDR_MASK      0x00000083      /* extract bits 7, 1, and 0 */
#define HDR_SIGN        0x00000082      /* header signature */
#define HDR_MASK        0x000000E3      /* Mask to extract header info */
#define FIXTAGMASK               3      /* FIXME: move to layouts.cfg */

/* Convert integer to fixnum */
#define fixnum( x )  ((x) << 2)

/* Convert fixnum to integer. Watch the sign! Can't use a shift here (sigh).
 * Might be faster to keep the sign, shift the absvalue, and convert the
 * sign again than to actually divide the signed number. Not used much, tho.
 */
#define nativeint( x )      ((word) ((s_word)(x) / 4))
#define nativeuint( n )     ((word)(n) / 4)

/* Given tagged pointer, return tag */
#define tagof( w )          ((word)(w) & TAG_MASK)

/* Given tagged pointer, return pointer */
#define ptrof( w )          ((word *)((word)(w) & ~TAG_MASK))

/* May be faster on some architectures, and should never be slower (?) */
#define striptag( w, t )   ((word*)((word)(w) - (t)))

/* Given pointer and tag, return tagged pointer */
#define tagptr( w, tag )    ((word)(w) | (tag))

/* extract header tag (i.e. sans typetag) from a header word */
#define header( w )         ((word)(w) & HDR_MASK)

/* extract type tag from a header word */
#define typetag( w )        ((word)(w) & TYPETAG_MASK)

/* strip type tag from a header word */
#define striptypetag( w )   ((word)(w) & ~TYPETAG_MASK)

/* Create a header given integer (not fixnum!) size (in bytes), and tag. */
#define mkheader( size, tag )  (((word) (size) << 8) | (tag))

/* a word is a pointer if the low bit is set */
#define isptr(w)            is_ptr(w)    /* isptr old name */
#define is_ptr(w)           ((word)(w) & 0x01)

/* a word is a header if it has a header mask layout */
#define ishdr(w)            is_hdr(w)    /* ishdr is old name */
#define is_hdr(w)           (((word)(w) & ISHDR_MASK) == HDR_SIGN)

/* Extract size field from a header word. Hi bit is always 0. */
#define sizefield( w )      ((w) >> 8)

/* miscellaneous */
#undef max
#define max( a, b )         ((a) > (b) ? (a) : (b))
#undef min
#define min( a, b )         ((a) < (b) ? (a) : (b))

#define ceildiv(a,b)        ((a)%(b) == 0 ? (a)/(b) : (a)/(b)+1)

#define roundup( a, m )     ((((a)+((m)-1)) / (m))*(m))
#define roundup2( a )       (((a) + 1) & ~1)
#define roundup4( a )       (((a) + 3) & ~3)
#define roundup8( a )       (((a) + 7) & ~7)

/* The following true on 32-bit machines */
#define roundup_word( a )   roundup4( a )
#define roundup_dword( a )  roundup8( a )

/* Rounding macros for wordsize-independence */
#define roundup_walign(a)   roundup2( a )   /* Word alignment: 2 words */
#define roundup_balign(a)   roundup8( a )   /* Byte alignment: 8 bytes */

#define the_gc( globals )      ((gc_t*)globals[ G_GC ])

#define bytes2words(x)      ((x) / sizeof(word))
#define words2bytes(x)      ((x) * sizeof(word))

/* Macros for manipulating Scheme data types. */

#define is_pair( ptr )          (tagof(ptr) == PAIR_TAG)
#define is_char( x )            (((word)(x) & 255) == IMM_CHAR)
#define is_fixnum( x )          (((word)(x) & FIXTAGMASK) == 0)
#define is_nonnegative_fixnum( x ) \
  (((x) & FIXTAGMASK) == 0 && (s_word)(x) >= 0)
#define is_both_fixnums( x, y ) \
  ((((x) | (y)) & FIXTAGMASK) == 0)

#define pair_car( ptr )        (*ptrof( ptr ))
#define pair_cdr( ptr )        (*(ptrof( ptr )+1))

#define string_length( x )     (sizefield(*ptrof( x )))
#define string_data( x )       ((char*)ptrof( x )+4)

#define vector_length( vp )    (sizefield(*ptrof(vp)) >> 2)
#define vector_ref( vp, i )    (ptrof( vp )[ VEC_HEADER_WORDS+(i) ])
#define vector_set( vp, i, v ) (ptrof( vp )[ VEC_HEADER_WORDS+(i) ] = (v))

#define procedure_length( pp ) (sizefield(*ptrof(pp)) >> 2)
#define procedure_ref( pp, i ) (ptrof(pp)[ PROC_HEADER_WORDS+(i) ])
#define procedure_set( pp, i, x )  (ptrof(pp)[ PROC_HEADER_WORDS+(i) ] = (x))

#define bytevector_length(x)   (sizefield(*ptrof(x)))
#define bytevector_ref(x,i)    (*((byte*)(ptrof(x)+1)+i))

#define mkbignum_header( sign, length )  (((sign) << 24) | length)
#define bignum_length( x )     (*(ptrof(x)+1) & 0x00FFFFFF)
#define bignum_sign( x )       ((*(ptrof(x)+1) >> 24) & 1)
#define bignum_ref32( x, i )   (*(ptrof(x)+2+i))

#define real_part( x )         (*(double*)(ptrof(x)+2))
#define imag_part( x )         (*((double*)(ptrof(x)+2)+1))

#define global_cell_ref( cp )  (pair_car( cp ))
#define global_cell_set( x, y ) (pair_car( x ) = (y))

#define fixnum_to_char( x )     (((x) << 6) | IMM_CHAR)
#define int_to_char( x )        (((x) << 8) | IMM_CHAR)
#define charcode_as_fixnum( x ) ((x) >> 6)
#define charcode( x )           ((x) >> 8)

#endif

/* eof */
