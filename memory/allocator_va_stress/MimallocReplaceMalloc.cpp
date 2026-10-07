/* Experimental Firefox replace-malloc adapter for mimalloc.
 *
 * This adapter deliberately replaces the ordinary malloc family while
 * preserving Firefox's native mozjemalloc arena API. Pointers that originate
 * from native arenas (or from any allocation made before replacement became
 * active) are routed back to the original allocator by ownership detection.
 *
 * This is a focused PoC adapter. The native jemalloc statistics interface is
 * intentionally left untouched, so Firefox internal heap reports do not
 * account for the mimalloc-owned ordinary heap. Browser A/B evaluation must
 * therefore use external process/VA measurements as the primary evidence.
 */

#include <stddef.h>

#include "mimalloc.h"
#include "replace_malloc.h"

static malloc_table_t gOriginal;

static bool IsMimallocPointer(const void* aPtr) {
  return aPtr && mi_is_in_heap_region(aPtr);
}

static void* replace_malloc(size_t aSize) { return mi_malloc(aSize); }

static void* replace_calloc(size_t aCount, size_t aSize) {
  return mi_calloc(aCount, aSize);
}

static void* replace_realloc(void* aPtr, size_t aSize) {
  if (!aPtr || IsMimallocPointer(aPtr)) {
    return mi_realloc(aPtr, aSize);
  }
  return gOriginal.realloc(aPtr, aSize);
}

static void replace_free(void* aPtr) {
  if (!aPtr) {
    return;
  }
  if (IsMimallocPointer(aPtr)) {
    mi_free(aPtr);
    return;
  }
  gOriginal.free(aPtr);
}

static void* replace_memalign(size_t aAlignment, size_t aSize) {
  return mi_malloc_aligned(aSize, aAlignment);
}

static int replace_posix_memalign(void** aPtr, size_t aAlignment,
                                  size_t aSize) {
  return mi_posix_memalign(aPtr, aAlignment, aSize);
}

static void* replace_aligned_alloc(size_t aAlignment, size_t aSize) {
  return mi_aligned_alloc(aAlignment, aSize);
}

static void* replace_valloc(size_t aSize) { return mi_valloc(aSize); }

static size_t replace_malloc_usable_size(usable_ptr_t aPtr) {
  if (!aPtr) {
    return 0;
  }
  if (IsMimallocPointer(aPtr)) {
    return mi_malloc_usable_size(aPtr);
  }
  return gOriginal.malloc_usable_size(aPtr);
}

static size_t replace_malloc_good_size(size_t aSize) {
  return mi_malloc_good_size(aSize);
}


/* Keep Firefox's explicit arena API on the original mozjemalloc allocator.
 *
 * Gecko's replace_malloc_init_funcs() installs DummyArenaAllocator when malloc
 * is replaced but the arena entries are left equal to the canonical table.
 * These forwarding wrappers intentionally make the entries non-canonical while
 * preserving native mozjemalloc arena semantics.
 */
static arena_id_t replace_moz_create_arena_with_params(
    arena_params_t* aParams) {
  return gOriginal.moz_create_arena_with_params(aParams);
}

static void replace_moz_dispose_arena(arena_id_t aArenaId) {
  gOriginal.moz_dispose_arena(aArenaId);
}

static void* replace_moz_arena_malloc(arena_id_t aArenaId, size_t aSize) {
  return gOriginal.moz_arena_malloc(aArenaId, aSize);
}

static void* replace_moz_arena_calloc(arena_id_t aArenaId, size_t aCount,
                                      size_t aSize) {
  return gOriginal.moz_arena_calloc(aArenaId, aCount, aSize);
}

static void* replace_moz_arena_realloc(arena_id_t aArenaId, void* aPtr,
                                       size_t aSize) {
  return gOriginal.moz_arena_realloc(aArenaId, aPtr, aSize);
}

static void replace_moz_arena_free(arena_id_t aArenaId, void* aPtr) {
  gOriginal.moz_arena_free(aArenaId, aPtr);
}

static void* replace_moz_arena_memalign(arena_id_t aArenaId,
                                        size_t aAlignment, size_t aSize) {
  return gOriginal.moz_arena_memalign(aArenaId, aAlignment, aSize);
}

/* Preserve Firefox's existing purge hooks while also asking mimalloc to return
 * unused backing pages. This keeps about:memory "Minimize memory usage" from
 * becoming a no-op for the replacement-owned ordinary heap.
 */
static void replace_jemalloc_purge_freed_pages() {
  mi_collect(true);
  gOriginal.jemalloc_purge_freed_pages();
}

static void replace_jemalloc_free_dirty_pages() {
  mi_collect(true);
  gOriginal.jemalloc_free_dirty_pages();
}

static void replace_jemalloc_free_excess_dirty_pages() {
  mi_collect(true);
  gOriginal.jemalloc_free_excess_dirty_pages();
}

MOZ_BEGIN_EXTERN_C

MOZ_EXPORT void replace_init(malloc_table_t* aTable,
                             ReplaceMallocBridge** aBridge) {
  gOriginal = *aTable;

  aTable->malloc = replace_malloc;
  aTable->calloc = replace_calloc;
  aTable->realloc = replace_realloc;
  aTable->free = replace_free;
  aTable->memalign = replace_memalign;
  aTable->posix_memalign = replace_posix_memalign;
  aTable->aligned_alloc = replace_aligned_alloc;
  aTable->valloc = replace_valloc;
  aTable->malloc_usable_size = replace_malloc_usable_size;
  aTable->malloc_good_size = replace_malloc_good_size;

  aTable->moz_create_arena_with_params =
      replace_moz_create_arena_with_params;
  aTable->moz_dispose_arena = replace_moz_dispose_arena;
  aTable->moz_arena_malloc = replace_moz_arena_malloc;
  aTable->moz_arena_calloc = replace_moz_arena_calloc;
  aTable->moz_arena_realloc = replace_moz_arena_realloc;
  aTable->moz_arena_free = replace_moz_arena_free;
  aTable->moz_arena_memalign = replace_moz_arena_memalign;

  aTable->jemalloc_purge_freed_pages = replace_jemalloc_purge_freed_pages;
  aTable->jemalloc_free_dirty_pages = replace_jemalloc_free_dirty_pages;
  aTable->jemalloc_free_excess_dirty_pages =
      replace_jemalloc_free_excess_dirty_pages;

  /* Native jemalloc statistics remain original. The explicit arena wrappers
   * above prevent Gecko from substituting DummyArenaAllocator and keep
   * moz_arena_* semantics on native mozjemalloc. Plain free/realloc/
   * malloc_usable_size route original-owned pointers back correctly.
   */
  *aBridge = nullptr;
}

MOZ_END_EXTERN_C
