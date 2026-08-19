/* MPL 2.0 */
#include "nsGostSSLIOLayer.h"

#include <stdint.h>
#include <string.h>

#include "GostSocketControl.h"
#include "mozilla/BasePrincipal.h"
#include "mozilla/Logging.h"
#include "mozilla/RefPtr.h"
#include "nsCOMPtr.h"
#include "nsISocketProvider.h"
#include "nsITLSSocketControl.h"
#include "prio.h"
#include "prerror.h"

#include "msspi.h"

using mozilla::OriginAttributes;

mozilla::LazyLogModule gGostTLSLog("GostTLS");

namespace {

static PRDescIdentity sGostIdentity = PR_INVALID_IO_LAYER;
static PRIOMethods sGostMethods;
static bool sMethodsInitialized = false;

static constexpr int kForcedTlsVersion = TLS1_2_VERSION;

struct GostSecret {
  RefPtr<GostSocketControl> control;
  MSSPI_HANDLE msspi = nullptr;
  uint32_t lastMsspiError = 0;
  bool handshakeComplete = false;
};

GostSecret* GetSecret(PRFileDesc* aFd) {
  if (!aFd || aFd->identity != sGostIdentity) {
    return nullptr;
  }
  return reinterpret_cast<GostSecret*>(aFd->secret);
}

PRFileDesc* FindLayer(PRFileDesc* aFd) {
  return aFd ? PR_GetIdentitiesLayer(aFd, sGostIdentity) : nullptr;
}

void SetWouldBlock() { PR_SetError(PR_WOULD_BLOCK_ERROR, 0); }

void SetMsspiError(GostSecret* aSecret) {
  const uint32_t nativeError = msspi_last_error();
  if (aSecret) {
    aSecret->lastMsspiError = nativeError;
  }
  PR_SetError(PR_IO_ERROR, static_cast<PRInt32>(nativeError));
}

int LowerRead(void* aArg, void* aBuf, int aLen) {
  PRFileDesc* layer = static_cast<PRFileDesc*>(aArg);
  if (!layer || !layer->lower) {
    return 0;
  }

  PRInt32 rv = layer->lower->methods->recv(
      layer->lower, aBuf, aLen, 0, PR_INTERVAL_NO_WAIT);
  if (rv >= 0) {
    return rv;
  }
  return PR_GetError() == PR_WOULD_BLOCK_ERROR ? -1 : 0;
}

int LowerWrite(void* aArg, const void* aBuf, int aLen) {
  PRFileDesc* layer = static_cast<PRFileDesc*>(aArg);
  if (!layer || !layer->lower) {
    return 0;
  }

  PRInt32 rv = layer->lower->methods->send(
      layer->lower, aBuf, aLen, 0, PR_INTERVAL_NO_WAIT);
  if (rv >= 0) {
    return rv;
  }
  return PR_GetError() == PR_WOULD_BLOCK_ERROR ? -1 : 0;
}

nsresult DriveHandshake(PRFileDesc* aLayer) {
  GostSecret* secret = GetSecret(aLayer);
  if (!secret || !secret->msspi) {
    return NS_ERROR_FAILURE;
  }

  if (secret->handshakeComplete) {
    return NS_OK;
  }

  const int rv = msspi_connect(secret->msspi);
  if (rv < 0) {
    SetWouldBlock();
    return NS_BASE_STREAM_WOULD_BLOCK;
  }

  if (rv == 0) {
    const uint32_t nativeError = msspi_last_error();
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("msspi_connect failed host=%s error=0x%08x state=0x%08x",
             PromiseFlatCString(secret->control->GetHostName()).get(),
             nativeError, msspi_state(secret->msspi)));
    SetMsspiError(secret);
    return NS_ERROR_FAILURE;
  }

  uint32_t tlsVersion = 0;
  const uint8_t* versionString = nullptr;
  size_t versionStringLen = 0;
  (void)msspi_get_version(secret->msspi, &tlsVersion, &versionString,
                          &versionStringLen);

  uint16_t cipherSuite = 0;
  const SecPkgContext_CipherInfo* cipherInfo = nullptr;
  if (msspi_get_cipherinfo(secret->msspi, &cipherInfo) && cipherInfo) {
    cipherSuite = static_cast<uint16_t>(cipherInfo->dwCipherSuite);
  }

