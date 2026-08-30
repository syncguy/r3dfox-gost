#include <windows.h>
#include <wincrypt.h>

#if defined(LEGACY_RNG_RTL_CONTROL)
extern "C" BOOLEAN NTAPI SystemFunction036(PVOID, ULONG);
#endif

static bool AllZero(const BYTE* data, DWORD len) {
  BYTE value = 0;
  for (DWORD i = 0; i < len; ++i) {
    value |= data[i];
  }
  return value == 0;
}

#if defined(LEGACY_RNG_CRYPTOAPI)
static bool Generate(BYTE* data, DWORD len) {
  HCRYPTPROV provider = 0;
  if (!CryptAcquireContextW(&provider, nullptr, nullptr, PROV_RSA_FULL,
                            CRYPT_VERIFYCONTEXT | CRYPT_SILENT)) {
    return false;
  }

  const BOOL ok = CryptGenRandom(provider, len, data);
  CryptReleaseContext(provider, 0);
  return ok == TRUE;
}
#elif defined(LEGACY_RNG_RTL_CONTROL)
static bool Generate(BYTE* data, DWORD len) {
  return SystemFunction036(data, len) == TRUE;
}
#else
#  error Define exactly one RNG backend
#endif

extern "C" void __stdcall mainCRTStartup() {
  BYTE data[32];

  for (DWORD i = 0; i < 256; ++i) {
    ZeroMemory(data, sizeof(data));
    if (!Generate(data, sizeof(data))) {
      ExitProcess(10);
    }
    if (AllZero(data, sizeof(data))) {
      ExitProcess(11);
    }
  }

  ExitProcess(0);
}
