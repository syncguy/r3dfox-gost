/* MPL 2.0 */
#include "nsGostSSLIOLayer.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef XP_WIN
#  include <windows.h>
#  include <wincrypt.h>
#endif

#include "GostSocketControl.h"
#include "mozilla/Mutex.h"
#include "mozilla/dom/BrowsingContext.h"
#include "nsIClientAuthDialogService.h"
#include "nsIClientAuthRememberService.h"
#include "nsIEventTarget.h"
#include "nsISocketTransportService.h"
#include "nsIX509Cert.h"
#include "nsIX509CertDB.h"
#include "nsServiceManagerUtils.h"
#include "nsThreadUtils.h"
#include "mozilla/BasePrincipal.h"
#include "mozilla/Logging.h"
#include "mozilla/RefPtr.h"
#include "mozilla/StaticMutex.h"
#include "mozilla/StaticPtr.h"
#include "nsCOMPtr.h"
#include "nsIProxyInfo.h"
#include "nsISocketProvider.h"
#include "nsITLSSocketControl.h"
#include "nsTArray.h"
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
static mozilla::StaticMutex sIssuerLogMutex;
static mozilla::StaticAutoPtr<nsTArray<nsCString>> sLoggedIssuerLists;

static constexpr int kForcedTlsVersion = TLS1_2_VERSION;
static constexpr char kDefaultGostCipherList[] =
    "C100:C101:C102:FF85:0081";
static constexpr char kStage1MtlsHost[] = "lk-fzs.roskazna.ru";
static constexpr char kClientCertThumbprintEnv[] =
    "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT";
static constexpr int kTlsDumpChunkSize = 256;
static constexpr size_t kSha1ThumbprintBytes = 20;

struct GostSecret {
  RefPtr<GostSocketControl> control;
  PRFileDesc* lower = nullptr;
  MSSPI_HANDLE msspi = nullptr;
  nsCString clientCertThumbprint;
  int32_t port = -1;
  uint32_t lastMsspiError = 0;
  bool tlsActive = true;
  bool handshakeComplete = false;
  bool redactOutboundHandshake = false;
  bool clientCertLoaded = false;
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

PRFileDesc* GetLower(GostSecret* aSecret) {
  if (!aSecret || !aSecret->lower || !aSecret->lower->methods) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return nullptr;
  }
  return aSecret->lower;
}

void SetWouldBlock() { PR_SetError(PR_WOULD_BLOCK_ERROR, 0); }

void SetMsspiError(GostSecret* aSecret, uint32_t aNativeError) {
  if (aSecret) {
    aSecret->lastMsspiError = aNativeError;
  }
  PR_SetError(PR_IO_ERROR, static_cast<PRInt32>(aNativeError));
}

int HexValue(char aChar) {
  if (aChar >= '0' && aChar <= '9') {
    return aChar - '0';
  }
  if (aChar >= 'a' && aChar <= 'f') {
    return aChar - 'a' + 10;
  }
  if (aChar >= 'A' && aChar <= 'F') {
    return aChar - 'A' + 10;
  }
  return -1;
}

bool ParseSha1Thumbprint(const nsACString& aValue,
                         uint8_t (&aHash)[kSha1ThumbprintBytes]) {
  size_t nibble = 0;
  memset(aHash, 0, sizeof(aHash));
  for (uint32_t i = 0; i < aValue.Length(); ++i) {
    const char c = aValue.CharAt(i);
    if (c == ' ' || c == '\t' || c == ':' || c == '-') {
      continue;
    }
    const int value = HexValue(c);
    if (value < 0 || nibble >= kSha1ThumbprintBytes * 2) {
      return false;
    }
    if ((nibble & 1) == 0) {
      aHash[nibble / 2] = static_cast<uint8_t>(value << 4);
    } else {
      aHash[nibble / 2] |= static_cast<uint8_t>(value);
    }
    ++nibble;
  }
  return nibble == kSha1ThumbprintBytes * 2;
}

#ifdef XP_WIN
nsCString WideToUtf8(const WCHAR* aValue) {
  if (!aValue || !*aValue) {
    return nsCString();
  }

  const int length =
      WideCharToMultiByte(CP_UTF8, 0, aValue, -1, nullptr, 0, nullptr, nullptr);
  if (length <= 1) {
    return nsCString();
  }

  nsTArray<char> buffer;
  buffer.SetLength(length);
  if (!WideCharToMultiByte(CP_UTF8, 0, aValue, -1, buffer.Elements(), length,
                           nullptr, nullptr)) {
    return nsCString();
  }
  return nsCString(buffer.Elements(), length - 1);
}

void AppendIssuerIdentityBytes(nsCString& aKey, const void* aData,
                               size_t aLength) {
  aKey.Append(reinterpret_cast<const char*>(aData), aLength);
}

bool MarkIssuerListFirstSeen(const nsACString& aHost, int32_t aPort,
                             const nsTArray<const uint8_t*>& aIssuers,
                             const nsTArray<size_t>& aLengths) {
  nsCString key(aHost);
  key.Append('\0');
  AppendIssuerIdentityBytes(key, &aPort, sizeof(aPort));
  const uint32_t count = aIssuers.Length();
  AppendIssuerIdentityBytes(key, &count, sizeof(count));
  for (uint32_t i = 0; i < count; ++i) {
    const uint64_t length = static_cast<uint64_t>(aLengths[i]);
    AppendIssuerIdentityBytes(key, &length, sizeof(length));
    if (aIssuers[i] && aLengths[i]) {
      AppendIssuerIdentityBytes(key, aIssuers[i], aLengths[i]);
    }
  }

  mozilla::StaticMutexAutoLock lock(sIssuerLogMutex);
  if (!sLoggedIssuerLists) {
    sLoggedIssuerLists = new nsTArray<nsCString>();
  }
  for (const auto& logged : *sLoggedIssuerLists) {
    if (logged.Equals(key)) {
      return false;
    }
  }
  sLoggedIssuerLists->AppendElement(std::move(key));
  return true;
}