  uint32_t verifyStatus = 0;
  if (msspi_get_verify_status(secret->msspi, &verifyStatus) &&
      verifyStatus != 0) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("peer verification failed host=%s status=0x%08x",
             PromiseFlatCString(secret->control->GetHostName()).get(),
             verifyStatus));
    PR_SetError(PR_IO_ERROR, static_cast<PRInt32>(verifyStatus));
    return NS_ERROR_FAILURE;
  }

  secret->handshakeComplete = true;
  secret->control->HandshakeSucceeded(cipherSuite,
                                      static_cast<uint16_t>(tlsVersion));
  return NS_OK;
}

PRInt32 GostRead(PRFileDesc* aFd, void* aBuf, PRInt32 aAmount) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  nsresult rv = DriveHandshake(aFd);
  if (rv == NS_BASE_STREAM_WOULD_BLOCK || NS_FAILED(rv)) {
    return -1;
  }

  const int n = msspi_read(secret->msspi, aBuf, aAmount);
  if (n < 0) {
    SetWouldBlock();
    return -1;
  }
  if (n == 0 && (msspi_state(secret->msspi) & MSSPI_ERROR)) {
    SetMsspiError(secret);
    return -1;
  }
  return n;
}

PRInt32 GostRecv(PRFileDesc* aFd, void* aBuf, PRInt32 aAmount, PRIntn aFlags,
                 PRIntervalTime) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  nsresult rv = DriveHandshake(aFd);
  if (rv == NS_BASE_STREAM_WOULD_BLOCK || NS_FAILED(rv)) {
    return -1;
  }

  int n = (aFlags & PR_MSG_PEEK)
              ? msspi_peek(secret->msspi, aBuf, aAmount)
              : msspi_read(secret->msspi, aBuf, aAmount);

  if (n < 0) {
    SetWouldBlock();
    return -1;
  }
  return n;
}

PRInt32 GostWrite(PRFileDesc* aFd, const void* aBuf, PRInt32 aAmount) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  nsresult rv = DriveHandshake(aFd);
  if (rv == NS_BASE_STREAM_WOULD_BLOCK || NS_FAILED(rv)) {
    return -1;
  }

  const int n = msspi_write(secret->msspi, aBuf, aAmount);
  if (n < 0) {
    SetWouldBlock();
    return -1;
  }
  if (n == 0) {
    SetMsspiError(secret);
    return -1;
  }
  return n;
}

PRInt32 GostSend(PRFileDesc* aFd, const void* aBuf, PRInt32 aAmount,
                 PRIntn, PRIntervalTime) {
  return GostWrite(aFd, aBuf, aAmount);
}

PRInt32 GostAvailable(PRFileDesc* aFd) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  if (secret->handshakeComplete) {
    int pending = msspi_pending(secret->msspi);
    if (pending > 0) {
      return pending;
    }
  }
  return aFd->lower->methods->available(aFd->lower);
}

PRInt16 GostPoll(PRFileDesc* aFd, PRInt16 aInFlags, PRInt16* aOutFlags) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret || !aFd->lower) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    *aOutFlags = PR_POLL_ERR;
    return aInFlags;
  }

  *aOutFlags = 0;

  if (secret->handshakeComplete) {
    if ((aInFlags & PR_POLL_READ) && msspi_pending(secret->msspi) > 0) {
      *aOutFlags |= PR_POLL_READ;
      return aInFlags;
    }
    return aFd->lower->methods->poll(aFd->lower, aInFlags, aOutFlags);
  }

  const int state = msspi_state(secret->msspi);
  PRInt16 lowerIn = 0;
  if (state & MSSPI_READING) {
    lowerIn |= PR_POLL_READ;
  }
  if (state & MSSPI_WRITING) {
    lowerIn |= PR_POLL_WRITE;
  }
  if (!lowerIn) {
    lowerIn = aInFlags;
  }

  PRInt16 lowerOut = 0;
  const PRInt16 result =
      aFd->lower->methods->poll(aFd->lower, lowerIn, &lowerOut);

  if (lowerOut & (PR_POLL_ERR | PR_POLL_EXCEPT)) {
    *aOutFlags |= lowerOut & (PR_POLL_ERR | PR_POLL_EXCEPT);
  }
  if ((state & MSSPI_READING) && (lowerOut & PR_POLL_READ)) {
    *aOutFlags |= aInFlags;
  }
  if ((state & MSSPI_WRITING) && (lowerOut & PR_POLL_WRITE)) {
    *aOutFlags |= aInFlags;
  }
  if (!state) {
    *aOutFlags |= lowerOut & aInFlags;
  }
  return result;
}

