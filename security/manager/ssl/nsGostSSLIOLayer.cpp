/* MPL 2.0 */

#include "prio.h"

int SelectStage1ClientCertificate(void* aArg);
PRInt16 GostPoll(PRFileDesc* aFd, PRInt16 aInFlags, PRInt16* aOutFlags);
PRStatus GostClose(PRFileDesc* aFd);

// Preserve the last proven per-socket implementation byte-for-byte and expose
// narrow wrappers for the new coordinated client-auth experiment. Function-like
// macros rename only the legacy function definitions/calls; bare function
// pointers in InitMethods()/msspi_set_cert_cb() continue to resolve to the
// wrappers declared above.
#define SelectStage1ClientCertificate(...) \
  LegacySelectStage1ClientCertificate(__VA_ARGS__)
#define GostPoll(...) LegacyGostPoll(__VA_ARGS__)
#define GostClose(...) LegacyGostClose(__VA_ARGS__)
#include "nsGostSSLIOLayerLegacy.inc"
#undef GostClose
#undef GostPoll
#undef SelectStage1ClientCertificate

#ifdef XP_WIN
namespace {
#include "GostClientAuthCoordinator.inc"
}  // namespace
#endif

int SelectStage1ClientCertificate(void* aArg) {
  GostSecret* secret = static_cast<GostSecret*>(aArg);
  if (!secret || !secret->msspi || !secret->control) {
    return 0;
  }

  // Keep the already-proven explicit-thumbprint Stage 1 path untouched.
  if (!secret->clientCertThumbprint.IsEmpty()) {
    return LegacySelectStage1ClientCertificate(aArg);
  }

  secret->redactOutboundHandshake = true;
  nsCString host(secret->control->GetHostName());
  if (!host.EqualsLiteral(kStage1MtlsHost)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("client certificate callback rejected unexpected host=%s",
             host.get()));
    return 0;
  }

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
  GostSecret* secret = GetSecret(aFd);
  if (secret && secret->msspi) {
    RemoveGostCoordinatedClientCertWaiter(secret->msspi);
  }
#endif
  return LegacyGostClose(aFd);
}
