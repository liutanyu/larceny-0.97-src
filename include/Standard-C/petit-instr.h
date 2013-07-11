/* Copyright 1998 Lars T Hansen.
 * 
 * $Id: petit-instr.h 5037 2007-10-30 19:35:39Z will $
 *
 * Petit Larceny -- Twobit instruction and primitive macros.
 *
 * The assembler defines the following to affect the code generated:
 *   UNSAFE_CODE        omit all type checks
 *   UNSAFE_GLOBALS     omit undefined-checks on globals
 *   INLINE_ALLOCATION  inline all allocation
 *   INLINE_ASSIGNMENT  inline the write barrier (at least partially)
 *
 * BUGS:
 *  - The code in this file makes some assumptions that are not 
 *    guaranteed by the ANSI/ISO C standard to be true, however 
 *    they are on most compilers:
 *
 *      - Right-shift of an unsigned quantity shifts in 0s at the 
 *        high end. Search for >> in the code to find all places 
 *        where this happens.
 *
 *        Larceny needs to be delivered with a program that tests this,
 *        and ideally the right shift should be abstracted out into a
 *        macro whose implementation can be selected as appropriate.
 */

#ifndef TWOBIT_H
#define TWOBIT_H

#include <string.h>
#include "config.h"
#include "macros.h"
#include "cdefs.h"
#include "millicode.h"
#include "petit-machine.h"
#include "assert.h"

#ifndef USE_CACHED_STATE
# define USE_CACHED_STATE 0     /* Cache some VM registers locally if 1 */
#endif
#define MC_DEBUG          0     /* Turn on some debugging code (slow) */
#define MC_DEBUG_CACHED   0	/* Debug the cached VM registers */

#ifdef WIN32
# define CDECL __cdecl
#else
# define CDECL 
#endif

#if USE_RETURN_WITHOUT_VALUE || USE_LONGJUMP
extern cont_t twobit_cont_label;
#endif

#define SECOND                    (globals[ G_SECOND ])
#define THIRD                     (globals[ G_THIRD ])
#define TIMER                     (globals[ G_TIMER ])
#define STKLIM                    (globals[ G_STKLIM ])

#if USE_GOTOS_LOCALLY
#  if USE_CACHED_STATE
     /* Caching RESULT and STKP bloats the object code significantly,
	but it also improves performance quite a bit.  Can be refined
	by not having STKP in either memory or a local, but just caching
        it in a local and always updating the value in memory when
        it changes.  This reduces code size but costs almost nothing.
        */