void LogIssuerDer(const nsACString& aHost, int32_t aPort, size_t aIndex,
                  const uint8_t* aData, size_t aLength) {
  if (!aData || !aLength) {
    return;
  }

  static constexpr char kHex[] = "0123456789ABCDEF";
  for (size_t offset = 0; offset < aLength; offset += kTlsDumpChunkSize) {
    const size_t remaining = aLength - offset;
    const size_t chunkLen =
        remaining < kTlsDumpChunkSize ? remaining : kTlsDumpChunkSize;
    nsCString hex;
    hex.SetCapacity(chunkLen * 2);
    for (size_t i = 0; i < chunkLen; ++i) {
      const uint8_t byte = aData[offset + i];
      hex.Append(kHex[byte >> 4]);
      hex.Append(kHex[byte & 0x0F]);
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("issuer-list DER host=%s port=%d index=%zu offset=%zu chunk=%zu "
             "hex=%s",
             PromiseFlatCString(aHost).get(), aPort, aIndex, offset, chunkLen,
             hex.get()));
  }
}

void LogIssuerNameDetails(const nsACString& aHost, int32_t aPort,
                          size_t aIndex, const uint8_t* aData,
                          size_t aLength) {
  if (!aData || !aLength || aLength > MAXDWORD) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("issuer-list invalid DER host=%s port=%d index=%zu der_len=%zu",
             PromiseFlatCString(aHost).get(), aPort, aIndex, aLength));
    return;
  }

  CERT_NAME_BLOB nameBlob = {};
  nameBlob.cbData = static_cast<DWORD>(aLength);
  nameBlob.pbData = const_cast<BYTE*>(aData);

  DWORD formattedLength = CertNameToStrW(
      X509_ASN_ENCODING, &nameBlob, CERT_X500_NAME_STR, nullptr, 0);
  if (formattedLength > 1) {
    nsTArray<WCHAR> formatted;
    formatted.SetLength(formattedLength);
    if (CertNameToStrW(X509_ASN_ENCODING, &nameBlob, CERT_X500_NAME_STR,
                       formatted.Elements(), formattedLength)) {
      nsCString dn = WideToUtf8(formatted.Elements());
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
              ("issuer-list DN host=%s port=%d index=%zu der_len=%zu dn=%s",
               PromiseFlatCString(aHost).get(), aPort, aIndex, aLength,
               dn.get()));
    }
  } else {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("issuer-list DN format failed host=%s port=%d index=%zu "
             "der_len=%zu win_error=0x%08lx",
             PromiseFlatCString(aHost).get(), aPort, aIndex, aLength,
             GetLastError()));
  }

  CERT_NAME_INFO* nameInfo = nullptr;
  DWORD decodedSize = 0;
  if (!CryptDecodeObjectEx(X509_ASN_ENCODING, X509_NAME, aData,
                           static_cast<DWORD>(aLength), CRYPT_DECODE_ALLOC_FLAG,
                           nullptr, &nameInfo, &decodedSize) ||
      !nameInfo) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("issuer-list ASN1 decode failed host=%s port=%d index=%zu "
             "der_len=%zu win_error=0x%08lx",
             PromiseFlatCString(aHost).get(), aPort, aIndex, aLength,
             GetLastError()));
    LogIssuerDer(aHost, aPort, aIndex, aData, aLength);
    return;
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("issuer-list ASN1 host=%s port=%d index=%zu rdn_count=%lu "
           "decoded_size=%lu",
           PromiseFlatCString(aHost).get(), aPort, aIndex,
           static_cast<unsigned long>(nameInfo->cRDN),
           static_cast<unsigned long>(decodedSize)));

  for (DWORD rdnIndex = 0; rdnIndex < nameInfo->cRDN; ++rdnIndex) {
    const CERT_RDN& rdn = nameInfo->rgRDN[rdnIndex];
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("issuer-list RDN host=%s port=%d index=%zu rdn=%lu "
             "attr_count=%lu",
             PromiseFlatCString(aHost).get(), aPort, aIndex,
             static_cast<unsigned long>(rdnIndex),
             static_cast<unsigned long>(rdn.cRDNAttr)));

    for (DWORD attrIndex = 0; attrIndex < rdn.cRDNAttr; ++attrIndex) {
      const CERT_RDN_ATTR& attr = rdn.rgRDNAttr[attrIndex];
      nsCString friendlyName;
      if (attr.pszObjId) {
        PCCRYPT_OID_INFO oidInfo = CryptFindOIDInfo(
            CRYPT_OID_INFO_OID_KEY, attr.pszObjId,
            CRYPT_RDN_ATTR_OID_GROUP_ID);
        if (oidInfo && oidInfo->pwszName) {
          friendlyName = WideToUtf8(oidInfo->pwszName);
        }
      }

      nsCString value;
      CERT_RDN_VALUE_BLOB valueBlob = attr.Value;
      const DWORD valueLength =
          CertRDNValueToStrW(attr.dwValueType, &valueBlob, nullptr, 0);
      if (valueLength > 1) {
        nsTArray<WCHAR> valueBuffer;
        valueBuffer.SetLength(valueLength);
        if (CertRDNValueToStrW(attr.dwValueType, &valueBlob,
                               valueBuffer.Elements(), valueLength)) {
          value = WideToUtf8(valueBuffer.Elements());
        }
      }

      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
              ("issuer-list ATTR host=%s port=%d index=%zu rdn=%lu attr=%lu "
               "oid=%s name=%s value_type=%lu value_len=%lu value=%s",
               PromiseFlatCString(aHost).get(), aPort, aIndex,
               static_cast<unsigned long>(rdnIndex),
               static_cast<unsigned long>(attrIndex),
               attr.pszObjId ? attr.pszObjId : "(null)", friendlyName.get(),
               static_cast<unsigned long>(attr.dwValueType),
               static_cast<unsigned long>(attr.Value.cbData), value.get()));
    }
  }

  LocalFree(nameInfo);
  LogIssuerDer(aHost, aPort, aIndex, aData, aLength);
}

