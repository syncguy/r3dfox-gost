// Isolated YY-Thunks v1.2.2 L1 negative control, not Firefox or XP product code.
// Compiled together with a TEST-ONLY YY_Thunks.cpp using __YY_Thunks_Unit_Test.
// Instrumentation is injected into upstream YY source only in a CI temp checkout.
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>

extern "C" PTP_WAIT WINAPI YY_Thunks_CreateThreadpoolWait(PTP_WAIT_CALLBACK, PVOID, PTP_CALLBACK_ENVIRON);
extern "C" VOID WINAPI YY_Thunks_SetThreadpoolWait(PTP_WAIT, HANDLE, PFILETIME);
extern "C" VOID WINAPI YY_Thunks_CloseThreadpoolWait(PTP_WAIT);

namespace YY { namespace Thunks {
extern bool aways_null_try_get_CreateThreadpoolWait;
extern bool aways_null_try_get_SetThreadpoolWait;
extern bool aways_null_try_get_WaitForThreadpoolWaitCallbacks;
extern bool aways_null_try_get_CloseThreadpoolWait;
}}

static volatile LONG g_seq = 0;
static volatile LONG g_fallback = 0;
static volatile LONG g_free_count = 0;
static volatile LONG g_free_seq = 0;
static volatile LONG g_post_count = 0;
static volatile LONG g_post_seq = 0;
static volatile LONG g_cb_count = 0;
static volatile LONG g_actual_heap_free = 0;
static volatile LONG g_unsafe = 0;
static PTP_WAIT g_wait = nullptr;
static void* g_freed = nullptr;
static HANDLE g_post_event = nullptr;

static LONG NextSeq() { return InterlockedIncrement(&g_seq); }
static void Note(const char* kind, LONG seq, void* object) {
  printf("EVENT seq=%ld kind=%s ptr=%p\n", seq, kind, object);
  fflush(stdout);
}

// Injected immediately on the known YY fallback branch, after native bypass.
extern "C" void __cdecl XP_L1_FallbackSelected(void) {
  LONG seq = NextSeq();
  InterlockedIncrement(&g_fallback);
  Note("yy_fallback_create", seq, nullptr);
}

// Injected after the REAL HeapFree returns in upstream TppWaitpFree.
// It records an actual heap deallocation, not merely a planned release.
extern "C" void __cdecl XP_L1_FreeObserved(void* object, int heap_free_ok) {
  LONG seq = NextSeq();
  g_freed = object;
  InterlockedExchange(&g_free_seq, seq);
  InterlockedExchange(&g_actual_heap_free, heap_free_ok ? 1 : 0);
  InterlockedIncrement(&g_free_count);
  Note(heap_free_ok ? "actual_heap_free" : "heap_free_failed", seq, object);
}

// Injected immediately before the YY worker's original SetEvent(Wait->hEvent).
// Returning 1 prevents the dangerous dereference only in this controlled trace;
// it does NOT change the release YY library or count as a lifetime safety fix.
extern "C" int __cdecl XP_L1_PostCallback(void* object) {
  LONG seq = NextSeq();
  InterlockedExchange(&g_post_seq, seq);
  InterlockedIncrement(&g_post_count);
  Note("yy_after_user_callback_before_access", seq, object);
  bool freed = (InterlockedCompareExchange(&g_free_count, 0, 0) != 0) &&
               (g_freed == object);
  if (freed) {
    InterlockedExchange(&g_unsafe, 1);
    Note("would_dereference_freed_wait", NextSeq(), object);
  }
  if (g_post_event) SetEvent(g_post_event);
  return freed ? 1 : 0;
}

static VOID CALLBACK Callback(PTP_CALLBACK_INSTANCE, PVOID,
                              PTP_WAIT wait, TP_WAIT_RESULT result) {
  InterlockedIncrement(&g_cb_count);
  Note("firefox_equivalent_callback_enter", NextSeq(), wait);
  if (result != WAIT_OBJECT_0 || wait != g_wait) {
    Note("invalid_callback_identity", NextSeq(), wait);
    return;
  }
  // Exact critical ordering: Firefox OnWaitCompleted -> Replace(Data{})
  // destroys its WaitHandlePtr, calling CloseThreadpoolWait IN callback.
  YY_Thunks_CloseThreadpoolWait(wait);
  Note("firefox_equivalent_callback_close_returned", NextSeq(), wait);
}

int main() {
  YY::Thunks::aways_null_try_get_CreateThreadpoolWait = true;
  YY::Thunks::aways_null_try_get_SetThreadpoolWait = true;
  YY::Thunks::aways_null_try_get_WaitForThreadpoolWaitCallbacks = true;
  YY::Thunks::aways_null_try_get_CloseThreadpoolWait = true;

  HANDLE trigger = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  g_post_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (!trigger || !g_post_event) {
    printf("FAIL cannot_create_events gle=%lu\n", GetLastError());
    return 10;
  }

  g_wait = YY_Thunks_CreateThreadpoolWait(&Callback, nullptr, nullptr);
  if (!g_wait) {
    printf("FAIL create_wait gle=%lu\n", GetLastError());
    return 11;
  }
  printf("EVENT wait_created ptr=%p\n", g_wait); fflush(stdout);
  YY_Thunks_SetThreadpoolWait(g_wait, trigger, nullptr);
  SetEvent(trigger);
  DWORD completed = WaitForSingleObject(g_post_event, 9000);
  if (completed != WAIT_OBJECT_0) {
    printf("FAIL missing_yy_post_callback_event rc=%lu gle=%lu\n",
           completed, GetLastError());
    return 12;
  }
  LONG fallback = InterlockedCompareExchange(&g_fallback, 0, 0);
  LONG frees = InterlockedCompareExchange(&g_free_count, 0, 0);
  LONG posts = InterlockedCompareExchange(&g_post_count, 0, 0);
  LONG calls = InterlockedCompareExchange(&g_cb_count, 0, 0);
  LONG free_seq = InterlockedCompareExchange(&g_free_seq, 0, 0);
  LONG post_seq = InterlockedCompareExchange(&g_post_seq, 0, 0);
  LONG heap_ok = InterlockedCompareExchange(&g_actual_heap_free, 0, 0);
  LONG unsafe = InterlockedCompareExchange(&g_unsafe, 0, 0);
  printf("RESULT fallback=%ld callback_count=%ld free_count=%ld post_count=%ld "
         "heap_free_ok=%ld free_seq=%ld post_seq=%ld free_before_post=%ld "
         "same_ptr=%ld\n",
         fallback, calls, frees, posts, heap_ok, free_seq, post_seq,
         unsafe, (g_freed == g_wait) ? 1L : 0L);
  fflush(stdout);

  if (fallback != 1 || calls != 1 || frees != 1 || posts != 1 ||
      heap_ok != 1 || !unsafe || free_seq < 1 || post_seq <= free_seq ||
      g_freed != g_wait) {
    printf("FAIL baseline_instrumentation_or_order\n"); fflush(stdout);
    return 20;
  }
  printf("EXPECTED_UNSAFE_ORDER_REPRODUCED -- negative control only; NOT safety PASS\n");
  fflush(stdout);
  // Do not close the wait twice: Firefox-equivalent callback already closed it.
  CloseHandle(trigger);
  CloseHandle(g_post_event);
  return 0;
}
