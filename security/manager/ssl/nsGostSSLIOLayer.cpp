/* MPL 2.0 */
#include "nsGostSSLIOLayer.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "GostSocketControl.h"
#include "mozilla/BasePrincipal.h"
#include "mozilla/Logging.h"
#include "mozilla/RefPtr.h"
#include "nsCOMPtr.h"
#include "nsISocketProvider.h"
#include "nsITLSSocketControl.h"
#include "prio.h"
#include "prerr.h"
#include "prerror.h"

#include "msspi.h"

using mozilla::OriginAttributes;

mozilla::LazyLogModule gGostTLSLog("GostTLS");

namespace {

static PRDescIdentity sGostIdentity = PR_INVALID_IO_LAYER;
static PRIOMethods sGostMethods;
static bool sMethodsInitialized = false;

static constexpr int kForcedTlsVersion = TLS1_2_VERSION;
static constexpr char kDefaultGostCipherList[] =
    "C100:C101:C102:FF85:0081";
static constexpr int kTlsDumpChunkSize = 256;

struct GostSecret {
  RefPtr<GostSocketControl> control;
  PRFileDesc* lower = nullptr;
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

void SetMsspiError(GostSecret* aSecret, uint32_t aNativeError) {
  if (aSecret) {
    aSecret->lastMsspiError = aNativeError;
  }
  PR_SetError(PR_IO_ERROR, static_cast<PRInt32>(aNativeError));
}

void LogHandshakeBuffer(GostSecret* aSecret, const char* aDirection,
                        const void* aBuf, int aLen) {
  if (!aSecret || aSecret->handshakeComplete || !aBuf || aLen <= 0) {
    return;
  }

  static constexpr char kHex[] = "0123456789ABCDEF";
  const auto* bytes = static_cast<const uint8_t*>(aBuf);
  for (int offset = 0; offset < aLen; offset += kTlsDumpChunkSize) {
    const int chunkLen =
        std::min(kTlsDumpChunkSize, static_cast<int>(aLen - offset));
    nsCString hex;
    for (int i = 0; i < chunkLen; ++i) {
      const uint8_t byte = bytes[offset + i];
      hex.Append(kHex[byte >> 4]);
      hex.Append(kHex[byte & 0x0F]);
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("TLSBUF direction=%s secret=%p len=%d offset=%d chunk=%d hex=%s",
             aDirection, aSecret, aLen, offset, chunkLen, hex.get()));
  }
}

bool IsTransientLowerError(GostSecret* aSecret, PRErrorCode aError) {
  if (aError == PR_WOULD_BLOCK_ERROR || aError == PR_IO_PENDING_ERROR ||
      aError == PR_IN_PROGRESS_ERROR ||
      aError == PR_ALREADY_INITIATED_ERROR) {
    return true;
  }

  return aError == PR_NOT_CONNECTED_ERROR && aSecret &&
         !aSecret->handshakeComplete;
}

int HandleLowerError(GostSecret* aSecret, const char* aOperation, int aLen) {
  const PRErrorCode prError = PR_GetError();
  const PRInt32 osError = PR_GetOSError();
  const int state =
      aSecret && aSecret->msspi ? msspi_state(aSecret->msspi) : 0;

  if (IsTransientLowerError(aSecret, prError)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("lower %s pending prError=%d osError=%d len=%d state=0x%08x",
             aOperation, static_cast<int>(prError), static_cast<int>(osError),
             aLen, state));
    return -1;
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
          ("lower %s failed prError=%d osError=%d len=%d state=0x%08x",
           aOperation, static_cast<int>(prError), static_cast<int>(osError),
           aLen, state));
  return 0;
}

int LowerRead(void* aArg, void* aBuf, int aLen) {
  GostSecret* secret = static_cast<GostSecret*>(aArg);
  PRFileDesc* lower = secret ? secret->lower : nullptr;
  if (!secret || !lower || !lower->methods) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("LowerRead missing transport secret=%p lower=%p len=%d", secret,
             lower, aLen));
    return 0;
  }

  const int stateBefore = secret->msspi ? msspi_state(secret->msspi) : 0;
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("LowerRead enter lower=%p len=%d state=0x%08x", lower, aLen,
           stateBefore));

  PRInt32 rv = lower->methods->recv(lower, aBuf, aLen, 0, PR_INTERVAL_NO_WAIT);
  if (rv >= 0) {
    const int stateAfter = secret->msspi ? msspi_state(secret->msspi) : 0;
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("LowerRead result rv=%d len=%d state=0x%08x", rv, aLen,
             stateAfter));
    LogHandshakeBuffer(secret, "in", aBuf, rv);
    return rv;
  }
  return HandleLowerError(secret, "read", aLen);
}

