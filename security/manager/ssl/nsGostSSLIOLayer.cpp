/* MPL 2.0 */

#include "nsGostSSLIOLayer.h"

#include "mozilla/TimeStamp.h"
#include "prio.h"

int SelectStage1ClientCertificate(void* aArg);
PRInt16 GostPoll(PRFileDesc* aFd, PRInt16 aInFlags, PRInt16* aOutFlags);
PRStatus GostClose(PRFileDesc* aFd);

// Preserve the proven per-socket implementation and wrap only the Stage 2
// client-auth lifecycle / host-scope integration points.
#define SelectStage1ClientCertificate(...) \
  LegacySelectStage1ClientCertificate(__VA_ARGS__)
#define GostPoll(...) LegacyGostPoll(__VA_ARGS__)
#define GostClose(...) LegacyGostClose(__VA_ARGS__)
#define nsGostSSLIOLayerAddToSocket(...) \
  LegacyGostSSLIOLayerAddToSocket(__VA_ARGS__)
#define nsGostSSLIOLayerNewSocket(...) LegacyGostSSLIOLayerNewSocket(__VA_ARGS__)
#include "nsGostSSLIOLayerLegacy.inc"
#undef nsGostSSLIOLayerNewSocket
#undef nsGostSSLIOLayerAddToSocket
#undef GostClose
#undef GostPoll
#undef SelectStage1ClientCertificate

#ifdef XP_WIN
namespace {
#include "GostClientAuthCoordinator.inc"
}  // namespace
#endif

namespace {

nsresult ConfigureGenericGostClientAuth(PRFileDesc* aSocket,
                                        const char* aHost) {
#ifdef XP_WIN
  PRFileDesc* layer = FindLayer(aSocket);
  GostSecret* secret = GetSecret(layer);
  if (!secret || !secret->msspi) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("client certificate callback registration missing GOST state "
             "host=%s socket=%p layer=%p",
             aHost ? aHost : "(null)", aSocket, layer));
    return NS_ERROR_FAILURE;
  }

  if (aHost && strcmp(aHost, kStage1MtlsHost) == 0) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate callback registered host=%s scope=stage1 "
             "mode=%s picker_default=session",
             aHost,
             UseCoordinatedGostClientAuth() ? "coordinated" : "legacy"));
    return NS_OK;
  }

  const int configured =
      msspi_set_cert_cb(secret->msspi, SelectStage1ClientCertificate);
  const uint32_t nativeError = msspi_last_error();
  MOZ_LOG(gGostTLSLog,
          configured ? mozilla::LogLevel::Info : mozilla::LogLevel::Error,
          ("client certificate callback registered host=%s scope=generic "
           "mode=%s picker_default=session ok=%d error=0x%08x state=0x%08x",
           aHost ? aHost : "(null)",
           UseCoordinatedGostClientAuth() ? "coordinated" : "legacy",
           configured, nativeError, msspi_state(secret->msspi)));
  return configured ? NS_OK : NS_ERROR_FAILURE;
#else
  return NS_OK;
#endif
}

}  // namespace

int SelectStage1ClientCertificate(void* aArg) {
  GostSecret* secret = static_cast<GostSecret*>(aArg);
  if (!secret || !secret->msspi || !secret->control) {
    return 0;
  }

#ifdef XP_WIN
  if (IsGostClientAuthMsspiClosing(secret->msspi)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate callback ignored reason=closing host=%s "
             "handle=%p",
             PromiseFlatCString(secret->control->GetHostName()).get(),
             secret->msspi));
    return 0;
  }
#endif

  // Keep the already-proven explicit-thumbprint Stage 1 path untouched.
  if (!secret->clientCertThumbprint.IsEmpty()) {
    return LegacySelectStage1ClientCertificate(aArg);
  }

  secret->redactOutboundHandshake = true;
  nsCString host(secret->control->GetHostName());

#ifdef XP_WIN
  LogIssuerListOnce(secret, host);
  if (UseCoordinatedGostClientAuth()) {
    return SelectCoordinatedFirefoxGostClientCertificate(secret, host);
  }
  return SelectFirefoxGostClientCertificate(secret, host);
#else
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
          ("client certificate selection unavailable host=%s", host.get()));
  return 0;
#endif
}

PRInt16 GostPoll(PRFileDesc* aFd, PRInt16 aInFlags, PRInt16* aOutFlags) {
#ifdef XP_WIN
  GostSecret* secret = GetSecret(aFd);
  if (secret && secret->msspi && UseCoordinatedGostClientAuth() &&
      IsGostCoordinatedClientCertWaiting(secret->msspi)) {
    if (!aOutFlags) {
      PR_SetError(PR_INVALID_ARGUMENT_ERROR, 0);
      return 0;
    }
    *aOutFlags = 0;
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostPoll client-auth wait quiescent in=0x%04x state=0x%08x",
             aInFlags, msspi_state(secret->msspi)));
    return 0;
  }
#endif
  return LegacyGostPoll(aFd, aInFlags, aOutFlags);
}

PRStatus GostClose(PRFileDesc* aFd) {
#ifdef XP_WIN
  MSSPI_HANDLE closingHandle = nullptr;
  GostSecret* secret = GetSecret(aFd);
  if (secret && secret->msspi) {
    closingHandle = secret->msspi;
    MarkGostClientAuthMsspiClosing(closingHandle);
    RemoveGostCoordinatedClientCertWaiter(closingHandle, "close-pre");
  }
#endif

  const PRStatus result = LegacyGostClose(aFd);

#ifdef XP_WIN
  if (closingHandle) {
    RemoveGostCoordinatedClientCertWaiter(closingHandle, "close-post");
    UnmarkGostClientAuthMsspiClosing(closingHandle);
  }
#endif
  return result;
}

nsresult nsGostSSLIOLayerAddToSocket(
    int32_t aFamily, const char* aHost, int32_t aPort, nsIProxyInfo* aProxy,
    const OriginAttributes& aOriginAttributes, PRFileDesc* aSocket,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags,
    uint32_t aTlsFlags) {
  nsresult rv = LegacyGostSSLIOLayerAddToSocket(
      aFamily, aHost, aPort, aProxy, aOriginAttributes, aSocket,
      aTlsSocketControl, aFlags, aTlsFlags);
  if (NS_FAILED(rv)) {
    return rv;
  }
  return ConfigureGenericGostClientAuth(aSocket, aHost);
}

nsresult nsGostSSLIOLayerNewSocket(
    int32_t aFamily, const char* aHost, int32_t aPort, nsIProxyInfo* aProxy,
    const OriginAttributes& aOriginAttributes, PRFileDesc** aResult,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags,
    uint32_t aTlsFlags) {
  nsresult rv = LegacyGostSSLIOLayerNewSocket(
      aFamily, aHost, aPort, aProxy, aOriginAttributes, aResult,
      aTlsSocketControl, aFlags, aTlsFlags);
  if (NS_FAILED(rv)) {
    return rv;
  }

  rv = ConfigureGenericGostClientAuth(*aResult, aHost);
  if (NS_FAILED(rv) && *aResult) {
    PR_Close(*aResult);
    *aResult = nullptr;
  }
  return rv;
}
