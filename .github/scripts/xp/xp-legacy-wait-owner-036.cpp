// xp-web-recycle-036: standalone ownership protocol, NOT Firefox integrated.
#define WINVER 0x0501
#define _WIN32_WINNT 0x0501
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static LONG g_created=0, g_destroyed=0, g_unregisters=0, g_notifies=0;
static LONG g_deadlock=0, g_reentry=0;
static void Log(const char* tag, bool pass) {
  printf("%s=%s\n",tag,pass?"PASS":"FAIL");fflush(stdout);
}
struct Watch {
  volatile LONG refs;
  CRITICAL_SECTION mu;
  HANDLE registration, watched;
  HANDLE entered, go, callbackDone;
  int phase; // 0 arming; 1 armed; 2 completing; 3 cancelling; 4 stopped
  bool claimed, notify, callbackHappened;
  bool reenter, dispatchFailure;
  volatile LONG entryClaim; // 0 unclaimed; 1 callback; 2 cancellation
  Watch():refs(2),registration(NULL),watched(NULL),entered(NULL),go(NULL),
    callbackDone(NULL),phase(0),claimed(false),notify(false),
    callbackHappened(false),reenter(false),dispatchFailure(false),entryClaim(0) {
    InitializeCriticalSection(&mu);InterlockedIncrement(&g_created);
    entered=CreateEventA(NULL,TRUE,FALSE,NULL);
    go=CreateEventA(NULL,TRUE,FALSE,NULL);
    callbackDone=CreateEventA(NULL,TRUE,FALSE,NULL);
  }
  ~Watch() {
    CloseHandle(entered);CloseHandle(go);CloseHandle(callbackDone);
    DeleteCriticalSection(&mu);InterlockedIncrement(&g_destroyed);
  }
  void Release(){if(InterlockedDecrement(&refs)==0)delete this;}
  static void CALLBACK Callback(void* ptr,BOOLEAN) {
    Watch* w=(Watch*)ptr;
    // Registration reference exists before registration and is not surrendered
    // by cancellation until synchronous UnregisterWaitEx returns.
    if(InterlockedCompareExchange(&w->entryClaim,1,0)!=0){
      InterlockedIncrement(&g_deadlock);return;
    }
    EnterCriticalSection(&w->mu);
    bool win=w->phase==1;
    if(win){w->phase=2;w->claimed=true;w->callbackHappened=true;}
    LeaveCriticalSection(&w->mu);
    SetEvent(w->entered);
    WaitForSingleObject(w->go,INFINITE);
    if(win){
      // Callback alone owns registration; never perform blocking unregister here.
      SetLastError(0);
      BOOL rc=UnregisterWaitEx(w->registration,NULL);
      DWORD err=GetLastError();
      if(!rc && err!=ERROR_IO_PENDING)InterlockedIncrement(&g_deadlock);
      InterlockedIncrement(&g_unregisters);
      // All potentially reentrant dispatch/destructor work occurs outside mu.
      if(w->dispatchFailure && w->reenter){
        InterlockedIncrement(&g_reentry);
        EnterCriticalSection(&w->mu);
        bool completed=w->phase==2;
        LeaveCriticalSection(&w->mu);
        if(!completed)InterlockedIncrement(&g_deadlock);
      }else InterlockedIncrement(&g_notifies);
      EnterCriticalSection(&w->mu);w->phase=4;LeaveCriticalSection(&w->mu);
    }
    SetEvent(w->callbackDone);
    w->Release(); // release callback-registration reference
  }
  bool Arm(HANDLE h) {
    if(!entered||!go||!callbackDone)return false;
    EnterCriticalSection(&mu);
    watched=h;
    BOOL ok=RegisterWaitForSingleObject(&registration,h,Callback,this,INFINITE,WT_EXECUTEONLYONCE);
    phase=ok?1:4;
    LeaveCriticalSection(&mu);
    if(!ok)Release(); // no callback may run on registration failure
    return !!ok;
  }
  bool Stop() {
    EnterCriticalSection(&mu);
    bool owner=phase==1;
    if(owner){phase=3;claimed=true;}
    LeaveCriticalSection(&mu);
    if(owner){
      BOOL ok=UnregisterWaitEx(registration,INVALID_HANDLE_VALUE);
      DWORD error=GetLastError();
      InterlockedIncrement(&g_unregisters);
      if(!ok && error!=ERROR_IO_PENDING)InterlockedIncrement(&g_deadlock);
      // No new callback can start after synchronous successful cancellation.
      if(InterlockedCompareExchange(&entryClaim,2,0)==0)Release();
      EnterCriticalSection(&mu);phase=4;LeaveCriticalSection(&mu);
      return !!ok;
    }
    return true;
  }
};
struct ThreadStopArgs {Watch* w;HANDLE finished;bool ok;};
static DWORD WINAPI StopThread(void* arg){
  ThreadStopArgs* a=(ThreadStopArgs*)arg;
  a->ok=a->w->Stop();
  SetEvent(a->finished);return 0;
}
static bool Test(const char* which){
  const bool presignaled=!strcmp(which,"presignaled");
  const bool cancelPending=!strcmp(which,"cancel-pending");
  const bool cancelRunning=!strcmp(which,"cancel-running");
  const bool completion=!strcmp(which,"completion");
  const bool reentry=!strcmp(which,"dispatch-reentry");
  if(!presignaled&&!cancelPending&&!cancelRunning&&!completion&&!reentry)return false;
  HANDLE watched=CreateEventA(NULL,TRUE,FALSE,NULL);
  if(!watched)return false;
  Watch* w=new Watch;
  if(reentry){w->dispatchFailure=true;w->reenter=true;}
  if(presignaled)SetEvent(watched);
  bool ok=w->Arm(watched);
  ThreadStopArgs args={w,CreateEventA(NULL,TRUE,FALSE,NULL),false};
  HANDLE stopper=NULL;
  if(cancelPending){
    ok=ok&&w->Stop();
    SetEvent(watched);
    ok=ok&&WaitForSingleObject(w->entered,100)==WAIT_TIMEOUT;
  }else{
    if(!presignaled)SetEvent(watched);
    ok=ok&&WaitForSingleObject(w->entered,5000)==WAIT_OBJECT_0;
    if(cancelRunning){
      // callback has claimed before the stop attempt; Stop must not self-wait
      // and callback wins. An alternative pre-entry cancellation is cancel-pending.
      stopper=CreateThread(NULL,0,StopThread,&args,0,NULL);
      ok=ok&&stopper&&WaitForSingleObject(args.finished,5000)==WAIT_OBJECT_0;
    }
    SetEvent(w->go);
    ok=ok&&WaitForSingleObject(w->callbackDone,5000)==WAIT_OBJECT_0;
    ok=ok&&w->Stop();
  }
  if(stopper){WaitForSingleObject(stopper,5000);CloseHandle(stopper);}
  CloseHandle(args.finished);
  w->Release(); // outer owner
  CloseHandle(watched);
  for(int spin=0;spin<200 && g_created!=g_destroyed;++spin)Sleep(10);\n  ok=ok && g_created==g_destroyed && g_unregisters==1 && g_deadlock==0;
  if(reentry)ok=ok&&g_reentry==1;
  if(cancelPending)ok=ok&&g_notifies==0;
  if(completion)ok=ok&&g_notifies==1;
  printf("scenario=%s created=%ld destroyed=%ld unregisters=%ld notified=%ld reentry=%ld errors=%ld\n",
    which,g_created,g_destroyed,g_unregisters,g_notifies,g_reentry,g_deadlock);
  Log("ownership_gate",ok);
  return ok;
}
int main(int argc,char** argv) {
  if(argc!=2)return 2;
  return Test(argv[1])?0:1;
}
