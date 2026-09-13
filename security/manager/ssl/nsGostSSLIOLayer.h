/* MPL 2.0 */
#ifndef nsGostSSLIOLayer_h
#define nsGostSSLIOLayer_h

#include "nsError.h"

class nsIProxyInfo;
class nsITLSSocketControl;
namespace mozilla {
class OriginAttributes;
}
struct PRFileDesc;

nsresult nsGostSSLIOLayerNewSocket(
    int32_t aFamily, const char* aHost, int32_t aPort, nsIProxyInfo* aProxy,
    const mozilla::OriginAttributes& aOriginAttributes, PRFileDesc** aResult,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags,
    uint32_t aTlsFlags);

nsresult nsGostSSLIOLayerAddToSocket(
    int32_t aFamily, const char* aHost, int32_t aPort, nsIProxyInfo* aProxy,
    const mozilla::OriginAttributes& aOriginAttributes, PRFileDesc* aSocket,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags,
    uint32_t aTlsFlags);

nsresult GostActivateTLS(PRFileDesc* aFd);
nsresult GostDriveHandshake(PRFileDesc* aFd);

#endif
