/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef ToastNotificationLegacy_h_
#define ToastNotificationLegacy_h_

#include "nsIAlertsService.h"
#include "nsIWindowsAlertsService.h"

namespace mozilla {
namespace widget {

class ToastNotificationLegacy final : public nsIWindowsAlertsService,
                                      public nsIAlertsDoNotDisturb {
 public:
  NS_DECL_NSIALERTSSERVICE
  NS_DECL_NSIWINDOWSALERTSSERVICE
  NS_DECL_NSIALERTSDONOTDISTURB
  NS_DECL_ISUPPORTS

  ToastNotificationLegacy();
  nsresult Init();

 protected:
  virtual ~ToastNotificationLegacy();
  bool mSuppressForScreenSharing = false;
};

}  // namespace widget
}  // namespace mozilla

#endif