#    define twobit_prologue()     word EXCODE_, RESULT_, STKP_; RESTORE_STATE(); \
                                  switch (ENTRY_LABEL) {  \
                                  case 0 :
#    define RESULT                RESULT_
#    define STKP                  STKP_
#    define SAVE_STATE()          globals[G_RESULT] = RESULT_; globals[G_STKP] = STKP_
#    define RESTORE_STATE()       RESULT_ = globals[G_RESULT]; STKP_ = globals[G_STKP]
#  else /* !USE_CACHED_STATE */
#    define twobit_prologue()     word EXCODE_; \
                                  switch (ENTRY_LABEL) {  \
                                  case 0 :
#    define RESULT                (globals[G_RESULT])
#    define STKP                  (globals[G_STKP])
#    define SAVE_STATE()          ((void)0)
#    define RESTORE_STATE()       ((void)0)
#  endif /* USE_CACHED_STATE */
#  define twobit_epilogue()       default: \
                                    /* panic_abort( "Bad case: %d", ENTRY_LABEL ); */ \
                                    RETURN_RTYPE(0); \
                                  } \
                                  failure: \
                                    SAVE_STATE(); mc_exception( globals, EXCODE_ ); \
                                    RETURN_RTYPE(0);
#  define FAIL(code)              do { EXCODE_ = code; goto failure; } while(0)
#else /* !USE_GOTOS_LOCALLY */
  /* The following probably still works but is not used much */
#define STKP                      (globals[ G_STKP ])
#define FAIL(code) \
   do { SAVE_STATE(); mc_exception( globals, code ); } while(0)
#if USE_CACHED_STATE     /* Cache the value of RESULT */
# if MC_DEBUG_CACHED     /* Keep cache state and check it */ 
   extern int twobit_cache_state;
#  define twobit_prologue()       word RESULT_; RESTORE_STATE()
#  define RESULT                  RESULT_
#  define SAVE_STATE() \
    do { assert( twobit_cache_state ); globals[ G_RESULT ]=RESULT_; \
         twobit_cache_state=0; \
    } while(0)
#  define RESTORE_STATE() \
    do { assert( !twobit_cache_state ); RESULT_ = globals[ G_RESULT ]; \
         twobit_cache_state=1; \
    } while(0)
# else                   /* Fast, non-checking code */
#  define twobit_prologue()       word RESULT_; RESTORE_STATE()
#  define RESULT                  RESULT_
#  define SAVE_STATE()            globals[ G_RESULT ] = RESULT_
#  define RESTORE_STATE()         RESULT_ = globals[ G_RESULT ]
# endif
#else                    /* Do not cache value of RESULT */
# define twobit_prologue()       (void)0
# define RESULT                  globals[ G_RESULT ]
# define SAVE_STATE()            (void)0
# define RESTORE_STATE()         (void)0
#endif
#define twobit_epilogue()        (void)0
#endif

#define SPLICE( x, y )  x ## y
#define MKLABEL( n )   SPLICE( L, n )

/* Save and restore cached state across a call-out */
#define WITH_SAVED_STATE( the_call ) \
  do { SAVE_STATE(); \
       the_call; \
       RESTORE_STATE(); \
  } while(0)

/* Define UNSAFE_CODE at the head of a file (before including petit-instr.h) 
   to compile without type checks.
   */
#ifdef UNSAFE_CODE
# define UNSAFE_TRUE( code )              (1)
# define UNSAFE_TRUE2( code1, code2 )     (code2)
# define UNSAFE_FALSE( code )             (0)
#else
# define UNSAFE_TRUE( code )              (code)
# define UNSAFE_TRUE2( code1, code2 )     (code1)
# define UNSAFE_FALSE( code )             (code)
#endif

/* Define INLINE_ALLOCATION at the head of a file (before including petit-instr.h)
   to compile with allocation inlined.
   */
#ifdef INLINE_ALLOCATION
# define ALLOCATE( nbytes ) /* fixnum number of words = native number of bytes */ \
    do { \
          word size = nbytes; \
          size = roundup_balign( size ); \
          if (globals[G_ETOP] + size <= STKP) { \
            RESULT = globals[G_ETOP]; \
            globals[G_ETOP] += size; \
          } \
          else { \
            RESULT = size; \
            WITH_SAVED_STATE( mc_alloc( globals ) ); \
          } \
    } while(0)
# define ALLOCATE_BV( nbytes_fix ) /* fixnum number of bytes */ \
    do { \
          word nbytes = nativeuint(nbytes_fix); \
          word size = roundup_balign(nbytes); \
          if (globals[G_ETOP] + size <= STKP) { \
            RESULT = globals[G_ETOP]; \
            globals[G_ETOP] += size; \
          } \
          else { \
            RESULT = fixnum(nbytes); \
            WITH_SAVED_STATE( mc_alloc_bv( globals ) ); \
          } \
    } while(0)
/* alloci does a bunch of work anyway, so just call to millicode always */
# define ALLOCATE_I( nbytes ) \
    do { \
          RESULT = nbytes; \
          WITH_SAVED_STATE( mc_alloci( globals ) ); \
    } while(0)
#else
# define ALLOCATE( nbytes ) \
    do { \
          RESULT = nbytes; \
          WITH_SAVED_STATE( mc_alloc( globals ) ); \
    } while(0)
# define ALLOCATE_I( nbytes ) \
    do { \
          RESULT = nbytes; \
          WITH_SAVED_STATE( mc_alloci( globals ) ); \
    } while(0)
# define ALLOCATE_BV( nbytes ) \
    do { \
          RESULT = nbytes; \
          WITH_SAVED_STATE( mc_alloc_bv( globals ) ); \
    } while(0)
#endif


/* Define INLINE_ASSIGNMENT at the head of a file (before including petit-instr.h)
   to compile with a fast pointer check inlined before calling the barrier.
   */
#ifdef INLINE_ASSIGNMENT
# define BARRIER()  \
    do { if (SECOND & 1) \
            WITH_SAVED_STATE( mc_partial_barrier( globals ) ); \
    } while(0)
#else
# define BARRIER()  \
    WITH_SAVED_STATE( mc_full_barrier( globals ) )
#endif


#if defined( BITS_32 )
# define SHIFT_LIMIT  32
#elif defined( BITS_64 )
# define SHIFT_LIMIT  64
#else
# error "Bits must be 32 or 64!"
#endif

#if MC_DEBUG
# define integrity_check( name ) \
  WITH_SAVED_STATE( twobit_integrity_check( globals, name ) )
#else
# define integrity_check( name ) (void)0
#endif

#define reg( k )            (globals[ G_REG0+(k) ])
#define stack( k )          *((word*)STKP + (k))
#define get_const( k )      *vec_addr( *proc_addr( reg(0), IDX_PROC_CONST ), k )
#define setcc( cond )       RESULT = ((cond) ? TRUE_CONST : FALSE_CONST)
#define framesize( n )      (n+2) /* not STK_OVERHEAD -- counts header also */
#define realframesize( n )  roundup_walign(framesize(n)+1)

#define word_addr( x, tag, header_words, fixnum_offset ) \
  ((word*)((byte*)(x)+((header_words)*sizeof(word)-(tag))+(fixnum_offset)))

#define byte_addr( x, tag, header_words, fixnum_offset ) \
  ((byte*)(x)+((header_words)*sizeof(word)-(tag))+((fixnum_offset)>>2))

#define car_addr( x )     word_addr( x, PAIR_TAG, 0, fixnum(0) )
#define cdr_addr( x )     word_addr( x, PAIR_TAG, 0, fixnum(1) )
#define vec_addr( x, y )  word_addr( x, VEC_TAG, VEC_HEADER_WORDS, fixnum(y) )
#define proc_addr( x, y ) word_addr( x, PROC_TAG, PROC_HEADER_WORDS, fixnum(y))

#define the_header( x, tag ) (*(word*)((byte*)(x)-tag))

#define double_tag_test( x, tag, hdr, tmp ) \
  (tagof(x) == tag && ((tmp = the_header( x, tag ))&255) == hdr)

#define double_tag_predicate( x, tag, hdr ) \
  setcc( tagof(x) == tag && (the_header( x, tag )&255) == hdr )

/* make-vector, make-procedure */
#define make_vectorish( header_words, excode, header, ptrtag, init ) \
   do { int n; word *p; \
        SECOND = init; \
        if (UNSAFE_TRUE(is_nonnegative_fixnum( RESULT ))) { \
          n = RESULT; \
          ALLOCATE_I( n + fixnum(header_words) ); \
          p = (word*)RESULT; \
          p[0] = mkheader( n, header ); \
          RESULT = tagptr( p, ptrtag ); \
        } else { FAIL( excode ); } \
   } while(0)

#if USE_GOTOS_LOCALLY
# define CONT_LOCAL( k_numeric, k_symbolic )  ((cont_t)k_numeric)

# define twobit_label( k_numeric, k_symbolic ) \
   case k_numeric : MKLABEL(k_symbolic) :
#else
# define CONT_LOCAL( k_numeric, k_symbolic )  ((cont_t)k_symbolic)

# define twobit_label( k_numeric, k_symbolic ) \
   twobit_skip( k_numeric, k_symbolic ); \
   } /* END OF PROCEDURE */ \
   /* NOW START NEW PROCEDURE */ \
   static RTYPE k_symbolic( CONT_PARAMS ) { \
     twobit_prologue(); 
#endif

#define implicit_label( e, k_numeric, k_symbolic ) \
   WITH_SAVED_STATE( e ); \
   twobit_label( k_numeric, k_symbolic ) 

/* From MIPS R4000 manual: Signed add with overflow detection.

   --- compute t0 = t1 + t2, branch to L on signed overflow
   addu t0, t1, t2
   xor  t3, t1, t2
   bltz t3, 1f
   --- t1 and t2 have same sign
   xor  t3, t0, t1
   bltz t3, L
1:
*/
#define twobit_add( x, y, kn, k ) /* addition */ \
   do { word a = x, b = y; \
        if (is_both_fixnums( a, b )) { \
          word res = a + b; \
          if ((s_word)(a ^ b) < 0 || (s_word)(res ^ a) >= 0) { \
            RESULT = res; \
            twobit_skip(kn,k); \
          } \
        } \
        SECOND = b; \
   } while(0); \
   implicit_label( mc_add( globals, CONT_LOCAL(kn,k) ), kn, k )

/* From MIPS R4000 manual: Signed subtract with overflow detection.

   --- compute t0 - t1 - t2, branch to L on signed overflow
   subu t0, t1, t2
   xor  t3, t1, t2
   bgez t3, 1f
   --- t1 and t2 have different signs
   xor  t3, t0, t1
   bltz t3, L
1:
*/
#define twobit_subtract( x, y, kn, k ) /* subtraction */ \
   do { word a = x, b = y; \
	if (is_both_fixnums( a, b )) { \
          word res = a - b; \
          if ((s_word)(a ^ b) >= 0 || (s_word)(res ^ a) >= 0) { \
            RESULT = res; \
            twobit_skip(kn,k); \
          } \
        } \
        SECOND = b; \
   } while(0); \
   implicit_label( mc_sub( globals, CONT_LOCAL(kn,k) ), kn, k )

/* Comparison (=, <, <=, >, >=) */
#define twobit_compare( x, y, op, generic, kn, k ) /* numeric comparison */ \
  do { word a = x, b = y; \
       if (is_both_fixnums( a, b )) { \
         setcc( (s_word)a op (s_word)b ); \
         twobit_skip( kn, k ); \
       } \
       SECOND = b; \
  } while(0); \
  implicit_label( generic( globals, CONT_LOCAL(kn,k) ), kn, k )


/* Twobit instructions */

#define twobit_imm_const( w ) \
  RESULT = (word)(w); integrity_check( "imm_const" )

#define twobit_const( k ) \
  RESULT = get_const( k ); integrity_check( "const" )

#if defined UNSAFE_CODE || defined UNSAFE_GLOBALS
#define twobit_global( k ) \
  do {  word cell = get_const( k ); \
        RESULT = global_cell_ref( cell ); \
        integrity_check( "global" ); \
  } while(0)
#else
#define twobit_global( k ) \
  do {  word cell = get_const( k ), \
             x = RESULT = global_cell_ref( cell ); \
        if (x == UNDEFINED_CONST) { \
	  RESULT = cell; \
	  FAIL( EX_UNDEF_GLOBAL ); \
	} \
        integrity_check( "global" ); \
  } while(0)
#endif

#define twobit_setglbl( k ) \
  do { word b=SECOND=RESULT; \
       word a=RESULT=get_const( k ); \
       global_cell_set( a, b ); \
       BARRIER(); \
       integrity_check( "setglbl" ); \
  } while(0)

#define init_closure( regs, p ) \
  do { if (regs >= LASTREG) { \
         word l = reg(LASTREG); int i=LASTREG; \
         do { p[ i+PROC_REG0 ] = *car_addr( l ); l = *cdr_addr( l ); \
	      regs--; i++; \
         } while (regs >= LASTREG); \
       } \
       while (regs >= 0) { p[regs+PROC_REG0] = reg(regs); regs--; }; \
       RESULT = tagptr( p, PROC_TAG ); \
  } while(0)

#define twobit_lambda( code_name, const_offs, n ) \
  do { int regs = n; word *p; \
       ALLOCATE( fixnum( PROC_HEADER_WORDS+PROC_OVERHEAD+regs+1 ) ); \
       p = (word*)RESULT; \
       p[0] = mkheader( (regs+1+PROC_OVERHEAD)*sizeof(word), PROC_HDR ); \
       p[PROC_CODE] = ENCODE_CODEPTR((word)code_name); \
       p[PROC_CONST] = get_const( const_offs ); \
       init_closure( regs, p ); \
       integrity_check( "lambda" ); \
  } while(0)

#define twobit_lexes( n ) \
  do { int regs = n; word *p; \
       ALLOCATE( fixnum( PROC_HEADER_WORDS+PROC_OVERHEAD+regs+1 ) ); \
       p = (word*)RESULT; \
       p[0] = mkheader( (regs+1+PROC_OVERHEAD)*sizeof(word), PROC_HDR ); \
       p[PROC_CODE] = *proc_addr( reg(0), IDX_PROC_CODE ); \
       p[PROC_CONST] = *proc_addr( reg(0), IDX_PROC_CONST ); \
       init_closure( regs, p ); \
       integrity_check( "lexes" ); \
  } while(0)

#define twobit_argseq( n ) \
   do { SECOND = fixnum(n); \
        THIRD = reg(0); \
        if (UNSAFE_FALSE(RESULT != fixnum(n))) { \
          FAIL( EX_ARGSEQ ); \
        } \
        integrity_check( "argseq" ); \
   } while(0)

#define twobit_argsge( n ) \
   do { SECOND = fixnum(n); \
        THIRD = reg(0); \
        if (UNSAFE_FALSE(RESULT < fixnum(n))) { \
          FAIL( EX_ARGSGE ); \
        } \
        else WITH_SAVED_STATE( mc_restargs( globals ) ); \
        integrity_check( "argsge" ); \
   } while(0)

#define twobit_restore( n ) \
  do { int i = n; \
       while ( i >= 0 ) { reg(i) = stack(i+STK_REG0); i--; } \
       integrity_check( "restore" ); \
  } while(0)

#define twobit_pop( n ) \
  STKP = (word)((word*)STKP + realframesize(n+1)); integrity_check( "pop" )

#define twobit_stack( n ) \
  RESULT = stack(n+STK_REG0); integrity_check( "stack" )

#define twobit_setstk( n ) \
  stack(n+STK_REG0) = RESULT; integrity_check( "setstk" )

#define twobit_load( k, n ) \
  reg(k) = stack(n+STK_REG0); integrity_check( "load" )

#define twobit_store( k, n ) \
  stack(n+STK_REG0) = reg(k); integrity_check( "store" )

#define twobit_lexical( m, n ) \
  do { int i; word p=reg(0); \
       for ( i=m ; i > 0 ; i-- ) p=*proc_addr( p, IDX_PROC_REG0 ); \
       RESULT = *proc_addr( p, IDX_PROC_REG0+n ); \
       integrity_check( "lexical" ); \
  } while(0)

#define twobit_setlex( m, n ) \
  do { int i; word p=reg(0); \
       for ( i=m ; i > 0 ; i-- ) p=*proc_addr( p, IDX_PROC_REG0 ); \
       *proc_addr( p, IDX_PROC_REG0+n ) = RESULT; \
       SECOND = RESULT; RESULT = p; \
       BARRIER(); \
       integrity_check( "setlex" ); \
  } while(0)

#define twobit_reg( k ) RESULT = reg(k); integrity_check( "reg" )

#define twobit_setreg( k )  reg(k) = RESULT; integrity_check( "setreg" )

#define twobit_movereg( k, l )  reg(l) = reg(k); integrity_check( "movereg" )

#define twobit_nop()  (void)0 /* nothing */

#define twobit_save( n ) \
  do { int i=n; word *stkp; \
       do { stkp = (word*)STKP-realframesize(n+1); \
            if (stkp >= (word*)STKLIM) break; \
            WITH_SAVED_STATE( mc_stack_overflow( globals ) ); \
       } while(1); \
       STKP = (word)stkp; \
       stkp[ STK_FRAMESIZE ] = fixnum(framesize(n+1)); \
       stkp[ STK_RETURN ] = 0; \
       stkp[ STK_REG0 ] = reg(0); \
       while (i > 0) { stkp[ STK_REG0+i ] = UNSPECIFIED_CONST; i--; } \
       integrity_check( "save" ); \
  } while (0)

#define twobit_setrtn( L_numeric, L_symbolic )  \
   do { stack( STK_RETURN ) = ENCODE_RETURN_ADDRESS(L_numeric,L_symbolic); \
        integrity_check( "setrtn" ); \
   } while(0)

#if USE_GOTOS_LOCALLY
# define twobit_return() \
   nonlocal_control_transfer( (word)stack( STK_REG0 ), DECODE_RETURN_ADDRESS(stack( STK_RETURN )) )
#else
# define twobit_return() \
   twobit_skip( -1, DECODE_RETURN_ADDRESS(stack( STK_RETURN )) )
#endif

#if USE_GOTOS_LOCALLY
# define twobit_invoke( n ) \
   do { word a=RESULT; \
        if (tagof(a) != PROC_TAG) { \
          FAIL( EX_NONPROC ); \
        } \
        reg(0) = a; \
        RESULT = fixnum(n); \
        if (!--TIMER) \
          WITH_SAVED_STATE( mc_timer_exception( globals, (cont_t)0 ) );	\
        integrity_check( "invoke" ); \
        nonlocal_control_transfer( reg(0), 0 ); \
   } while(0)
#else 
# define twobit_invoke( n ) \
  do { cont_t invL; word a=RESULT; \
       if (tagof(a) != PROC_TAG) { \
         FAIL( EX_NONPROC ); \
       } \
       invL = (cont_t)*proc_addr( a, IDX_PROC_CODE ); \
       reg(0) = a; \
       RESULT = fixnum(n); \
       integrity_check( "invoke" ); \
        twobit_branch( -1, invL ); \
   } while(0)
#endif

#if USE_GOTOS_LOCALLY
# define twobit_apply( k, l ) \
   do { SECOND=reg(k); THIRD=reg(l); \
        WITH_SAVED_STATE( mc_apply( globals ) ); /* Sets up REG0 */ \
        integrity_check( "apply" ); \
        nonlocal_control_transfer( reg(0), 0 ); \
   } while (0)
#else
# define twobit_apply( k, l ) \
  do { cont_t appL = (cont_t)*proc_addr( RESULT, IDX_PROC_CODE ); \
       SECOND=reg(k); THIRD=reg(l); \
       WITH_SAVED_STATE( mc_apply( globals ) ); \
       integrity_check( "apply" ); \
        twobit_branch( -1, appL ); \
   } while (0)
#endif

#if USE_GOTOS_LOCALLY
# define twobit_jump( n, L_numeric, L_symbolic ) \
   do { int i; word p=reg(0); \
        for ( i=n ; i > 0 ; i-- ) p=*proc_addr( p, IDX_PROC_REG0 );\
        reg(0) = p; \
        integrity_check( "jump" ); \
        nonlocal_control_transfer( reg(0), L_numeric ); \
   } while(0)
#else
# define twobit_jump( n, L_numeric, L_symbolic ) \
   do { int i; word p=reg(0); \
        for ( i=n ; i > 0 ; i-- ) p=*proc_addr( p, IDX_PROC_REG0 );\
        reg(0) = p; \
        integrity_check( "jump" ); \
        twobit_branch( L_numeric, L_symbolic ); \
   } while(0)
#endif

#if USE_GOTOS_LOCALLY
#  if USE_LONGJUMP
#    define nonlocal_control_transfer( REGZERO, L ) \
       do { \
         if (--TIMER == 0) \
           WITH_SAVED_STATE( mc_timer_exception( globals, (cont_t)L ) ); \
         globals[ G_EFFECTIVE_REG0 ] = REGZERO; \
         (DECODE_CODEPTR(procedure_ref(REGZERO,IDX_PROC_CODE)))( globals, L ); \
       } while(0)
#  elif USE_RETURN_WITH_VALUE
#    define nonlocal_control_transfer( REGZERO, L ) \
       do { globals[ G_EFFECTIVE_REG0 ] = REGZERO; \
            SAVE_STATE(); return (cont_t)L; } while(0)
#  elif USE_RETURN_WITHOUT_VALUE
#    define nonlocal_control_transfer( REGZERO, L ) \
       do { globals[ G_EFFECTIVE_REG0 ] = REGZERO; \
            twobit_cont_label = (cont_t)L; SAVE_STATE(); return; } while(0)
#  endif
#endif

#if USE_GOTOS_LOCALLY
# define twobit_branch( L_numeric, L_symbolic ) \
   do { \
     integrity_check( "branch" ); \
     if (!--TIMER) \
       WITH_SAVED_STATE( mc_timer_exception( globals, (cont_t)L_numeric ) ); \
     goto MKLABEL( L_symbolic ); \
   } while(0)
#else 
# if USE_LONGJUMP
#  define twobit_branch   twobit_skip
# else
# define twobit_branch( L_numeric, L_symbolic ) \
   do { \
     integrity_check( "branch" ); \
     if (!--TIMER) \
       WITH_SAVED_STATE( mc_timer_exception( globals, (cont_t)L_symbolic ) ); \
     twobit_skip( L_numeric, L_symbolic ); \
   } while(0)
# endif
#endif

#define twobit_branchf( L_numeric, L_symbolic ) \
  if (RESULT == FALSE_CONST) twobit_branch( L_numeric, L_symbolic )

#if USE_GOTOS_LOCALLY
# define twobit_skip( L_numeric, L_symbolic )  goto MKLABEL( L_symbolic )
#else
# if USE_LONGJUMP
#  define twobit_skip( L_numeric, L_symbolic ) \
    if (!--TIMER) \
      WITH_SAVED_STATE( mc_timer_exception( globals, (cont_t)L_symbolic ) ); \
    else \
      L_symbolic( CONT_ACTUALS )
# elif USE_RETURN_WITH_VALUE
#  define twobit_skip( L_numeric, L_symbolic ) \
    do { SAVE_STATE(); return (cont_t)L_symbolic; } while(0)
# elif USE_RETURN_WITHOUT_VALUE 
#  define twobit_skip( L_numeric, L_symbolic ) \
    do { \
      twobit_cont_label = (cont_t)L_symbolic; \
      SAVE_STATE(); \
      return; \
    } while(0)
# endif
#endif

#define twobit_check( x, y, z, L_numeric, L_symbolic ) \
  if (RESULT == FALSE_CONST) { \
    twobit_skip( L_numeric, L_symbolic ); \
  }

#define twobit_trap( x, y, z, excode ) \
  do { \
    if (x != 0) RESULT = reg(x); \
    if (y != 0) SECOND = reg(y); \
    if (z != 0) THIRD  = reg(z); \
    FAIL( excode ); \
  } while(0)

#define twobit_imm_const_setreg( w, r ) \
  reg(r) = (word)(w); integrity_check( "imm_const_setreg" )

#define twobit_const_setreg( k, r ) \
  reg(r) = get_const( k ); integrity_check( "const_setreg" )


/* Primitives */

#define twobit_op1_1() /* break -- really 0 args */ \
   WITH_SAVED_STATE( mc_break( globals ) )

#define twobit_op1_3() /* unspecified -- really 0 args */ \
   RESULT = UNSPECIFIED_CONST

#define twobit_op1_4() /* undefined -- really 0 args */ \
   RESULT = UNDEFINED_CONST

#define twobit_op1_5() /* eof-object -- really 0 args */ \
   RESULT = EOF_CONST

#define twobit_op1_6( kn, k ) /* enable-interrupts */ \
   implicit_label( mc_enable_interrupts( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_7( kn, k ) /* disable-interrupts -- really 0 args */ \
   implicit_label( mc_disable_interrupts( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_8() /* typetag */ \
   WITH_SAVED_STATE( mc_typetag( globals ) )

#define twobit_op1_9() /* not */ \
   setcc( RESULT == FALSE_CONST )

#define twobit_op1_10() /* null? */ \
   setcc( RESULT == NIL_CONST )

#define twobit_op1_11() /* pair? */ \
   setcc( tagof( RESULT ) == PAIR_TAG )

#define twobit_op1_12() /* eof-object? */ \
   setcc( RESULT == EOF_CONST )

#define twobit_op1_13() /* port? */ \
   double_tag_predicate( RESULT, VEC_TAG, PORT_HDR )

#define twobit_op1_14() /* structure? */ \
   double_tag_predicate( RESULT, VEC_TAG, STRUCT_HDR )

#define twobit_op1_15() /* car */ \
   do { word a=RESULT; \
	if (UNSAFE_TRUE(tagof( a ) == PAIR_TAG)) \
	  RESULT = *car_addr( a ); \
        else { FAIL( EX_CAR ); } \
   } while(0)

#define twobit_op1_16() /* cdr */ \
   do { word a=RESULT; \
        if (UNSAFE_TRUE(tagof( a ) == PAIR_TAG)) \
          RESULT = *cdr_addr( a ); \
        else { FAIL( EX_CDR ); } \
   } while(0)

#define twobit_op1_17() /* symbol? */ \
   double_tag_predicate( RESULT, VEC_TAG, SYMBOL_HDR )

#define twobit_op1_18() /* number?, complex? */ \
   WITH_SAVED_STATE( mc_complexp( globals ) )

#define twobit_op1_20() /* real?, rational? */ \
   WITH_SAVED_STATE( mc_rationalp( globals ) )

#define twobit_op1_21() /* compnum? */ \
   double_tag_predicate( RESULT, BVEC_TAG, COMPNUM_HDR )

#define twobit_op1_22() /* integer? */ \
   WITH_SAVED_STATE( mc_integerp( globals ) )

#define twobit_op1_23() /* fixnum? */ \
   setcc( is_fixnum(RESULT) )

#define twobit_op1_24() /* flonum? */ \
   double_tag_predicate( RESULT, BVEC_TAG, FLONUM_HDR )

#define twobit_op1_25() /* exact? */ \
   WITH_SAVED_STATE( mc_exactp( globals ) )

#define twobit_op1_26() /* inexact? */ \
   WITH_SAVED_STATE( mc_inexactp( globals ) )

#define twobit_op1_27( kn, k ) /* exact->inexact */ \
   implicit_label( mc_exact2inexact( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_28( kn, k ) /* inexact->exact */ \
   implicit_label( mc_inexact2exact( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_29( kn, k ) /* round */ \
   implicit_label( mc_round( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_30( kn, k ) /* truncate */ \
   implicit_label( mc_truncate( globals, CONT_LOCAL(kn,k) ), kn, k )

/* Note: label not actually used; millicode handles everything */
#define twobit_op1_31( kn, k ) /* zero? */ \
   WITH_SAVED_STATE( mc_zerop( globals ) )

#define twobit_op1_32( kn, k ) /* -- */ \
   implicit_label( mc_neg( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_33() /* fxlognot */ \
   do { word a=RESULT; \
        if (UNSAFE_TRUE(is_fixnum(a))) \
          RESULT = ~a & ~3; \
        else { FAIL( EX_LOGNOT ); } \
   } while(0)

#define twobit_op1_34() /* real-part */ \
   WITH_SAVED_STATE( mc_real_part( globals ) )

#define twobit_op1_35() /* imag-part */ \
   WITH_SAVED_STATE( mc_imag_part( globals ) )

#define twobit_op1_36() /* char? */ \
   setcc( is_char( RESULT ) )

#define twobit_op1_37() /* char->integer */ \
   do { word a=RESULT; \
        if (UNSAFE_TRUE(is_char(a))) \
          RESULT = charcode_as_fixnum(a); \
        else { FAIL( EX_CHAR2INT ); } \
   } while(0)

#define twobit_op1_38() /* integer->char */ \
   do { word a=RESULT; \
        if (/* argument must be fixnum. */ \
               UNSAFE_TRUE(is_fixnum(a))   \
            /* argument cannot be a surrogate (#x0000d800 - #x0000dfff). */ \
	    && ((a >> 2) < 0xd800 || (a >> 2) > 0xdfff) \
            /* argument must be non-negative and less than #x00110000. */ \
	    && (a >= 0     && (a >> 2) < 0x110000)) \
          RESULT = fixnum_to_char(a); \
        else { FAIL( EX_INT2CHAR ); } \
   } while(0)

#define twobit_op1_39() /* string? */ \
   double_tag_predicate( RESULT, BVEC_TAG, STR_HDR )

#define twobit_op1_40() /* string-length */				  \
   do { word h, a=RESULT;						  \
        if (UNSAFE_TRUE2(double_tag_test( a, BVEC_TAG, STR_HDR, h ),	  \
                         h = the_header( a, BVEC_TAG )))		  \
          RESULT = sizefield(h) << 2;					  \
        else { FAIL( EX_STRING_LENGTH ); } \
        integrity_check( "string-length" );				  \
   } while( 0 )

#define twobit_op1_41() /* vector? */ \
   double_tag_predicate( RESULT, VEC_TAG, VECTOR_HDR )

#define twobit_op1_42() /* vector-length */				  \
   do { word h, a=RESULT;						  \
        if (UNSAFE_TRUE2(double_tag_test( a, VEC_TAG, VECTOR_HDR, h ),	  \
                         h = the_header( a, VEC_TAG )))			  \
          RESULT = h >> 8;						  \
        else { FAIL( EX_VECTOR_LENGTH ); } \
        integrity_check( "vector-length" );				  \
   } while(0)

#define twobit_op1_43() /* bytevector? */ \
   double_tag_predicate( RESULT, BVEC_TAG, BYTEVECTOR_HDR )

#define twobit_op1_44() /* bytevector-length */				    \
   do { word h, a=RESULT;						    \
        if (UNSAFE_TRUE2(double_tag_test( a, BVEC_TAG, BYTEVECTOR_HDR, h ), \
                         h = the_header( a, BVEC_TAG )))		    \
          RESULT = fixnum(sizefield(h));				    \
        else { FAIL( EX_BYTEVECTOR_LENGTH ); }		                    \
        integrity_check( "bytevector-length" );				    \
   } while(0)

#define twobit_op2_45( y ) /* bytevector-fill! */ \
   do { word b=SECOND=reg(y); \
        if (UNSAFE_TRUE(tagof( RESULT ) == BVEC_TAG && is_fixnum( b ))) \
          WITH_SAVED_STATE( mc_bytevector_like_fill( globals ) ); \
        else { FAIL( EX_BVFILL ); } \
        integrity_check( "bytevector-fill!" ); \
   } while(0)

#define twobit_op1_46() /* make-bytevector */ \
   do { word a=RESULT, *p; \
        if (UNSAFE_TRUE(is_nonnegative_fixnum(a))) { \
          word size = a >> 2; \
          ALLOCATE_BV( a + fixnum(BVEC_HEADER_WORDS*sizeof( word )) ); \
          p =(word*)RESULT; \
          *p = mkheader( size, BV_HDR ); \
	  RESULT = tagptr( p, BVEC_TAG ); \
        } else { FAIL( EX_MKBVL ); } \
        integrity_check( "make-bytevector" ); \
   } while(0)

#define twobit_op1_47() /* procedure? */ \
   setcc( tagof( RESULT ) == PROC_TAG )

#define twobit_op1_48() /* procedure-length */ \
   do { word a=RESULT; \
        if (UNSAFE_TRUE(tagof( a ) == PROC_TAG)) \
          RESULT = fixnum(procedure_length(a)); \
        else { FAIL( EX_PROCEDURE_LENGTH ); } \
   } while(0)

#define twobit_op1_49() /* make-procedure */ \
   make_vectorish( PROC_HEADER_WORDS, EX_MAKE_PROCEDURE, \
		   PROC_HDR, PROC_TAG, NIL_CONST )

/* 50 missing */

/* 51 missing */

#define twobit_op1_52() /* make-cell */ \
   do { word *p; \
        THIRD = RESULT; \
        ALLOCATE( fixnum(2) ); \
        p = (word*)RESULT;  \
        p[0] = THIRD; \
        p[1] = NIL_CONST; \
        RESULT = tagptr( p, PAIR_TAG ); \
   } while(0)

/* 53 missing */

#define twobit_op1_54() /* cell-ref */ \
   RESULT = *car_addr( RESULT )

#define twobit_op2_55( y ) /* typetag-set! */ \
   SECOND = reg(y); WITH_SAVED_STATE( mc_typetag_set( globals ) )

#define twobit_op2_56( y ) /* eq? */ \
   setcc( RESULT == reg(y) )

#define twobit_op2_57( y, kn, k ) /* eqv? */ \
   implicit_label( SECOND = reg(y); mc_eqv( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op2_58( y ) /* cons */ \
   do { word *p; \
        THIRD = RESULT; \
        ALLOCATE( fixnum(2) ); \
        p = (word*)RESULT;  \
        p[0] = THIRD; \
        p[1] = reg(y); \
        RESULT = tagptr( p, PAIR_TAG ); \
        integrity_check( "cons" ); \
   } while(0)

#define twobit_op2_59( y ) /* set-car! */ \
   do { word a=RESULT, b=SECOND=reg(y); \
	if (UNSAFE_TRUE(tagof( a ) == PAIR_TAG)) { \
	  *car_addr( a ) = b; \
	  BARRIER(); \
        } \
	else { FAIL( EX_SETCAR ); } \
   } while(0)

#define twobit_op2_60( y ) /* set-cdr! */ \
   do { word a=RESULT, b=SECOND=reg(y); \
	if (UNSAFE_TRUE(tagof( a ) == PAIR_TAG)) { \
	  *cdr_addr( a ) = b; \
	  BARRIER(); \
        } \
	else { FAIL( EX_SETCDR ); } \
   } while(0)

#define twobit_op2_61( y, kn, k ) /* + */ \
   twobit_add( RESULT, reg( y ), kn, k )

#define twobit_op2_62( y, kn, k ) /* - */ \
   twobit_subtract( RESULT, reg( y ), kn, k )

#define twobit_op2_63( y, kn, k ) /* * */ \
   implicit_label( SECOND = reg(y); mc_mul( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op2_64( y, kn, k ) /* / */ \
   implicit_label( SECOND = reg(y); mc_div( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op2_65( y, kn, k ) /* quotient */ \
   implicit_label( SECOND = reg(y); mc_quo( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op2_66( y, kn, k ) /* < */ \
  twobit_compare( RESULT, reg(y), <, mc_lessp, kn, k )

#define twobit_op2_67( y, kn, k ) /* <= */ \
  twobit_compare( RESULT, reg(y), <=, mc_less_or_equalp, kn, k )

#define twobit_op2_68( y, kn, k ) /* = */ \
  twobit_compare( RESULT, reg(y), ==, mc_equalp, kn, k )

#define twobit_op2_69( y, kn, k ) /* > */ \
  twobit_compare( RESULT, reg(y), >, mc_greaterp, kn, k )

#define twobit_op2_70( y, kn, k ) /* >= */ \
  twobit_compare( RESULT, reg(y), >=, mc_greater_or_equalp, kn, k )

#define twobit_op2_71( y ) /* fxlogand */ \
   do { word a=RESULT, b=reg(y); \
        if (UNSAFE_TRUE(is_both_fixnums( a, b ))) \
          RESULT = (a & b); \
        else { SECOND=reg(y); \
	       FAIL( EX_LOGAND ); } \
   } while(0)

#define twobit_op2_72( y ) /* fxlogior */ \
   do { word a=RESULT, b=reg(y); \
        if (UNSAFE_TRUE(is_both_fixnums( a, b ))) \
          RESULT = (a | b); \
        else { SECOND=reg(y); \
	       FAIL( EX_LOGIOR ); } \
   } while(0)

#define twobit_op2_73( y ) /* fxlogxor */ \
   do { word a=RESULT, b=reg(y); \
        if (UNSAFE_TRUE(is_both_fixnums( a, b ))) \
          RESULT = (a ^ b); \
        else { SECOND=reg(y); \
	       FAIL( EX_LOGXOR ); } \
   } while(0)

#define twobit_op2_74( y ) /* fxlsh */ \
   do { word a=RESULT, b=reg(y); \
        if (UNSAFE_TRUE(is_both_fixnums( a, b ) && b < fixnum(SHIFT_LIMIT))) \
          RESULT = a << (b >> 2); \
        else { SECOND=b; \
	       FAIL( EX_LSH ); } \
   } while(0)

#define twobit_op2_75( y ) /* fxrsha */ \
   do { word a=RESULT, b=reg(y); \
        if (UNSAFE_TRUE(is_both_fixnums( a, b ) && b < fixnum(SHIFT_LIMIT))) \
          RESULT = ((s_word)a >> (b >> 2)) & ~3; \
        else { SECOND=b; \
               FAIL( EX_RSHL ); } \
   } while(0)

#define twobit_op2_76( y ) /* fxrshl */ \
   do { word a=RESULT, b=reg(y); \
        if (UNSAFE_TRUE(is_both_fixnums( a, b ) && b < fixnum(SHIFT_LIMIT))) \
          RESULT = (a >> (b >> 2)) & ~3; \
        else { SECOND=b; \
               FAIL( EX_RSHL ); } \
   } while(0)

#define twobit_op2_77( y ) /* rot */ \
   panic( "twobit_rot not implemented." )

#define twobit_op2_78( y ) /* string-ref */ \
   do { word a=RESULT, b=reg(y), h; \
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, STR_HDR, h ) && \
	                is_fixnum(b) && \
	                (b >> 2) < (h >> 8))) \
	 RESULT = int_to_char(*byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b));\
        else { SECOND=b; \
               FAIL( EX_STRING_REF ); } \
   } while(0)

#define twobit_op3_79( y, z ) /* string-set! */ \
   do { word a=RESULT, b=reg(y), c=reg(z), h; \
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, STR_HDR, h ) && \
	               is_fixnum(b) && \
	               (b >> 2) < (h >> 8) && \
	               is_char( c ))) \
	  *byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b ) = charcode(c); \
        else { SECOND=b; THIRD=c; \
               FAIL( EX_STRING_SET ); } \
   } while(0)

#define twobit_op2_80( y ) /* make-vector */ \
   make_vectorish( VEC_HEADER_WORDS, EX_MAKE_VECTOR, VEC_HDR, VEC_TAG, reg(y) )

#define twobit_op2_81( y ) /* vector-ref */ \
  do { word a=RESULT, b=reg(y), h; \
       if (UNSAFE_TRUE(double_tag_test( a, VEC_TAG, VECTOR_HDR, h ) && \
                       is_fixnum(b) && \
                       b < (h >> 8))) \
         RESULT = *word_addr( a, VEC_TAG, VEC_HEADER_WORDS, b ); \
       else { SECOND=b; \
	      FAIL( EX_VECTOR_REF ); } \
  } while(0)

#define twobit_op2_82( y ) /* bytevector-ref */ \
   do { word a=RESULT, b=reg( y ), h; \
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, BV_HDR, h ) && \
	                is_fixnum(b) && \
	                (b >> 2) < (h >> 8))) \
	  RESULT = fixnum(*byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b )); \
        else { SECOND=b; \
	       FAIL( EX_BYTEVECTOR_REF ); } \
   } while(0)

#define twobit_op2_83( y ) /* procedure-ref */ \
  do { word a=RESULT, b=reg(y); \
       if (UNSAFE_TRUE(tagof( a ) == PROC_TAG && \
                       is_fixnum(b) && \
                       (b < (the_header( a, PROC_TAG ) >> 8)))) \
        RESULT = *word_addr( a, PROC_TAG, PROC_HEADER_WORDS, b);\
       else { SECOND=b; \
	      FAIL( EX_PROCEDURE_REF ); } \
  } while(0)

#define twobit_op2_84( y ) /* cell-set! */ \
  do { word b=SECOND=reg(y); \
       *car_addr( RESULT ) = b; \
       BARRIER(); \
  } while(0)

#define charcmp( op, y, ex ) /* generic character comparison */ \
  do { word a=RESULT, b=SECOND=reg(y); \
       if (UNSAFE_TRUE(is_char(a) && is_char(b))) \
	 setcc( a op b ); \
       else { FAIL( ex ); } \
  } while(0)

#define twobit_op2_85( y ) /* char<? */ \
  charcmp( <, y, EX_CHARLT )

#define twobit_op2_86( y ) /* char<=? */ \
  charcmp( <=, y, EX_CHARLE )

#define twobit_op2_87( y ) /* char=? */ \
  charcmp( ==, y, EX_CHAREQ )

#define twobit_op2_88( y ) /* char>? */ \
  charcmp( >, y, EX_CHARGT )

#define twobit_op2_89( y ) /* char>=? */ \
  charcmp( >=, y, EX_CHARGE )

#define twobit_op2_90( y ) /* sys$partial-list->vector */ \
  SECOND = reg(y); WITH_SAVED_STATE( mc_partial_list2vector( globals ) )

#define twobit_op3_91( y, z ) /* vector-set! */ \
  do { word a=RESULT, b=reg(y), c=reg(z), h; \
       if (UNSAFE_TRUE(double_tag_test( a, VEC_TAG, VECTOR_HDR, h ) && \
                       is_fixnum(b) && \
                       b < (h >> 8))) { \
         *word_addr( a, VEC_TAG, VEC_HEADER_WORDS, b ) = c; \
         SECOND = c; \
	 BARRIER(); \
       } else { SECOND=b; THIRD=c; \
		FAIL( EX_VECTOR_SET ); \
       } \
  } while(0)

#define twobit_op3_92( y, z ) /* bytevector-set! */ \
   do { word h, a=RESULT, b=reg( y ), c=reg( z ); \
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, BV_HDR, h ) && \
	                is_both_fixnums( b, c ) && \
                        (b >> 2) < (h >> 8) && \
	                c < fixnum(256))) \
	  *byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b ) = (c >> 2); \
        else { SECOND=b; THIRD=c; \
               FAIL( EX_BYTEVECTOR_SET ); } \
   } while(0)

#define twobit_op3_93( y, z ) /* procedure-set! */ \
  do { word a=RESULT, b=reg(y), c=reg(z); \
       if (UNSAFE_TRUE(tagof( a ) == PROC_TAG && \
                       is_fixnum(b) && \
                       (b < (the_header( a, PROC_TAG ) >> 8)))) { \
         *word_addr(a, PROC_TAG, PROC_HEADER_WORDS, b) = c; \
         SECOND=c; \
	 BARRIER(); \
       } else { SECOND=b; THIRD=c; \
		FAIL( EX_PROCEDURE_SET ); \
       } \
  } while(0)

#define twobit_op1_94() /* bytevector-like? */ \
  setcc( tagof( RESULT ) == BVEC_TAG )

#define twobit_op1_95() /* vector-like? */ \
  setcc( tagof( RESULT ) == VEC_TAG )

#define twobit_op2_96( y ) /* bytevector-like-ref */ \
   do { word a=RESULT, b=reg( y ); \
        if (UNSAFE_TRUE(tagof( a ) == BVEC_TAG && \
	                is_fixnum(b) && \
	                ((b >> 2) < (the_header( a, BVEC_TAG ) >> 8)))) \
	  RESULT = fixnum(*byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b )); \
        else { SECOND=b; \
	       FAIL( EX_BYTEVECTOR_LIKE_REF ); } \
   } while(0)

#define twobit_op3_97( y, z ) /* bytevector-like-set! */ \
   do { word a=RESULT, b=reg( y ), c=reg( z ); \
        if (UNSAFE_TRUE(tagof( a ) == BVEC_TAG && \
	    is_both_fixnums( b, c ) && \
	    ((b >> 2) < (the_header( a, BVEC_TAG ) >> 8)) && \
	                c < fixnum(256))) \
	  *byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b ) = (c >> 2); \
        else { SECOND=b; THIRD=c; \
               FAIL( EX_BYTEVECTOR_LIKE_SET ); } \
   } while(0)

#define twobit_op2_98( y ) /* sys$bvlcmp */ \
  SECOND = reg(y); WITH_SAVED_STATE( mc_bytevector_like_compare( globals ) )

#define twobit_op2_99( y ) /* vector-like-ref */ \
  do { word a=RESULT, b=reg(y); \
       if (UNSAFE_TRUE(tagof( a ) == VEC_TAG && \
                       is_fixnum(b) && \
                       (b < (the_header( a, VEC_TAG ) >> 8)))) \
         RESULT = *word_addr( a, VEC_TAG, VEC_HEADER_WORDS, b ); \
       else { SECOND=b; \
	      FAIL( EX_VECTOR_LIKE_REF ); } \
  } while(0)

#define twobit_op3_100( y, z ) /* vector-like-set! */ \
  do { word a=RESULT, b=reg(y), c=reg(z); \
       if (UNSAFE_TRUE(tagof( a ) == VEC_TAG && \
                       is_fixnum(b) && \
                       (b < (the_header( a, VEC_TAG ) >> 8)))) { \
         *word_addr( a, VEC_TAG, VEC_HEADER_WORDS, b ) = c; \
	 SECOND=c; \
	 BARRIER(); \
       } else { SECOND=b; THIRD=c; \
		FAIL( EX_VECTOR_LIKE_SET ); \
       } \
  } while(0)

#define twobit_op1_101() /* vector-like-length */ \
   do { word a=RESULT; \
        if (UNSAFE_TRUE(tagof(a) == VEC_TAG)) \
          RESULT = sizefield( the_header( a, VEC_TAG ) ); \
        else { FAIL( EX_VECTOR_LIKE_LENGTH ); } \
   } while(0)

#define twobit_op1_102() /* bytevector-like-length */ \
   do { word a=RESULT; \
        if (UNSAFE_TRUE(tagof(a) == BVEC_TAG)) \
          RESULT = fixnum( sizefield( the_header( a, BVEC_TAG ) ) ); \
        else { FAIL( EX_BYTEVECTOR_LIKE_LENGTH ); } \
   } while(0)

#define twobit_op2_103( y, kn, k ) /* remainder */ \
   implicit_label( SECOND = reg(y); mc_rem( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_104() /* petit-patch-boot-code */ \
   WITH_SAVED_STATE( mc_petit_patch_boot_code( globals ) )

#define twobit_op1_105( kn, k ) /* syscall */ \
  implicit_label( mc_syscall( globals, CONT_LOCAL(kn,k) ), kn, k )

#define twobit_op1_106() /* creg -- really 0 args */ \
  WITH_SAVED_STATE( mc_capture_continuation( globals ) )

#define twobit_op1_107() /* creg-set! */ \
  WITH_SAVED_STATE( mc_restore_continuation( globals ) )

#define twobit_op1_108() /* gc-counter */ \
  RESULT = globals[ G_GC_CNT ]

#define twobit_op1_109() /* major-gc-counter */ \
  RESULT = globals[ G_MAJORGC_CNT ]

#define twobit_op1_110() /* machine-address */ \
  RESULT = (RESULT >> 4) << 2;

/* FIXME: the following is obsolete */

#define twobit_op2_109( y ) /* make-string */ \
   do { word a=RESULT, b=reg(y), *p; \
        if (UNSAFE_TRUE(is_nonnegative_fixnum(a) && is_char(b))) { \
          word size = a >> 2; \
          ALLOCATE_BV( a + fixnum(BVEC_HEADER_WORDS*sizeof( word )) ); \
          p =(word*)RESULT; \
          *p = mkheader( size, STR_HDR ); \
          memset( (char*)p + sizeof(word), charcode(b), size ); \
	  RESULT = tagptr( p, BVEC_TAG ); \
        } else { FAIL( EX_MAKE_STRING ); } \
        integrity_check( "make-string" ); \
   } while(0)
  

#define twobit_op2imm_128( y ) /* typetag-set! */ \
  SECOND = y; WITH_SAVED_STATE( mc_typetag_set( globals ) )

#define twobit_op2imm_129( y ) /* eq? */ \
  setcc( RESULT == y )

#define twobit_op2imm_130( y, kn, k ) /* + */ \
  twobit_add( RESULT, y, kn, k )

#define twobit_op2imm_131( y, kn, k ) /* -  */ \
  twobit_subtract( RESULT, y, kn, k )

#define twobit_op2imm_132( y, kn, k ) /* < */ \
  twobit_compare( RESULT, y, <, mc_lessp, kn, k )

#define twobit_op2imm_133( y, kn, k ) /* <= */ \
  twobit_compare( RESULT, y, <=, mc_less_or_equalp, kn, k )

#define twobit_op2imm_134( y, kn, k ) /* = */ \
  twobit_compare( RESULT, y, ==, mc_equalp, kn, k )

#define twobit_op2imm_135( y, kn, k ) /* > */ \
  twobit_compare( RESULT, y, >, mc_greaterp, kn, k )

#define twobit_op2imm_136( y, kn, k ) /* >= */ \
  twobit_compare( RESULT, y, >=, mc_greater_or_equalp, kn, k )

#define charcmp_imm( op, y, ex ) /* generic character comparison */ \
  do { word a=RESULT, b=y; \
       if (UNSAFE_TRUE(is_char(a))) \
	 setcc( a op b ); \
       else { SECOND = b; FAIL( ex ); } \
  } while(0)

#define twobit_op2imm_137( y ) /* char<? */ \
  charcmp_imm( <, y, EX_CHARLT )

#define twobit_op2imm_138( y ) /* char<= */ \
  charcmp_imm( <=, y, EX_CHARLE )

#define twobit_op2imm_139( y ) /* char=? */ \
  charcmp_imm( ==, y, EX_CHAREQ )

#define twobit_op2imm_140( y ) /* char>? */ \
  charcmp_imm( >, y, EX_CHARGT )

#define twobit_op2imm_141( y ) /* char>=? */ \
  charcmp_imm( >=, y, EX_CHARGE )

#define twobit_op2imm_142( b ) /* string-ref */						\
   do { word a=RESULT, h;								\
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, STR_HDR, h ) &&			\
	                (word)(b >> 2) < (h >> 8)))					\
	 RESULT = int_to_char(*byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b));          \
        else { SECOND=b;							\
               FAIL( EX_STRING_REF ); }							\
   } while(0)

#define twobit_op2imm_143( b ) /* vector-ref */				\
  do { word a=RESULT, h;						\
       if (UNSAFE_TRUE(double_tag_test( a, VEC_TAG, VECTOR_HDR, h ) &&	\
                       b < (h >> 8)))					\
         RESULT = *word_addr( a, VEC_TAG, VEC_HEADER_WORDS, b );        \
       else { SECOND=b;						\
	      FAIL( EX_VECTOR_REF ); }					\
  } while(0)

#define twobit_op2imm_144( b ) /* bytevector-ref */					\
   do { word a=RESULT, h;								\
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, BV_HDR, h ) &&			\
	                (word)(b >> 2) < (h >> 8)))					\
	  RESULT = fixnum(*byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b ));             \
        else { SECOND=b;							\
	       FAIL( EX_BYTEVECTOR_REF ); }						\
   } while(0)