int LowerWrite(void* aArg, const void* aBuf, int aLen) {
  GostSecret* secret = static_cast<GostSecret*>(aArg);
  PRFileDesc* lower = secret ? secret->lower : nullptr;
  if (!secret || !lower || !lower->methods) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("LowerWrite missing transport secret=%p lower=%p len=%d", secret,
             lower, aLen));
    return 0;
  }

  const int stateBefore = secret->msspi ? msspi_state(secret->msspi) : 0;
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("LowerWrite enter lower=%p len=%d state=0x%08x", lower, aLen,
           stateBefore));

  PRInt32 rv = lower->methods->send(lower, aBuf, aLen, 0, PR_INTERVAL_NO_WAIT);

  if (rv > 0 || aLen == 0) {
    const int stateAfter = secret->msspi ? msspi_state(secret->msspi) : 0;
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("LowerWrite result rv=%d len=%d state=0x%08x", rv, aLen,
             stateAfter));
    LogHandshakeBuffer(secret, "out", aBuf, rv);
    return rv;
  }

  if (rv == 0) {
    const PRErrorCode prError = PR_GetError();
    const PRInt32 osError = PR_GetOSError();
    const int state = secret->msspi ? msspi_state(secret->msspi) : 0;

    if (!secret->handshakeComplete) {
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
              ("LowerWrite zero during handshake len=%d prError=%d "
               "osError=%d state=0x%08x; treating as pending",
               aLen, static_cast<int>(prError), static_cast<int>(osError),
               state));
      SetWouldBlock();
      return -1;
    }

    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("LowerWrite zero after handshake len=%d prError=%d osError=%d "
             "state=0x%08x; treating as transport close",
             aLen, static_cast<int>(prError), static_cast<int>(osError),
             state));
    return 0;
  }

  return HandleLowerError(secret, "write", aLen);
}

nsresult DriveHandshake(PRFileDesc* aLayer) {
  GostSecret* secret = GetSecret(aLayer);
  if (!secret || !secret->msspi) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("DriveHandshake missing MSSPI state"));
    return NS_ERROR_FAILURE;
  }

  nsCString host(secret->control->GetHostName());

  if (secret->handshakeComplete) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("DriveHandshake already complete host=%s", host.get()));
    return NS_OK;
  }

  const int stateBefore = msspi_state(secret->msspi);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("DriveHandshake enter host=%s state=0x%08x", host.get(),
           stateBefore));

  const int rv = msspi_connect(secret->msspi);
  const int stateAfter = msspi_state(secret->msspi);
  const uint32_t nativeError = msspi_last_error();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("DriveHandshake msspi_connect host=%s rv=%d error=0x%08x "
           "state_before=0x%08x state_after=0x%08x",
           host.get(), rv, nativeError, stateBefore, stateAfter));

  if (rv < 0) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("DriveHandshake pending host=%s state=0x%08x", host.get(),
             stateAfter));
    SetWouldBlock();
    return NS_BASE_STREAM_WOULD_BLOCK;
  }

  if (rv == 0) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("msspi_connect failed host=%s error=0x%08x state=0x%08x",
             host.get(), nativeError, stateAfter));
    SetMsspiError(secret, nativeError);
    return NS_ERROR_FAILURE;
  }

  uint32_t tlsVersion = 0;
  const uint8_t* versionString = nullptr;
  size_t versionStringLen = 0;
  const int versionOk =
      msspi_get_version(secret->msspi, &tlsVersion, &versionString,
                        &versionStringLen);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("DriveHandshake version host=%s ok=%d tlsVersion=0x%08x "
           "versionStringLen=%zu",
           host.get(), versionOk, tlsVersion, versionStringLen));

  uint16_t cipherSuite = 0;
  const SecPkgContext_CipherInfo* cipherInfo = nullptr;
  const int cipherOk = msspi_get_cipherinfo(secret->msspi, &cipherInfo);
  if (cipherOk && cipherInfo) {
    cipherSuite = static_cast<uint16_t>(cipherInfo->dwCipherSuite);
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("DriveHandshake cipher host=%s ok=%d cipherInfo=%p suite=0x%04x",
           host.get(), cipherOk, cipherInfo, cipherSuite));

  uint32_t verifyStatus = 0;
  const int verifyOk =
      msspi_get_verify_status(secret->msspi, &verifyStatus);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("DriveHandshake verify host=%s ok=%d status=0x%08x", host.get(),
           verifyOk, verifyStatus));
  if (verifyOk && verifyStatus != 0) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("peer verification failed host=%s status=0x%08x", host.get(),
             verifyStatus));
    PR_SetError(PR_IO_ERROR, static_cast<PRInt32>(verifyStatus));
    return NS_ERROR_FAILURE;
  }

  secret->handshakeComplete = true;
  secret->control->HandshakeSucceeded(cipherSuite,
                                      static_cast<uint16_t>(tlsVersion));
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("MSSPI handshake complete host=%s TLS=0x%04x cipher=0x%04x "
           "state=0x%08x",
           host.get(), static_cast<unsigned int>(tlsVersion), cipherSuite,
           msspi_state(secret->msspi)));
  return NS_OK;
}

