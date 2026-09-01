#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef LONG NTSTATUS;
typedef PVOID BCRYPT_HANDLE;
typedef BCRYPT_HANDLE BCRYPT_ALG_HANDLE;
typedef BCRYPT_HANDLE BCRYPT_HASH_HANDLE;
typedef NTSTATUS (WINAPI *PFN_Open)(BCRYPT_ALG_HANDLE*, LPCWSTR, LPCWSTR, ULONG);
typedef NTSTATUS (WINAPI *PFN_Close)(BCRYPT_ALG_HANDLE, ULONG);
typedef NTSTATUS (WINAPI *PFN_Get)(BCRYPT_HANDLE, LPCWSTR, PUCHAR, ULONG, ULONG*, ULONG);
typedef NTSTATUS (WINAPI *PFN_Create)(BCRYPT_ALG_HANDLE, BCRYPT_HASH_HANDLE*, PUCHAR, ULONG, PUCHAR, ULONG, ULONG);
typedef NTSTATUS (WINAPI *PFN_Hash)(BCRYPT_HASH_HANDLE, PUCHAR, ULONG, ULONG);
typedef NTSTATUS (WINAPI *PFN_Finish)(BCRYPT_HASH_HANDLE, PUCHAR, ULONG, ULONG);
typedef NTSTATUS (WINAPI *PFN_Destroy)(BCRYPT_HASH_HANDLE);
typedef NTSTATUS (WINAPI *PFN_Rng)(BCRYPT_ALG_HANDLE, PUCHAR, ULONG, ULONG);

static HANDLE gOut;
static void out(const char* s) { DWORD n=0,len=0; while(s[len]) ++len; WriteFile(gOut,s,len,&n,0); }
static void outw(LPCWSTR s){ char b[1024]; int n=WideCharToMultiByte(CP_UTF8,0,s,-1,b,sizeof(b),0,0); if(n>1){ DWORD w=0; WriteFile(gOut,b,n-1,&w,0); } }
static bool ok(NTSTATUS s){ return s >= 0; }
static int fail(const char* s){ out(s); return 1; }

extern "C" void __cdecl mainCRTStartup(void) {
  gOut=GetStdHandle(STD_OUTPUT_HANDLE);
  HMODULE m=LoadLibraryW(L".\\bcrypt.dll");
  if(!m) ExitProcess(fail("LOAD FAIL\r\n"));
  out("LOAD PASS\r\n"); WCHAR modulePath[1024]; DWORD moduleLen=GetModuleFileNameW(m,modulePath,1024); if(moduleLen){ out("MODULE PATH: "); outw(modulePath); out("\r\n"); }
  PFN_Open Open=(PFN_Open)GetProcAddress(m,"BCryptOpenAlgorithmProvider");
  PFN_Close Close=(PFN_Close)GetProcAddress(m,"BCryptCloseAlgorithmProvider");
  PFN_Get Get=(PFN_Get)GetProcAddress(m,"BCryptGetProperty");
  PFN_Create Create=(PFN_Create)GetProcAddress(m,"BCryptCreateHash");
  PFN_Hash Hash=(PFN_Hash)GetProcAddress(m,"BCryptHashData");
  PFN_Finish Finish=(PFN_Finish)GetProcAddress(m,"BCryptFinishHash");
  PFN_Destroy Destroy=(PFN_Destroy)GetProcAddress(m,"BCryptDestroyHash");
  PFN_Rng Rng=(PFN_Rng)GetProcAddress(m,"BCryptGenRandom");
  if(!Open||!Close||!Get||!Create||!Hash||!Finish||!Destroy||!Rng) ExitProcess(fail("EXPORTS FAIL\r\n"));
  out("EXPORTS PASS\r\n");
  BYTE rnd[32];
  if(!ok(Rng(0,rnd,sizeof(rnd),2))) ExitProcess(fail("RNG FAIL\r\n"));
  out("RNG PASS\r\n");
  BCRYPT_ALG_HANDLE alg=0; BCRYPT_HASH_HANDLE hash=0; ULONG cb=0,objLen=0;
  if(!ok(Open(&alg,L"SHA256",0,0))) ExitProcess(fail("SHA256 FAIL\r\n"));
  if(!ok(Get(alg,L"ObjectLength",(PUCHAR)&objLen,sizeof(objLen),&cb,0)) || objLen==0) { Close(alg,0); ExitProcess(fail("SHA256 FAIL\r\n")); }
  PUCHAR obj=(PUCHAR)HeapAlloc(GetProcessHeap(),0,objLen); if(!obj){ Close(alg,0); ExitProcess(fail("SHA256 FAIL\r\n")); }
  BYTE digest[32]; BYTE data[3]={'a','b','c'};
  bool pass=ok(Create(alg,&hash,obj,objLen,0,0,0)) && ok(Hash(hash,data,3,0)) && ok(Finish(hash,digest,32,0));
  const BYTE expected[32]={0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad};
  for(int i=0;i<32 && pass;i++) if(digest[i]!=expected[i]) pass=false;
  if(hash) Destroy(hash); HeapFree(GetProcessHeap(),0,obj); Close(alg,0);
  if(!pass) ExitProcess(fail("SHA256 FAIL\r\n"));
  out("SHA256 PASS\r\n");
  FreeLibrary(m); ExitProcess(0);
}
