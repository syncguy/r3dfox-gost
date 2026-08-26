enum class GostCoordinatedClientCertPhase {
  Selecting,
  Selected,
  Declined,
  Failed,
};

struct GostCoordinatedClientCertWaiter {
  MSSPI_HANDLE mMsspi;
  RefPtr<GostSocketControl> mControl;
};

class GostCoordinatedClientCertDecision final {
 public:
  NS_INLINE_DECL_THREADSAFE_REFCOUNTING(GostCoordinatedClientCertDecision)

  GostCoordinatedClientCertDecision(
      const nsACString& aKey, const nsACString& aHost,
      const mozilla::OriginAttributes& aOriginAttributes, uint64_t aBrowserId,
      nsTArray<nsTArray<uint8_t>>&& aCandidates,
      nsTArray<nsTArray<uint8_t>>&& aCANames)
      : mMutex("GostCoordinatedClientCertDecision"),
        mKey(aKey),
        mHost(aHost),
        mOriginAttributes(aOriginAttributes),
        mBrowserId(aBrowserId),
        mCandidates(std::move(aCandidates)),
        mCANames(std::move(aCANames)) {}

  mozilla::Mutex mMutex;
  MSSPI_HANDLE mMsspiForDiagnostics = nullptr;
  nsCString mKey;
  nsCString mHost;
  mozilla::OriginAttributes mOriginAttributes;
  uint64_t mBrowserId;
  nsTArray<nsTArray<uint8_t>> mCandidates;
  nsTArray<nsTArray<uint8_t>> mCANames;
  nsTArray<GostCoordinatedClientCertWaiter> mWaiters;
  GostCoordinatedClientCertPhase mPhase =
      GostCoordinatedClientCertPhase::Selecting;
  nsTArray<uint8_t> mSelectedDER;

 private:
  ~GostCoordinatedClientCertDecision() = default;
};

static mozilla::StaticAutoPtr<
    nsTArray<RefPtr<GostCoordinatedClientCertDecision>>>
    sCoordinatedClientCertDecisions;

bool UseCoordinatedGostClientAuth() {
  const char* mode = getenv("R3DFOX_GOST_CLIENT_AUTH_MODE");
  return !(mode && strcmp(mode, "legacy") == 0);
}

nsCString GostCoordinatedClientCertDecisionKey(
    const nsACString& aHost, int32_t aPort,
    const mozilla::OriginAttributes& aOriginAttributes,
    const nsTArray<nsTArray<uint8_t>>& aCANames) {
  nsCString key(GostClientCertDecisionKey(aHost, aOriginAttributes));
  key.Append('\0');
  AppendIssuerIdentityBytes(key, &aPort, sizeof(aPort));
  const uint32_t count = aCANames.Length();
  AppendIssuerIdentityBytes(key, &count, sizeof(count));
  for (const auto& caName : aCANames) {
    const uint64_t length = static_cast<uint64_t>(caName.Length());
    AppendIssuerIdentityBytes(key, &length, sizeof(length));
    if (!caName.IsEmpty()) {
      AppendIssuerIdentityBytes(key, caName.Elements(), caName.Length());
    }
  }
  return key;
}

bool GostCoordinatedDecisionIsActive(
    GostCoordinatedClientCertDecision* aDecision) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sCoordinatedClientCertDecisions) {
    return false;
  }
  for (const auto& decision : *sCoordinatedClientCertDecisions) {
    if (decision == aDecision) {
      return true;
    }
  }
  return false;
}

RefPtr<GostCoordinatedClientCertDecision>
FindGostCoordinatedDecisionByMsspi(MSSPI_HANDLE aMsspi) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sCoordinatedClientCertDecisions) {
    return nullptr;
  }
  for (const auto& decision : *sCoordinatedClientCertDecisions) {
    mozilla::MutexAutoLock decisionLock(decision->mMutex);
    for (const auto& waiter : decision->mWaiters) {
      if (waiter.mMsspi == aMsspi) {
        return decision;
      }
    }
  }
  return nullptr;
}

RefPtr<GostCoordinatedClientCertDecision>
FindGostCoordinatedDecisionByKey(const nsACString& aKey) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sCoordinatedClientCertDecisions) {
    return nullptr;
  }
  for (const auto& decision : *sCoordinatedClientCertDecisions) {
    if (decision->mKey.Equals(aKey)) {
      return decision;
    }
  }
  return nullptr;
}