void LogIssuerListOnce(GostSecret* aSecret, const nsACString& aHost) {
  if (!aSecret || !aSecret->msspi) {
    return;
  }

  size_t count = 0;
  const int countOk =
      msspi_get_issuerlist(aSecret->msspi, nullptr, nullptr, &count);
  const uint32_t countError = msspi_last_error();
  if (!countOk) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("issuer-list count failed host=%s port=%d error=0x%08x "
             "state=0x%08x",
             PromiseFlatCString(aHost).get(), aSecret->port, countError,
             msspi_state(aSecret->msspi)));
    return;
  }

  if (!count) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("issuer-list host=%s port=%d count=0",
             PromiseFlatCString(aHost).get(), aSecret->port));
    return;
  }

  nsTArray<const uint8_t*> issuers;
  nsTArray<size_t> lengths;
  issuers.SetLength(count);
  lengths.SetLength(count);
  size_t actualCount = count;
  const int listOk = msspi_get_issuerlist(
      aSecret->msspi, issuers.Elements(), lengths.Elements(), &actualCount);
  const uint32_t listError = msspi_last_error();
  if (!listOk) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("issuer-list fetch failed host=%s port=%d requested=%zu "
             "actual=%zu error=0x%08x state=0x%08x",
             PromiseFlatCString(aHost).get(), aSecret->port, count, actualCount,
             listError, msspi_state(aSecret->msspi)));
    return;
  }

  if (actualCount < issuers.Length()) {
    issuers.TruncateLength(actualCount);
    lengths.TruncateLength(actualCount);
  }

  size_t totalDer = 0;
  for (size_t length : lengths) {
    totalDer += length;
  }

  if (!MarkIssuerListFirstSeen(aHost, aSecret->port, issuers, lengths)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("issuer-list host=%s port=%d count=%zu total_der=%zu "
             "already_logged=1",
             PromiseFlatCString(aHost).get(), aSecret->port, issuers.Length(),
             totalDer));
    return;
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("issuer-list host=%s port=%d count=%zu total_der=%zu "
           "already_logged=0",
           PromiseFlatCString(aHost).get(), aSecret->port, issuers.Length(),
           totalDer));
  for (size_t i = 0; i < issuers.Length(); ++i) {
    LogIssuerNameDetails(aHost, aSecret->port, i, issuers[i], lengths[i]);
  }
}
#endif


#ifdef XP_WIN
enum class GostClientCertPhase { Selecting, Selected, Declined, Failed };

class GostClientCertState final
    : public mozilla::RefCountedThreadSafe<GostClientCertState> {
 public:
  GostClientCertState(MSSPI_HANDLE aMsspi, GostSocketControl* aControl,
                      const nsACString& aHost,
                      const mozilla::OriginAttributes& aOriginAttributes,
                      uint64_t aBrowserId,
                      nsTArray<nsTArray<uint8_t>>&& aCandidates,
                      nsTArray<nsTArray<uint8_t>>&& aCANames)
      : mMutex("GostClientCertState"),
        mMsspi(aMsspi),
        mControl(aControl),
        mHost(aHost),
        mOriginAttributes(aOriginAttributes),
        mBrowserId(aBrowserId),
        mCandidates(std::move(aCandidates)),
        mCANames(std::move(aCANames)) {}

  mozilla::Mutex mMutex;
  MSSPI_HANDLE mMsspi;
  RefPtr<GostSocketControl> mControl;
  nsCString mHost;
  mozilla::OriginAttributes mOriginAttributes;
  uint64_t mBrowserId;
  nsTArray<nsTArray<uint8_t>> mCandidates;
  nsTArray<nsTArray<uint8_t>> mCANames;
  GostClientCertPhase mPhase = GostClientCertPhase::Selecting;
  nsTArray<uint8_t> mSelectedDER;

 private:
  friend class mozilla::RefCountedThreadSafe<GostClientCertState>;
  ~GostClientCertState() = default;
};

struct GostRememberedClientCert {
  nsCString key;
  nsTArray<uint8_t> der;
  bool declined = false;
};

static mozilla::StaticMutex sClientCertSelectionMutex;
static mozilla::StaticAutoPtr<nsTArray<RefPtr<GostClientCertState>>>
    sClientCertSelections;
static mozilla::StaticAutoPtr<nsTArray<GostRememberedClientCert>>
    sRememberedClientCerts;

