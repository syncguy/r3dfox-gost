/* MPL 2.0 */
#ifndef GostSocketControl_h
#define GostSocketControl_h

#include "CommonSocketControl.h"
#include "nsCOMPtr.h"
#include "nsITlsHandshakeListener.h"

struct PRFileDesc;

class GostSocketControl final : public CommonSocketControl {
 public:
  GostSocketControl(const nsCString& aHostName, int32_t aPort,
                    uint32_t aProviderFlags);

  NS_INLINE_DECL_REFCOUNTING_INHERITED(GostSocketControl, CommonSocketControl)

  void SetFileDesc(PRFileDesc* aFd);
  void HandshakeSucceeded(uint16_t aCipherSuite, uint16_t aTlsVersion);

  NS_IMETHOD DriveHandshake() override;
  NS_IMETHOD SetNPNList(nsTArray<nsCString>& aNPNList) override;
  NS_IMETHOD GetAlpnEarlySelection(nsACString& aResult) override;
  NS_IMETHOD GetEarlyDataAccepted(bool* aAccepted) override;
  NS_IMETHOD GetSSLVersionOffered(int16_t* aVersion) override;
  NS_IMETHOD GetKEAUsed(int16_t* aKEAUsed) override;
  NS_IMETHOD GetKEAKeyBits(uint32_t* aBits) override;
  NS_IMETHOD GetMACAlgorithmUsed(int16_t* aMAC) override;
  NS_IMETHOD DisableEarlyData() override;
  NS_IMETHOD SetHandshakeCallbackListener(
      nsITlsHandshakeCallbackListener* aCallback) override;
  NS_IMETHOD Claim() override;
  NS_IMETHOD SetBrowserId(uint64_t aBrowserId) override;
  NS_IMETHOD GetBrowserId(uint64_t* aBrowserId) override;

 private:
  ~GostSocketControl() override = default;

  PRFileDesc* mFd = nullptr;
  nsCOMPtr<nsITlsHandshakeCallbackListener> mHandshakeCallback;
  uint64_t mBrowserId = 0;
};

#endif
