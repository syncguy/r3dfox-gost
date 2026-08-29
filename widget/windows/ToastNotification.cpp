/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "ToastNotification.h"

#include "nsError.h"

namespace mozilla {
namespace widget {

NS_IMPL_ISUPPORTS(ToastNotification, nsIAlertsService, nsIWindowsAlertsService,
                  nsIAlertsDoNotDisturb)

ToastNotification::ToastNotification() = default;
ToastNotification::~ToastNotification() = default;

nsresult ToastNotification::Init() { return NS_ERROR_NOT_IMPLEMENTED; }

NS_IMETHODIMP
ToastNotification::GetSuppressForScreenSharing(bool* aRetVal) {
  *aRetVal = mSuppressForScreenSharing;
  return NS_OK;
}

NS_IMETHODIMP
ToastNotification::SetSuppressForScreenSharing(bool aSuppress) {
  mSuppressForScreenSharing = aSuppress;
  return NS_OK;
}

NS_IMETHODIMP ToastNotification::Teardown() { return NS_OK; }

NS_IMETHODIMP ToastNotification::PbmTeardown() { return NS_OK; }

NS_IMETHODIMP
ToastNotification::SetManualDoNotDisturb(bool aDoNotDisturb) {
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
ToastNotification::GetManualDoNotDisturb(bool* aRetVal) {
  if (aRetVal) {
    *aRetVal = false;
  }
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
ToastNotification::ShowAlert(nsIAlertNotification* aAlert,
                             nsIObserver* aAlertListener) {
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
ToastNotification::GetXmlStringForWindowsAlert(nsIAlertNotification* aAlert,
                                               const nsAString& aWindowsTag,
                                               nsAString& aString) {
  aString.Truncate();
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
ToastNotification::HandleWindowsTag(const nsAString& aWindowsTag,
                                    JSContext* aCx, dom::Promise** aPromise) {
  if (aPromise) {
    *aPromise = nullptr;
  }
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
ToastNotification::CloseAlert(const nsAString& aAlertName,
                              bool aContextClosed) {
  return NS_OK;
}

NS_IMETHODIMP
ToastNotification::GetHistory(nsTArray<nsString>& aResult) {
  aResult.Clear();
  return NS_OK;
}

NS_IMETHODIMP
ToastNotification::RemoveAllNotificationsForInstall() {
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP
ToastNotification::IsFullscreen(bool* aRetVal) {
  *aRetVal = false;
  return NS_OK;
}

NS_IMPL_ISUPPORTS_INHERITED(WindowsAlertNotification, AlertNotification,
                            nsIWindowsAlertNotification)

NS_IMETHODIMP WindowsAlertNotification::GetImagePlacement(
    nsIWindowsAlertNotification::ImagePlacement* aImagePlacement) {
  *aImagePlacement = mImagePlacement;
  return NS_OK;
}

NS_IMETHODIMP WindowsAlertNotification::SetImagePlacement(
    nsIWindowsAlertNotification::ImagePlacement aImagePlacement) {
  switch (aImagePlacement) {
    case eHero:
    case eIcon:
    case eInline:
      mImagePlacement = aImagePlacement;
      return NS_OK;
    default:
      return NS_ERROR_INVALID_ARG;
  }
}

NS_IMETHODIMP WindowsAlertNotification::GetImagePathUnchecked(
    nsAString& aImagePathUnchecked) {
  aImagePathUnchecked = mImagePathUnchecked;
  return NS_OK;
}

NS_IMETHODIMP WindowsAlertNotification::SetImagePathUnchecked(
    const nsAString& aImagePathUnchecked) {
  mImagePathUnchecked = aImagePathUnchecked;
  return NS_OK;
}

}  // namespace widget
}  // namespace mozilla