nsCString GostClientCertDecisionKey(
    const nsACString& aHost,
    const mozilla::OriginAttributes& aOriginAttributes) {
  nsCString key(aHost);
  key.Append('\0');
  nsAutoCString suffix;
  aOriginAttributes.CreateSuffix(suffix);
  key.Append(suffix);
  return key;
}

RefPtr<GostClientCertState> FindGostClientCertState(MSSPI_HANDLE aMsspi) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sClientCertSelections) {
    return nullptr;
  }
  for (const auto& state : *sClientCertSelections) {
    if (state->mMsspi == aMsspi) {
      return state;
    }
  }
  return nullptr;
}

void RemoveGostClientCertState(MSSPI_HANDLE aMsspi) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sClientCertSelections) {
    return;
  }
  for (uint32_t i = 0; i < sClientCertSelections->Length(); ++i) {
    if ((*sClientCertSelections)[i]->mMsspi == aMsspi) {
      sClientCertSelections->RemoveElementAt(i);
      return;
    }
  }
}

bool FindRememberedGostClientCert(const nsACString& aKey,
                                  nsTArray<uint8_t>& aDER,
                                  bool& aDeclined) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sRememberedClientCerts) {
    return false;
  }
  for (const auto& choice : *sRememberedClientCerts) {
    if (choice.key.Equals(aKey)) {
      aDER = choice.der.Clone();
      aDeclined = choice.declined;
      return true;
    }
  }
  return false;
}

void RememberGostClientCert(const nsACString& aKey,
                            const nsTArray<uint8_t>& aDER,
                            bool aDeclined) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sRememberedClientCerts) {
    sRememberedClientCerts = new nsTArray<GostRememberedClientCert>();
  }
  for (auto& choice : *sRememberedClientCerts) {
    if (choice.key.Equals(aKey)) {
      choice.der = aDER.Clone();
      choice.declined = aDeclined;
      return;
    }
  }
  GostRememberedClientCert choice;
  choice.key = aKey;
  choice.der = aDER.Clone();
  choice.declined = aDeclined;
  sRememberedClientCerts->AppendElement(std::move(choice));
}

bool GostCertNameEquals(const CERT_NAME_BLOB& aName,
                        const nsTArray<uint8_t>& aCAName) {
  return aName.cbData == aCAName.Length() && aName.pbData &&
         memcmp(aName.pbData, aCAName.Elements(), aCAName.Length()) == 0;
}

bool GostClientCertMatchesCANames(
    PCCERT_CONTEXT aCert, const nsTArray<nsTArray<uint8_t>>& aCANames) {
  if (aCANames.IsEmpty()) {
    return true;
  }

  CERT_CHAIN_PARA para = {};
  para.cbSize = sizeof(para);
  PCCERT_CHAIN_CONTEXT chain = nullptr;
  if (!CertGetCertificateChain(
          nullptr, aCert, nullptr, aCert->hCertStore, &para,
          CERT_CHAIN_CACHE_END_CERT | CERT_CHAIN_CACHE_ONLY_URL_RETRIEVAL,
          nullptr, &chain) ||
      !chain) {
    return false;
  }

  bool matched = false;
  for (DWORD chainIndex = 0; chainIndex < chain->cChain && !matched;
       ++chainIndex) {
    PCERT_SIMPLE_CHAIN simple = chain->rgpChain[chainIndex];
    for (DWORD element = 0; element < simple->cElement && !matched; ++element) {
      PCCERT_CONTEXT current = simple->rgpElement[element]->pCertContext;
      for (const auto& caName : aCANames) {
        if (GostCertNameEquals(current->pCertInfo->Subject, caName) ||
            GostCertNameEquals(current->pCertInfo->Issuer, caName)) {
          matched = true;
          break;
        }
      }
    }
  }
  CertFreeCertificateChain(chain);
  return matched;
}

bool CollectGostCANames(MSSPI_HANDLE aMsspi,
                        nsTArray<nsTArray<uint8_t>>& aCANames) {
  size_t count = 0;
  if (!msspi_get_issuerlist(aMsspi, nullptr, nullptr, &count)) {
    return false;
  }
  if (!count) {
    return true;
  }
  nsTArray<const uint8_t*> buffers;
  nsTArray<size_t> lengths;
  buffers.SetLength(count);
  lengths.SetLength(count);
  size_t actualCount = count;
  if (!msspi_get_issuerlist(aMsspi, buffers.Elements(), lengths.Elements(),
                            &actualCount)) {
    return false;
  }
  for (size_t i = 0; i < actualCount; ++i) {
    nsTArray<uint8_t> name;
    name.AppendElements(buffers[i], lengths[i]);
    aCANames.AppendElement(std::move(name));
  }
  return true;
}

bool CollectGostClientCertCandidates(
    const nsTArray<nsTArray<uint8_t>>& aCANames,
    nsTArray<nsTArray<uint8_t>>& aCandidates) {
  HCERTSTORE store = CertOpenStore(
      CERT_STORE_PROV_SYSTEM_W, 0, 0,
      CERT_SYSTEM_STORE_CURRENT_USER | CERT_STORE_OPEN_EXISTING_FLAG |
          CERT_STORE_READONLY_FLAG,
      L"MY");
  if (!store) {
    return false;
  }

  PCCERT_CONTEXT cert = nullptr;
  while ((cert = CertEnumCertificatesInStore(store, cert))) {
    DWORD keyProviderInfoSize = 0;
    if (!CertGetCertificateContextProperty(cert, CERT_KEY_PROV_INFO_PROP_ID,
                                           nullptr, &keyProviderInfoSize) ||
        !keyProviderInfoSize) {
      continue;
    }
    if (!GostClientCertMatchesCANames(cert, aCANames)) {
      continue;
    }
    nsTArray<uint8_t> der;
    der.AppendElements(cert->pbCertEncoded, cert->cbCertEncoded);
    aCandidates.AppendElement(std::move(der));
  }
  CertCloseStore(store, 0);
  return true;
}

