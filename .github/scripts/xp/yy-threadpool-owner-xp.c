/* XP SP3 x86 standalone YY 1.2.2 *release* fallback lifecycle smoke.
 * Not the Firefox product. No source instrumentation on release YY.
 * Each launch is ONE scenario; run-xp-owner-lifetime.cmd starts four processes.
 */
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>
#include <string.h>
static volatile LONG cb=0, callback_left=0, close_count=0, dispatch_fail=0, bad=0;
static HANDLE entered,release_cb,request,cleanup_started,closed,trigger,finished;
static PTP_WAIT wait_obj;
static int mode;
static LONG readlong(volatile LONG* p){return InterlockedCompareExchange(p,0,0);}
static void note(const char* s){printf("EVENT %s\n",s);fflush(stdout);}
static DWORD WINAPI deadline(LPVOID unused) {
  (void)unused;
  if(WaitForSingleObject(finished,14000)!=WAIT_OBJECT_0){
    note("WATCHDOG_TIMEOUT");
    TerminateProcess(GetCurrentProcess(),90);
  }
  return 0;
}
static VOID CALLBACK on_wait(PTP_CALLBACK_INSTANCE inst,PVOID context,PTP_WAIT w,TP_WAIT_RESULT result) {
  (void)inst;(void)context;
  InterlockedIncrement(&cb);
  if(w!=wait_obj||result!=WAIT_OBJECT_0)InterlockedExchange(&bad,1);
  if(mode==4){InterlockedIncrement(&dispatch_fail);note("DISPATCH_FAILED_SIMULATED");}
  note("CALLBACK_ENTER");
  SetEvent(entered);
  if(mode==2||mode==4){
    if(WaitForSingleObject(release_cb,7000)!=WAIT_OBJECT_0)InterlockedExchange(&bad,1);
  }
  InterlockedIncrement(&callback_left);
  note("CALLBACK_RETURNING");
  /* NEVER close from callback. Owner cleanup owns the wait and joins off-thread. */
}
static DWORD WINAPI cleanup(LPVOID unused){
  (void)unused;
  if(WaitForSingleObject(request,7000)!=WAIT_OBJECT_0)return 51;
  note("CLEANUP_START");
  SetEvent(cleanup_started);
  SetThreadpoolWait(wait_obj,NULL,NULL);  /* unregister / synchronize callback */
  WaitForThreadpoolWaitCallbacks(wait_obj,TRUE);
  note("CLEANUP_CANCEL_FLUSH_RETURN");
  CloseThreadpoolWait(wait_obj);          /* exactly once, on cleanup thread */
  InterlockedIncrement(&close_count);
  note("CLEANUP_CLOSE_RETURN");
  SetEvent(closed);
  return 0;
}
#define REQUIRE(cond,msg) do{if(!(cond)){printf("FAIL %s gle=%lu\n",msg,GetLastError());fflush(stdout);return 41;}}while(0)
int main(int argc,char** argv) {
  HANDLE th,watchdog;
  DWORD thread_result=77;
  LONG calls,exits,closes,failed,b;
  REQUIRE(argc==2,"mode_arg");
  if(strcmp(argv[1],"l1")==0)mode=1;
  else if(strcmp(argv[1],"l2")==0)mode=2;
  else if(strcmp(argv[1],"l2-pending")==0)mode=3;
  else if(strcmp(argv[1],"l3")==0)mode=4;
  else {printf("FAIL mode_unknown\n");return 42;}
  printf("SCENARIO mode=%s\n",argv[1]);fflush(stdout);
  entered=CreateEventW(NULL,TRUE,FALSE,NULL);
  release_cb=CreateEventW(NULL,TRUE,FALSE,NULL);
  request=CreateEventW(NULL,TRUE,FALSE,NULL);
  cleanup_started=CreateEventW(NULL,TRUE,FALSE,NULL);
  closed=CreateEventW(NULL,TRUE,FALSE,NULL);
  trigger=CreateEventW(NULL,TRUE,FALSE,NULL);
  finished=CreateEventW(NULL,TRUE,FALSE,NULL);
  REQUIRE(entered&&release_cb&&request&&cleanup_started&&closed&&trigger&&finished,"events");
  watchdog=CreateThread(NULL,0,deadline,NULL,0,NULL);
  REQUIRE(watchdog!=NULL,"watchdog");
  wait_obj=CreateThreadpoolWait(on_wait,NULL,NULL);
  REQUIRE(wait_obj!=NULL,"create_YY_wait");
  note("WAIT_CREATED");
  SetThreadpoolWait(wait_obj,trigger,NULL);
  th=CreateThread(NULL,0,cleanup,NULL,0,NULL);
  REQUIRE(th!=NULL,"cleanup_thread");
  if(mode!=3){
    SetEvent(trigger);
    REQUIRE(WaitForSingleObject(entered,5500)==WAIT_OBJECT_0,"callback_enter");
  }
  if(mode==4)note("OWNER_SHUTDOWN_SIMULATED");
  SetEvent(request);
  REQUIRE(WaitForSingleObject(cleanup_started,5500)==WAIT_OBJECT_0,"cleanup_start");
  if(mode==2||mode==4){
    REQUIRE(WaitForSingleObject(closed,220)==WAIT_TIMEOUT,"cleanup_must_wait");
    note("CLEANUP_WAITED_FOR_CALLBACK_BARRIER");
    SetEvent(release_cb);
  }
  REQUIRE(WaitForSingleObject(closed,8500)==WAIT_OBJECT_0,"cleanup_complete");
  REQUIRE(WaitForSingleObject(th,1000)==WAIT_OBJECT_0,"cleanup_thread_exit");
  REQUIRE(GetExitCodeThread(th,&thread_result)&&thread_result==0,"cleanup_thread_code");
  calls=readlong(&cb);exits=readlong(&callback_left);
  closes=readlong(&close_count);failed=readlong(&dispatch_fail);b=readlong(&bad);
  printf("RESULT mode=%s callback_count=%ld callback_left=%ld close_count=%ld failed_dispatch=%ld bad=%ld exit_thread=%lu\n",
    argv[1],calls,exits,closes,failed,b,thread_result);fflush(stdout);
  REQUIRE(closes==1&&b==0,"single_close_and_no_error");
  if(mode==3)REQUIRE(calls==0&&exits==0,"pending_cancel_did_not_dispatch");
  else REQUIRE(calls==1&&exits==1,"exactly_one_callback");
  if(mode==4)REQUIRE(failed==1,"failed_dispatch_mode");
  else REQUIRE(failed==0,"unexpected_dispatch_failure");
  printf("XP_OWNER_LIFETIME_PASS mode=%s\n",argv[1]);fflush(stdout);
  SetEvent(finished);
  REQUIRE(WaitForSingleObject(watchdog,2000)==WAIT_OBJECT_0,"watchdog_join");
  CloseHandle(watchdog);CloseHandle(th);
  CloseHandle(entered);CloseHandle(release_cb);CloseHandle(request);
  CloseHandle(cleanup_started);CloseHandle(closed);CloseHandle(trigger);
  CloseHandle(finished);
  return 0;
}