PRInt32 GostRead(PRFileDesc* aFd, void* aBuf, PRInt32 aAmount) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostRead enter amount=%d handshakeComplete=%d state=0x%08x",
           aAmount, secret->handshakeComplete, msspi_state(secret->msspi)));

  nsresult rv = DriveHandshake(aFd);
  if (rv == NS_BASE_STREAM_WOULD_BLOCK || NS_FAILED(rv)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostRead handshake blocked rv=0x%08x state=0x%08x",
             static_cast<unsigned int>(rv), msspi_state(secret->msspi)));
    return -1;
  }

  const int n = msspi_read(secret->msspi, aBuf, aAmount);
  const int state = msspi_state(secret->msspi);
  const uint32_t nativeError = msspi_last_error();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostRead msspi_read n=%d amount=%d error=0x%08x state=0x%08x",
           n, aAmount, nativeError, state));
  if (n < 0) {
    SetWouldBlock();
    return -1;
  }
  if (n == 0 && (state & MSSPI_ERROR)) {
    SetMsspiError(secret, nativeError);
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

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostRecv enter amount=%d flags=0x%x handshakeComplete=%d "
           "state=0x%08x",
           aAmount, aFlags, secret->handshakeComplete,
           msspi_state(secret->msspi)));

  nsresult rv = DriveHandshake(aFd);
  if (rv == NS_BASE_STREAM_WOULD_BLOCK || NS_FAILED(rv)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostRecv handshake blocked rv=0x%08x state=0x%08x",
             static_cast<unsigned int>(rv), msspi_state(secret->msspi)));
    return -1;
  }

  int n = (aFlags & PR_MSG_PEEK)
              ? msspi_peek(secret->msspi, aBuf, aAmount)
              : msspi_read(secret->msspi, aBuf, aAmount);
  const int state = msspi_state(secret->msspi);
  const uint32_t nativeError = msspi_last_error();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostRecv msspi_%s n=%d amount=%d error=0x%08x state=0x%08x",
           (aFlags & PR_MSG_PEEK) ? "peek" : "read", n, aAmount,
           nativeError, state));

  if (n < 0) {
    SetWouldBlock();
    return -1;
  }
  if (n == 0 && (state & MSSPI_ERROR)) {
    SetMsspiError(secret, nativeError);
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

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostWrite enter amount=%d handshakeComplete=%d state=0x%08x",
           aAmount, secret->handshakeComplete, msspi_state(secret->msspi)));

  nsresult rv = DriveHandshake(aFd);
  if (rv == NS_BASE_STREAM_WOULD_BLOCK || NS_FAILED(rv)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostWrite handshake blocked rv=0x%08x state=0x%08x",
             static_cast<unsigned int>(rv), msspi_state(secret->msspi)));
    return -1;
  }

  const int n = msspi_write(secret->msspi, aBuf, aAmount);
  const int state = msspi_state(secret->msspi);
  const uint32_t nativeError = msspi_last_error();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostWrite msspi_write n=%d amount=%d error=0x%08x "
           "state=0x%08x",
           n, aAmount, nativeError, state));
  if (n < 0) {
    SetWouldBlock();
    return -1;
  }
  if (n == 0) {
    SetMsspiError(secret, nativeError);
    return -1;
  }
  return n;
}

