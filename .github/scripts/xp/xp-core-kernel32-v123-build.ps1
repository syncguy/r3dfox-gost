param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('compile', 'link')]
    [string]$Stage
)

switch ($Stage) {
    'compile' {
$ErrorActionPreference='Stop'
@'
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>
#include "capability.h"
static int failures=0;
#define PASS(x) printf(#x ": PASS\n")
#define FAIL(x) do{printf(#x ": FAIL err=%lu\n",GetLastError());++failures;}while(0)
#define SKIP(x) printf(#x ": SKIP (YY capability missing)\n")
#if HAVE_CreateWaitableTimerExW
static BOOL timer_w(){HANDLE h=CreateWaitableTimerExW(0,0,0,TIMER_ALL_ACCESS);if(!h)return FALSE;LARGE_INTEGER d;d.QuadPart=-100000LL;BOOL ok=SetWaitableTimer(h,&d,0,0,0,FALSE);DWORD w=ok?WaitForSingleObject(h,2000):WAIT_FAILED;CloseHandle(h);return ok&&w==WAIT_OBJECT_0;}
#endif
int main(){
#if HAVE_CreateWaitableTimerExA
  HANDLE ta=CreateWaitableTimerExA(0,0,0,TIMER_ALL_ACCESS); if(!ta) FAIL(CreateWaitableTimerExA); else {LARGE_INTEGER d;d.QuadPart=-100000LL;BOOL ok=SetWaitableTimer(ta,&d,0,0,0,FALSE);DWORD w=ok?WaitForSingleObject(ta,2000):WAIT_FAILED;CloseHandle(ta);if(ok&&w==WAIT_OBJECT_0)PASS(CreateWaitableTimerExA);else FAIL(CreateWaitableTimerExA);}
#else
  SKIP(CreateWaitableTimerExA);
#endif
#if HAVE_GetTickCount64
  (void)GetTickCount64(); PASS(GetTickCount64);
#else
  SKIP(GetTickCount64);
#endif
#if HAVE_InitializeCriticalSectionEx
  {CRITICAL_SECTION cs;if(InitializeCriticalSectionEx(&cs,0,0)){EnterCriticalSection(&cs);LeaveCriticalSection(&cs);DeleteCriticalSection(&cs);PASS(InitializeCriticalSectionEx);}else FAIL(InitializeCriticalSectionEx);}
#else
  SKIP(InitializeCriticalSectionEx);
#endif
#if HAVE_CompareStringOrdinal
  if(CompareStringOrdinal(L"abc",3,L"abc",3,TRUE)==CSTR_EQUAL)PASS(CompareStringOrdinal);else FAIL(CompareStringOrdinal);
#else
  SKIP(CompareStringOrdinal);
#endif
#if HAVE_GetCurrentProcessorNumber
  (void)GetCurrentProcessorNumber();PASS(GetCurrentProcessorNumber);
#else
  SKIP(GetCurrentProcessorNumber);
#endif
  WCHAR p[MAX_PATH];DWORD n=GetTempPathW(MAX_PATH,p);const WCHAR s[]=L"r3dfox-yy-cluster.tmp";DWORD i=n;for(DWORD j=0;s[j]&&i+1<MAX_PATH;++j)p[i++]=s[j];p[i]=0;HANDLE f=CreateFileW(p,GENERIC_READ|GENERIC_WRITE|FILE_WRITE_ATTRIBUTES,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL|FILE_FLAG_DELETE_ON_CLOSE,0);
  if(f==INVALID_HANDLE_VALUE){printf("control-temp-file: FAIL\n");++failures;}else{
#if HAVE_GetFileInformationByHandleEx
    FILE_BASIC_INFO bi;if(GetFileInformationByHandleEx(f,FileBasicInfo,&bi,sizeof(bi)))PASS(GetFileInformationByHandleEx);else FAIL(GetFileInformationByHandleEx);
#else
    SKIP(GetFileInformationByHandleEx);
#endif
#if HAVE_SetFileInformationByHandle && HAVE_GetFileInformationByHandleEx
    if(SetFileInformationByHandle(f,FileBasicInfo,&bi,sizeof(bi)))PASS(SetFileInformationByHandle);else FAIL(SetFileInformationByHandle);
#elif HAVE_SetFileInformationByHandle
    printf("SetFileInformationByHandle: SKIP (safe setup capability missing)\n");
#else
    SKIP(SetFileInformationByHandle);
#endif
#if HAVE_GetFinalPathNameByHandleW
    {WCHAR q[512];DWORD z=GetFinalPathNameByHandleW(f,q,512,FILE_NAME_NORMALIZED);if(z>0&&z<512)PASS(GetFinalPathNameByHandleW);else FAIL(GetFinalPathNameByHandleW);}
#else
    SKIP(GetFinalPathNameByHandleW);
#endif
#if HAVE_CancelIoEx
    SetLastError(ERROR_SUCCESS);if(CancelIoEx(f,0)||GetLastError()==ERROR_NOT_FOUND)PASS(CancelIoEx);else FAIL(CancelIoEx);
#else
    SKIP(CancelIoEx);
#endif
    CloseHandle(f);
  }
  WCHAR ln[LOCALE_NAME_MAX_LENGTH]={L'e',L'n',L'-',L'U',L'S',0};
#if HAVE_LCIDToLocaleName
  if(LCIDToLocaleName(GetUserDefaultLCID(),ln,LOCALE_NAME_MAX_LENGTH,0)>0)PASS(LCIDToLocaleName);else FAIL(LCIDToLocaleName);
#else
  SKIP(LCIDToLocaleName);
#endif
#if HAVE_LocaleNameToLCID
  if(LocaleNameToLCID(ln,0))PASS(LocaleNameToLCID);else FAIL(LocaleNameToLCID);
#else
  SKIP(LocaleNameToLCID);
#endif
#if HAVE_GetLocaleInfoEx
  {WCHAR v[128];if(GetLocaleInfoEx(ln,LOCALE_SLANGUAGE,v,128)>0)PASS(GetLocaleInfoEx);else FAIL(GetLocaleInfoEx);}
#else
  SKIP(GetLocaleInfoEx);
#endif
#if HAVE_CreateWaitableTimerExW
  if(timer_w())PASS(CreateWaitableTimerExW);else FAIL(CreateWaitableTimerExW);
#else
  SKIP(CreateWaitableTimerExW);
#endif
#if HAVE_CancelSynchronousIo
  SetLastError(ERROR_SUCCESS);if(CancelSynchronousIo(GetCurrentThread())||GetLastError()==ERROR_NOT_FOUND)PASS(CancelSynchronousIo);else FAIL(CancelSynchronousIo);
#else
  SKIP(CancelSynchronousIo);
#endif
#if HAVE_GetDynamicTimeZoneInformation
  {DYNAMIC_TIME_ZONE_INFORMATION z;if(GetDynamicTimeZoneInformation(&z)!=TIME_ZONE_ID_INVALID)PASS(GetDynamicTimeZoneInformation);else FAIL(GetDynamicTimeZoneInformation);}
#else
  SKIP(GetDynamicTimeZoneInformation);
#endif
#if HAVE_GetProcessIdOfThread
  if(GetProcessIdOfThread(GetCurrentThread())==GetCurrentProcessId())PASS(GetProcessIdOfThread);else FAIL(GetProcessIdOfThread);
#else
  SKIP(GetProcessIdOfThread);
#endif
#if HAVE_GetQueuedCompletionStatusEx
  {HANDLE cp=CreateIoCompletionPort(INVALID_HANDLE_VALUE,0,0,1);OVERLAPPED_ENTRY e;ULONG r=0;SetLastError(0);BOOL ok=cp?GetQueuedCompletionStatusEx(cp,&e,1,&r,0,FALSE):FALSE;DWORD er=GetLastError();if(cp)CloseHandle(cp);if((!ok&&er==WAIT_TIMEOUT)||(ok&&r==0))PASS(GetQueuedCompletionStatusEx);else FAIL(GetQueuedCompletionStatusEx);}
#else
  SKIP(GetQueuedCompletionStatusEx);
#endif
#if HAVE_GetThreadId
  if(GetThreadId(GetCurrentThread())==GetCurrentThreadId())PASS(GetThreadId);else FAIL(GetThreadId);
#else
  SKIP(GetThreadId);
#endif
#if HAVE_GetThreadPreferredUILanguages
  {ULONG c=0,ch=0;if(GetThreadPreferredUILanguages(MUI_LANGUAGE_NAME,&c,0,&ch)&&ch>0)PASS(GetThreadPreferredUILanguages);else FAIL(GetThreadPreferredUILanguages);}
#else
  SKIP(GetThreadPreferredUILanguages);
#endif
#if HAVE_GetProcessPreferredUILanguages
  {ULONG c=0,ch=0;if(GetProcessPreferredUILanguages(MUI_LANGUAGE_NAME,&c,0,&ch)&&ch>0)PASS(GetProcessPreferredUILanguages);else FAIL(GetProcessPreferredUILanguages);}
#else
  SKIP(GetProcessPreferredUILanguages);
#endif
#if HAVE_GetUserPreferredUILanguages
  {ULONG c=0,ch=0;if(GetUserPreferredUILanguages(MUI_LANGUAGE_NAME,&c,0,&ch)&&ch>0)PASS(GetUserPreferredUILanguages);else FAIL(GetUserPreferredUILanguages);}
#else
  SKIP(GetUserPreferredUILanguages);
#endif
#if HAVE_InitOnceBeginInitialize && HAVE_InitOnceComplete
  {INIT_ONCE o=INIT_ONCE_STATIC_INIT;BOOL pending=FALSE;PVOID ctx=0;if(InitOnceBeginInitialize(&o,0,&pending,&ctx)&&pending){PASS(InitOnceBeginInitialize);if(InitOnceComplete(&o,0,0))PASS(InitOnceComplete);else FAIL(InitOnceComplete);}else{FAIL(InitOnceBeginInitialize);FAIL(InitOnceComplete);}}
#else
  printf("InitOnceBeginInitialize: SKIP (paired capability missing)\n");printf("InitOnceComplete: SKIP (paired capability missing)\n");
#endif
#if HAVE_QueryFullProcessImageNameW
  {WCHAR q[512];DWORD z=512;if(QueryFullProcessImageNameW(GetCurrentProcess(),0,q,&z)&&z)PASS(QueryFullProcessImageNameW);else FAIL(QueryFullProcessImageNameW);}
#else
  SKIP(QueryFullProcessImageNameW);
#endif
#if HAVE_QueryProcessCycleTime
  {ULONG64 c=0;if(QueryProcessCycleTime(GetCurrentProcess(),&c))PASS(QueryProcessCycleTime);else FAIL(QueryProcessCycleTime);}
#else
  SKIP(QueryProcessCycleTime);
#endif
#if HAVE_QueryThreadCycleTime
  {ULONG64 c=0;if(QueryThreadCycleTime(GetCurrentThread(),&c))PASS(QueryThreadCycleTime);else FAIL(QueryThreadCycleTime);}
#else
  SKIP(QueryThreadCycleTime);
#endif
#if HAVE_GetTimeZoneInformationForYear && HAVE_GetDynamicTimeZoneInformation
  {SYSTEMTIME st;GetSystemTime(&st);DYNAMIC_TIME_ZONE_INFORMATION dz;TIME_ZONE_INFORMATION tz;if(GetDynamicTimeZoneInformation(&dz)!=TIME_ZONE_ID_INVALID&&GetTimeZoneInformationForYear(st.wYear,&dz,&tz))PASS(GetTimeZoneInformationForYear);else FAIL(GetTimeZoneInformationForYear);}
#else
  printf("GetTimeZoneInformationForYear: SKIP (setup capability missing)\n");
#endif
  printf("Overall: %s\n",failures?"FAIL":"PASS");printf("ExitCode=%d\n",failures?1:0);return failures?1:0;
}
'@ | Set-Content -Encoding ascii probe.cpp
& cl.exe /nologo /c /MD /O2 /GS- /EHsc- /GR- /D_WIN32_WINNT=0x0601 probe.cpp /Foprobe.obj 2>&1 | Tee-Object diagnostics\probe-compile.log
if($LASTEXITCODE-ne 0){throw 'probe compile failed'}
(& dumpbin.exe /nologo /symbols probe.obj 2>&1) | Set-Content -Encoding utf8 diagnostics\probe-object-symbols.txt
    }
    'link' {
$ErrorActionPreference='Stop'
$lld=(Get-Command lld-link.exe -ErrorAction SilentlyContinue).Source;if(-not $lld){$lld='C:\Program Files\LLVM\bin\lld-link.exe'};if(-not(Test-Path $lld)){throw 'lld-link missing'}
$exe=(Resolve-Path runtime).Path+'\xp-core-kernel32-cluster.exe';$map=(Resolve-Path diagnostics).Path+'\final.map';$log=(Resolve-Path diagnostics).Path+'\final-link-command.txt'
$args=@("-LIBPATH:$env:MSVCR14X_RELEASE",$env:THUNK_YY_SYNCH_LIB,$env:NARROW_YY_LIB,
  '/nodefaultlib:runtimeobject.lib',
  'probe.obj','/subsystem:console','/entry:mainCRTStartup',"/map:$map","/out:$exe")
foreach($entry in (Get-Content diagnostics\winrt-closure-apis.txt)){
  $args+="/alternatename:_$entry=_YY_Thunks_$entry"
  $args+="/alternatename:__imp__$entry=__imp__YY_Thunks_$entry"
}
($lld+' '+($args -join ' ')) | Set-Content -Encoding utf8 $log
& $lld @args 2>&1 | Tee-Object diagnostics\final-link-output.txt
if($LASTEXITCODE-ne 0-or-not(Test-Path $exe)){throw 'cluster link failed'}
& editbin.exe /nologo "/SUBSYSTEM:CONSOLE,$env:WINDOWS_XP_SUBSYSTEM" $exe | Out-Null
if($LASTEXITCODE-ne 0){throw 'XP subsystem retarget failed'}
$logged=Get-Content $log -Raw
if($logged.IndexOf($env:THUNK_YY_KERNEL32_LIB,[System.StringComparison]::OrdinalIgnoreCase)-ge 0){throw 'Full YY kernel32.lib reached final link'}
if($logged.IndexOf("-LIBPATH:$env:THUNK_YY_LIB",[System.StringComparison]::OrdinalIgnoreCase)-ge 0){throw 'Full YY directory reached final LIBPATH'}
$mapText=Get-Content $map -Raw
foreach($api in (Get-Content diagnostics\capable-apis.txt)){if($mapText.IndexOf("YY_Thunks_$api",[System.StringComparison]::Ordinal)-lt 0){throw "Final map did not select YY_Thunks_$api"}}
if($mapText.IndexOf('_YY_Thunks_WindowsCreateString@12',[System.StringComparison]::Ordinal)-lt 0){throw 'XP WinRT closure was not selected in final link'}
$prngMapSelected=$mapText.IndexOf('YY_Thunks_ProcessPrng',[System.StringComparison]::Ordinal)-ge 0
"processprng_map_selected=$($prngMapSelected.ToString().ToLowerInvariant())"|Set-Content -Encoding ascii diagnostics\processprng-map-selection.txt
"SMOKE_EXE=$exe"|Out-File $env:GITHUB_ENV -Append -Encoding utf8
    }
    default { throw "Unsupported cluster stage: $Stage" }
}
