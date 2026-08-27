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

struct GostPositiveOnceLease {
  nsCString mKey;
  uint64_t mBrowserId = 0;
  nsTArray<uint8_t> mSelectedDER;
  mozilla::TimeStamp mExpiresAt;
  uint64_t mGeneration = 0;
};

class GostCoordinatedClientCertDecision final {
 public:
  NS_INLINE_DECL_THREADSAFE_REFCOUNTING(GostCoordinatedClientCertDecision)

  GostCoordinatedClientCertDecision(
      uint64_t aDecisionId, const nsACString& aKey, const nsACString& aHost,
      const mozilla::OriginAttributes& aOriginAttributes, uint64_t aBrowserId,
      nsTArray<nsTArray<uint8_t>>&& aCandidates,
      nsTArray<nsTArray<uint8_t>>&& aCANames)
      : mMutex("GostCoordinatedClientCertDecision"),
        mDecisionId(aDecisionId),
        mKey(aKey),
        mHost(aHost),
        mOriginAttributes(aOriginAttributes),
        mBrowserId(aBrowserId),
        mCandidates(std::move(aCandidates)),
        mCANames(std::move(aCANames)) {}

  mozilla::Mutex mMutex;
  uint64_t mDecisionId;
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
static mozilla::StaticAutoPtr<nsTArray<GostPositiveOnceLease>>
    sGostPositiveOnceLeases;
static mozilla::StaticAutoPtr<nsTArray<MSSPI_HANDLE>>
    sGostClientAuthClosingHandles;
static uint64_t sNextGostClientAuthDecisionId = 1;
static uint64_t sNextGostPositiveOnceLeaseGeneration = 1;
static constexpr double kGostPositiveOnceLeaseIdleSeconds = 5.0;

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

uint64_t NextGostClientAuthDecisionId() {
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  return sNextGostClientAuthDecisionId++;
}

void PruneGostPositiveOnceLeasesLocked(const mozilla::TimeStamp& aNow) {
  if (!sGostPositiveOnceLeases) {
    return;
  }
  for (uint32_t i = sGostPositiveOnceLeases->Length(); i > 0; --i) {
    if ((*sGostPositiveOnceLeases)[i - 1].mExpiresAt <= aNow) {
      sGostPositiveOnceLeases->RemoveElementAt(i - 1);
    }
  }
}

void StoreGostPositiveOnceLease(const nsACString& aKey,
                                const nsACString& aHost,
                                uint64_t aBrowserId,
                                const nsTArray<uint8_t>& aDER) {
  if (!aBrowserId || aDER.IsEmpty()) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate once lease skipped host=%s browser_id=%llu",
             PromiseFlatCString(aHost).get(),
             static_cast<unsigned long long>(aBrowserId)));
    return;
  }

  const mozilla::TimeStamp now = mozilla::TimeStamp::Now();
  const mozilla::TimeStamp expires =
      now + mozilla::TimeDuration::FromSeconds(kGostPositiveOnceLeaseIdleSeconds);
  uint64_t generation = 0;
  {
    mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
    PruneGostPositiveOnceLeasesLocked(now);
    if (!sGostPositiveOnceLeases) {
      sGostPositiveOnceLeases = new nsTArray<GostPositiveOnceLease>();
    }
    for (auto& lease : *sGostPositiveOnceLeases) {
      if (lease.mBrowserId == aBrowserId && lease.mKey.Equals(aKey)) {
        lease.mSelectedDER = aDER.Clone();
        lease.mExpiresAt = expires;
        lease.mGeneration = sNextGostPositiveOnceLeaseGeneration++;
        generation = lease.mGeneration;
        break;
      }
    }
    if (!generation) {
      GostPositiveOnceLease lease;
      lease.mKey = aKey;
      lease.mBrowserId = aBrowserId;
      lease.mSelectedDER = aDER.Clone();
      lease.mExpiresAt = expires;
      lease.mGeneration = sNextGostPositiveOnceLeaseGeneration++;
      generation = lease.mGeneration;
      sGostPositiveOnceLeases->AppendElement(std::move(lease));
    }
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate once lease stored host=%s browser_id=%llu "
           "generation=%llu idle_ms=5000",
           PromiseFlatCString(aHost).get(),
           static_cast<unsigned long long>(aBrowserId),
           static_cast<unsigned long long>(generation)));
}