void AddGostCoordinatedWaiter(GostCoordinatedClientCertDecision* aDecision,
                              MSSPI_HANDLE aMsspi,
                              GostSocketControl* aControl) {
  mozilla::MutexAutoLock lock(aDecision->mMutex);
  for (const auto& waiter : aDecision->mWaiters) {
    if (waiter.mMsspi == aMsspi) {
      return;
    }
  }
  aDecision->mWaiters.AppendElement(
      GostCoordinatedClientCertWaiter{aMsspi, aControl});
}

void RemoveGostCoordinatedClientCertWaiter(MSSPI_HANDLE aMsspi) {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  if (!sCoordinatedClientCertDecisions) {
    return;
  }
  for (uint32_t decisionIndex = 0;
       decisionIndex < sCoordinatedClientCertDecisions->Length();
       ++decisionIndex) {
    RefPtr<GostCoordinatedClientCertDecision> decision =
        (*sCoordinatedClientCertDecisions)[decisionIndex];
    bool removed = false;
    bool empty = false;
    {
      mozilla::MutexAutoLock decisionLock(decision->mMutex);
      for (uint32_t waiterIndex = 0; waiterIndex < decision->mWaiters.Length();
           ++waiterIndex) {
        if (decision->mWaiters[waiterIndex].mMsspi == aMsspi) {
          decision->mWaiters.RemoveElementAt(waiterIndex);
          removed = true;
          break;
        }
      }
      empty = decision->mWaiters.IsEmpty();
    }
    if (!removed) {
      continue;
    }
    if (empty) {
      sCoordinatedClientCertDecisions->RemoveElementAt(decisionIndex);
    }
    return;
  }
}

bool IsGostCoordinatedClientCertWaiting(MSSPI_HANDLE aMsspi) {
  RefPtr<GostCoordinatedClientCertDecision> decision =
      FindGostCoordinatedDecisionByMsspi(aMsspi);
  if (!decision) {
    return false;
  }
  mozilla::MutexAutoLock lock(decision->mMutex);
  return decision->mPhase == GostCoordinatedClientCertPhase::Selecting;
}

void WakeGostCoordinatedClientCertHandshakes(
    GostCoordinatedClientCertDecision* aDecision) {
  nsCOMPtr<nsIEventTarget> socketThread(
      do_GetService(NS_SOCKETTRANSPORTSERVICE_CONTRACTID));
  if (!socketThread) {
    return;
  }
  RefPtr<GostCoordinatedClientCertDecision> decision(aDecision);
  (void)socketThread->Dispatch(NS_NewRunnableFunction(
      "GostCoordinatedClientAuthResume", [decision]() {
        if (!GostCoordinatedDecisionIsActive(decision)) {
          return;
        }
        nsTArray<RefPtr<GostSocketControl>> controls;
        {
          mozilla::MutexAutoLock lock(decision->mMutex);
          for (const auto& waiter : decision->mWaiters) {
            controls.AppendElement(waiter.mControl);
          }
        }
        for (const auto& control : controls) {
          control->ClientAuthCertificateSelected();
          (void)control->DriveHandshake();
        }
      }));
}

class GostCoordinatedClientAuthDialogCallback final
    : public nsIClientAuthDialogCallback {
 public:
  NS_DECL_THREADSAFE_ISUPPORTS
  NS_DECL_NSICLIENTAUTHDIALOGCALLBACK

  explicit GostCoordinatedClientAuthDialogCallback(
      GostCoordinatedClientCertDecision* aDecision)
      : mDecision(aDecision) {}

 private:
  ~GostCoordinatedClientAuthDialogCallback() = default;
  RefPtr<GostCoordinatedClientCertDecision> mDecision;
};

NS_IMPL_ISUPPORTS(GostCoordinatedClientAuthDialogCallback,
                  nsIClientAuthDialogCallback)

