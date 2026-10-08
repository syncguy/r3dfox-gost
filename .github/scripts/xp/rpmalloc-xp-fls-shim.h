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

#endif
