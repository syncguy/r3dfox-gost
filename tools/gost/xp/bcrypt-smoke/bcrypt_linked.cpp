#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef LONG NTSTATUS;
typedef PVOID BCRYPT_HANDLE;
typedef BCRYPT_HANDLE BCRYPT_ALG_HANDLE;
typedef BCRYPT_HANDLE BCRYPT_HASH_HANDLE;
extern "C" {
__declspec(dllimport) NTSTATUS WINAPI BCryptOpenAlgorithmProvider(BCRYPT_ALG_HANDLE*, LPCWSTR, LPCWSTR, ULONG);
__declspec(dllimport) NTSTATUS WINAPI BCryptCloseAlgorithmProvider(BCRYPT_ALG_HANDLE, ULONG);
__declspec(dllimport) NTSTATUS WINAPI BCryptGetProperty(BCRYPT_HANDLE, LPCWSTR, PUCHAR, ULONG, ULONG*, ULONG);
__declspec(dllimport) NTSTATUS WINAPI BCryptCreateHash(BCRYPT_ALG_HANDLE, BCRYPT_HASH_HANDLE*, PUCHAR, ULONG, PUCHAR, ULONG, ULONG);
__declspec(dllimport) NTSTATUS WINAPI BCryptHashData(BCRYPT_HASH_HANDLE, PUCHAR, ULONG, ULONG);
__declspec(dllimport) NTSTATUS WINAPI BCryptFinishHash(BCRYPT_HASH_HANDLE, PUCHAR, ULONG, ULONG);
__declspec(dllimport) NTSTATUS WINAPI BCryptDestroyHash(BCRYPT_HASH_HANDLE);
__declspec(dllimport) NTSTATUS WINAPI BCryptGenRandom(BCRYPT_ALG_HANDLE, PUCHAR, ULONG, ULONG);
}
static HANDLE gOut;
static void out(const char* s) { DWORD n=0,len=0; while(s[len]) ++len; WriteFile(gOut,s,len,&n,0); }
static void outw(LPCWSTR s){ char b[1024]; int n=WideCharToMultiByte(CP_UTF8,0,s,-1,b,sizeof(b),0,0); if(n>1){ DWORD w=0; WriteFile(gOut,b,n-1,&w,0); } }
static bool ok(NTSTATUS s){ return s >= 0; }
static int fail(const char* s){ out(s); return 1; }
extern "C" void __cdecl mainCRTStartup(void) {
  gOut=GetStdHandle(STD_OUTPUT_HANDLE);
  out("LOAD PASS\r\n"); HMODULE m=GetModuleHandleW(L"bcrypt.dll"); WCHAR modulePath[1024]; DWORD moduleLen=m?GetModuleFileNameW(m,modulePath,1024):0; if(moduleLen){ out("MODULE PATH: "); outw(modulePath); out("\r\n"); } out("EXPORTS PASS\r\n");
  BYTE rnd[32]; if(!ok(BCryptGenRandom(0,rnd,sizeof(rnd),2))) ExitProcess(fail("RNG FAIL\r\n")); out("RNG PASS\r\n");
  BCRYPT_ALG_HANDLE alg=0; BCRYPT_HASH_HANDLE hash=0; ULONG cb=0,objLen=0;
  if(!ok(BCryptOpenAlgorithmProvider(&alg,L"SHA256",0,0))) ExitProcess(fail("SHA256 FAIL\r\n"));
  if(!ok(BCryptGetProperty(alg,L"ObjectLength",(PUCHAR)&objLen,sizeof(objLen),&cb,0)) || !objLen) { BCryptCloseAlgorithmProvider(alg,0); ExitProcess(fail("SHA256 FAIL\r\n")); }
  PUCHAR obj=(PUCHAR)HeapAlloc(GetProcessHeap(),0,objLen); if(!obj){ BCryptCloseAlgorithmProvider(alg,0); ExitProcess(fail("SHA256 FAIL\r\n")); }
  BYTE digest[32]; BYTE data[3]={'a','b','c'};
  bool pass=ok(BCryptCreateHash(alg,&hash,obj,objLen,0,0,0)) && ok(BCryptHashData(hash,data,3,0)) && ok(BCryptFinishHash(hash,digest,32,0));
  const BYTE expected[32]={0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad};
  for(int i=0;i<32 && pass;i++) if(digest[i]!=expected[i]) pass=false;
  if(hash) BCryptDestroyHash(hash); HeapFree(GetProcessHeap(),0,obj); BCryptCloseAlgorithmProvider(alg,0);
  if(!pass) ExitProcess(fail("SHA256 FAIL\r\n")); out("SHA256 PASS\r\n"); ExitProcess(0);
}
