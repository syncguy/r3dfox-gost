// Isolated YY-Thunks v1.2.2 L1 negative control, not Firefox or XP product code.
// Compiled together with a TEST-ONLY YY_Thunks.cpp using __YY_Thunks_Unit_Test.
// Instrumentation is injected into upstream YY source only in a CI temp checkout.
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>

// Upstream Build.cmd FixObj weak defaults, supplied explicitly ONLY by this
// isolated test binary. The source-built YY object has no LibMaker FixObj pass.
extern "C" {
  BOOL __YY_Thunks_Disable_Rreload_Dlls = FALSE;
  extern HMODULE (__fastcall * const __pfnYY_Thunks_CustomLoadLibrary)(const wchar_t*, DWORD) = nullptr;
  void* __acrt_atexit_table = nullptr;
  extern void* const __pfnDllMainCRTStartupForYY_Thunks = nullptr;
}

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
static volatile LONG g_worker_ref = 0;
static volatile LONG g_setter_would_uaf = 0;
static volatile LONG g_setter_alive = 0;
static volatile LONG g_setter_ref = 0;
static volatile LONG g_setter_release_ready = 0;
static volatile LONG g_after_count = 0;
static volatile LONG g_after_seq = 0;
static PTP_WAIT g_wait = nullptr;
static void* g_freed = nullptr;
static HANDLE g_post_event = nullptr;
static HANDLE g_free_event = nullptr;
static HANDLE g_after_event = nullptr;

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
  if (g_free_event) SetEvent(g_free_event);
}

