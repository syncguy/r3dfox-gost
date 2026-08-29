/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

use nserror::{nsresult, NS_OK};
use nsstring::nsAString;
use xpcom::{xpcom, xpcom_method};

// AppCapability is a WinRT facility with no XP equivalent.  Keep the XPCOM
// object available, but report the capability as unsupported at runtime.
#[xpcom(implement(nsIPermissionMonitor), nonatomic)]
struct PermissionMonitor {}

impl PermissionMonitor {
    xpcom_method!(start_monitoring => StartMonitoring(capability_name: *const nsAString));
    fn start_monitoring(&self, _capability_name: &nsAString) -> Result<(), nsresult> {
        Err(nserror::NS_ERROR_NOT_IMPLEMENTED)
    }
}

#[no_mangle]
pub extern "C" fn new_permission_monitor(
    iid: *const xpcom::nsIID,
    result: *mut *mut xpcom::reexports::libc::c_void,
) -> nsresult {
    let monitor = PermissionMonitor::allocate(InitPermissionMonitor {});
    // SAFETY: The caller is responsible to pass a valid IID and pointer-to-pointer.
    unsafe { monitor.QueryInterface(iid, result) }
}
