#ifndef RPMALLOC_XP_FLS_SHIM_H
#define RPMALLOC_XP_FLS_SHIM_H

#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN 1
#endif
#include <windows.h>

#define FlsAlloc(callback) TlsAlloc()
#define FlsFree(index) TlsFree(index)
#define FlsGetValue(index) TlsGetValue(index)
#define FlsSetValue(index, value) TlsSetValue(index, value)

// Windows XP KERNEL32.dll does not export GetLargePageMinimum.
// rpmalloc calls this only in its optional huge-page path. Disable that
// unsupported optimization at compile time for the standalone XP probe;
// a runtime branch alone would still leave an unconditional PE import.
#if defined(_WIN32_WINNT) && (_WIN32_WINNT < 0x0600)
#  define GetLargePageMinimum() ((SIZE_T)0)
#endif

#endif