extern "C" void __cdecl XP_REF_Hold(void* object) {
  InterlockedIncrement(&g_worker_ref);
  Note("yy_worker_extra_ref", NextSeq(), object);
}
extern "C" void __cdecl XP_L1_AfterEvent(void* object) {
  LONG seq = NextSeq();
  InterlockedIncrement(&g_after_count);
  InterlockedExchange(&g_after_seq, seq);
  Note("yy_epilogue_after_real_SetEvent", seq, object);
  if (g_after_event) SetEvent(g_after_event);
}
// Called after RegisterWaitForSingleObject but before the setter unlocks
// WaitObjectLock. Controlled test-only delay exposes early object destruction.
// Return 1 to skip unsafe unlock only in this disposable source instrument.
extern "C" void __cdecl XP_SET_Hold(void* object) {
  InterlockedIncrement(&g_setter_ref);
  Note("setter_scope_ref_acquired", NextSeq(), object);
}
extern "C" void __cdecl XP_SET_BeforeRelease(void* object) {
  InterlockedIncrement(&g_setter_release_ready);
  Note("setter_scope_before_final_release", NextSeq(), object);
}
extern "C" int __cdecl XP_REG_BeforeUnlock(void* object) {
  Note("setter_before_WaitObjectLock_unlock", NextSeq(), object);
  // Keep setter in its critical section until the worker's real
  // post-callback SetEvent has executed.
  DWORD completed = WaitForSingleObject(g_after_event, 7000);
  if (completed != WAIT_OBJECT_0) {
    Note("setter_wait_for_epilogue_timeout",NextSeq(),object);
    InterlockedExchange(&g_setter_would_uaf,1);
    return 1;
  }
  if (InterlockedCompareExchange(&g_free_count,0,0)>0 && g_freed==object) {
    InterlockedExchange(&g_setter_would_uaf, 1);
    Note("setter_would_unlock_freed_wait", NextSeq(), object);
    return 1;
  }
  InterlockedIncrement(&g_setter_alive);
  Note("setter_verified_alive_after_epilogue", NextSeq(), object);
  return 0;
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
  g_free_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  g_after_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (!trigger || !g_post_event || !g_free_event || !g_after_event) {
    printf("FAIL cannot_create_events gle=%lu\n", GetLastError());
    return 10;
  }

  g_wait = YY_Thunks_CreateThreadpoolWait(&Callback, nullptr, nullptr);
  if (!g_wait) {
    printf("FAIL create_wait gle=%lu\n", GetLastError());
    return 11;
  }
  printf("EVENT wait_created ptr=%p\n", g_wait); fflush(stdout);
  // Pre-signaled: registration call still owns WaitObjectLock when callback runs.
  SetEvent(trigger);
  YY_Thunks_SetThreadpoolWait(g_wait, trigger, nullptr);
  DWORD completed = WaitForSingleObject(g_post_event, 9000);
  if (completed != WAIT_OBJECT_0) {
    printf("FAIL missing_yy_post_callback_event rc=%lu gle=%lu\n",
           completed, GetLastError());
    return 12;
  }
  if (WaitForSingleObject(g_after_event, 9000) != WAIT_OBJECT_0 ||
      WaitForSingleObject(g_free_event, 9000) != WAIT_OBJECT_0) {
    printf("FAIL missing_real_YY_epilogue_or_free\n"); fflush(stdout);
    return 15;
  }
  LONG fallback = InterlockedCompareExchange(&g_fallback, 0, 0);
  LONG frees = InterlockedCompareExchange(&g_free_count, 0, 0);
  LONG posts = InterlockedCompareExchange(&g_post_count, 0, 0);
  LONG calls = InterlockedCompareExchange(&g_cb_count, 0, 0);
  LONG free_seq = InterlockedCompareExchange(&g_free_seq, 0, 0);
  LONG post_seq = InterlockedCompareExchange(&g_post_seq, 0, 0);
  LONG heap_ok = InterlockedCompareExchange(&g_actual_heap_free, 0, 0);
  LONG unsafe = InterlockedCompareExchange(&g_unsafe, 0, 0);
  LONG afters = InterlockedCompareExchange(&g_after_count, 0, 0);
  LONG after_seq = InterlockedCompareExchange(&g_after_seq, 0, 0);
  LONG refs = InterlockedCompareExchange(&g_worker_ref, 0, 0);
  LONG setter_uaf = InterlockedCompareExchange(&g_setter_would_uaf, 0, 0);
  LONG setter_alive = InterlockedCompareExchange(&g_setter_alive, 0, 0);
  LONG setter_ref = InterlockedCompareExchange(&g_setter_ref, 0, 0);
  LONG setter_release = InterlockedCompareExchange(&g_setter_release_ready, 0, 0);
  printf("RESULT fallback=%ld callback_count=%ld free_count=%ld post_count=%ld "
         "heap_free_ok=%ld free_seq=%ld post_seq=%ld free_before_post=%ld "
         "same_ptr=%ld worker_ref=%ld after_count=%ld after_seq=%ld free_after_epilogue=%ld unsafe=%ld setter_would_uaf=%ld setter_alive=%ld setter_ref=%ld setter_release=%ld\n",
         fallback, calls, frees, posts, heap_ok, free_seq, post_seq,
         unsafe, (g_freed == g_wait) ? 1L : 0L,
         refs, afters, after_seq, (free_seq > after_seq && after_seq > 0) ? 1L : 0L, unsafe, setter_uaf, setter_alive, setter_ref, setter_release);
  fflush(stdout);

  if (fallback != 1 || calls != 1 || frees != 1 || posts != 1 ||
      heap_ok != 1 || unsafe || setter_uaf != 0 || setter_alive != 1 || setter_ref != 1 || setter_release != 1 || refs != 1 || afters != 1 || free_seq <= after_seq || post_seq >= after_seq ||
      g_freed != g_wait) {
    printf("FAIL baseline_instrumentation_or_order\n"); fflush(stdout);
    return 20;
  }
  printf("YY_SETTER_PLUS_WORKER_PIN_PASS -- controlled presignaled registration case only\n");
  fflush(stdout);
  // Do not close the wait twice: Firefox-equivalent callback already closed it.
  CloseHandle(trigger);
  CloseHandle(g_post_event);
  CloseHandle(g_after_event);
  CloseHandle(g_free_event);
  return 0;
}