#define twobit_op2imm_145( b ) /* bytevector-like-ref */				\
   do { word a=RESULT;									\
        if (UNSAFE_TRUE(tagof( a ) == BVEC_TAG &&					\
	                (word)(b >> 2) < (the_header( a, BVEC_TAG ) >> 8)))		\
	  RESULT = fixnum(*byte_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b ));             \
        else { SECOND=b;							\
	       FAIL( EX_BYTEVECTOR_LIKE_REF ); }					\
   } while(0)

#define twobit_op2imm_146( b ) /* vector-like-ref */		\
  do { word a=RESULT;						\
       if (UNSAFE_TRUE(tagof( a ) == VEC_TAG &&			\
                       (b < (the_header( a, VEC_TAG ) >> 8))))	\
         RESULT = *word_addr( a, VEC_TAG, VEC_HEADER_WORDS, b );\
       else { SECOND=b;					\
	      FAIL( EX_VECTOR_LIKE_REF ); }			\
  } while(0)

/* Fixnum primitives: 200 - 299 */

#define twobit_op1_200() /* most-positive-fixnum */ \
  RESULT = 0x7ffffffc

#define twobit_op1_201() /* most-negative-fixnum */ \
  RESULT = 0x80000000

/* See comments to twobit_add, above */
#define twobit_op2_202( y ) /* fx+ */					    \
  do { word a = RESULT, b = reg(y), res = a + b;			    \
      if (UNSAFE_TRUE(is_both_fixnums(a,b)) &&				    \
          UNSAFE_TRUE((s_word)(a ^ b) < 0 || (s_word)(res ^ a) >= 0))	    \
        RESULT = res;							    \
      else { SECOND = b; FAIL( EX_FXADD ); } \
  } while(0)