bool GostClientCertStateIsActive(GostClientCertState* aState) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sClientCertSelections) {
    return false;
  }
  for (const auto& state : *sClientCertSelections) {
    if (state == aState) {
      return true;
    }
  }
  return false;
}

void WakeGostClientCertHandshake(GostClientCertState* aState) {
  nsCOMPtr<nsIEventTarget> socketThread(
      do_GetService(NS_SOCKETTRANSPORTSERVICE_CONTRACTID));
  if (!socketThread) {
    return;
  }
  RefPtr<GostClientCertState> state(aState);
  (void)socketThread->Dispatch(
      NS_NewRunnableFunction("GostClientAuthResume", [state]() {
        if (!GostClientCertStateIsActive(state)) {
          return;
        }
        (void)state->mControl->DriveHandshake();
      }));
}

class GostClientAuthDialogCallback final
    : public nsIClientAuthDialogCallback {
 public:
  NS_DECL_THREADSAFE_ISUPPORTS
  NS_DECL_NSICLIENTAUTHDIALOGCALLBACK

  explicit GostClientAuthDialogCallback(GostClientCertState* aState)
      : mState(aState) {}

 private:
  ~GostClientAuthDialogCallback() = default;
  RefPtr<GostClientCertState> mState;
};

NS_IMPL_ISUPPORTS(GostClientAuthDialogCallback, nsIClientAuthDialogCallback)

NS_IMETHODIMP GostClientAuthDialogCallback::CertificateChosen(
    nsIX509Cert* aCert,
    nsIClientAuthRememberService::Duration aRememberDuration) {
  nsTArray<uint8_t> der;
  if (aCert) {
    nsresult rv = aCert->GetRawDER(der);
    if (NS_FAILED(rv)) {
      {
        mozilla::MutexAutoLock lock(mState->mMutex);
        mState->mPhase = GostClientCertPhase::Failed;
      }
      WakeGostClientCertHandshake(mState);
      return rv;
    }
  }

  {
    mozilla::MutexAutoLock lock(mState->mMutex);
    mState->mSelectedDER = der.Clone();
    mState->mPhase = aCert ? GostClientCertPhase::Selected
                           : GostClientCertPhase::Declined;
  }
  if (aRememberDuration != nsIClientAuthRememberService::Once) {
    RememberGostClientCert(
        GostClientCertDecisionKey(mState->mHost, mState->mOriginAttributes),
        der, !aCert);
  }
  WakeGostClientCertHandshake(mState);
  return NS_OK;
}

void OpenGostClientAuthDialog(GostClientCertState* aState) {
  MOZ_ASSERT(NS_IsMainThread());
  RefPtr<GostClientCertState> state(aState);
  nsCOMPtr<nsIX509CertDB> certDB(do_GetService(NS_X509CERTDB_CONTRACTID));
  nsCOMPtr<nsIClientAuthDialogService> dialog(
      do_GetService(NS_CLIENTAUTHDIALOGSERVICE_CONTRACTID));
  if (!certDB || !dialog) {
    {
      mozilla::MutexAutoLock lock(state->mMutex);
      state->mPhase = GostClientCertPhase::Failed;
    }
    WakeGostClientCertHandshake(state);
    return;
  }

  nsTArray<RefPtr<nsIX509Cert>> certArray;
  for (const auto& der : state->mCandidates) {
    nsCOMPtr<nsIX509Cert> cert;
    if (NS_SUCCEEDED(certDB->ConstructX509(der, getter_AddRefs(cert))) && cert) {
      certArray.AppendElement(cert);
    }
  }
  if (certArray.IsEmpty()) {
    {
      mozilla::MutexAutoLock lock(state->mMutex);
      state->mPhase = GostClientCertPhase::Declined;
    }
    WakeGostClientCertHandshake(state);
    return;
  }

  RefPtr<mozilla::dom::BrowsingContext> browsingContext;
  if (state->mBrowserId) {
    browsingContext =
        mozilla::dom::BrowsingContext::GetCurrentTopByBrowserId(state->mBrowserId);
  }
  RefPtr<nsIClientAuthDialogCallback> callback(
      new GostClientAuthDialogCallback(state));
  nsresult rv = dialog->ChooseCertificate(state->mHost, certArray,
                                          browsingContext, state->mCANames,
                                          callback);
  if (NS_FAILED(rv)) {
    {
      mozilla::MutexAutoLock lock(state->mMutex);
      state->mPhase = GostClientCertPhase::Failed;
    }
    WakeGostClientCertHandshake(state);
  }
}