bool FindGostPositiveOnceLease(const nsACString& aKey,
                               const nsACString& aHost, uint64_t aBrowserId,
                               nsTArray<uint8_t>& aDER,
                               uint64_t& aGeneration) {
  aGeneration = 0;
  if (!aBrowserId) {
    return false;
  }

  const mozilla::TimeStamp now = mozilla::TimeStamp::Now();
  const mozilla::TimeStamp expires =
      now + mozilla::TimeDuration::FromSeconds(kGostPositiveOnceLeaseIdleSeconds);
  {
    mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
    PruneGostPositiveOnceLeasesLocked(now);
    if (!sGostPositiveOnceLeases) {
      return false;
    }
    for (auto& lease : *sGostPositiveOnceLeases) {
      if (lease.mBrowserId == aBrowserId && lease.mKey.Equals(aKey)) {
        aDER = lease.mSelectedDER.Clone();
        lease.mExpiresAt = expires;
        aGeneration = lease.mGeneration;
        break;
      }
    }
  }

  if (!aGeneration) {
    return false;
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate once lease reused host=%s browser_id=%llu "
           "generation=%llu idle_ms=5000",
           PromiseFlatCString(aHost).get(),
           static_cast<unsigned long long>(aBrowserId),
           static_cast<unsigned long long>(aGeneration)));
  return true;
}

void MarkGostClientAuthMsspiClosing(MSSPI_HANDLE aMsspi) {
  if (!aMsspi) {
    return;
  }
  bool added = false;
  {
    mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
    if (!sGostClientAuthClosingHandles) {
      sGostClientAuthClosingHandles = new nsTArray<MSSPI_HANDLE>();
    }
    if (!sGostClientAuthClosingHandles->Contains(aMsspi)) {
      sGostClientAuthClosingHandles->AppendElement(aMsspi);
      added = true;
    }
  }
  if (added) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client auth handle closing handle=%p", aMsspi));
  }
}

bool IsGostClientAuthMsspiClosing(MSSPI_HANDLE aMsspi) {
  if (!aMsspi) {
    return false;
  }
  mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
  return sGostClientAuthClosingHandles &&
         sGostClientAuthClosingHandles->Contains(aMsspi);
}

void UnmarkGostClientAuthMsspiClosing(MSSPI_HANDLE aMsspi) {
  if (!aMsspi) {
    return;
  }
  bool removed = false;
  {
    mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
    if (sGostClientAuthClosingHandles) {
      removed = sGostClientAuthClosingHandles->RemoveElement(aMsspi);
    }
  }
  if (removed) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client auth handle closed handle=%p", aMsspi));
  }
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
  uint32_t waiterCount = 0;
  {
    mozilla::MutexAutoLock lock(aDecision->mMutex);
    for (const auto& waiter : aDecision->mWaiters) {
      if (waiter.mMsspi == aMsspi) {
        return;
      }
    }
    aDecision->mWaiters.AppendElement(
        GostCoordinatedClientCertWaiter{aMsspi, aControl});
    waiterCount = aDecision->mWaiters.Length();
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client auth waiter added host=%s decision=%llu handle=%p "
           "waiters=%u",
           aDecision->mHost.get(),
           static_cast<unsigned long long>(aDecision->mDecisionId), aMsspi,
           waiterCount));
}

void RemoveGostCoordinatedClientCertWaiter(MSSPI_HANDLE aMsspi,
                                            const char* aReason = "consume") {
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
    uint32_t waiterCount = 0;
    GostCoordinatedClientCertPhase phase =
        GostCoordinatedClientCertPhase::Failed;
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
      waiterCount = decision->mWaiters.Length();
      empty = decision->mWaiters.IsEmpty();
      phase = decision->mPhase;
    }
    if (!removed) {
      continue;
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client auth waiter removed host=%s decision=%llu handle=%p "
             "reason=%s waiters=%u",
             decision->mHost.get(),
             static_cast<unsigned long long>(decision->mDecisionId), aMsspi,
             aReason ? aReason : "unknown", waiterCount));
    if (empty) {
      MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
              ("client auth decision removed host=%s decision=%llu "
               "reason=no-waiters phase=%u",
               decision->mHost.get(),
               static_cast<unsigned long long>(decision->mDecisionId),
               static_cast<unsigned int>(phase)));
      sCoordinatedClientCertDecisions->RemoveElementAt(decisionIndex);
    }
    return;
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Debug,
          ("client auth waiter cleanup no-op handle=%p reason=%s", aMsspi,
           aReason ? aReason : "unknown"));
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
            ("client certificate stale callback ignored host=%s decision=%llu "
             "mode=coordinated",
             mDecision->mHost.get(),
             static_cast<unsigned long long>(mDecision->mDecisionId)));
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

  if (aCert) {
    if (aRememberDuration == nsIClientAuthRememberService::Once) {
      StoreGostPositiveOnceLease(mDecision->mKey, mDecision->mHost,
                                 mDecision->mBrowserId, der);
    } else {
      RememberGostClientCert(mDecision->mKey, der, false);
    }
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client auth decision resolved host=%s decision=%llu selected=%d "
           "remember=%u browser_id=%llu",
           mDecision->mHost.get(),
           static_cast<unsigned long long>(mDecision->mDecisionId),
           aCert ? 1 : 0, static_cast<unsigned int>(aRememberDuration),
           static_cast<unsigned long long>(mDecision->mBrowserId)));
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
  uint64_t decisionId = 0;
  {
    mozilla::MutexAutoLock lock(aDecision->mMutex);
    phase = aDecision->mPhase;
    der = aDecision->mSelectedDER.Clone();
    decisionId = aDecision->mDecisionId;
  }
  if (phase == GostCoordinatedClientCertPhase::Selecting) {
    return -1;
  }
  if (phase == GostCoordinatedClientCertPhase::Declined) {
    RemoveGostCoordinatedClientCertWaiter(aSecret->msspi, "declined-consume");
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate dialog completed host=%s decision=%llu "
             "selected=0 mode=coordinated",
             PromiseFlatCString(aHost).get(),
             static_cast<unsigned long long>(decisionId)));
    return 1;
  }
  if (phase == GostCoordinatedClientCertPhase::Failed || der.IsEmpty()) {
    RemoveGostCoordinatedClientCertWaiter(aSecret->msspi, "failed-consume");
    return 0;
  }
  const int selected =
      msspi_set_mycert(aSecret->msspi, der.Elements(), der.Length());
  RemoveGostCoordinatedClientCertWaiter(aSecret->msspi, "selected-consume");
  if (selected) {
    aSecret->clientCertLoaded = true;
  }
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate dialog completed host=%s decision=%llu "
           "selected=%d mode=coordinated",
           PromiseFlatCString(aHost).get(),
           static_cast<unsigned long long>(decisionId), selected ? 1 : 0));
  return selected ? 1 : 0;
}