/* See comments to twobit_subtract, above */
#define twobit_op2_203( y ) /* fx- */					      \
   do { word a = RESULT, b = reg(y), res = a - b;			      \
	if (UNSAFE_TRUE(is_both_fixnums(a,b)) &&  		              \
            UNSAFE_TRUE((s_word)(a ^ b) >= 0 || (s_word)(res ^ a) >= 0))      \
          RESULT = res;							      \
        else { SECOND = b; FAIL( EX_FXSUB ); } \
   } while(0)

#define twobit_op1_204() /* fx-- */				\
  do { word a = RESULT, res = -a;				\
       if (UNSAFE_TRUE(is_fixnum(a) && a != res))		\
         RESULT = res;						\
       else { FAIL( EX_FXNEG ); }                               \
  } while(0)

#define twobit_fxcmp( y, op, ex )             \
  do { word a = RESULT,  b=reg(y);            \
       if (UNSAFE_TRUE(is_both_fixnums(a,b))) \
         setcc( (s_word)a op (s_word)b );       \
       else { SECOND=b; FAIL( ex ); }         \
  } while(0)

#define sllong(X) ((long long)(s_word)(X))

#define twobit_op2_205( y ) /* fx* */				\
  do { word a = RESULT, b = reg(y), res = (s_word)a * ((s_word)b / 4);		\
      if (UNSAFE_TRUE(is_both_fixnums(a,b)) &&			\
          UNSAFE_TRUE(sllong(res) == 			\
                      sllong(a) * (sllong(b) / 4)))	\
        RESULT = res;						\
      else { SECOND = b; FAIL( EX_FXMUL ); }			\
  } while(0)

