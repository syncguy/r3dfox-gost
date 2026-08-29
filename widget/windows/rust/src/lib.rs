/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

mod permission_monitor;

use nserror::{nsresult, NS_OK};
use nsstring::{nsAString, nsString};
use thin_vec::ThinVec;
use xpcom::{xpcom, xpcom_method};

// XP has no Windows toast history.  Keep the component ABI but expose an empty
// history without linking the windows crate or WinRT activation/string APIs.
#[xpcom(implement(nsIAlertsServiceRust), nonatomic)]
struct AlertsServiceRust {}

impl AlertsServiceRust {
    xpcom_method!(get_history => GetHistory(aumid: *const nsAString, result: *mut ThinVec<nsString>));
    fn get_history(
        &self,
        _aumid: &nsAString,
        result: *mut ThinVec<nsString>,
    ) -> Result<(), nsresult> {
        if result.is_null() {
            return Err(nserror::NS_ERROR_INVALID_ARG);
        }

        // SAFETY: XPCOM owns and validates the out parameter.
        unsafe { (&mut *result).clear() };
        Ok(())
    }
}

#[no_mangle]
pub extern "C" fn new_windows_alerts_service(
    iid: *const xpcom::nsIID,
    result: *mut *mut xpcom::reexports::libc::c_void,
) -> nsresult {
    let service = AlertsServiceRust::allocate(InitAlertsServiceRust {});
    // SAFETY: The caller is responsible to pass a valid IID and pointer-to-pointer.
    unsafe { service.QueryInterface(iid, result) }
}