int SelectFirefoxGostClientCertificate(GostSecret* aSecret,
                                       const nsACString& aHost) {
  const mozilla::OriginAttributes originAttributes(
      aSecret->control->GetOriginAttributes());
  const nsCString decisionKey(
      GostClientCertDecisionKey(aHost, originAttributes));

  nsTArray<uint8_t> rememberedDER;
  bool rememberedDeclined = false;
  if (FindRememberedGostClientCert(decisionKey, rememberedDER,
                                   rememberedDeclined)) {
    if (rememberedDeclined) {
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
              ("client certificate remembered host=%s selected=0 scope=session",
               PromiseFlatCString(aHost).get()));
      return 1;
    }
    const int selected = msspi_set_mycert(
        aSecret->msspi, rememberedDER.Elements(), rememberedDER.Length());
    if (selected) {
      aSecret->clientCertLoaded = true;
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate remembered host=%s selected=%d scope=session",
             PromiseFlatCString(aHost).get(), selected ? 1 : 0));
    return selected ? 1 : 0;
  }

  RefPtr<GostClientCertState> state(
      FindGostClientCertState(aSecret->msspi));
  if (state) {
    GostClientCertPhase phase;
    nsTArray<uint8_t> der;
    {
      mozilla::MutexAutoLock lock(state->mMutex);
      phase = state->mPhase;
      der = state->mSelectedDER.Clone();
    }
    if (phase == GostClientCertPhase::Selecting) {
      return -1;
    }
    if (phase == GostClientCertPhase::Declined) {
      RemoveGostClientCertState(aSecret->msspi);
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
              ("client certificate dialog completed host=%s selected=0",
               PromiseFlatCString(aHost).get()));
      return 1;
    }
    if (phase == GostClientCertPhase::Failed || der.IsEmpty()) {
      RemoveGostClientCertState(aSecret->msspi);
      return 0;
    }
    const int selected =
        msspi_set_mycert(aSecret->msspi, der.Elements(), der.Length());
    RemoveGostClientCertState(aSecret->msspi);
    if (selected) {
      aSecret->clientCertLoaded = true;
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate dialog completed host=%s selected=%d",
             PromiseFlatCString(aHost).get(), selected ? 1 : 0));
    return selected ? 1 : 0;
  }

  nsTArray<nsTArray<uint8_t>> caNames;
  if (!CollectGostCANames(aSecret->msspi, caNames)) {
    return 0;
  }
  nsTArray<nsTArray<uint8_t>> candidates;
  if (!CollectGostClientCertCandidates(caNames, candidates)) {
    return 0;
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate candidates host=%s count=%zu mode=firefox-ui",
           PromiseFlatCString(aHost).get(), candidates.Length()));
  if (candidates.IsEmpty()) {
    return 1;
  }

  uint64_t browserId = 0;
  (void)aSecret->control->GetBrowserId(&browserId);
  state = new GostClientCertState(aSecret->msspi, aSecret->control, aHost,
                                  originAttributes, browserId,
                                  std::move(candidates), std::move(caNames));
  {
    mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
    if (!sClientCertSelections) {
      sClientCertSelections = new nsTArray<RefPtr<GostClientCertState>>();
    }
    sClientCertSelections->AppendElement(state);
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate dialog requested host=%s mode=firefox-ui",
           PromiseFlatCString(aHost).get()));
  (void)NS_DispatchToMainThread(NS_NewRunnableFunction(
      "GostClientAuthDialog", [state]() { OpenGostClientAuthDialog(state); }));
  return -1;
}
#endif

int SelectStage1ClientCertificate(void* aArg) {
  GostSecret* secret = static_cast<GostSecret*>(aArg);
  if (!secret || !secret->msspi || !secret->control) {
    return 0;
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
#endif

  if (secret->clientCertThumbprint.IsEmpty()) {
#ifdef XP_WIN
    return SelectFirefoxGostClientCertificate(secret, host);
#else
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("client certificate selection unavailable host=%s", host.get()));
    return 0;
#endif
  }

#ifdef XP_WIN
  uint8_t hash[kSha1ThumbprintBytes];
  if (!ParseSha1Thumbprint(secret->clientCertThumbprint, hash)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("client certificate selector malformed host=%s selector=thumbprint",
             host.get()));
    return 0;
  }

  HCERTSTORE store = CertOpenStore(
      CERT_STORE_PROV_SYSTEM_W, 0, 0,
      CERT_SYSTEM_STORE_CURRENT_USER | CERT_STORE_OPEN_EXISTING_FLAG |
          CERT_STORE_READONLY_FLAG,
      L"MY");
  if (!store) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("client certificate store open failed host=%s error=0x%08lx",
             host.get(), GetLastError()));
    return 0;
  }

  CRYPT_HASH_BLOB hashBlob = {};
  hashBlob.cbData = static_cast<DWORD>(sizeof(hash));
  hashBlob.pbData = hash;
  PCCERT_CONTEXT cert = CertFindCertificateInStore(
      store, X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, 0, CERT_FIND_SHA1_HASH,
      &hashBlob, nullptr);
  if (!cert) {
    const DWORD error = GetLastError();
    CertCloseStore(store, 0);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("client certificate not found host=%s selector=thumbprint "
             "store=current-user-my error=0x%08lx",
             host.get(), error));
    return 0;
  }

  DWORD keyProviderInfoSize = 0;
  if (!CertGetCertificateContextProperty(cert, CERT_KEY_PROV_INFO_PROP_ID,
                                         nullptr, &keyProviderInfoSize) ||
      keyProviderInfoSize == 0) {
    const DWORD error = GetLastError();
    CertFreeCertificateContext(cert);
    CertCloseStore(store, 0);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("client certificate has no private-key binding host=%s "
             "selector=thumbprint store=current-user-my error=0x%08lx",
             host.get(), error));
    return 0;
  }

  const int selected =
      msspi_set_mycert(secret->msspi, cert->pbCertEncoded, cert->cbCertEncoded);
  const uint32_t nativeError = msspi_last_error();
  CertFreeCertificateContext(cert);
  CertCloseStore(store, 0);

  if (!selected) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("msspi_set_mycert failed host=%s selector=thumbprint "
             "store=current-user-my error=0x%08x",
             host.get(), nativeError));
    return 0;
  }

  secret->clientCertLoaded = true;
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate selected host=%s selector=thumbprint "
           "store=current-user-my private_key_binding=1",
           host.get()));
  return 1;
