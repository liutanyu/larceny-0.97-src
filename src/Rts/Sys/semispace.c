/* Copyright 1998 Lars T Hansen.             -*- indent-tabs-mode: nil -*-
 *
 * $Id: semispace.c 4071 2007-03-02 20:45:34Z pnkfelix $
 */

#define GC_INTERNAL

#include <stdlib.h>
#include "larceny.h"
#include "gclib.h"
#include "semispace_t.h"

static word NOWHERE[1];
  /* NOWHERE is a dummy word address that we use in the .bot, .top,
     and .lim fields of empty chunks in place of null pointers, 
     because ANSI/ISO C apparently does not allow two null pointers
     to be subtracted (at least there is no language in K&R2 to permit
     such subtraction). 
     */

/* Invariants that it's good to check every time. */
#define ss_invariants( ss )                                             \
  do {                                                                  \
    assert( -1 <= ss->current && ss->current < ss->n );                 \
    assert( ss->chunks != 0 );                                          \
    assert( ss->current == -1 || ss->chunks[ss->current].bytes > 0 );   \
    assert( ss->allocated > 0 || ss->current == -1 );                   \
    assert( ss->chunks[-1].bot == NOWHERE );                            \
  } while (0)

static void extend_chunk_array( semispace_t *ss );
static void allocate_chunk_memory( semispace_t *ss, int slot, int bytes );
static void free_chunk_memory( semispace_t *ss, int slot );
static void clear( semispace_t *ss, int i );
static int find_empty_slot_and_chunk( semispace_t *ss, int bytes, int *chunk );


semispace_t *create_semispace( int bytes, int gen_no )
{
  assert( bytes > 0 );
  assert( gen_no >= 0 );

  return create_semispace_n( bytes, 1, gen_no );
}


semispace_t *create_semispace_n( int bytes, int nchunks, int gen_no )
{
  semispace_t *ss;
  ss_chunk_t *chunks;
  int n, i;

  assert( nchunks >= 0 );
  assert( bytes > 0 || nchunks == 0 );
  assert( gen_no >= 0 );

  bytes = roundup_page( bytes );
  n = max( 5, nchunks*2 );

  chunks = (ss_chunk_t*)must_malloc( sizeof( ss_chunk_t )*(n+1) );
  for ( i = 0; i < n+1; i++ ) {
    chunks[i].bytes = 0;
    chunks[i].bot = chunks[i].top = chunks[i].lim = NOWHERE;
  }

  ss = (semispace_t*)must_malloc( sizeof( semispace_t ) );
  ss->gen_no = gen_no;
  ss->n = n;
  ss->current = (nchunks > 0 ? 0 : -1);
  ss->chunks = chunks+1;        /* Entry -1 is valid, too */
  ss->allocated = 0;
  ss->used = 0;

  for ( i=0 ; i < nchunks ; i++ )
    allocate_chunk_memory( ss, i, bytes );
      
  ss_invariants( ss );

  return ss;
}


void ss_expand( semispace_t *ss, int bytes_needed )
{
  int empty, chunk;

  ss_invariants( ss );
  assert( bytes_needed > 0 );

  bytes_needed = roundup_page( bytes_needed );

  empty = find_empty_slot_and_chunk( ss, bytes_needed, &chunk );

  if (chunk >= 0) {
    /* Found a chunk.  Increment current, and swap the found chunk into
       the now-current slot, then return.  Ignore the empty slot.
       */
    ss_chunk_t tmp;

    ss->current = ss->current + 1;
    tmp = ss->chunks[chunk];
    ss->chunks[chunk] = ss->chunks[ss->current];
    ss->chunks[ss->current] = tmp;
    ss->chunks[ss->current].top = ss->chunks[ss->current].bot;

    ss_invariants( ss );
    return;
  }

  /* We have an empty slot, but no chunk yet.  Increment current, move
   * the chunk from the current slot to slot 'empty' (to preserve its 
   * contents -- it has memory, just not enough), then allocate a
   * new chunk in the current slot.
   */
  ss->current = ss->current + 1;
  ss->chunks[empty] = ss->chunks[ss->current];
  allocate_chunk_memory( ss, ss->current, bytes_needed );

  ss_invariants( ss );
}


void ss_reset( semispace_t *ss )
{
  int i;

  ss_invariants( ss );

  for ( i = 0 ; i < ss->n ; i++ )
    if (ss->chunks[i].bytes > 0)
      ss->chunks[i].top = ss->chunks[i].bot;

  ss->current = (ss->chunks[0].bytes > 0 ? 0 : -1);
  ss->used = 0;

  ss_invariants( ss );
}


void ss_prune( semispace_t *ss )
{
  int i;

  ss_invariants( ss );

  for ( i = ss->current+1 ; i < ss->n ; i++ )
    if (ss->chunks[i].bytes > 0)
      free_chunk_memory( ss, i );
  ss_reset( ss );

  ss_invariants( ss );
}


