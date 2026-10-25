// Independent test-only owner model; NOT Firefox source or an accepted product fix.
// Built with pinned YY-Thunks v1.2.2 __YY_Thunks_Unit_Test forced fallback.
// Modes: l1 (deferred cleanup), l2 (running callback), l2-pending, l3 (failed dispatch + shutdown).
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>
#include <string.h>

// Upstream YY Build.cmd FixObj default slots, only for standalone test object.
extern "C" {
  BOOL __YY_Thunks_Disable_Rreload_Dlls = FALSE;
  extern HMODULE (__fastcall * const __pfnYY_Thunks_CustomLoadLibrary)(const wchar_t*, DWORD) = nullptr;
  void* __acrt_atexit_table = nullptr;
  extern void* const __pfnDllMainCRTStartupForYY_Thunks = nullptr;
}
extern "C" PTP_WAIT WINAPI YY_Thunks_CreateThreadpoolWait(PTP_WAIT_CALLBACK, PVOID, PTP_CALLBACK_ENVIRON);
extern "C" VOID WINAPI YY_Thunks_SetThreadpoolWait(PTP_WAIT, HANDLE, PFILETIME);
extern "C" VOID WINAPI YY_Thunks_WaitForThreadpoolWaitCallbacks(PTP_WAIT, BOOL);
extern "C" VOID WINAPI YY_Thunks_CloseThreadpoolWait(PTP_WAIT);

namespace YY { namespace Thunks {
  extern bool aways_null_try_get_CreateThreadpoolWait;
  extern bool aways_null_try_get_SetThreadpoolWait;
  extern bool aways_null_try_get_WaitForThreadpoolWaitCallbacks;
  extern bool aways_null_try_get_CloseThreadpoolWait;
}}

static volatile LONG g_seq=0, g_fallback=0, g_cb=0, g_post=0, g_after=0;
static volatile LONG g_free=0, g_free_ok=0, g_free_seq=0, g_post_seq=0, g_after_seq=0;
static volatile LONG g_bad=0, g_dispatch_failed=0, g_shutdown=0, g_close_count=0;
static volatile LONG g_callback_left=0, g_callback_enter_seq=0, g_close_done_seq=0, g_close_start_seq=0;
static volatile LONG g_cancel_end_seq=0;
static PTP_WAIT g_wait=nullptr;
static void* g_freed=nullptr;
static HANDLE g_entered=nullptr, g_release=nullptr, g_request=nullptr, g_cleanup_started=nullptr;
static HANDLE g_closed=nullptr, g_after_event=nullptr, g_trigger=nullptr;
static int g_mode=0; // 1=l1; 2=l2; 3=l2-pending; 4=l3

static LONG Next() { return InterlockedIncrement(&g_seq); }
static void Note(const char* kind, void* ptr, LONG seq) {
  printf("EVENT seq=%ld kind=%s ptr=%p\n",seq,kind,ptr); fflush(stdout);
}
static LONG Read(volatile LONG* p) { return InterlockedCompareExchange(p,0,0); }
static void Fail(const char* msg) {
  InterlockedExchange(&g_bad,1);
  Note(msg,g_wait,Next());
}

extern "C" void __cdecl XP_L1_FallbackSelected(void) {
  InterlockedIncrement(&g_fallback);
  Note("yy_fallback_create",nullptr,Next());
}
extern "C" void __cdecl XP_L1_FreeObserved(void* ptr,int ok) {
  LONG seq=Next();
  g_freed=ptr;
  InterlockedExchange(&g_free_seq,seq);
  InterlockedExchange(&g_free_ok,ok ? 1 : 0);
  InterlockedIncrement(&g_free);
  Note(ok ? "actual_heap_free" : "heap_free_failed",ptr,seq);
}
// Called before YY's original post-callback SetEvent(Wait->hEvent).
// Return 1 ONLY on already-freed object: test-only circuit breaker against UAF.
extern "C" int __cdecl XP_L1_PostCallback(void* ptr) {
  LONG seq=Next();
  InterlockedExchange(&g_post_seq,seq);
  InterlockedIncrement(&g_post);
  Note("yy_after_callback_before_access",ptr,seq);
  if (Read(&g_free)!=0 && g_freed==ptr) {
    Fail("would_dereference_freed_wait");
    return 1;
  }
  return 0;
}
// Called after the REAL YY SetEvent(Wait->hEvent) has executed.
extern "C" void __cdecl XP_L1_AfterEvent(void* ptr) {
  LONG seq=Next();
  InterlockedExchange(&g_after_seq,seq);
  InterlockedIncrement(&g_after);
  Note("yy_after_real_epilogue_event",ptr,seq);
  SetEvent(g_after_event);
}