NS_IMETHODIMP GostCoordinatedClientAuthDialogCallback::CertificateChosen(
    nsIX509Cert* aCert,
    nsIClientAuthRememberService::Duration aRememberDuration) {
  if (!GostCoordinatedDecisionIsActive(mDecision)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate stale callback ignored host=%s mode=coordinated",
             mDecision->mHost.get()));
    return NS_OK;
  }

  nsTArray<uint8_t> der;
  if (aCert) {
    nsresult rv = aCert->GetRawDER(der);
    if (NS_FAILED(rv)) {
      {
        mozilla::MutexAutoLock lock(mDecision->mMutex);
        mDecision->mPhase = GostCoordinatedClientCertPhase::Failed;
      }
      WakeGostCoordinatedClientCertHandshakes(mDecision);
      return rv;
    }
  }

  {
    mozilla::MutexAutoLock lock(mDecision->mMutex);
    mDecision->mSelectedDER = der.Clone();
    mDecision->mPhase = aCert ? GostCoordinatedClientCertPhase::Selected
                              : GostCoordinatedClientCertPhase::Declined;
  }

  if (aCert && aRememberDuration != nsIClientAuthRememberService::Once) {
    RememberGostClientCert(mDecision->mKey, der, false);
  }

  WakeGostCoordinatedClientCertHandshakes(mDecision);
  return NS_OK;
}

void OpenGostCoordinatedClientAuthDialog(
    GostCoordinatedClientCertDecision* aDecision) {
  MOZ_ASSERT(NS_IsMainThread());
  RefPtr<GostCoordinatedClientCertDecision> decision(aDecision);
  if (!GostCoordinatedDecisionIsActive(decision)) {
    return;
  }

  nsCOMPtr<nsIX509CertDB> certDB(do_GetService(NS_X509CERTDB_CONTRACTID));
  nsCOMPtr<nsIClientAuthDialogService> dialog(
      do_GetService(NS_CLIENTAUTHDIALOGSERVICE_CONTRACTID));
  if (!certDB || !dialog) {
    {
      mozilla::MutexAutoLock lock(decision->mMutex);
      decision->mPhase = GostCoordinatedClientCertPhase::Failed;
    }
    WakeGostCoordinatedClientCertHandshakes(decision);
    return;
  }

  nsTArray<RefPtr<nsIX509Cert>> certArray;
  for (const auto& der : decision->mCandidates) {
    nsCOMPtr<nsIX509Cert> cert;
    if (NS_SUCCEEDED(certDB->ConstructX509(der, getter_AddRefs(cert))) && cert) {
      certArray.AppendElement(cert);
    }
  }
  if (certArray.IsEmpty()) {
    {
      mozilla::MutexAutoLock lock(decision->mMutex);
      decision->mPhase = GostCoordinatedClientCertPhase::Failed;
    }
    WakeGostCoordinatedClientCertHandshakes(decision);
    return;
  }

  RefPtr<mozilla::dom::BrowsingContext> browsingContext;
  if (decision->mBrowserId) {
    browsingContext = mozilla::dom::BrowsingContext::GetCurrentTopByBrowserId(
        decision->mBrowserId);
  }
  RefPtr<nsIClientAuthDialogCallback> callback(
      new GostCoordinatedClientAuthDialogCallback(decision));
  nsresult rv = dialog->ChooseCertificateWithDefaultRememberDuration(
      decision->mHost, certArray, browsingContext, decision->mCANames,
      nsIClientAuthRememberService::Once, callback);
  if (NS_FAILED(rv)) {
    {
      mozilla::MutexAutoLock lock(decision->mMutex);
      decision->mPhase = GostCoordinatedClientCertPhase::Failed;
    }
    WakeGostCoordinatedClientCertHandshakes(decision);
  }
}

int ConsumeGostCoordinatedClientCertDecision(
    GostSecret* aSecret, const nsACString& aHost,
    GostCoordinatedClientCertDecision* aDecision) {
  GostCoordinatedClientCertPhase phase;
  nsTArray<uint8_t> der;
  {
    mozilla::MutexAutoLock lock(aDecision->mMutex);
    phase = aDecision->mPhase;
    der = aDecision->mSelectedDER.Clone();
  }
  if (phase == GostCoordinatedClientCertPhase::Selecting) {
    return -1;
  }
  if (phase == GostCoordinatedClientCertPhase::Declined) {
    RemoveGostCoordinatedClientCertWaiter(aSecret->msspi);
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate dialog completed host=%s selected=0 "
             "mode=coordinated",
             PromiseFlatCString(aHost).get()));
    return 1;
  }
  if (phase == GostCoordinatedClientCertPhase::Failed || der.IsEmpty()) {
    RemoveGostCoordinatedClientCertWaiter(aSecret->msspi);
    return 0;
  }
  const int selected =
      msspi_set_mycert(aSecret->msspi, der.Elements(), der.Length());
  RemoveGostCoordinatedClientCertWaiter(aSecret->msspi);
  if (selected) {
    aSecret->clientCertLoaded = true;
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate dialog completed host=%s selected=%d "
           "mode=coordinated",
           PromiseFlatCString(aHost).get(), selected ? 1 : 0));
  return selected ? 1 : 0;
}