#define twobit_op2_206( y ) twobit_fxcmp( y, ==, EX_FXEQ )  /* fx= */
#define twobit_op2_207( y ) twobit_fxcmp( y, <, EX_FXLT )   /* fx< */
#define twobit_op2_208( y ) twobit_fxcmp( y, <=, EX_FXLE )  /* fx<= */
#define twobit_op2_209( y ) twobit_fxcmp( y, >, EX_FXGT )   /* fx> */
#define twobit_op2_210( y ) twobit_fxcmp( y, >=, EX_FXGE )  /* fx>= */

#define twobit_op1_211() /* fxzero? */		\
  do { word a = RESULT;				\
       if (UNSAFE_TRUE(is_fixnum(a)))		\
         setcc( (s_word)a == fixnum(0) );	\
       else { FAIL( EX_FXZERO ); }    \
  } while(0)
  
#define twobit_op1_212() /* fxpositive? */	\
  do { word a = RESULT;				\
       if (UNSAFE_TRUE(is_fixnum(a)))		\
         setcc( (s_word)a > fixnum(0) );	\
       else { FAIL( EX_FXPOSITIVE ); } \
  } while(0)
  
#define twobit_op1_213() /* fxnegative? */	\
  do { word a = RESULT;				\
       if (UNSAFE_TRUE(is_fixnum(a)))		\
         setcc( (s_word)a < fixnum(0) );	\
       else { FAIL( EX_FXNEGATIVE ); } \
  } while(0)
  
