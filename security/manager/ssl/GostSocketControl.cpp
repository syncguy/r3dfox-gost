/* MPL 2.0 */
#include "GostSocketControl.h"

#include "mozilla/Logging.h"
#include "nsGostSSLIOLayer.h"

extern mozilla::LazyLogModule gGostTLSLog;

GostSocketControl::GostSocketControl(const nsCString& aHostName, int32_t aPort,
                                     uint32_t aProviderFlags)
    : CommonSocketControl(aHostName, aPort, aProviderFlags) {}

void GostSocketControl::SetFileDesc(PRFileDesc* aFd) {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  mFd = aFd;
}

void GostSocketControl::HandshakeSucceeded(uint16_t aCipherSuite,
                                           uint16_t aTlsVersion) {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();

  if (mHandshakeCompleted) {
    return;
  }

  mCipherSuite.emplace(aCipherSuite);
  mProtocolVersion.emplace(aTlsVersion);
  mSSLVersionUsed = static_cast<uint16_t>(aTlsVersion);
  mNPNCompleted = true;
  mNegotiatedNPN.Truncate();
  mHandshakeCompleted = true;
  mFailedVerification = false;

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("handshake complete host=%s cipher=0x%04x tls=0x%04x",
           PromiseFlatCString(GetHostName()).get(), aCipherSuite, aTlsVersion));

  if (mHandshakeCallback) {
    (void)mHandshakeCallback->CertVerificationDone();
    (void)mHandshakeCallback->HandshakeDone();
  }
}

void GostSocketControl::ClientAuthCertificateRequested() {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  if (mHandshakeCallback) {
    (void)mHandshakeCallback->ClientAuthCertificateRequested();
  }
}

void GostSocketControl::ClientAuthCertificateSelected() {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  if (mHandshakeCallback) {
    (void)mHandshakeCallback->ClientAuthCertificateSelected();
  }
}

NS_IMETHODIMP GostSocketControl::ProxyStartSSL() {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("ProxyStartSSL host=%s",
           PromiseFlatCString(GetHostName()).get()));
  return mFd ? GostActivateTLS(mFd) : NS_ERROR_FAILURE;
}

NS_IMETHODIMP GostSocketControl::StartTLS() {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("StartTLS host=%s", PromiseFlatCString(GetHostName()).get()));
  return mFd ? GostActivateTLS(mFd) : NS_ERROR_FAILURE;
}

NS_IMETHODIMP GostSocketControl::DriveHandshake() {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  return mFd ? GostDriveHandshake(mFd) : NS_ERROR_FAILURE;
}

NS_IMETHODIMP GostSocketControl::SetNPNList(nsTArray<nsCString>&) {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::GetAlpnEarlySelection(nsACString& aResult) {
  aResult.Truncate();
  return NS_ERROR_NOT_AVAILABLE;
}

NS_IMETHODIMP GostSocketControl::GetEarlyDataAccepted(bool* aAccepted) {
  *aAccepted = false;
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::GetSSLVersionOffered(int16_t* aVersion) {
  *aVersion = nsITLSSocketControl::TLS_VERSION_1_2;
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::GetKEAUsed(int16_t* aKEAUsed) {
  *aKEAUsed = nsITLSSocketControl::KEY_EXCHANGE_UNKNOWN;
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::GetKEAKeyBits(uint32_t* aBits) {
  *aBits = 0;
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::GetMACAlgorithmUsed(int16_t* aMAC) {
  *aMAC = nsITLSSocketControl::SSL_MAC_UNKNOWN;
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::DisableEarlyData() { return NS_OK; }

NS_IMETHODIMP GostSocketControl::SetHandshakeCallbackListener(
    nsITlsHandshakeCallbackListener* aCallback) {
  COMMON_SOCKET_CONTROL_ASSERT_ON_OWNING_THREAD();
  mHandshakeCallback = aCallback;
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::Claim() { return NS_OK; }

NS_IMETHODIMP GostSocketControl::SetBrowserId(uint64_t aBrowserId) {
  mBrowserId = aBrowserId;
  return NS_OK;
}

NS_IMETHODIMP GostSocketControl::GetBrowserId(uint64_t* aBrowserId) {
  NS_ENSURE_ARG_POINTER(aBrowserId);
  *aBrowserId = mBrowserId;
  return NS_OK;
}