PRInt32 GostSend(PRFileDesc* aFd, const void* aBuf, PRInt32 aAmount,
                 PRIntn aFlags, PRIntervalTime aTimeout) {
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostSend amount=%d flags=0x%x timeout=%u", aAmount, aFlags,
           static_cast<unsigned int>(aTimeout)));
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
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostAvailable msspi pending=%d state=0x%08x", pending,
             msspi_state(secret->msspi)));
    if (pending > 0) {
      return pending;
    }
  }

  const PRInt32 rv = aFd->lower->methods->available(aFd->lower);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostAvailable lower rv=%d handshakeComplete=%d", rv,
           secret->handshakeComplete));
  return rv;
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
    const int pending = msspi_pending(secret->msspi);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostPoll complete in=0x%04x pending=%d state=0x%08x", aInFlags,
             pending, msspi_state(secret->msspi)));
    if ((aInFlags & PR_POLL_READ) && pending > 0) {
      *aOutFlags |= PR_POLL_READ;
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
              ("GostPoll satisfied by MSSPI pending out=0x%04x",
               *aOutFlags));
      return aInFlags;
    }

    const PRInt16 result =
        aFd->lower->methods->poll(aFd->lower, aInFlags, aOutFlags);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostPoll complete lower result=0x%04x in=0x%04x out=0x%04x",
             result, aInFlags, *aOutFlags));
    return result;
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

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostPoll handshake enter in=0x%04x state=0x%08x lowerIn=0x%04x "
           "reading=%d writing=%d",
           aInFlags, state, lowerIn, !!(state & MSSPI_READING),
           !!(state & MSSPI_WRITING)));

  PRInt16 lowerOut = 0;
  const PRInt16 result =
      aFd->lower->methods->poll(aFd->lower, lowerIn, &lowerOut);

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostPoll lower result=0x%04x lowerIn=0x%04x lowerOut=0x%04x "
           "state=0x%08x",
           result, lowerIn, lowerOut, state));

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

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostPoll handshake exit result=0x%04x in=0x%04x out=0x%04x "
           "state=0x%08x",
           result, aInFlags, *aOutFlags, state));
  return result;
}

PRStatus GostClose(PRFileDesc* aFd) {
  if (!aFd) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("GostClose called with null fd"));
    return PR_FAILURE;
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostClose enter fd=%p", aFd));

  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return PR_FAILURE;
  }

  if (secret->msspi) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostClose MSSPI shutdown host=%s state=0x%08x lower=%p",
             PromiseFlatCString(secret->control->GetHostName()).get(),
             msspi_state(secret->msspi), secret->lower));
    (void)msspi_shutdown(secret->msspi);
    (void)msspi_close(secret->msspi);
    secret->msspi = nullptr;
  }

  PRFileDesc* layer = PR_PopIOLayer(aFd, PR_TOP_IO_LAYER);
  if (!layer || layer->identity != sGostIdentity) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("GostClose failed to pop expected GOST layer fd=%p layer=%p",
             aFd, layer));
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return PR_FAILURE;
  }

  secret->control->SetFileDesc(nullptr);
  secret->lower = nullptr;
  layer->secret = nullptr;
  layer->dtor(layer);
  delete secret;
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostClose closing lower fd=%p", aFd));
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

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("initialized MSSPI GOST NSPR methods identity=%d",
           static_cast<int>(sGostIdentity)));
}

}  // namespace