static VOID CALLBACK OnWait(PTP_CALLBACK_INSTANCE,PVOID,PTP_WAIT wait,TP_WAIT_RESULT result) {
  InterlockedIncrement(&g_cb);
  InterlockedExchange(&g_callback_enter_seq,Next());
  Note("owner_callback_enter",wait,Read(&g_callback_enter_seq));
  if (wait!=g_wait || result!=WAIT_OBJECT_0) Fail("callback_identity_or_result_mismatch");
  if (g_mode==4) {
    InterlockedIncrement(&g_dispatch_failed);
    Note("dispatch_failure_simulated",wait,Next());
  } else {
    Note("dispatch_success_simulated",wait,Next());
  }
  SetEvent(g_entered);
  if (g_mode==2 || g_mode==4) {
    if (WaitForSingleObject(g_release,6000)!=WAIT_OBJECT_0) Fail("callback_barrier_timeout");
  }
  InterlockedIncrement(&g_callback_left);
  Note("owner_callback_returning",wait,Next());
  // No close here; ownership transferred to independent cleanup thread.
}

static DWORD WINAPI CleanupThread(LPVOID) {
  if (WaitForSingleObject(g_request,6000)!=WAIT_OBJECT_0) {
    Fail("cleanup_request_timeout"); return 31;
  }
  InterlockedExchange(&g_close_start_seq,Next());
  Note("cleanup_start",g_wait,Read(&g_close_start_seq));
  SetEvent(g_cleanup_started);
  // Crucial: this thread, not YY's callback, waits in UnregisterWaitEx.
  YY_Thunks_SetThreadpoolWait(g_wait,nullptr,nullptr);
  YY_Thunks_WaitForThreadpoolWaitCallbacks(g_wait,TRUE);
  InterlockedExchange(&g_cancel_end_seq,Next());
  Note("cleanup_cancel_flush_return",g_wait,Read(&g_cancel_end_seq));
  YY_Thunks_CloseThreadpoolWait(g_wait);
  InterlockedIncrement(&g_close_count);
  InterlockedExchange(&g_close_done_seq,Next());
  Note("cleanup_close_return",g_wait,Read(&g_close_done_seq));
  SetEvent(g_closed);
  return 0;
}
static HANDLE Event() { return CreateEventW(nullptr,TRUE,FALSE,nullptr); }
#define ENSURE(pred, label) do { if (!(pred)) { printf("FAIL %s err=%lu\n",label,GetLastError()); fflush(stdout); return 30; } } while(0)