int SelectCoordinatedFirefoxGostClientCertificate(GostSecret* aSecret,
                                                  const nsACString& aHost) {
  if (IsGostClientAuthMsspiClosing(aSecret->msspi)) {
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate coordinated callback ignored reason=closing "
             "host=%s handle=%p",
             PromiseFlatCString(aHost).get(), aSecret->msspi));
    return 0;
  }

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
  uint64_t browserId = 0;
  (void)aSecret->control->GetBrowserId(&browserId);

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate request host=%s ca_count=%zu browser_id=%llu "
           "mode=coordinated",
           PromiseFlatCString(aHost).get(), caNames.Length(),
           static_cast<unsigned long long>(browserId)));

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
    uint64_t decisionId = 0;
    {
      mozilla::MutexAutoLock lock(decision->mMutex);
      phase = decision->mPhase;
      decisionId = decision->mDecisionId;
    }
    if (phase != GostCoordinatedClientCertPhase::Selecting) {
      return ConsumeGostCoordinatedClientCertDecision(aSecret, aHost, decision);
    }
    aSecret->control->ClientAuthCertificateRequested();
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate joined existing decision host=%s "
             "decision=%llu mode=coordinated",
             PromiseFlatCString(aHost).get(),
             static_cast<unsigned long long>(decisionId)));
    return -1;
  }

  nsTArray<uint8_t> leasedDER;
  uint64_t leaseGeneration = 0;
  if (FindGostPositiveOnceLease(decisionKey, aHost, browserId, leasedDER,
                                leaseGeneration) &&
      !leasedDER.IsEmpty()) {
    const int selected = msspi_set_mycert(aSecret->msspi, leasedDER.Elements(),
                                          leasedDER.Length());
    if (selected) {
      aSecret->clientCertLoaded = true;
    }
    MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
            ("client certificate leased host=%s selected=%d scope=once "
             "generation=%llu browser_id=%llu mode=coordinated",
             PromiseFlatCString(aHost).get(), selected ? 1 : 0,
             static_cast<unsigned long long>(leaseGeneration),
             static_cast<unsigned long long>(browserId)));
    return selected ? 1 : 0;
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

  const uint64_t decisionId = NextGostClientAuthDecisionId();
  decision = new GostCoordinatedClientCertDecision(
      decisionId, decisionKey, aHost, originAttributes, browserId,
      std::move(candidates), std::move(caNames));
  AddGostCoordinatedWaiter(decision, aSecret->msspi, aSecret->control);
  {
    mozilla::StaticMutexAutoLock lock(sClientCertSelectionMutex);
    if (!sCoordinatedClientCertDecisions) {
      sCoordinatedClientCertDecisions =
          new nsTArray<RefPtr<GostCoordinatedClientCertDecision>>();
    }
    sCoordinatedClientCertDecisions->AppendElement(decision);
  }

  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client auth decision created host=%s decision=%llu browser_id=%llu "
           "mode=coordinated",
           PromiseFlatCString(aHost).get(),
           static_cast<unsigned long long>(decisionId),
           static_cast<unsigned long long>(browserId)));
  aSecret->control->ClientAuthCertificateRequested();
  MOZ_LOG(gGostTLSLog, mozilla::LogLevel::Info,
          ("client certificate dialog requested host=%s decision=%llu "
           "mode=coordinated",
           PromiseFlatCString(aHost).get(),
           static_cast<unsigned long long>(decisionId)));
  (void)NS_DispatchToMainThread(NS_NewRunnableFunction(
      "GostCoordinatedClientAuthDialog",
      [decision]() { OpenGostCoordinatedClientAuthDialog(decision); }));
  return -1;
}
