#include <windows.h>
#include <wincrypt.h>
#include <stddef.h>

namespace mozilla {

bool GenerateRandomBytesFromOS(void* aBuffer, size_t aLength) {
  if (!aBuffer || aLength == 0 || aLength > MAXDWORD) {
    return false;
  }

  HCRYPTPROV provider = 0;
  if (!CryptAcquireContextW(&provider, nullptr, nullptr, PROV_RSA_FULL,
                            CRYPT_VERIFYCONTEXT | CRYPT_SILENT)) {
    return false;
  }

  const BOOL ok =
      CryptGenRandom(provider, static_cast<DWORD>(aLength),
                     static_cast<BYTE*>(aBuffer));
  CryptReleaseContext(provider, 0);
  return ok == TRUE;
}

}  // namespace mozilla

static bool AllZero(const BYTE* data, DWORD len) {
  BYTE value = 0;
  for (DWORD i = 0; i < len; ++i) {
    value |= data[i];
  }
  return value == 0;
}

extern "C" void __stdcall mainCRTStartup() {
  BYTE data[32];

  for (DWORD i = 0; i < 256; ++i) {
    for (DWORD j = 0; j < sizeof(data); ++j) {
      data[j] = 0;
    }
    if (!mozilla::GenerateRandomBytesFromOS(data, sizeof(data))) {
      ExitProcess(10);
    }
    if (AllZero(data, sizeof(data))) {
      ExitProcess(11);
    }
  }

  ExitProcess(0);
}