nsresult GostDriveHandshake(PRFileDesc* aFd) {
  PRFileDesc* layer = FindLayer(aFd);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostDriveHandshake fd=%p layer=%p", aFd, layer));
  return layer ? DriveHandshake(layer) : NS_ERROR_FAILURE;
}

nsresult nsGostSSLIOLayerAddToSocket(
    int32_t, const char* aHost, int32_t aPort, nsIProxyInfo*,
    const OriginAttributes& aOriginAttributes, PRFileDesc* aSocket,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags, uint32_t) {
  NS_ENSURE_ARG_POINTER(aHost);
  NS_ENSURE_ARG_POINTER(aSocket);
  NS_ENSURE_ARG_POINTER(aTlsSocketControl);

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("AddToSocket begin host=%s port=%d socket=%p flags=0x%08x", aHost,
           aPort, aSocket, aFlags));

  InitMethods();

  RefPtr<GostSocketControl> control =
      new GostSocketControl(nsCString(aHost), aPort, aFlags);
  control->SetOriginAttributes(aOriginAttributes);

  PRFileDesc* layer = PR_CreateIOLayerStub(sGostIdentity, &sGostMethods);
  if (!layer) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("AddToSocket PR_CreateIOLayerStub failed host=%s", aHost));
    return NS_ERROR_OUT_OF_MEMORY;
  }

  auto* secret = new GostSecret();
  secret->control = control;
  layer->secret = reinterpret_cast<PRFilePrivate*>(secret);

  secret->msspi = msspi_open(secret, LowerRead, LowerWrite);
  if (!secret->msspi) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("AddToSocket msspi_open failed host=%s error=0x%08x", aHost,
             msspi_last_error()));
    layer->secret = nullptr;
    layer->dtor(layer);
    delete secret;
    return NS_ERROR_FAILURE;
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("AddToSocket msspi_open ok host=%s handle=%p state=0x%08x", aHost,
           secret->msspi, msspi_state(secret->msspi)));

  bool configured = msspi_set_client(secret->msspi, 1);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("AddToSocket set_client host=%s ok=%d error=0x%08x state=0x%08x",
           aHost, configured, msspi_last_error(), msspi_state(secret->msspi)));

  if (configured) {
    configured = msspi_set_version(secret->msspi, kForcedTlsVersion,
                                   kForcedTlsVersion);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("AddToSocket set_version host=%s ok=%d version=0x%04x "
             "error=0x%08x state=0x%08x",
             aHost, configured, kForcedTlsVersion, msspi_last_error(),
             msspi_state(secret->msspi)));
  }

  if (configured) {
    const char* cipherOverride = getenv("R3DFOX_GOST_CIPHERS");
    if (cipherOverride && strcmp(cipherOverride, "default") == 0) {
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
              ("AddToSocket set_cipherlist host=%s mode=native-default "
               "explicit=0 state=0x%08x",
               aHost, msspi_state(secret->msspi)));
    } else {
      const char* cipherList =
          cipherOverride && *cipherOverride ? cipherOverride
                                            : kDefaultGostCipherList;
      configured = msspi_set_cipherlist(
          secret->msspi, reinterpret_cast<const uint8_t*>(cipherList),
          strlen(cipherList));
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
              ("AddToSocket set_cipherlist host=%s ok=%d source=%s list=%s "
               "error=0x%08x state=0x%08x",
               aHost, configured,
               cipherOverride && *cipherOverride ? "environment"
                                                 : "gost-default",
               cipherList, msspi_last_error(), msspi_state(secret->msspi)));
    }
  }

  if (configured) {
    configured = msspi_set_hostname(
        secret->msspi, reinterpret_cast<const uint8_t*>(aHost), strlen(aHost));
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("AddToSocket set_hostname host=%s ok=%d error=0x%08x "
             "state=0x%08x",
             aHost, configured, msspi_last_error(),
             msspi_state(secret->msspi)));
  }

  if (configured) {
    configured = msspi_set_peerauth(secret->msspi, 1);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("AddToSocket set_peerauth host=%s ok=%d error=0x%08x "
             "state=0x%08x",
             aHost, configured, msspi_last_error(),
             msspi_state(secret->msspi)));
  }

  if (!configured) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("AddToSocket MSSPI configuration failed host=%s error=0x%08x "
             "state=0x%08x",
             aHost, msspi_last_error(), msspi_state(secret->msspi)));
    (void)msspi_close(secret->msspi);
    layer->secret = nullptr;
    layer->dtor(layer);
    delete secret;
    return NS_ERROR_FAILURE;
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("AddToSocket pushing NSPR layer host=%s socket=%p layer=%p",
           aHost, aSocket, layer));
  if (PR_PushIOLayer(aSocket, PR_NSPR_IO_LAYER, layer) != PR_SUCCESS) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("AddToSocket PR_PushIOLayer failed host=%s prError=%d "
             "osError=%d",
             aHost, static_cast<int>(PR_GetError()),
             static_cast<int>(PR_GetOSError())));
    (void)msspi_close(secret->msspi);
    layer->secret = nullptr;
    layer->dtor(layer);
    delete secret;
    return NS_ERROR_FAILURE;
  }

  PRFileDesc* activeLayer = PR_GetIdentitiesLayer(aSocket, sGostIdentity);
  if (!activeLayer || !activeLayer->lower) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("AddToSocket cannot resolve pushed GOST layer host=%s socket=%p "
             "activeLayer=%p lower=%p",
             aHost, aSocket, activeLayer,
             activeLayer ? activeLayer->lower : nullptr));

    PRFileDesc* popped = PR_PopIOLayer(aSocket, PR_TOP_IO_LAYER);
    (void)msspi_close(secret->msspi);
    secret->msspi = nullptr;
    if (popped && popped->identity == sGostIdentity) {
      popped->secret = nullptr;
      popped->dtor(popped);
    }
    delete secret;
    return NS_ERROR_FAILURE;
  }

  secret->lower = activeLayer->lower;
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("AddToSocket GOST transport resolved host=%s socket=%p gost=%p "
           "lower=%p",
           aHost, aSocket, activeLayer, secret->lower));

  control->SetFileDesc(aSocket);
  nsCOMPtr<nsITLSSocketControl> result = control.get();
  result.forget(aTlsSocketControl);

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("attached MSSPI GOST layer host=%s port=%d TLS=1.2 socket=%p "
           "layer=%p lower=%p state=0x%08x",
           aHost, aPort, aSocket, activeLayer, secret->lower,
           msspi_state(secret->msspi)));
  return NS_OK;
}

