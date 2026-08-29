/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef ToastNotification_h_
#define ToastNotification_h_

#include "nsIAlertsService.h"
#include "nsIWindowsAlertsService.h"
#include "mozilla/AlertNotification.h"

namespace mozilla {
namespace widget {

class WindowsAlertNotification final : public AlertNotification,
                                       public nsIWindowsAlertNotification {
 public:
  NS_DECL_NSIWINDOWSALERTNOTIFICATION
  NS_FORWARD_NSIALERTNOTIFICATION(AlertNotification::)
  NS_DECL_ISUPPORTS_INHERITED

  WindowsAlertNotification() = default;

 protected:
  virtual ~WindowsAlertNotification() = default;
  nsIWindowsAlertNotification::ImagePlacement mImagePlacement = eInline;
  nsString mImagePathUnchecked;
};

// XP-only legacy backend.  Keep the XPCOM contract available so callers can
// probe it, but never instantiate WinRT or carry WinRT imports into libxul.
class ToastNotification final : public nsIWindowsAlertsService,
                                public nsIAlertsDoNotDisturb {
 public:
  NS_DECL_NSIALERTSSERVICE
  NS_DECL_NSIWINDOWSALERTSSERVICE
  NS_DECL_NSIALERTSDONOTDISTURB
  NS_DECL_ISUPPORTS

  ToastNotification();
  nsresult Init();

 protected:
  virtual ~ToastNotification();
  bool mSuppressForScreenSharing = false;
};

}  // namespace widget
}  // namespace mozilla

#endif