int main(int argc,char** argv) {
  ENSURE(argc==2,"scenario_arg");
  if (!strcmp(argv[1],"l1")) g_mode=1;
  else if (!strcmp(argv[1],"l2")) g_mode=2;
  else if (!strcmp(argv[1],"l2-pending")) g_mode=3;
  else if (!strcmp(argv[1],"l3")) g_mode=4;
  else { printf("FAIL unsupported_scenario\n"); return 9; }
  printf("SCENARIO mode=%s\n",argv[1]); fflush(stdout);

  YY::Thunks::aways_null_try_get_CreateThreadpoolWait=true;
  YY::Thunks::aways_null_try_get_SetThreadpoolWait=true;
  YY::Thunks::aways_null_try_get_WaitForThreadpoolWaitCallbacks=true;
  YY::Thunks::aways_null_try_get_CloseThreadpoolWait=true;
  g_entered=Event(); g_release=Event(); g_request=Event();
  g_cleanup_started=Event(); g_closed=Event(); g_after_event=Event(); g_trigger=Event();
  ENSURE(g_entered && g_release && g_request && g_cleanup_started &&
         g_closed && g_after_event && g_trigger,"events");
  g_wait=YY_Thunks_CreateThreadpoolWait(&OnWait,nullptr,nullptr);
  ENSURE(g_wait!=nullptr,"create_wait");
  printf("EVENT wait_created ptr=%p\n",g_wait); fflush(stdout);
  YY_Thunks_SetThreadpoolWait(g_wait,g_trigger,nullptr);
  HANDLE worker=CreateThread(nullptr,0,&CleanupThread,nullptr,0,nullptr);
  ENSURE(worker!=nullptr,"cleanup_thread");

  if (g_mode!=3) {
    SetEvent(g_trigger);
    ENSURE(WaitForSingleObject(g_entered,5000)==WAIT_OBJECT_0,"callback_entered");
  }
  if (g_mode==4) {
    InterlockedIncrement(&g_shutdown);
    Note("owner_shutdown_start",g_wait,Next());
  }
  SetEvent(g_request);
  ENSURE(WaitForSingleObject(g_cleanup_started,5000)==WAIT_OBJECT_0,"cleanup_started");
  if (g_mode==2 || g_mode==4) {
    DWORD early=WaitForSingleObject(g_closed,220);
    ENSURE(early==WAIT_TIMEOUT,"cleanup_must_wait_for_callback_barrier");
    Note("barrier_proved_cleanup_blocked",g_wait,Next());
    SetEvent(g_release);
  }
  ENSURE(WaitForSingleObject(g_closed,6000)==WAIT_OBJECT_0,"cleanup_complete");
  ENSURE(WaitForSingleObject(worker,1000)==WAIT_OBJECT_0,"cleanup_thread_exit");
  DWORD thread_code=999;
  ENSURE(GetExitCodeThread(worker,&thread_code) && thread_code==0,"cleanup_thread_status");
  if(g_mode!=3) {
    ENSURE(WaitForSingleObject(g_after_event,1000)==WAIT_OBJECT_0,"yy_after_event");
  }
  // No cleanup before YY worker has completed its actual SetEvent. No free
  // inside the user callback. Release occurs only once on the same pointer.
  LONG fallback=Read(&g_fallback), cb=Read(&g_cb),post=Read(&g_post),after=Read(&g_after);
  LONG frees=Read(&g_free),free_seq=Read(&g_free_seq),after_seq=Read(&g_after_seq);
  LONG bad=Read(&g_bad),close=Read(&g_close_count), close_seq=Read(&g_close_done_seq);
  LONG dispatch_fail=Read(&g_dispatch_failed),shutdown=Read(&g_shutdown);
  LONG cancel_seq=Read(&g_cancel_end_seq);
  int safe = fallback==1 && frees==1 && Read(&g_free_ok)==1 &&
             close==1 && bad==0 && g_freed==g_wait &&
             free_seq>0 && close_seq>free_seq && cancel_seq>0 && free_seq>cancel_seq;
  if(g_mode==3) {
    safe = safe && cb==0 && post==0 && after==0;
  } else {
    safe = safe && cb==1 && post==1 && after==1 &&
           after_seq>0 && free_seq>after_seq && Read(&g_callback_left)==1;
  }
  if(g_mode==4) safe = safe && dispatch_fail==1 && shutdown==1;
  else safe = safe && dispatch_fail==0 && shutdown==0;
  printf("RESULT mode=%s fallback=%ld callback_count=%ld post_count=%ld after_count=%ld free_count=%ld heap_free_ok=%ld free_after_epilogue=%d same_ptr=%d close_count=%ld unsafe=%ld failed_dispatch=%ld shutdown=%ld free_seq=%ld after_seq=%ld cancel_seq=%ld\n",
    argv[1],fallback,cb,post,after,frees,Read(&g_free_ok),
    (after_seq>0 && free_seq>after_seq)?1:0,g_freed==g_wait?1:0,close,bad,dispatch_fail,shutdown,
    free_seq,after_seq,cancel_seq); fflush(stdout);
  if(!safe) { printf("FAIL candidate_lifetime_gate\n"); fflush(stdout); return 40; }
  printf("SAFE_OWNER_MODEL_PASS mode=%s (hosted forced fallback only; NOT Firefox fix)\n",argv[1]);
  fflush(stdout);
  CloseHandle(worker);
  CloseHandle(g_trigger); CloseHandle(g_entered); CloseHandle(g_release);
  CloseHandle(g_request); CloseHandle(g_cleanup_started);
  CloseHandle(g_closed); CloseHandle(g_after_event);
  return 0;
}
