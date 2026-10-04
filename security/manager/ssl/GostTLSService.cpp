/* MPL 2.0 */
#include "GostTLSService.h"

#include "mozilla/Logging.h"
#include "nsString.h"
#include "prenv.h"

extern mozilla::LazyLogModule gGostTLSLog;

namespace {

bool HostMatches(const nsACString& aHost, const nsACString& aToken) {
  if (aToken.IsEmpty()) {
    return false;
  }

  if (aToken.Length() > 2 && aToken.CharAt(0) == '*' &&
      aToken.CharAt(1) == '.') {
    nsDependentCSubstring suffix(aToken, 1);
    return aHost.Length() > suffix.Length() &&
           StringEndsWith(aHost, suffix,
                          nsCaseInsensitiveCStringComparator);
  }

  return aHost.Equals(aToken, nsCaseInsensitiveCStringComparator);
}

}  // namespace

bool GostTLSService::ShouldUseForHost(const char* aHost) {
  if (!aHost || !*aHost) {
    return false;
  }

  const char* raw = PR_GetEnv("R3DFOX_GOST_HOSTS");
  if (!raw || !*raw) {
    return false;
  }

  nsAutoCString host(aHost);
  nsAutoCString list(raw);

  int32_t start = 0;
  while (start < static_cast<int32_t>(list.Length())) {
    int32_t end = start;
    while (end < static_cast<int32_t>(list.Length()) &&
           list.CharAt(end) != ',' && list.CharAt(end) != ';') {
      ++end;
    }

    nsAutoCString token(Substring(list, start, end - start));
    token.Trim(" \t\r\n");

    if (HostMatches(host, token)) {
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
              ("allowlist matched host=%s token=%s", aHost, token.get()));
      return true;
    }

    start = end + 1;
  }

  return false;
}