nsresult nsGostSSLIOLayerNewSocket(
    int32_t aFamily, const char* aHost, int32_t aPort, nsIProxyInfo* aProxy,
    const OriginAttributes& aOriginAttributes, PRFileDesc** aResult,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags,
    uint32_t aTlsFlags) {
  NS_ENSURE_ARG_POINTER(aResult);

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("NewSocket begin family=%d host=%s port=%d flags=0x%08x "
           "tlsFlags=0x%08x",
           aFamily, aHost ? aHost : "(null)", aPort, aFlags, aTlsFlags));

  PRFileDesc* fd = PR_OpenTCPSocket(aFamily);
  if (!fd) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("NewSocket PR_OpenTCPSocket failed family=%d prError=%d "
             "osError=%d",
             aFamily, static_cast<int>(PR_GetError()),
             static_cast<int>(PR_GetOSError())));
    return NS_ERROR_SOCKET_CREATE_FAILED;
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("NewSocket PR_OpenTCPSocket ok fd=%p", fd));

  nsresult rv = nsGostSSLIOLayerAddToSocket(
      aFamily, aHost, aPort, aProxy, aOriginAttributes, fd,
      aTlsSocketControl, aFlags, aTlsFlags);
  if (NS_FAILED(rv)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("NewSocket AddToSocket failed host=%s rv=0x%08x", aHost,
             static_cast<unsigned int>(rv)));
    PR_Close(fd);
    return rv;
  }

  *aResult = fd;
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("NewSocket complete host=%s fd=%p", aHost, fd));
  return NS_OK;
}