#define twobit_op2imm_250( y ) /* fx+ */					    \
  do { word a = RESULT, b = y, res = a + b;			    	    \
      if (UNSAFE_TRUE(is_both_fixnums(a,b)) &&				            \
          UNSAFE_TRUE((s_word)(a ^ b) < 0 || (s_word)(res ^ a) >= 0))	    \
        RESULT = res;							    \
      else { SECOND = b; FAIL( EX_FXADD ); }                                \
  } while(0)

#define twobit_op2imm_251( y ) /* fx- */					    \
   do { word a = RESULT, b = y, res = a - b;			        \
	if (UNSAFE_TRUE(is_both_fixnums(a,b)) &&  		            \
            UNSAFE_TRUE((s_word)(a ^ b) >= 0 || (s_word)(res ^ a) >= 0))   \
          RESULT = res;							                \
        else { SECOND = b; FAIL( EX_FXSUB ); }                  \
   } while(0)

#define twobit_fxcmp_imm( y, op, ex )		\
  do { word a = RESULT, b = y;				\
       if (UNSAFE_TRUE(is_both_fixnums(a,b)))		\
         setcc( (s_word)a op (s_word)b );		\
       else { SECOND=b; FAIL( ex ); }		\
  } while(0)

#define twobit_op2imm_253( y ) twobit_fxcmp_imm( y, ==, EX_FXEQ )  /* fx= */
#define twobit_op2imm_254( y ) twobit_fxcmp_imm( y, <, EX_FXLT )   /* fx< */
#define twobit_op2imm_255( y ) twobit_fxcmp_imm( y, <=, EX_FXLE )  /* fx<= */
#define twobit_op2imm_256( y ) twobit_fxcmp_imm( y, >, EX_FXGT )   /* fx> */
#define twobit_op2imm_257( y ) twobit_fxcmp_imm( y, >=, EX_FXGE )  /* fx>= */


/* For CSE and representation analysis: 400 - 499 */
/* 400 unused, feel free to use it */

#define twobit_op1_401() /* vector-length:vec */ \
  RESULT = fixnum( vector_length( RESULT ) )

#define twobit_op2_402( y ) /* vector-ref:trusted */ \
  RESULT = vector_ref( RESULT, reg(y) >> 2 )

#define twobit_op3_403( y, z ) /* vector-set!:trusted */	\
  do { word b=reg(y) >> 2, c=SECOND=reg(z);			\
       vector_set( RESULT, b, c );				\
       BARRIER();		                                \
  } while(0)

#define twobit_op1_404() /* car:pair */ \
  RESULT = pair_car(RESULT)

#define twobit_op1_405() /* cdr:pair */ \
  RESULT = pair_cdr(RESULT)

#define twobit_op2_406( y ) /* =:fix:fix */ \
  setcc((s_word)RESULT == (s_word)reg(y))

#define twobit_op2_407( y ) /* <:fix:fix */ \
  setcc((s_word)RESULT < (s_word)reg(y))

#define twobit_op2_408( y ) /* <=:fix:fix */ \
  setcc((s_word)RESULT <= (s_word)reg(y))

#define twobit_op2_409( y ) /* >=:fix:fix */ \
  setcc((s_word)RESULT >= (s_word)reg(y))

#define twobit_op2_410( y ) /* >:fix:fix */ \
  setcc((s_word)RESULT > (s_word)reg(y))

#define twobit_op2imm_450( k ) /* vector-ref:trusted */ \
  RESULT = vector_ref( RESULT, (k >> 2) )

#define twobit_op2imm_451( k ) /* =:fix:fix */ \
  setcc((s_word)RESULT == k)

#define twobit_op2imm_452( k ) /* <:fix:fix */ \
  setcc((s_word)RESULT < k)

#define twobit_op2imm_453( k ) /* <=:fix:fix */ \
  setcc((s_word)RESULT <= k)

#define twobit_op2imm_454( k ) /* >:fix:fix */ \
  setcc((s_word)RESULT > k)

#define twobit_op2imm_455( k ) /* >=:fix:fix */ \
  setcc((s_word)RESULT >= k)