PRStatus GostClose(PRFileDesc* aFd) {
  if (!aFd) {
    return PR_FAILURE;
  }

  PRFileDesc* layer = PR_PopIOLayer(aFd, PR_TOP_IO_LAYER);
  if (!layer || layer->identity != sGostIdentity) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return PR_FAILURE;
  }

  GostSecret* secret = GetSecret(layer);
  if (secret) {
    if (secret->msspi) {
      (void)msspi_shutdown(secret->msspi);
      (void)msspi_close(secret->msspi);
      secret->msspi = nullptr;
    }
    secret->control->SetFileDesc(nullptr);
  }

  layer->secret = nullptr;
  layer->dtor(layer);
  delete secret;
  return aFd->methods->close(aFd);
}

void InitMethods() {
  if (sMethodsInitialized) {
    return;
  }

  sGostIdentity = PR_GetUniqueIdentity("MSSPI GOST TLS");
  sGostMethods = *PR_GetDefaultIOMethods();
  sGostMethods.read = GostRead;
  sGostMethods.recv = GostRecv;
  sGostMethods.write = GostWrite;
  sGostMethods.send = GostSend;
  sGostMethods.available = GostAvailable;
  sGostMethods.poll = GostPoll;
  sGostMethods.close = GostClose;
  sMethodsInitialized = true;
}

}  // namespace

nsresult GostDriveHandshake(PRFileDesc* aFd) {
  PRFileDesc* layer = FindLayer(aFd);
  return layer ? DriveHandshake(layer) : NS_ERROR_FAILURE;
}

nsresult nsGostSSLIOLayerAddToSocket(
    int32_t, const char* aHost, int32_t aPort, nsIProxyInfo*,
    const OriginAttributes& aOriginAttributes, PRFileDesc* aSocket,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags, uint32_t) {
  NS_ENSURE_ARG_POINTER(aHost);
  NS_ENSURE_ARG_POINTER(aSocket);
  NS_ENSURE_ARG_POINTER(aTlsSocketControl);

  InitMethods();

  RefPtr<GostSocketControl> control =
      new GostSocketControl(nsCString(aHost), aPort, aFlags);
  control->SetOriginAttributes(aOriginAttributes);

  PRFileDesc* layer = PR_CreateIOLayerStub(sGostIdentity, &sGostMethods);
  if (!layer) {
    return NS_ERROR_OUT_OF_MEMORY;
  }

  auto* secret = new GostSecret();
  secret->control = control;
  layer->secret = reinterpret_cast<PRFilePrivate*>(secret);

  secret->msspi = msspi_open(layer, LowerRead, LowerWrite);
  if (!secret->msspi) {
    layer->secret = nullptr;
    layer->dtor(layer);
    delete secret;
    return NS_ERROR_FAILURE;
  }

  const bool configured =
      msspi_set_client(secret->msspi, 1) &&
      msspi_set_version(secret->msspi, kForcedTlsVersion,
                        kForcedTlsVersion) &&
      msspi_set_hostname(secret->msspi,
                         reinterpret_cast<const uint8_t*>(aHost),
                         strlen(aHost)) &&
      msspi_set_peerauth(secret->msspi, 1);

  if (!configured) {
    (void)msspi_close(secret->msspi);
    layer->secret = nullptr;
    layer->dtor(layer);
    delete secret;
    return NS_ERROR_FAILURE;
  }

  if (PR_PushIOLayer(aSocket, PR_NSPR_IO_LAYER, layer) != PR_SUCCESS) {
    (void)msspi_close(secret->msspi);
    layer->secret = nullptr;
    layer->dtor(layer);
    delete secret;
    return NS_ERROR_FAILURE;
  }

  control->SetFileDesc(aSocket);
  nsCOMPtr<nsITLSSocketControl> result = control.get();
  result.forget(aTlsSocketControl);

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("attached MSSPI GOST layer host=%s port=%d TLS=1.2", aHost,
           aPort));
  return NS_OK;
}

nsresult nsGostSSLIOLayerNewSocket(
    int32_t aFamily, const char* aHost, int32_t aPort, nsIProxyInfo* aProxy,
    const OriginAttributes& aOriginAttributes, PRFileDesc** aResult,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags,
    uint32_t aTlsFlags) {
  NS_ENSURE_ARG_POINTER(aResult);

  PRFileDesc* fd = PR_OpenTCPSocket(aFamily);
  if (!fd) {
    return NS_ERROR_SOCKET_CREATE_FAILED;
  }

  nsresult rv = nsGostSSLIOLayerAddToSocket(
      aFamily, aHost, aPort, aProxy, aOriginAttributes, fd,
      aTlsSocketControl, aFlags, aTlsFlags);
  if (NS_FAILED(rv)) {
    PR_Close(fd);
    return rv;
  }

  *aResult = fd;
  return NS_OK;
}
