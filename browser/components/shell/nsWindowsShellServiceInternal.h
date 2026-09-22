/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef nswindowsshellserviceinternal_h_
#define nswindowsshellserviceinternal_h_

#include "ErrorList.h"
#include "nsStringFwd.h"
#include "nsTArray.h"
#include "nsIFile.h"

#include <objbase.h>
#include <shlobj.h>

#ifdef MOZ_XP_COMPAT
static inline HRESULT XPCompatSHGetKnownFolderPath(REFKNOWNFOLDERID aFolderId,
                                                    DWORD aFlags,
                                                    HANDLE aToken,
                                                    PWSTR* aPath) {
  if (!aPath) {
    return E_INVALIDARG;
  }
  *aPath = nullptr;

  int csidl;
  if (IsEqualGUID(aFolderId, FOLDERID_CommonStartMenu)) {
    csidl = CSIDL_COMMON_STARTMENU;
  } else if (IsEqualGUID(aFolderId, FOLDERID_StartMenu)) {
    csidl = CSIDL_STARTMENU;
  } else if (IsEqualGUID(aFolderId, FOLDERID_PublicDesktop)) {
    csidl = CSIDL_COMMON_DESKTOPDIRECTORY;
  } else if (IsEqualGUID(aFolderId, FOLDERID_Desktop)) {
    csidl = CSIDL_DESKTOPDIRECTORY;
  } else if (IsEqualGUID(aFolderId, FOLDERID_CommonPrograms)) {
    csidl = CSIDL_COMMON_PROGRAMS;
  } else if (IsEqualGUID(aFolderId, FOLDERID_Programs)) {
    csidl = CSIDL_PROGRAMS;
  } else if (IsEqualGUID(aFolderId, FOLDERID_RoamingAppData)) {
    csidl = CSIDL_APPDATA;
  } else if (IsEqualGUID(aFolderId, FOLDERID_LocalAppData)) {
    csidl = CSIDL_LOCAL_APPDATA;
  } else if (IsEqualGUID(aFolderId, FOLDERID_ProgramData)) {
    csidl = CSIDL_COMMON_APPDATA;
  } else if (IsEqualGUID(aFolderId, FOLDERID_ProgramFiles) ||
             IsEqualGUID(aFolderId, FOLDERID_ProgramFilesX86)) {
    csidl = CSIDL_PROGRAM_FILES;
  } else if (IsEqualGUID(aFolderId, FOLDERID_Windows)) {
    csidl = CSIDL_WINDOWS;
  } else if (IsEqualGUID(aFolderId, FOLDERID_System) ||
             IsEqualGUID(aFolderId, FOLDERID_SystemX86)) {
    csidl = CSIDL_SYSTEM;
  } else {
    return E_NOTIMPL;
  }

  if (aFlags & KF_FLAG_CREATE) {
    csidl |= CSIDL_FLAG_CREATE;
  }
  if (aFlags & KF_FLAG_DONT_VERIFY) {
    csidl |= CSIDL_FLAG_DONT_VERIFY;
  }

  WCHAR path[MAX_PATH] = {};
  HRESULT hr =
      ::SHGetFolderPathW(nullptr, csidl, aToken, SHGFP_TYPE_CURRENT, path);
  if (FAILED(hr)) {
    return hr;
  }

  SIZE_T bytes = (static_cast<SIZE_T>(::lstrlenW(path)) + 1) * sizeof(WCHAR);
  PWSTR result = static_cast<PWSTR>(::CoTaskMemAlloc(bytes));
  if (!result) {
    return E_OUTOFMEMORY;
  }

  ::CopyMemory(result, path, bytes);
  *aPath = result;
  return S_OK;
}

#  define SHGetKnownFolderPath XPCompatSHGetKnownFolderPath
#endif

nsresult CreateShellLinkObject(nsIFile* aBinary,
                               const CopyableTArray<nsString>& aArguments,
                               const nsAString& aDescription,
                               nsIFile* aIconFile, uint16_t aIconIndex,
                               const nsAString& aAppUserModelId,
                               IShellLinkW** aLink);

#endif  // nswindowsshellserviceinternal_h_