void ss_free_unused_chunks( semispace_t *ss )
{
  int i;

  ss_invariants( ss );

  for ( i = ss->current+1 ; i < ss->n ; i++ )
    if (ss->chunks[i].bytes > 0) 
      free_chunk_memory( ss, i );

  ss_invariants( ss );
}


void ss_shrinkwrap( semispace_t *ss )
{
  int i;
  int newbytes;
  ss_chunk_t *c;

  ss_invariants( ss );

  for ( i = ss->current+1 ; i < ss->n ; i++ )
    if (ss->chunks[i].bytes > 0) 
      free_chunk_memory( ss, i );

  if (ss->current >= 0) {
    word *newtop;
    c = &ss->chunks[ss->current];
    newtop = (word*)roundup_page( (unsigned)c->top );
    while(c->top < newtop) {
      *c->top = 0;
      c->top++;
    }
    c->lim = c->top = newtop;
    newbytes = (c->top - c->bot)*sizeof( word );
    gclib_shrink_block( c->bot, c->bytes, newbytes );
    ss->allocated -= c->bytes - newbytes;
    c->bytes = newbytes;
  }

  ss_invariants( ss );
}


void ss_sync( semispace_t *ss )
{
  int i;

  ss_invariants( ss );

  ss->used = 0;
  for ( i = 0 ; i <= ss->current ; i++ )
    if (ss->chunks[i].bytes > 0)
      ss->used += (ss->chunks[i].top - ss->chunks[i].bot)*sizeof(word);

  ss_invariants( ss );
}


void ss_free( semispace_t *ss )
{
  int i;

  ss_invariants( ss );

  for ( i=0 ; i < ss->n ; i++ )
    if (ss->chunks[i].bytes > 0)
      free_chunk_memory( ss, i );

  free( ss->chunks-1 );         /* Because ss->chunks points to start+1 */
  ss->current = -1;             /* Clear variables just in case... */
  ss->n = -1;
  ss->chunks = 0;
  free( ss );
  /* *ss is dead */
}


int ss_allocate_and_insert_block( semispace_t *ss, int nbytes )
{
  int curr = ss->current;
  ss_chunk_t tmp;

  ss_invariants( ss );
  assert( nbytes > 0 );

  ss_expand( ss, nbytes );
  if (curr >= 0) {
    tmp = ss->chunks[ curr ];
    ss->chunks[ curr ] = ss->chunks[ ss->current ];
    ss->chunks[ ss->current ] = tmp;
  }
  else
    curr = ss->current;

  ss_invariants( ss );

  return curr;
}


int ss_allocate_block_unconditionally( semispace_t *ss, int nbytes )
{
  int empty;

  ss_invariants( ss );
  assert( nbytes > 0 );

  empty = find_empty_slot_and_chunk( ss, nbytes, 0 );
  allocate_chunk_memory( ss, empty, nbytes );

  ss_invariants( ss );
  return empty;
}


int 
ss_move_block_to_semispace( semispace_t *from, int from_idx, semispace_t *to )
{
  int slot, k;

  ss_invariants( from );
  ss_invariants( to );
  assert( 0 <= from_idx && from_idx < from->n );
  assert( from->chunks[from_idx].bytes > 0 );

  slot = find_empty_slot_and_chunk( to, 0, 0 );

  /* Swap the chunk into the current slot. */
  to->chunks[slot] = from->chunks[from_idx];
  if (to->current == -1)
    to->current = 0;

  /* Fill hole in `from': shift down, adjust current if necessary */
  for ( k=from_idx ; k < from->n - 1 ; k++ )
    from->chunks[k] = from->chunks[k+1];
  clear( from, from->n - 1 );
  while (from->chunks[from->current].bytes == 0 && from->current >= 0)
    from->current = from->current - 1;

  /* Update statistics */
  to->allocated += to->chunks[slot].bytes;
  from->allocated -= to->chunks[slot].bytes;

  /* Set generation number on moved memory */
  gclib_set_generation( to->chunks[slot].bot, to->chunks[slot].bytes, 
                        to->gen_no );

  ss_invariants( from );
  ss_invariants( to );

  return slot;
}


int 
ss_insert_block_in_semispace( semispace_t *from, int from_idx, semispace_t *to)
{
  int slot, k;

  ss_invariants( from );
  ss_invariants( to );
  assert( 0 <= from_idx && from_idx < from->n );
  assert( from->chunks[from_idx].bytes > 0 );

  if (to->current == -1) {
    slot = 0;
    to->current = 0;
  }
  else {
    slot = to->current;
    /* Create a hole at to->current: move the following chunk, shift current */
    for ( k=to->current+1 ; k < to->n && to->chunks[k].bytes > 0 ; k++ )
      ;
    if (k == to->n)
      extend_chunk_array( to );
    to->chunks[k] = to->chunks[to->current+1];
    to->chunks[to->current+1] = to->chunks[to->current];
    to->current++;
  }

  /* Swap the chunk into the right slot. */
  to->chunks[slot] = from->chunks[from_idx];

  /* Fill hole in `from': shift down, adjust current if necessary */
  for ( k=from_idx ; k < from->n - 1 ; k++ )
    from->chunks[k] = from->chunks[k+1];
  clear( from, from->n - 1 );
  while (from->chunks[from->current].bytes == 0 && from->current >= 0)
    from->current = from->current - 1;

  /* Update statistics */
  to->allocated += to->chunks[slot].bytes;
  from->allocated -= to->chunks[slot].bytes;

  /* Set generation number on moved memory */
  gclib_set_generation( to->chunks[slot].bot, to->chunks[slot].bytes, 
                        to->gen_no );

  ss_invariants( from );
  ss_invariants( to );

  return slot;
}


