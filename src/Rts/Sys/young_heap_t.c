/* Copyright 1998 Lars T Hansen.
 *
 * $Id: young_heap_t.c 2543 2005-07-20 21:54:03Z pnkfelix $
 *
 * Larceny run-time system -- generic young heap operations
 */

#include "larceny.h"
#include "young_heap_t.h"

static int default_initialize( young_heap_t *h ) { return 1; }
static void default_set_policy( young_heap_t *h, int x, int y ) { }
static void default_before_after_collection( young_heap_t *h ) { }

young_heap_t *create_young_heap_t(
   char *id,
   word code,
   int  (*initialize)( young_heap_t *heap ),
   void (*create_initial_stack)( young_heap_t *heap ),
   word *(*allocate)( young_heap_t *heap, int nbytes, int no_gc ),
   void (*make_room)( young_heap_t *h ),
   void (*collect)( young_heap_t *heap, int nbytes, int request ),
   void (*before_collection)( young_heap_t *heap ),
   void (*after_collection)( young_heap_t *heap ),
   void (*set_policy)( young_heap_t *heap, int rator, int rand ),
   int  (*free_space)( young_heap_t *heap ),
   void (*stats)( young_heap_t *heap ),
   word *(*data_load_area)( young_heap_t *heap, int nbytes ),
   int  (*load_prepare)( young_heap_t *heap, metadata_block_t *m, 
			 heapio_t *h, word **lo, word **hi ),
   int  (*load_data)( young_heap_t *heap, metadata_block_t *m, heapio_t *h),
   word (*creg_get)( young_heap_t *heap ),
   void (*creg_set)( young_heap_t *heap, word k ),
   void (*stack_underflow)( young_heap_t *heap ),
   void (*stack_overflow)( young_heap_t *heap ),
   void *data )
{
  young_heap_t *heap;

  heap = (young_heap_t*)must_malloc( sizeof( young_heap_t ) );
  heap->id = id;
  heap->code = code;
  heap->allocated = 0;
  heap->maximum = 0;

  heap->initialize = (initialize ? initialize : default_initialize );
  heap->create_initial_stack = create_initial_stack;
  heap->allocate = allocate;
  heap->make_room = make_room;
  heap->collect = collect;
  heap->before_collection =
    (before_collection ? before_collection : default_before_after_collection);
  heap->after_collection = 
    (after_collection ? after_collection : default_before_after_collection);
  heap->set_policy = (set_policy ? set_policy : default_set_policy );
  heap->free_space = free_space;
  heap->stats = stats;
  heap->data_load_area = data_load_area;
  heap->load_prepare = load_prepare;
  heap->load_data = load_data;
  heap->creg_get = creg_get;
  heap->creg_set = creg_set;
  heap->stack_underflow = stack_underflow;
  heap->stack_overflow = stack_overflow;
  heap->data = data;

  return heap;
}

/* eof */