/* Introduced by representation inference.  These are trusted. */
#define twobit_op2_500( y ) /* +:idx:idx */ \
  RESULT = (s_word)RESULT + (s_word)reg(y)

/* OPTIMIZEME: tag checks not required, but overflow checks are */
#define twobit_op2_501( y, kn, k ) /* +:fix:fix */ \
  twobit_add( RESULT, reg(y), kn, k )

#define twobit_op2_502( y ) /* -:idx:idx */ \
  RESULT = (s_word)RESULT - (s_word)reg(y)

/* OPTIMIZEME: tag checks not required, but overflow checks are */
#define twobit_op2_503( y, kn, k ) /* -:fix:fix */ \
  twobit_subtract( RESULT, reg(y), kn, k )

#define twobit_op2imm_520( k ) /* +:idx:idx */ \
  RESULT = (s_word)RESULT + k

/* OPTIMIZEME: tag checks not required, but overflow checks are */
#define twobit_op2imm_521( y, kn, k ) /* +:fix:fix */ \
  twobit_add( RESULT, y, kn, k )

#define twobit_op2imm_522( k ) /* -:idx:idx */ \
  RESULT = (s_word)RESULT - k

/* OPTIMIZEME: tag checks not required, but overflow checks are */
#define twobit_op2imm_523( y, kn, k ) /* -:fix:fix */ \
  twobit_subtract( RESULT, y, kn, k )


/* Introduced by peephole optimization */
#define twobit_alloc_known_vector( k )		\
  do {						\
    word *p;					\
    ALLOCATE(fixnum( VEC_HEADER_WORDS+k ));	\
    p = (word*)RESULT;				\
    p[0] = mkheader( words2bytes(k), VEC_HDR );	\
    RESULT = tagptr( p, VEC_TAG );		\
  } while(0)

#define twobit_fxcmp_branchf( y, op, ex, L_numeric, L_symbolic )	\
  do { word a = RESULT, b = y;						\
       if (UNSAFE_TRUE(is_both_fixnums(a,b)))				\
       {								\
         if (!((s_word)a op (s_word)b))                                 \
                   twobit_branch( L_numeric, L_symbolic );	        \
       }								\
       else { SECOND=b; FAIL( ex ); }					\
  } while(0)

#define twobit_fxcmp_imm_branchf( b, op, ex, L_numeric, L_symbolic )	\
  do { word a = RESULT;							\
       if (UNSAFE_TRUE(is_fixnum(a)))					\
       {								\
         if (!((s_word)a op (s_word)b))                                 \
                   twobit_branch( L_numeric, L_symbolic );	        \
       }								\
       else { SECOND=b; FAIL( ex ); }					\
  } while(0)

#define twobit_numcmp_branchf( x, y, op, generic, kn, k, L_numeric, L_symbolic )	\
  do { word a = x, b = y;								\
       if (is_both_fixnums( a, b )) {							\
         if( !((s_word)a op (s_word)b) ) twobit_branch( L_numeric, L_symbolic );	\
         twobit_skip( kn, k );								\
       }										\
       SECOND = b;									\
  } while(0);										\
  WITH_SAVED_STATE( generic( globals, CONT_LOCAL(kn*10000,SPLICE(k,_10000)) ) );	\
  twobit_label( kn*10000, SPLICE(k,_10000) );						\
  if (RESULT == FALSE_CONST) twobit_branch( L_numeric, L_symbolic );			\
  twobit_label( kn, k )

#define twobit_charcmp_branchf( y, op, ex, L_numeric, L_symbolic )	\
  do { word a=RESULT, b=SECOND=y;					\
       if (UNSAFE_TRUE(is_char(a) && is_char(b)))			\
       {								\
         if (!(a op b)) twobit_branch( L_numeric, L_symbolic );		\
       }								\
       else { FAIL( ex ); }						\
  } while(0)

#define twobit_charcmp_imm_branchf( y, op, ex, L_numeric, L_symbolic )	\
  do { word a=RESULT, b=SECOND=y;					\
       if (UNSAFE_TRUE(is_char(a)))					\
       {								\
         if (!(a op b))	 twobit_branch( L_numeric, L_symbolic );	\
       }								\
       else { FAIL( ex ); }						\
  } while(0)

#define twobit_op2_600( y ) /* make-vector:0 */	\
  twobit_alloc_known_vector( 0 )

#define twobit_op2_601( y ) /* make-vector:1 */			\
  twobit_alloc_known_vector( 1 );				\
  SECOND = reg(y);						\
  *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = SECOND;	\
  BARRIER();

#define twobit_op2_602( y ) /* make-vector:2 */				\
  twobit_alloc_known_vector( 2 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
  }									\
  BARRIER();

#define twobit_op2_603( y ) /* make-vector:3 */				\
  twobit_alloc_known_vector( 3 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+2)) = x;	\
  }									\
  BARRIER();

#define twobit_op2_604( y ) /* make-vector:4 */				\
  twobit_alloc_known_vector( 4 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+2)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+3)) = x;	\
  }									\
  BARRIER();

#define twobit_op2_605( y ) /* make-vector:5 */				\
  twobit_alloc_known_vector( 5 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+2)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+3)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+4)) = x;	\
  }									\
  BARRIER();

#define twobit_op2_606( y ) /* make-vector:6 */				\
  twobit_alloc_known_vector( 6 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+2)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+3)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+4)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+5)) = x;	\
  }									\
  BARRIER();

#define twobit_op2_607( y ) /* make-vector:7 */				\
  twobit_alloc_known_vector( 7 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+2)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+3)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+4)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+5)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+6)) = x;	\
  }									\
  BARRIER();

#define twobit_op2_608( y ) /* make-vector:8 */				\
  twobit_alloc_known_vector( 8 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+2)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+3)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+4)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+5)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+6)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+7)) = x;	\
  }									\
  BARRIER();

#define twobit_op2_609( y ) /* make-vector:9 */				\
  twobit_alloc_known_vector( 9 );					\
  { word x;								\
    x = SECOND = reg(y);						\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS)) = x;		\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+1)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+2)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+3)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+4)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+5)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+6)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+7)) = x;	\
    *(word*)(RESULT-VEC_TAG+words2bytes(VEC_HEADER_WORDS+8)) = x;	\
  }									\
  BARRIER();

#define twobit_op1_branchf_610( L_numeric, L_symbolic ) /* null? */ \
  do { if( RESULT != NIL_CONST ) twobit_branch( L_numeric, L_symbolic ); } while(0)
    
#define twobit_op1_branchf_611( L_numeric, L_symbolic ) /* pair? */ \
  do { if( tagof(RESULT) != PAIR_TAG ) twobit_branch( L_numeric, L_symbolic ); } while(0)
    
/* FIXME: I'm not sure this is being used, because Twobit translates (zero? x) to (= x 0).
   The twobit_label inside the do { ... }  looks very dubious.
   */
#define twobit_op1_branchf_612( kn, k, L_numeric, L_symbolic ) /* zero? */	\
  do { if (is_fixnum(RESULT)) {							\
         if (RESULT != fixnum(0))						\
           twobit_branch( L_numeric, L_symbolic );				\
       }									\
       else {									\
         WITH_SAVED_STATE( mc_zerop( globals ) );				\
         if (RESULT == FALSE_CONST) twobit_branch( L_numeric, L_symbolic );	\
       }									\
       twobit_label( kn, k );							\
   } while(0)

#define twobit_op1_branchf_613( L_numeric, L_symbolic ) /* eof-object? */ \
  do { if( RESULT != EOF_CONST ) twobit_branch( L_numeric, L_symbolic ); } while(0)

#define twobit_op1_branchf_614( L_numeric, L_symbolic ) /* fixnum? */ \
  do { if( !is_fixnum(RESULT) ) twobit_branch( L_numeric, L_symbolic ); } while(0)

#define twobit_op1_branchf_615( L_numeric, L_symbolic ) /* char? */ \
  do { if( !is_char(RESULT) ) twobit_branch( L_numeric, L_symbolic ); } while(0)

#define twobit_op1_branchf_616( L_numeric, L_symbolic ) /* fxzero? */ \
  twobit_fxcmp_imm_branchf( 0, ==, EX_FXZERO, L_numeric, L_symbolic )

#define twobit_op1_branchf_617( L_numeric, L_symbolic ) /* fxnegative? */ \
  twobit_fxcmp_imm_branchf( 0, <, EX_FXNEGATIVE, L_numeric, L_symbolic )

#define twobit_op1_branchf_618( L_numeric, L_symbolic ) /* fxpositive? */ \
  twobit_fxcmp_imm_branchf( 0, >, EX_FXPOSITIVE, L_numeric, L_symbolic )

#define twobit_op2_branchf_619( y, kn, k, L_numeric, L_symbolic ) /* < */ \
  twobit_numcmp_branchf( RESULT, reg(y), <, mc_lessp, kn, k, L_numeric, L_symbolic )

#define twobit_op2_branchf_620( y, kn, k, L_numeric, L_symbolic ) /* > */ \
  twobit_numcmp_branchf( RESULT, reg(y), >, mc_greaterp, kn, k, L_numeric, L_symbolic )

#define twobit_op2_branchf_621( y, kn, k, L_numeric, L_symbolic ) /* >= */ \
  twobit_numcmp_branchf( RESULT, reg(y), >=, mc_greater_or_equalp, kn, k, L_numeric, L_symbolic )

#define twobit_op2_branchf_622( y, kn, k, L_numeric, L_symbolic ) /* <= */ \
  twobit_numcmp_branchf( RESULT, reg(y), <=, mc_less_or_equalp, kn, k, L_numeric, L_symbolic )

#define twobit_op2_branchf_623( y, kn, k, L_numeric, L_symbolic ) /* = */ \
  twobit_numcmp_branchf( RESULT, reg(y), ==, mc_equalp, kn, k, L_numeric, L_symbolic )

#define twobit_op2_branchf_624( y, L_numeric, L_symbolic ) /* eq? */ \
  do { if( RESULT != reg(y) ) twobit_branch( L_numeric, L_symbolic ); } while(0)

#define twobit_op2_branchf_625( y, L_numeric, L_symbolic ) /* char=? */ \
  twobit_charcmp_branchf( reg(y), ==, EX_CHAREQ, L_numeric, L_symbolic )

#define twobit_op2_branchf_626( y, L_numeric, L_symbolic ) /* char>=? */ \
  twobit_charcmp_branchf( reg(y), >=, EX_CHARGE, L_numeric, L_symbolic )

#define twobit_op2_branchf_627( y, L_numeric, L_symbolic ) /* char>? */ \
  twobit_charcmp_branchf( reg(y), >, EX_CHARGT, L_numeric, L_symbolic )