void ss_free_block( semispace_t *ss, int idx )
{
  int k;
  
  ss_invariants( ss );
  assert( 0 <= idx && idx < ss->n );
  assert( ss->chunks[idx].bytes > 0 );
  
  free_chunk_memory( ss, idx ); /* Adjusts ss->allocated */

  /* Fill hole in `from': shift down, adjust current if necessary */
  for ( k=idx ; k < ss->n - 1 ; k++ )
    ss->chunks[k] = ss->chunks[k+1];
  clear( ss, ss->n - 1 );
  while (ss->chunks[ss->current].bytes == 0 && ss->current >= 0)
    ss->current = ss->current - 1;

  ss_invariants( ss );
}

void ss_set_gen_no( semispace_t *ss, int gen_no )
{
  int i;

  ss_invariants( ss );
  assert( gen_no >= 0 );

  ss->gen_no = gen_no;
  for ( i=0 ; i < ss->n ; i++ ) {
    if (ss->chunks[i].bytes == 0) continue;
    gclib_set_generation( ss->chunks[i].bot, ss->chunks[i].bytes, gen_no );
  }

  ss_invariants( ss );
}


/* Finds the first empty slot past ss->current and returns its index,
   extending the chunk array if necessary.

   Finds the first available chunk c with c.bytes >= bytes and returns its
   index in *chunk, if chunk is non-null.  If no chunk was found, returns -1
   in *chunk.
   */
static int find_empty_slot_and_chunk( semispace_t *ss, int bytes, int *chunk )
{
  int i, empty, found;

  /* Search for a large-enough chunk, and remember the first empty slot. */
  empty = -1;
  found = -1;
  for ( i=ss->current+1 ; i < ss->n && (found == -1 || empty == -1) ; i++ ) {
    if (ss->chunks[i].bytes == 0 && empty == -1)
      empty = i;
    if (ss->chunks[i].bytes >= bytes && found == -1)
      found = i;
  }

  if (chunk)
    *chunk = found;

  if (empty == -1) {            /* Found no other slot */
    empty = ss->n;              /* First slot of extension will be empty */
    extend_chunk_array( ss );
  }

  assert( ss->n > empty && ss->chunks[empty].bytes == 0);
  assert( chunk == 0 ||
          *chunk == -1 || 
          *chunk > ss->current && ss->chunks[*chunk].bytes >= bytes );

  return empty;
}


static void clear( semispace_t *ss, int i )
{
  ss->chunks[i].bytes = 0;
  ss->chunks[i].bot = ss->chunks[i].top = ss->chunks[i].lim = NOWHERE;
}


static void extend_chunk_array( semispace_t *ss )
{
  const int n = ss->n*2;
  ss_chunk_t *c;
  int i;

  c = (ss_chunk_t*)must_realloc( ss->chunks-1, sizeof( ss_chunk_t )*(n+1) );
  ss->chunks = c+1;
  for ( i = ss->n ; i < n ; i++ ) 
    clear( ss, i );
  ss->n = n;
}


static void allocate_chunk_memory( semispace_t *ss, int slot, int bytes )
{
  word *p;

  assert( bytes % PAGESIZE == 0 );
  assert( slot >= 0 && slot < ss->n );
  assert( ss->chunks[slot].bytes == 0 );

 again:
  p = (word*)gclib_alloc_heap( bytes, ss->gen_no );
  if (p == 0) {
    memfail( MF_HEAP, "Could not expand semispace, request=%u bytes.\n", 
             bytes );
    goto again;
  }

  ss->allocated += bytes;
  ss->chunks[slot].bytes = bytes;
  ss->chunks[slot].bot = p;
  ss->chunks[slot].top = p;
  ss->chunks[slot].lim = (word*)((char*)p + bytes);
}


static void free_chunk_memory( semispace_t *ss, int slot )
{
  ss_chunk_t *c;

  assert( slot >= 0 && slot < ss->n );
  assert( ss->chunks[slot].bytes > 0 );

  c = &ss->chunks[slot];
  gclib_free( c->bot, c->bytes );
  ss->allocated -= c->bytes;
  clear( ss, slot );
}

/* eof */
