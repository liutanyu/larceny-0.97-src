/* Copyright 1998 Lars T Hansen.
 * 
 * $Id: gc_t.c 5605 2008-06-30 15:14:15Z pnkfelix $
 *
 * Larceny -- garbage collector structure constructor
 */

#include "larceny.h"
#include "gc_t.h"

gc_t 
*create_gc_t(char *id,
	     void *data,
	     int  (*initialize)( gc_t *gc ),
	     word *(*allocate)( gc_t *gc, int nbytes, bool no_gc, bool atomic),
	     word *(*allocate_nonmoving)( gc_t *gc, int nbytes, bool atomic ),
	     void (*make_room)( gc_t *gc ), 
	     void (*collect)( gc_t *gc, int gen, int bytes, gc_type_t req ),
	     void (*permute_remembered_sets)( gc_t *gc, int permutation[] ),
	     void (*set_policy)( gc_t *gc, int heap, int x, int y ),
	     word *(*data_load_area)( gc_t *gc, int nbytes ),
	     word *(*text_load_area)( gc_t *gc, int nbytes ),
	     int  (*iflush)( gc_t *gc, int generation ),
	     word (*creg_get)( gc_t *gc ),
	     void (*creg_set)( gc_t *gc, word k ),
	     void (*stack_overflow)( gc_t *gc ),
	     void (*stack_underflow)( gc_t *gc ),
	     int  (*compact_all_ssbs)( gc_t *gc ),
#if defined(SIMULATE_NEW_BARRIER)
	     int (*isremembered)( gc_t *gc, word w ),
#endif
	     void (*compact_np_ssb)( gc_t *gc ),
	     void (*np_remset_ptrs)( gc_t *gc, word ***ssbtop, word ***ssblim),
	     int  (*load_heap)( gc_t *gc, heapio_t *h ),
	     int  (*dump_heap)( gc_t *gc, const char *filename, bool compact ),
	     word *(*make_handle)( gc_t *gc, word obj ),
	     void (*free_handle)( gc_t *gc, word *handle ),
	     void (*enumerate_roots)( gc_t *gc, void (*f)( word*, void *),
				     void * ),
	     void (*enumerate_remsets_older_than)
	        ( gc_t *gc, int generation,
		  bool (*f)(word, void*, unsigned * ),
		  void *data, 
		  bool enumerate_np_remset )
	     )
{
  gc_t *gc;
  gc = (gc_t*)must_malloc( sizeof( gc_t ) );

  gc->id = id;
  gc->data = data;

  gc->los = 0;
  gc->young_area = 0;
  gc->ephemeral_area = 0;
  gc->dynamic_area = 0;
  gc->static_area = 0;
  gc->los = 0;
  gc->remset = 0;
  gc->ephemeral_area_count = 0;
  gc->remset_count = 0;
  gc->np_remset = -1;

  gc->initialize = initialize;
  gc->allocate = allocate;
  gc->allocate_nonmoving = allocate_nonmoving;
  gc->make_room = make_room;
  gc->collect = collect;
  gc->permute_remembered_sets = permute_remembered_sets;
  gc->set_policy = set_policy;
  gc->data_load_area = data_load_area;
  gc->text_load_area = text_load_area;

  gc->iflush = iflush;
  gc->creg_get = creg_get;
  gc->creg_set = creg_set;
  gc->stack_overflow = stack_overflow;
  gc->stack_underflow = stack_underflow;

  gc->compact_all_ssbs = compact_all_ssbs;
#if defined(SIMULATE_NEW_BARRIER)
  gc->isremembered = isremembered;
#endif
  gc->compact_np_ssb = compact_np_ssb;

  gc->np_remset_ptrs = np_remset_ptrs;

  gc->load_heap = load_heap;
  gc->dump_heap = dump_heap;

  gc->make_handle = make_handle;
  gc->free_handle = free_handle;
  
  gc->enumerate_roots = enumerate_roots;
  gc->enumerate_remsets_older_than = enumerate_remsets_older_than;

  return gc;
}

/* eof */