#define twobit_op2_branchf_628( y, L_numeric, L_symbolic ) /* char<=? */ \
  twobit_charcmp_branchf( reg(y), <=, EX_CHARLE, L_numeric, L_symbolic )

#define twobit_op2_branchf_629( y, L_numeric, L_symbolic ) /* char<? */ \
  twobit_charcmp_branchf( reg(y), <, EX_CHARLT, L_numeric, L_symbolic )

#define twobit_op2_branchf_630( y, L_numeric, L_symbolic ) /* fx= */ \
  twobit_fxcmp_branchf( reg(y), ==, EX_FXEQ, L_numeric, L_symbolic )

#define twobit_op2_branchf_631( y, L_numeric, L_symbolic ) /* fx> */ \
  twobit_fxcmp_branchf( reg(y), >, EX_FXGT, L_numeric, L_symbolic )

#define twobit_op2_branchf_632( y, L_numeric, L_symbolic ) /* fx>= */ \
  twobit_fxcmp_branchf( reg(y), >=, EX_FXGE, L_numeric, L_symbolic )

#define twobit_op2_branchf_633( y, L_numeric, L_symbolic ) /* fx< */ \
  twobit_fxcmp_branchf( reg(y), <, EX_FXLT, L_numeric, L_symbolic )

#define twobit_op2_branchf_634( y, L_numeric, L_symbolic ) /* fx<= */ \
  twobit_fxcmp_branchf( reg(y), <=, EX_FXLE, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_635( y, kn, k, L_numeric, L_symbolic ) /* < */ \
  twobit_numcmp_branchf( RESULT, y, <, mc_lessp, kn, k, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_636( y, kn, k, L_numeric, L_symbolic ) /* > */ \
  twobit_numcmp_branchf( RESULT, y, >, mc_greaterp, kn, k, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_637( y, kn, k, L_numeric, L_symbolic ) /* >= */ \
  twobit_numcmp_branchf( RESULT, y, >=, mc_greater_or_equalp, kn, k, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_638( y, kn, k, L_numeric, L_symbolic ) /* <= */ \
  twobit_numcmp_branchf( RESULT, y, <=, mc_less_or_equalp, kn, k, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_639( y, kn, k, L_numeric, L_symbolic ) /* = */ \
  twobit_numcmp_branchf( RESULT, y, ==, mc_equalp, kn, k, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_640( y, L_numeric, L_symbolic ) /* eq? */ \
  do { if( RESULT != y ) twobit_branch( L_numeric, L_symbolic ); } while(0)

#define twobit_op2imm_branchf_641( y, L_numeric, L_symbolic ) /* char=? */ \
  twobit_charcmp_imm_branchf( y, ==, EX_CHAREQ, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_642( y, L_numeric, L_symbolic ) /* char>=? */ \
  twobit_charcmp_imm_branchf( y, >=, EX_CHARGE, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_643( y, L_numeric, L_symbolic ) /* char>? */ \
  twobit_charcmp_imm_branchf( y, >, EX_CHARGT, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_644( y, L_numeric, L_symbolic ) /* char<=? */ \
  twobit_charcmp_imm_branchf( y, <=, EX_CHARLE, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_645( y, L_numeric, L_symbolic ) /* char<? */ \
  twobit_charcmp_imm_branchf( y, <, EX_CHARLT, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_646( y, L_numeric, L_symbolic ) /* fx= */ \
  twobit_fxcmp_imm_branchf( y, ==, EX_FXEQ, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_647( y, L_numeric, L_symbolic ) /* fx> */ \
  twobit_fxcmp_imm_branchf( y, >, EX_FXGT, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_648( y, L_numeric, L_symbolic ) /* fx>= */ \
  twobit_fxcmp_imm_branchf( y, >=, EX_FXGE, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_649( y, L_numeric, L_symbolic ) /* fx< */ \
  twobit_fxcmp_imm_branchf( y, <, EX_FXLT, L_numeric, L_symbolic )

#define twobit_op2imm_branchf_650( y, L_numeric, L_symbolic ) /* fx<= */ \
  twobit_fxcmp_imm_branchf( y, <=, EX_FXLE, L_numeric, L_symbolic )

/* Note, for the _check_ optimizations there is a hack in place.  Rather
   than using register numbers in the instructions the assembler emits
   reg(k) expressions when appropriate.  The reason it does this is so
   that it can also emit RESULT when it needs to, since RESULT can
   appear as a register name in these instructions.

   This is a hack, but it beats having two versions of every macro.
   */

#define twobit_reg_op1_check_651( y, L_numeric, L_symbolic ) /* fixnum? */ \
  if (!is_fixnum(y)) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op1_check_652( y, L_numeric, L_symbolic ) /* pair? */ \
  if (tagof(y) != PAIR_TAG) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op1_check_653( y, L_numeric, L_symbolic ) /* string? */	\
  do { word x = y;								\
       if (tagof(x) != VEC_TAG || typetag(*ptrof(x)) != VEC_SUBTAG)		\
         twobit_skip( L_numeric, L_symbolic );					\
  } while(0)

#define twobit_reg_op1_check_654( y, L_numeric, L_symbolic ) /* vector? */	\
  do { word x = y;								\
       if (tagof(x) != BVEC_TAG || typetag(*ptrof(x)) != STR_SUBTAG)		\
         twobit_skip( L_numeric, L_symbolic );					\
  } while(0)

#define twobit_reg_op2_check_655( y1, y2, L_numeric, L_symbolic ) /* <:fix:fix */ \
  if (!((s_word)(y1) < (s_word)(y2))) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op2_check_656( y1, y2, L_numeric, L_symbolic ) /* <=:fix:fix */ \
  if (!((s_word)(y1) <= (s_word)(y2))) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op2_check_657( y1, y2, L_numeric, L_symbolic ) /* >=:fix:fix */ \
  if (!((s_word)(y1) >= (s_word)(y2))) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op2imm_check_658( y1, y2, L_numeric, L_symbolic ) /* <:fix:fix */ \
  if (!((s_word)(y1) < (s_word)(y2))) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op2imm_check_659( y1, y2, L_numeric, L_symbolic ) /* <=:fix:fix */ \
  if (!((s_word)(y1) <= (s_word)(y2))) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op2imm_check_660( y1, y2, L_numeric, L_symbolic ) /* >=:fix:fix */ \
  if (!((s_word)(y1) >= (s_word)(y2))) twobit_skip( L_numeric, L_symbolic )

/* Trick -- unsigned comparison computes !(0 <= y1 < y2) */
#define twobit_reg_op2_check_661( y1, y2, L_numeric, L_symbolic ) /* range check */ \
  if ((y1) >= (y2)) twobit_skip( L_numeric, L_symbolic )

#define twobit_reg_op2_check_662( y1, y2, L_numeric, L_symbolic ) /* check-vector?/vector-length:vec */	\
  do { word x1 = (y1);							\
       if (tagof(x1) != VEC_TAG || typetag(*ptrof(x1)) != VEC_SUBTAG)	\
         twobit_skip( L_numeric, L_symbolic );				\
       y2 = fixnum(vector_length(x1));					\
  } while(0)

#define twobit_reg_op2_check_663( y1, y2, L_numeric, L_symbolic ) /* check-string?/string-length:str */	\
  do { word x1 = (y1);							\
       if (tagof(x1) != BVEC_TAG || typetag(*ptrof(x1)) != STR_SUBTAG)	\
         twobit_skip( L_numeric, L_symbolic );				\
       y2 = fixnum(string_length(x1));					\
  } while(0)

#define twobit_op2_799( y ) /* make-ustring */ \
   do { word a=RESULT, b=reg(y), *p; \
        if (UNSAFE_TRUE(is_nonnegative_fixnum(a) && is_char(b))) { \
          word size = a; \
          long n = a >> 2; \
          ALLOCATE_BV( 4*a + fixnum(BVEC_HEADER_WORDS*sizeof( word )) ); \
          p =(word*)RESULT; \
          *p = mkheader( size, BV_HDR+USTR_SUBTAG ); \
          while (n > 0) { \
              *(p+n) = b; \
              n = n - 1; \
          } \
	  RESULT = tagptr( p, BVEC_TAG ); \
        } else { FAIL( EX_MAKE_STRING ); } \
        integrity_check( "make-string" ); \
   } while(0)
  
#define twobit_op1_800()         /* ustring?       */ \
   double_tag_predicate( RESULT, BVEC_TAG, BV_HDR+USTR_SUBTAG )

/* The compiler inserts safety checks before these instructions. */

#define twobit_op1_801()         /* ustring-length */                         \
   do { word h, a=RESULT;                                                     \
        h = the_header( a, BVEC_TAG );                                        \
        RESULT = sizefield(h);                                                \
   } while ( 0 ) 

/*
   do { word h, a=RESULT;                                                     \
      if (UNSAFE_TRUE2(double_tag_test( a, BVEC_TAG, BV_HDR+USTR_SUBTAG, h ), \
                       h = the_header( a, BVEC_TAG )))                        \
        RESULT = sizefield(h);                                                \
      else { FAIL( EX_STRING_LENGTH ); }                                      \
      integrity_check( "string-length" );                                     \
   } while ( 0 )
*/
 
#define twobit_op2_802( y )      /* ustring-ref    */                         \
   do { word a=RESULT, b=reg(y);                                              \
         RESULT = *word_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b);             \
   } while (0)

/*
   do { word a=RESULT, b=reg(y), h;                                           \
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, BV_HDR+USTR_SUBTAG, h ) \
            && is_fixnum(b) &&                                                \
            b < (h >> 8))) {                                                  \
         RESULT = *word_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b);             \
        } else { SECOND=b;                                                    \
               FAIL( EX_STRING_REF ); }                                       \
   } while (0)
*/

#define twobit_op3_803( y, z )   /* ustring-set!   */                         \
   do { word a=RESULT, b=reg(y), c=reg(z);                                    \
           *word_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b ) = c;               \
   } while (0)

/*
   do { word a=RESULT, b=reg(y), c=reg(z), h;                                 \
        if (UNSAFE_TRUE(double_tag_test( a, BVEC_TAG, BV_HDR+USTR_SUBTAG, h ) \
            && is_fixnum(b) &&                                                \
            b < (h >> 8) &&                                                   \
                       is_char( c ))) {                                       \
           *word_addr( a, BVEC_TAG, BVEC_HEADER_WORDS, b ) = c;               \
        } else { SECOND=b; THIRD=c;                                           \
               FAIL( EX_STRING_SET ); }                                       \
   } while (0)
*/

#endif /* TWOBIT_H */

/* eof */