#else
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
          ("client certificate selection unavailable host=%s", host.get()));
  return 0;
#endif
}

void LogHandshakeBuffer(GostSecret* aSecret, const char* aDirection,
                        const void* aBuf, int aLen) {
  if (!aSecret || aSecret->handshakeComplete || !aBuf || aLen <= 0) {
    return;
  }

  if (aSecret->redactOutboundHandshake && strcmp(aDirection, "out") == 0) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("TLSBUF direction=out secret=%p len=%d redacted=client-auth",
             aSecret, aLen));
    return;
  }

  static constexpr char kHex[] = "0123456789ABCDEF";
  const auto* bytes = static_cast<const uint8_t*>(aBuf);
  for (int offset = 0; offset < aLen; offset += kTlsDumpChunkSize) {
    const int remaining = aLen - offset;
    const int chunkLen =
        remaining < kTlsDumpChunkSize ? remaining : kTlsDumpChunkSize;
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

  if (!secret->tlsActive) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("DriveHandshake deferred host=%s waiting_for_proxy_tunnel=1",
             host.get()));
    SetWouldBlock();
    return NS_BASE_STREAM_WOULD_BLOCK;
  }

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

  size_t peerCertCount = 0;
  const int peerCertsOk =
      msspi_get_peercerts(secret->msspi, nullptr, nullptr, &peerCertCount);
  const uint32_t peerCertsError = msspi_last_error();
  size_t peerChainCount = 0;
  const int peerChainOk =
      msspi_get_peerchain(secret->msspi, nullptr, nullptr, &peerChainCount);
  const uint32_t peerChainError = msspi_last_error();
  const uint8_t* peerSubject = nullptr;
  size_t peerSubjectLen = 0;
  const uint8_t* peerIssuer = nullptr;
  size_t peerIssuerLen = 0;
  const int peerNamesOk =
      msspi_get_peernames(secret->msspi, &peerSubject, &peerSubjectLen,
                          &peerIssuer, &peerIssuerLen);
  const uint32_t peerNamesError = msspi_last_error();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("server-cert diagnostics host=%s peercerts_ok=%d peercerts_count=%zu "
           "peercerts_error=0x%08x peerchain_ok=%d peerchain_count=%zu "
           "peerchain_error=0x%08x peernames_ok=%d subject_len=%zu "
           "issuer_len=%zu peernames_error=0x%08x state=0x%08x",
           host.get(), peerCertsOk, peerCertCount, peerCertsError, peerChainOk,
           peerChainCount, peerChainError, peerNamesOk, peerSubjectLen,
           peerIssuerLen, peerNamesError, msspi_state(secret->msspi)));

  uint32_t verifyStatus = 0;
  const int verifyOk = msspi_get_verify_status(secret->msspi, &verifyStatus);
  const uint32_t verifyError = msspi_last_error();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("DriveHandshake verify host=%s ok=%d status=0x%08x "
           "error=0x%08x state=0x%08x",
           host.get(), verifyOk, verifyStatus, verifyError,
           msspi_state(secret->msspi)));
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
           "state=0x%08x client_cert_loaded=%d",
           host.get(), static_cast<unsigned int>(tlsVersion), cipherSuite,
           msspi_state(secret->msspi), secret->clientCertLoaded));
  return NS_OK;
}

PRInt32 GostRead(PRFileDesc* aFd, void* aBuf, PRInt32 aAmount) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  if (!secret->tlsActive) {
    PRFileDesc* lower = GetLower(secret);
    if (!lower) {
      return -1;
    }
    const PRInt32 n = lower->methods->read(lower, aBuf, aAmount);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostRead proxy plaintext n=%d amount=%d", n, aAmount));
    return n;
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
                 PRIntervalTime aTimeout) {
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  if (!secret->tlsActive) {
    PRFileDesc* lower = GetLower(secret);
    if (!lower) {
      return -1;
    }
    const PRInt32 n =
        lower->methods->recv(lower, aBuf, aAmount, aFlags, aTimeout);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostRecv proxy plaintext n=%d amount=%d flags=0x%x", n,
             aAmount, aFlags));
    return n;
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

  if (!secret->tlsActive) {
    PRFileDesc* lower = GetLower(secret);
    if (!lower) {
      return -1;
    }
    const PRInt32 n = lower->methods->write(lower, aBuf, aAmount);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostWrite proxy plaintext n=%d amount=%d", n, aAmount));
    return n;
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
  GostSecret* secret = GetSecret(aFd);
  if (!secret) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    return -1;
  }

  if (!secret->tlsActive) {
    PRFileDesc* lower = GetLower(secret);
    if (!lower) {
      return -1;
    }
    const PRInt32 n =
        lower->methods->send(lower, aBuf, aAmount, aFlags, aTimeout);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostSend proxy plaintext n=%d amount=%d flags=0x%x timeout=%u",
             n, aAmount, aFlags, static_cast<unsigned int>(aTimeout)));
    return n;
  }

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

  PRFileDesc* lower = GetLower(secret);
  if (!lower) {
    return -1;
  }

  if (!secret->tlsActive) {
    const PRInt32 rv = lower->methods->available(lower);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostAvailable proxy plaintext rv=%d", rv));
    return rv;
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

  const PRInt32 rv = lower->methods->available(lower);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostAvailable lower rv=%d handshakeComplete=%d", rv,
           secret->handshakeComplete));
  return rv;
}