int SelectCoordinatedFirefoxGostClientCertificate(GostSecret* aSecret,
                                                  const nsACString& aHost) {
  RefPtr<GostCoordinatedClientCertDecision> decision =
      FindGostCoordinatedDecisionByMsspi(aSecret->msspi);
  if (decision) {
    return ConsumeGostCoordinatedClientCertDecision(aSecret, aHost, decision);
  }

  nsTArray<nsTArray<uint8_t>> caNames;
  if (!CollectGostCANames(aSecret->msspi, caNames)) {
    return 0;
  }
  const mozilla::OriginAttributes originAttributes(
      aSecret->control->GetOriginAttributes());
  const nsCString decisionKey(GostCoordinatedClientCertDecisionKey(
      aHost, aSecret->port, originAttributes, caNames));

  nsTArray<uint8_t> rememberedDER;
  bool rememberedDeclined = false;
  if (FindRememberedGostClientCert(decisionKey, rememberedDER,
                                   rememberedDeclined) &&
      !rememberedDeclined && !rememberedDER.IsEmpty()) {
    const int selected = msspi_set_mycert(
        aSecret->msspi, rememberedDER.Elements(), rememberedDER.Length());
    if (selected) {
      aSecret->clientCertLoaded = true;
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate remembered host=%s selected=%d "
             "scope=session mode=coordinated",
             PromiseFlatCString(aHost).get(), selected ? 1 : 0));
    return selected ? 1 : 0;
  }

  decision = FindGostCoordinatedDecisionByKey(decisionKey);
  if (decision) {
    AddGostCoordinatedWaiter(decision, aSecret->msspi, aSecret->control);
    GostCoordinatedClientCertPhase phase;
    {
      mozilla::MutexAutoLock lock(decision->mMutex);
      phase = decision->mPhase;
    }
    if (phase != GostCoordinatedClientCertPhase::Selecting) {
      return ConsumeGostCoordinatedClientCertDecision(aSecret, aHost, decision);
    }
    aSecret->control->ClientAuthCertificateRequested();
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate joined existing decision host=%s "
             "mode=coordinated",
             PromiseFlatCString(aHost).get()));
    return -1;
  }

  nsTArray<nsTArray<uint8_t>> candidates;
  if (!CollectGostClientCertCandidates(caNames, candidates)) {
    return 0;
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate candidates host=%s count=%zu mode=coordinated",
           PromiseFlatCString(aHost).get(), candidates.Length()));
  if (candidates.IsEmpty()) {
    return 1;
  }

  uint64_t browserId = 0;
  (void)aSecret->control->GetBrowserId(&browserId);
  decision = new GostCoordinatedClientCertDecision(
      decisionKey, aHost, originAttributes, browserId, std::move(candidates),
      std::move(caNames));
  AddGostCoordinatedWaiter(decision, aSecret->msspi, aSecret->control);
  {
    mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
    if (!sCoordinatedClientCertDecisions) {
      sCoordinatedClientCertDecisions =
          new nsTArray<RefPtr<GostCoordinatedClientCertDecision>>();
    }
    sCoordinatedClientCertDecisions->AppendElement(decision);
  }

  aSecret->control->ClientAuthCertificateRequested();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate dialog requested host=%s mode=coordinated",
           PromiseFlatCString(aHost).get()));
  (void)NS_DispatchToMainThread(NS_NewRunnableFunction(
      "GostCoordinatedClientAuthDialog",
      [decision]() { OpenGostCoordinatedClientAuthDialog(decision); }));
  return -1;
}
