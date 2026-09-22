// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

use std::{
    io::{Error, Result},
    net::IpAddr,
    ptr,
};

#[cfg(not(moz_xp_compat))]
use std::{ffi::CStr, slice};

use windows::Win32::{
    NetworkManagement::IpHelper::GetBestInterfaceEx,
    Networking::WinSock::{
        AF_INET, AF_INET6, IN_ADDR, IN_ADDR_0, IN6_ADDR, IN6_ADDR_0, SOCKADDR, SOCKADDR_IN,
        SOCKADDR_IN6, SOCKADDR_INET,
    },
};

#[cfg(moz_xp_compat)]
use windows::Win32::{
    Foundation::ERROR_BUFFER_OVERFLOW,
    NetworkManagement::IpHelper::{
        GET_ADAPTERS_ADDRESSES_FLAGS, GetAdaptersAddresses, IP_ADAPTER_ADDRESSES_LH,
    },
};

#[cfg(not(moz_xp_compat))]
use windows::Win32::NetworkManagement::{
    IpHelper::{
        FreeMibTable, GetIpInterfaceTable, MIB_IPINTERFACE_ROW, MIB_IPINTERFACE_TABLE,
        if_indextoname,
    },
    Ndis::IF_MAX_STRING_SIZE,
};

use crate::default_err;

#[cfg(not(moz_xp_compat))]
struct MibTablePtr(*mut MIB_IPINTERFACE_TABLE);

#[cfg(not(moz_xp_compat))]
impl MibTablePtr {
    const fn mut_ptr_ptr(&mut self) -> *mut *mut MIB_IPINTERFACE_TABLE {
        ptr::from_mut(&mut self.0)
    }
}

#[cfg(not(moz_xp_compat))]
impl Default for MibTablePtr {
    fn default() -> Self {
        Self(ptr::null_mut())
    }
}

#[cfg(not(moz_xp_compat))]
impl Drop for MibTablePtr {
    fn drop(&mut self) {
        if !self.0.is_null() {
            // Free the memory allocated by GetIpInterfaceTable.
            unsafe {
                FreeMibTable(self.0.cast());
            }
        }
    }
}

#[cfg(moz_xp_compat)]
fn interface_and_mtu_for_index(remote: IpAddr, idx: u32) -> Result<(String, usize)> {
    let family = if remote.is_ipv4() { AF_INET } else { AF_INET6 };
    let flags = GET_ADAPTERS_ADDRESSES_FLAGS(0);
    let mut size = 15 * 1024;

    for _ in 0..3 {
        let word_size = std::mem::size_of::<u64>();
        let words = (size as usize + word_size - 1) / word_size;
        let mut storage = vec![0u64; words];
        let adapters = storage.as_mut_ptr().cast::<IP_ADAPTER_ADDRESSES_LH>();

        let res = unsafe {
            GetAdaptersAddresses(family.0.into(), flags, None, Some(adapters), &mut size)
        };
        if res == ERROR_BUFFER_OVERFLOW.0 {
            continue;
        }
        if res != 0 {
            return Err(Error::from_raw_os_error(
                res.try_into().unwrap_or(i32::MAX),
            ));
        }

        let mut adapter = adapters;
        while !adapter.is_null() {
            let current = unsafe { &*adapter };
            let adapter_idx = if remote.is_ipv4() {
                unsafe { current.Anonymous1.Anonymous.IfIndex }
            } else {
                current.Ipv6IfIndex
            };

            if adapter_idx == idx {
                let mtu = current.Mtu.try_into().map_err(|_| default_err())?;
                if current.AdapterName.is_null() {
                    return Err(default_err());
                }
                let name = unsafe { current.AdapterName.to_string() }.map_err(Error::other)?;
                return Ok((name, mtu));
            }

            adapter = current.Next;
        }

        return Err(default_err());
    }

    Err(default_err())
}

#[cfg(not(moz_xp_compat))]
fn interface_and_mtu_for_index(remote: IpAddr, idx: u32) -> Result<(String, usize)> {
    // Get a list of all interfaces with associated metadata.
    let mut if_table = MibTablePtr::default();
    // GetIpInterfaceTable allocates memory, which MibTablePtr::drop will free.
    let family = if remote.is_ipv4() { AF_INET } else { AF_INET6 };
    let res = unsafe { GetIpInterfaceTable(family, if_table.mut_ptr_ptr()) };
    if res.is_err() {
        return Err(Error::from_raw_os_error(
            res.0.try_into().unwrap_or(i32::MAX),
        ));
    }
    // Make a slice
    let ifaces = unsafe {
        slice::from_raw_parts::<MIB_IPINTERFACE_ROW>(
            &raw const (*if_table.0).Table[0],
            (*if_table.0).NumEntries as usize,
        )
    };

    // Find the local interface matching `idx`.
    for iface in ifaces {
        if iface.InterfaceIndex == idx {
            // Get the MTU.
            let mtu: usize = iface.NlMtu.try_into().map_err(|_| default_err())?;
            // Get the interface name.
            let mut interfacename = [0u8; IF_MAX_STRING_SIZE as usize];
            // if_indextoname writes into the provided buffer.
            if unsafe { if_indextoname(iface.InterfaceIndex, &mut interfacename).is_null() } {
                return Err(default_err());
            }
            // Convert the interface name to a Rust string.
            let name = CStr::from_bytes_until_nul(interfacename.as_ref())
                .map_err(|_| default_err())?
                .to_str()
                .map_err(Error::other)?
                .to_string();
            // We found our interface information.
            return Ok((name, mtu));
        }
    }
    Err(default_err())
}

pub fn interface_and_mtu_impl(remote: IpAddr) -> Result<(String, usize)> {
    // Convert remote to Windows SOCKADDR_INET format. The SOCKADDR_INET union contains an IPv4 or
    // an IPv6 address.
    //
    // See https://learn.microsoft.com/en-us/windows/win32/api/ws2ipdef/ns-ws2ipdef-sockaddr_inet
    let dst = match remote {
        IpAddr::V4(ip) => {
            // Initialize the `SOCKADDR_IN` variant of `SOCKADDR_INET` based on `ip`.
            SOCKADDR_INET {
                Ipv4: SOCKADDR_IN {
                    sin_family: AF_INET,
                    sin_addr: IN_ADDR {
                        S_un: IN_ADDR_0 {
                            S_addr: u32::to_be(ip.into()),
                        },
                    },
                    ..Default::default()
                },
            }
        }
        IpAddr::V6(ip) => {
            // Initialize the `SOCKADDR_IN6` variant of `SOCKADDR_INET` based on `ip`.
            SOCKADDR_INET {
                Ipv6: SOCKADDR_IN6 {
                    sin6_family: AF_INET6,
                    sin6_addr: IN6_ADDR {
                        u: IN6_ADDR_0 { Byte: ip.octets() },
                    },
                    ..Default::default()
                },
            }
        }
    };

    // Get the interface index of the best outbound interface towards `dst`.
    let mut idx = 0;
    let res = unsafe {
        // We're now casting `&dst` to a `SOCKADDR` pointer. This is OK based on
        // https://learn.microsoft.com/en-us/windows/win32/winsock/sockaddr-2.
        // With that, we call `GetBestInterfaceEx` to get the interface index into `idx`.
        // See https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getbestinterfaceex
        GetBestInterfaceEx(
            ptr::from_ref(&dst).cast::<SOCKADDR>(),
            ptr::from_mut(&mut idx),
        )
    };
    if res != 0 {
        return Err(Error::from_raw_os_error(res.try_into().unwrap_or(i32::MAX)));
    }

    interface_and_mtu_for_index(remote, idx)
}
