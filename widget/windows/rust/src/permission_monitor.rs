/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#[cfg(not(moz_xp_compat))]
use std::cell::RefCell;

#[cfg(not(moz_xp_compat))]
use moz_task::RunnableBuilder;
use nserror::{nsresult, NS_OK};
use nsstring::nsAString;
#[cfg(not(moz_xp_compat))]
use nsstring::nsString;
#[cfg(not(moz_xp_compat))]
use windows::core::Ref;
#[cfg(not(moz_xp_compat))]
use windows::Foundation::TypedEventHandler;
#[cfg(not(moz_xp_compat))]
use windows::Security::Authorization::AppCapabilityAccess::{
    AppCapability, AppCapabilityAccessChangedEventArgs,
};
#[cfg(not(moz_xp_compat))]
use xpcom::interfaces::nsIObserverService;
use xpcom::{xpcom, xpcom_method};

#[cfg(not(moz_xp_compat))]
struct MonitorState {
    capability: AppCapability,
    token: i64,
}

#[cfg(not(moz_xp_compat))]
#[xpcom(implement(nsIPermissionMonitor), nonatomic)]
struct PermissionMonitor {
    monitor_state: RefCell<Option<MonitorState>>,
}

#[cfg(moz_xp_compat)]
#[xpcom(implement(nsIPermissionMonitor), nonatomic)]
struct PermissionMonitor {}

impl PermissionMonitor {
    xpcom_method!(start_monitoring => StartMonitoring(capability_name: *const nsAString));

    #[cfg(not(moz_xp_compat))]
    fn start_monitoring(&self, capability_name: &nsAString) -> Result<(), nsresult> {
        if self.monitor_state.borrow().is_some() {
            return Ok(());
        }

        let capability =
            match AppCapability::Create(&windows::core::HSTRING::from_wide(&capability_name[..])) {
                Ok(c) => c,
                Err(_) => return Err(nserror::NS_ERROR_FAILURE),
            };

        let capability_name_nsstring = nsString::from(&capability_name[..]);

        let handler = TypedEventHandler::new(
            move |_: Ref<AppCapability>, _: Ref<AppCapabilityAccessChangedEventArgs>| {
                let name = capability_name_nsstring.clone();
                if let Ok(main_thread) = moz_task::get_main_thread() {
                    RunnableBuilder::new("PermissionMonitor::notify", move || {
                        if let Ok(obs_svc) =
                            xpcom::components::Observer::service::<nsIObserverService>()
                        {
                            unsafe {
                                obs_svc.NotifyObservers(
                                    std::ptr::null(),
                                    c"system-permission-changed".as_ptr(),
                                    name.as_ptr(),
                                );
                            }
                        }
                    })
                    .dispatch(main_thread.coerce())
                    .ok();
                }

                Ok(())
            },
        );

        let token = match capability.AccessChanged(&handler) {
            Ok(t) => t,
            Err(_) => return Err(nserror::NS_ERROR_FAILURE),
        };

        *self.monitor_state.borrow_mut() = Some(MonitorState { capability, token });
        Ok(())
    }

    #[cfg(moz_xp_compat)]
    fn start_monitoring(&self, _capability_name: &nsAString) -> Result<(), nsresult> {
        Err(nserror::NS_ERROR_NOT_IMPLEMENTED)
    }

    #[cfg(not(moz_xp_compat))]
    fn stop_monitoring(&self) {
        if let Some(state) = self.monitor_state.borrow_mut().take() {
            let _ = state.capability.RemoveAccessChanged(state.token);
        }
    }
}

#[cfg(not(moz_xp_compat))]
impl Drop for PermissionMonitor {
    fn drop(&mut self) {
        self.stop_monitoring();
    }
}

#[no_mangle]
pub extern "C" fn new_permission_monitor(
    iid: *const xpcom::nsIID,
    result: *mut *mut xpcom::reexports::libc::c_void,
) -> nsresult {
    #[cfg(not(moz_xp_compat))]
    let monitor = PermissionMonitor::allocate(InitPermissionMonitor {
        monitor_state: RefCell::new(None),
    });

    #[cfg(moz_xp_compat)]
    let monitor = PermissionMonitor::allocate(InitPermissionMonitor {});

    unsafe { monitor.QueryInterface(iid, result) }
}
