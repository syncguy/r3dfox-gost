// Controlled NEGATIVE test only: YY-Thunks 1.2.2 setter+worker pins do not
// protect worker entry from external CloseThreadpoolWait BEFORE worker AddRef.
// No actual freed pointer is ever dereferenced: YY temporary source returns
// at a test-only guard placed BEFORE worker AddRef.
// Not Firefox, not an XP release artifact, not a production remediation.
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>

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
static volatile LONG g_seq=0, g_fallback=0, g_actual_free=0, g_free_ok=0;
static volatile LONG g_worker_entry=0, g_worker_ref=0, g_user_cb=0, g_unsafe_window=0;
static volatile LONG g_setter_ref=0, g_setter_release=0, g_error=0;
static PTP_WAIT g_wait=nullptr;
static void* g_freed=nullptr;
static HANDLE g_worker_entered=nullptr,g_worker_continue=nullptr,g_worker_done=nullptr;
static HANDLE g_free_event=nullptr;
static LONG Value(volatile LONG* p){return InterlockedCompareExchange(p,0,0);}
static LONG Seq(){return InterlockedIncrement(&g_seq);}
static void EventNote(const char* kind,void* ptr,LONG seq){
  printf("EVENT seq=%ld kind=%s ptr=%p\n",seq,kind,ptr);
  fflush(stdout);
}
extern "C" void __cdecl XP_L1_FallbackSelected(void){
  InterlockedIncrement(&g_fallback); EventNote("yy_fallback_create",nullptr,Seq());
}
extern "C" void __cdecl XP_L1_FreeObserved(void* ptr,int ok){
  LONG seq=Seq();
  g_freed=ptr;
  InterlockedIncrement(&g_actual_free);
  InterlockedExchange(&g_free_ok,ok?1:0);
  EventNote(ok?"actual_heap_free":"heap_free_failed",ptr,seq);
  SetEvent(g_free_event);
}
extern "C" void __cdecl XP_SET_Hold(void* ptr){
  InterlockedIncrement(&g_setter_ref); EventNote("setter_scope_ref_acquired",ptr,Seq());
}
extern "C" void __cdecl XP_SET_BeforeRelease(void* ptr){
  InterlockedIncrement(&g_setter_release); EventNote("setter_scope_before_release",ptr,Seq());
}
extern "C" void __cdecl XP_REF_Hold(void* ptr){
  InterlockedIncrement(&g_worker_ref); EventNote("unexpected_worker_ref",ptr,Seq());
}
// This hook is inside YY's registered worker, BEFORE any dereference/AddRef
// of the pointer passed by RegisterWaitForSingleObject. Control thread:
// 1) waits until this hook is entered;
// 2) calls YY_Thunks_CloseThreadpoolWait externally;
// 3) waits for REAL heap-free observation;
// 4) allows hook to exit. The unsafe dereference is NEVER performed.
extern "C" int __cdecl XP_EXT_BeforeWorkerAddRef(void* ptr){
  InterlockedIncrement(&g_worker_entry);
  EventNote("worker_before_AddRef_barrier",ptr,Seq());
  SetEvent(g_worker_entered);
  DWORD rc=WaitForSingleObject(g_worker_continue,7000);
  if(rc!=WAIT_OBJECT_0){
    InterlockedExchange(&g_error,1);
    EventNote("worker_barrier_timeout",ptr,Seq());
    SetEvent(g_worker_done); return 1;
  }
  if(Value(&g_actual_free)==1 && g_freed==ptr){
    InterlockedExchange(&g_unsafe_window,1);
    EventNote("would_AddRef_freed_wait_TEST_GUARD",ptr,Seq());
  } else {
    InterlockedExchange(&g_error,1);
    EventNote("external_close_did_not_free_wait",ptr,Seq());
  }
  SetEvent(g_worker_done);
  return 1;  // IMPORTANT: always skip actual freed-pointer AddRef, callback, YY epilogue.
}
static VOID CALLBACK ShouldNeverRun(PTP_CALLBACK_INSTANCE,PVOID,PTP_WAIT,TP_WAIT_RESULT){
  InterlockedIncrement(&g_user_cb);
  EventNote("UNEXPECTED_USER_CALLBACK",g_wait,Seq());
}
#define ENSURE(test,name) do {if(!(test)){printf("FAIL %s gle=%lu\n",name,GetLastError());fflush(stdout);return 20;}}while(0)
int main(){
  YY::Thunks::aways_null_try_get_CreateThreadpoolWait=true;
  YY::Thunks::aways_null_try_get_SetThreadpoolWait=true;
  YY::Thunks::aways_null_try_get_WaitForThreadpoolWaitCallbacks=true;
  YY::Thunks::aways_null_try_get_CloseThreadpoolWait=true;
  g_worker_entered=CreateEventW(nullptr,TRUE,FALSE,nullptr);
  g_worker_continue=CreateEventW(nullptr,TRUE,FALSE,nullptr);
  g_worker_done=CreateEventW(nullptr,TRUE,FALSE,nullptr);
  g_free_event=CreateEventW(nullptr,TRUE,FALSE,nullptr);
  HANDLE trigger=CreateEventW(nullptr,TRUE,FALSE,nullptr);
  ENSURE(g_worker_entered&&g_worker_continue&&g_worker_done&&g_free_event&&trigger,"events");
  g_wait=YY_Thunks_CreateThreadpoolWait(&ShouldNeverRun,nullptr,nullptr);
  ENSURE(g_wait!=nullptr,"create_wait");
  EventNote("wait_created",g_wait,Seq());
  // Initial HANDLE is NOT signaled: setter completes, releases its scope pin.
  YY_Thunks_SetThreadpoolWait(g_wait,trigger,nullptr);
  ENSURE(Value(&g_setter_ref)==1&&Value(&g_setter_release)==1,"setter_scope_exited");
  EventNote("setter_finished_before_signal",g_wait,Seq());
  SetEvent(trigger);
  ENSURE(WaitForSingleObject(g_worker_entered,5000)==WAIT_OBJECT_0,"worker_entry");
  EventNote("external_CloseThreadpoolWait_begin",g_wait,Seq());
  YY_Thunks_CloseThreadpoolWait(g_wait);
  EventNote("external_CloseThreadpoolWait_returned",g_wait,Seq());
  DWORD free_rc=WaitForSingleObject(g_free_event,5000);
  // Resume worker even on failure: it must never be left parked.
  EventNote(free_rc==WAIT_OBJECT_0?"external_close_freed_before_AddRef":"external_close_free_not_observed",g_wait,Seq());
  SetEvent(g_worker_continue);
  ENSURE(WaitForSingleObject(g_worker_done,5000)==WAIT_OBJECT_0,"worker_done");
  LONG freed=Value(&g_actual_free),windows=Value(&g_unsafe_window),entered=Value(&g_worker_entry);
  LONG setter=Value(&g_setter_ref),setter_done=Value(&g_setter_release),work_ref=Value(&g_worker_ref);
  LONG calls=Value(&g_user_cb),ok=Value(&g_free_ok),err=Value(&g_error);
  printf("RESULT fallback=%ld entered=%ld external_close_free_count=%ld heap_free_ok=%ld same_ptr=%ld setter_ref=%ld setter_release=%ld worker_ref=%ld user_callback=%ld unsafe_before_AddRef=%ld errors=%ld\n",
    Value(&g_fallback),entered,freed,ok,g_freed==g_wait?1L:0L,
    setter,setter_done,work_ref,calls,windows,err);
  fflush(stdout);
  if(Value(&g_fallback)!=1||entered!=1||freed!=1||ok!=1||g_freed!=g_wait||
     setter!=1||setter_done!=1||work_ref!=0||calls!=0||windows!=1||err!=0){
     printf("FAIL external_close_pre_AddRef_control_not_reproduced\n");fflush(stdout);
     return 21;
  }
  printf("EXPECTED_EXTERNAL_CLOSE_PRE_ADDREF_UAF_WINDOW_REPRODUCED (negative control, NOT safety PASS)\n");
  fflush(stdout);
  CloseHandle(trigger); CloseHandle(g_worker_entered);CloseHandle(g_worker_continue);
  CloseHandle(g_worker_done); CloseHandle(g_free_event);
  return 0;
}