PRInt16 GostPoll(PRFileDesc* aFd, PRInt16 aInFlags, PRInt16* aOutFlags) {
  GostSecret* secret = GetSecret(aFd);
  PRFileDesc* lower = GetLower(secret);
  if (!secret || !lower) {
    PR_SetError(PR_BAD_DESCRIPTOR_ERROR, 0);
    *aOutFlags = PR_POLL_ERR;
    return aInFlags;
  }

  *aOutFlags = 0;

  if (!secret->tlsActive) {
    const PRInt16 result = lower->methods->poll(lower, aInFlags, aOutFlags);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostPoll proxy plaintext result=0x%04x in=0x%04x out=0x%04x",
             result, aInFlags, *aOutFlags));
    return result;
  }

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

    const PRInt16 result = lower->methods->poll(lower, aInFlags, aOutFlags);
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
  const PRInt16 result = lower->methods->poll(lower, lowerIn, &lowerOut);

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
            ("GostClose MSSPI shutdown host=%s state=0x%08x lower=%p "
             "tlsActive=%d",
             PromiseFlatCString(secret->control->GetHostName()).get(),
             msspi_state(secret->msspi), secret->lower, secret->tlsActive));
    if (secret->tlsActive) {
      (void)msspi_shutdown(secret->msspi);
    }
#ifdef XP_WIN
    RemoveGostClientCertState(secret->msspi);
#endif
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

nsresult GostActivateTLS(PRFileDesc* aFd) {
  PRFileDesc* layer = FindLayer(aFd);
  GostSecret* secret = GetSecret(layer);
  if (!secret || !secret->msspi) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Error,
            ("GostActivateTLS missing GOST layer fd=%p layer=%p", aFd,
             layer));
    return NS_ERROR_FAILURE;
  }

  if (secret->tlsActive) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("GostActivateTLS already active host=%s state=0x%08x",
             PromiseFlatCString(secret->control->GetHostName()).get(),
             msspi_state(secret->msspi)));
    return NS_OK;
  }

  secret->tlsActive = true;
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("GOST TLS activated host=%s after_proxy_tunnel=1 state=0x%08x",
           PromiseFlatCString(secret->control->GetHostName()).get(),
           msspi_state(secret->msspi)));
  return NS_OK;
}

nsresult GostDriveHandshake(PRFileDesc* aFd) {
  PRFileDesc* layer = FindLayer(aFd);
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("GostDriveHandshake fd=%p layer=%p", aFd, layer));
  return layer ? DriveHandshake(layer) : NS_ERROR_FAILURE;
}

nsresult nsGostSSLIOLayerAddToSocket(
    int32_t, const char* aHost, int32_t aPort, nsIProxyInfo* aProxy,
    const OriginAttributes& aOriginAttributes, PRFileDesc* aSocket,
    nsITLSSocketControl** aTlsSocketControl, uint32_t aFlags, uint32_t) {
  NS_ENSURE_ARG_POINTER(aHost);
  NS_ENSURE_ARG_POINTER(aSocket);
  NS_ENSURE_ARG_POINTER(aTlsSocketControl);

  nsAutoCString proxyHost;
  nsAutoCString proxyType;
  bool waitForHttpProxyTunnel = false;
  if (aProxy) {
    nsresult proxyRv = aProxy->GetHost(proxyHost);
    if (NS_FAILED(proxyRv)) {
      return proxyRv;
    }
    if (!proxyHost.IsEmpty()) {
      proxyRv = aProxy->GetType(proxyType);
      if (NS_FAILED(proxyRv)) {
        return proxyRv;
      }
      waitForHttpProxyTunnel = proxyType.EqualsLiteral("http");
    }
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("AddToSocket begin host=%s port=%d socket=%p flags=0x%08x "
           "proxyHost=%s proxyType=%s waitForHttpTunnel=%d",
           aHost, aPort, aSocket, aFlags, proxyHost.get(), proxyType.get(),
           waitForHttpProxyTunnel));

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
  secret->port = aPort;
  secret->tlsActive = !waitForHttpProxyTunnel;
  layer->secret = reinterpret_cast<PRFilePrivate*>(secret);

  if (strcmp(aHost, kStage1MtlsHost) == 0) {
    const char* selector = getenv(kClientCertThumbprintEnv);
    if (selector && *selector) {
      secret->clientCertThumbprint.Assign(selector);
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("AddToSocket mTLS Stage1 host=%s selector=thumbprint present=%d",
             aHost, !secret->clientCertThumbprint.IsEmpty()));
  }

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

  if (configured && strcmp(aHost, kStage1MtlsHost) == 0) {
    configured =
        msspi_set_cert_cb(secret->msspi, SelectStage1ClientCertificate);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
            ("AddToSocket set_cert_cb host=%s ok=%d selector=thumbprint "
             "error=0x%08x state=0x%08x",
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
           "layer=%p lower=%p state=0x%08x tlsActive=%d proxyType=%s",
           aHost, aPort, aSocket, activeLayer, secret->lower,
           msspi_state(secret->msspi), secret->tlsActive, proxyType.get()));
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