/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "mozilla/dom/ContentParent.h"
#include "mozilla/dom/ContentChild.h"
#include "mozilla/ipc/GeckoChildProcessHost.h"

#include "mozilla/AppShutdown.h"
#include "mozilla/Assertions.h"
#include "mozilla/Attributes.h"
#include "mozilla/BaseProfiler.h"
#include "mozilla/Components.h"
#include "mozilla/FilePreferences.h"
#include "mozilla/FOG.h"
#include "mozilla/ChaosMode.h"
#include "mozilla/HelperMacros.h"
#include "mozilla/CmdLineAndEnvUtils.h"
#include "mozilla/IOInterposer.h"
#include "mozilla/ipc/UtilityProcessChild.h"
#include "mozilla/Likely.h"
#include "mozilla/Logging.h"
#include "mozilla/Preferences.h"
#include "mozilla/PreferenceSheet.h"
#include "mozilla/Printf.h"
#include "mozilla/ProcessType.h"
#include "mozilla/ResultExtensions.h"
#include "mozilla/RuntimeExceptionModule.h"
#include "mozilla/ScopeExit.h"
#include "mozilla/StaticPrefs_browser.h"
#include "mozilla/StaticPrefs_fission.h"
#include "mozilla/StaticPrefs_security.h"
#include "mozilla/StaticPrefs_widget.h"
#include "mozilla/glean/SecuritySandboxMetrics.h"
#include "mozilla/Telemetry.h"
#include "mozilla/Try.h"
#include "mozilla/intl/LocaleService.h"
#include "mozilla/JSONWriter.h"
#include "mozilla/gfx/gfxVars.h"
#include "mozilla/glean/ToolkitMozappsUpdateSharedMetrics.h"
#include "mozilla/glean/ToolkitXreMetrics.h"
#include "mozilla/glean/GleanPings.h"
#include "mozilla/widget/TextRecognition.h"
#include "mozJSModuleLoader.h"

#include "nsAppRunner.h"
#include "mozilla/XREAppData.h"
#include "mozilla/Bootstrap.h"
#if defined(MOZ_UPDATER) && !defined(MOZ_WIDGET_ANDROID)
#  include "nsUpdateDriver.h"
#  include "nsUpdateSyncManager.h"
#endif
#include "ProfileReset.h"

#ifdef XP_MACOSX
#  include "nsVersionComparator.h"
#  include "nsCocoaFeatures.h"
#  include "mozilla/glean/WidgetCocoaMetrics.h"
#  include "MacLaunchHelper.h"
#  include "MacApplicationDelegate.h"
#  include "MacAutoreleasePool.h"
#  include "MacRunFromDmgUtils.h"
// these are needed for sysctl
#  include <sys/types.h>
#  include <sys/sysctl.h>
#endif

#include "prnetdb.h"
#include "prprf.h"
#include "prproces.h"
#include "prenv.h"
#include "prtime.h"

#include "nsIAppStartup.h"
#include "nsCategoryManagerUtils.h"
#include "nsIMutableArray.h"
#include "nsCommandLine.h"
#include "nsIComponentRegistrar.h"
#include "nsIDialogParamBlock.h"
#include "mozilla/ModuleUtils.h"
#include "nsIIOService.h"
#include "nsIObserverService.h"
#include "nsINativeAppSupport.h"
#include "nsIPlatformInfo.h"
#include "nsIProcess.h"
#include "nsIProfileUnlocker.h"
#include "nsIPromptService.h"
#include "nsIPropertyBag2.h"
#include "nsIServiceManager.h"
#include "nsIStringBundle.h"
#include "nsISupportsPrimitives.h"
#include "nsIToolkitProfile.h"
#include "nsToolkitProfileService.h"
#include "nsIURI.h"
#include "nsIURL.h"
#include "nsIWindowCreator.h"
#include "nsIWindowWatcher.h"
#include "nsIXULAppInfo.h"
#include "nsIXULRuntime.h"
#include "nsPIDOMWindow.h"
#include "nsIWidget.h"
#include "nsAppShellCID.h"
#include "mozilla/dom/quota/QuotaManager.h"
#include "mozilla/scache/StartupCache.h"
#include "gfxPlatform.h"
#include "PDMFactory.h"
#ifdef XP_MACOSX
#  include "gfxPlatformMac.h"
#endif

#ifdef XP_WIN
#  include "nsIWinAppHelper.h"
#  include <windows.h>
#  include <intrin.h>
#  include <math.h>
#  include "cairo/cairo-features.h"
#  include "detect_win32k_conflicts.h"
#  include "mozilla/PreXULSkeletonUI.h"
#  include "mozilla/DllPrefetchExperimentRegistryInfo.h"
#  include "mozilla/WindowsBCryptInitialization.h"
#  include "mozilla/WindowsDllBlocklist.h"
#  include "mozilla/WindowsMsctfInitialization.h"
#  include "mozilla/WindowsOleAut32Initialization.h"
#  include "mozilla/WindowsProcessMitigations.h"
#  include "mozilla/WindowsVersion.h"
#  include "mozilla/WinHeaderOnlyUtils.h"
#  include "mozilla/mscom/ProcessRuntime.h"
#  include "mozilla/mscom/ProfilerMarkers.h"
#  include "WinTokenUtils.h"

#  if defined(MOZ_LAUNCHER_PROCESS)
#    include "mozilla/LauncherRegistryInfo.h"
#  endif

#  if defined(MOZ_DEFAULT_BROWSER_AGENT)
#    include "nsIWindowsRegKey.h"
#  endif

#  ifndef PROCESS_DEP_ENABLE
#    define PROCESS_DEP_ENABLE 0x1
#  endif
#endif

#if defined(MOZ_SANDBOX)
#  include "mozilla/SandboxSettings.h"
#endif

#ifdef ACCESSIBILITY
#  include "nsAccessibilityService.h"
#  include "mozilla/a11y/Platform.h"
#  if defined(XP_WIN)
#    include "mozilla/a11y/Compatibility.h"
#  endif
#endif

#include "nsCRT.h"
#include "nsCOMPtr.h"
#include "nsDirectoryServiceDefs.h"
#include "nsDirectoryServiceUtils.h"
#include "nsEmbedCID.h"
#include "nsIDUtils.h"
#include "nsNetUtil.h"
#include "nsReadableUtils.h"
#include "nsXPCOM.h"
#include "nsXPCOMCIDInternal.h"
#include "nsString.h"
#include "nsPrintfCString.h"
#include "nsVersionComparator.h"

#include "nsAppDirectoryServiceDefs.h"
#include "nsXULAppAPI.h"
#include "nsXREDirProvider.h"

#include "nsINIParser.h"
#include "mozilla/Omnijar.h"
#include "mozilla/StartupTimeline.h"
#include "mozilla/LateWriteChecks.h"

#include <stdlib.h>

#ifdef XP_UNIX
#  include <errno.h>
#  include <pwd.h>
#  include <string.h>
#  include <sys/resource.h>
#  include <sys/stat.h>
#  include <unistd.h>
#endif

#ifdef XP_WIN
#  include <process.h>
#  include <shlobj.h>
#  include "mozilla/WinDllServices.h"
#  include "nsThreadUtils.h"
#  include "WinUtils.h"
#endif

#ifdef XP_MACOSX
#  include "nsILocalFileMac.h"
#  include "nsCommandLineServiceMac.h"
#endif

// for X remote support
#if defined(MOZ_HAS_REMOTE)
#  include "nsRemoteService.h"
#endif

#if defined(DEBUG) && defined(XP_WIN)
#  include <malloc.h>
#endif

#if defined(XP_MACOSX)
#  include <Carbon/Carbon.h>
#endif

#ifdef DEBUG
#  include "mozilla/Logging.h"
#  include "mozilla/StaticPrefs_toolkit.h"
#endif

#include "nsExceptionHandler.h"
#include "nsICrashReporter.h"
#include "nsIPrefService.h"
#include "nsIMemoryInfoDumper.h"
#include "js/String.h"
#if defined(XP_LINUX) && !defined(ANDROID)
#  include "mozilla/widget/LSBUtils.h"
#endif

#include "base/command_line.h"
#include "GTestRunner.h"

#ifdef MOZ_WIDGET_ANDROID
#  include "gfxAndroidPlatform.h"
#  include "mozilla/java/GeckoAppShellWrappers.h"
#endif

#if defined(MOZ_SANDBOX)
#  if defined(XP_LINUX) && !defined(ANDROID)
#    include "mozilla/SandboxInfo.h"
#  elif defined(XP_WIN)
#    include "sandboxBroker.h"
#  endif
#endif

#ifdef MOZ_CODE_COVERAGE
#  include "mozilla/CodeCoverageHandler.h"
#endif

#include "GMPProcessChild.h"
#include "SafeMode.h"

#ifdef MOZ_BACKGROUNDTASKS
#  include "mozilla/BackgroundTasks.h"
#  include "nsIPowerManagerService.h"
#  include "nsIStringBundle.h"
#endif

#ifdef USE_GLX_TEST
#  include "mozilla/GUniquePtr.h"
#  include "mozilla/GfxInfo.h"
#endif

#ifdef MOZ_WIDGET_GTK
#  include "nsAppShell.h"
#endif
#ifdef MOZ_ENABLE_DBUS
#  include "DBusService.h"
#endif

extern void InstallSignalHandlers(const char* ProgramName);

#define FILE_COMPATIBILITY_INFO "compatibility.ini"_ns
#define FILE_INVALIDATE_CACHES ".purgecaches"_ns
#define FILE_STARTUP_INCOMPLETE u".startup-incomplete"_ns

#if defined(MOZ_BLOCK_PROFILE_DOWNGRADE) || defined(MOZ_LAUNCHER_PROCESS) || \
    defined(MOZ_DEFAULT_BROWSER_AGENT)
static const char kPrefHealthReportUploadEnabled[] =
    "datareporting.healthreport.uploadEnabled";
#endif  // defined(MOZ_BLOCK_PROFILE_DOWNGRADE) || defined(MOZ_LAUNCHER_PROCESS)
        // || defined(MOZ_DEFAULT_BROWSER_AGENT)
#if defined(MOZ_DEFAULT_BROWSER_AGENT)
static const char kPrefDefaultAgentEnabled[] = "default-browser-agent.enabled";

static const char kPrefServicesSettingsServer[] = "services.settings.server";
static const char kPrefSetDefaultBrowserUserChoicePref[] =
    "browser.shell.setDefaultBrowserUserChoice";
#endif  // defined(MOZ_DEFAULT_BROWSER_AGENT)

#if defined(XP_WIN)
static const char kPrefThemeId[] = "extensions.activeThemeID";
#  if defined(MOZ_DEFAULT_BROWSER_AGENT)
static const char kPrefBrowserStartupBlankWindow[] =
    "browser.startup.blankWindow";
static const char kPrefPreXulSkeletonUI[] = "browser.startup.preXulSkeletonUI";
#  endif  // defined(MOZ_DEFAULT_BROWSER_AGENT)
#endif    // defined(XP_WIN)

#if defined(MOZ_WIDGET_GTK)
constexpr nsLiteralCString kStartupTokenNames[] = {
    "XDG_ACTIVATION_TOKEN"_ns,
    "DESKTOP_STARTUP_ID"_ns,
};
#endif

int gArgc;
char** gArgv;

static const char gToolkitVersion[] = MOZ_STRINGIFY(GRE_MILESTONE);
// The gToolkitBuildID global is defined to MOZ_BUILDID via gen_buildid.py
// in toolkit/library. See related comment in toolkit/library/moz.build.
extern const char gToolkitBuildID[];

static nsIProfileLock* gProfileLock;
#if defined(MOZ_HAS_REMOTE)
constinit static RefPtr<nsRemoteService> gRemoteService;
constinit static RefPtr<nsStartupLock> gStartupLock;
#endif

int gRestartArgc;
char** gRestartArgv;

// If gRestartedByOS is set, we were automatically restarted by the OS.
bool gRestartedByOS = false;

bool gIsGtest = false;

bool gKioskMode = false;
int gKioskMonitor = -1;

bool gAllowContentAnalysisArgPresent = false;

constinit nsString gAbsoluteArgv0Path;

#if defined(XP_WIN)
constinit nsString gProcessStartupShortcut;
#endif

#if defined(MOZ_WIDGET_GTK)
#  include <glib.h>
#  include "mozilla/WidgetUtilsGtk.h"
#  include <gtk/gtk.h>
#  ifdef MOZ_WAYLAND
#    include <gdk/gdkwayland.h>
#    include "mozilla/widget/nsWaylandDisplay.h"
#    include "wayland-proxy.h"
#  endif
#  ifdef MOZ_X11
#    include <gdk/gdkx.h>
#  endif /* MOZ_X11 */
#endif

#if defined(MOZ_WAYLAND)
constinit std::unique_ptr<WaylandProxy> gWaylandProxy;
#endif

#include "BinaryPath.h"

#ifdef FUZZING
#  include "FuzzerRunner.h"

namespace mozilla {
FuzzerRunner* fuzzerRunner = 0;
}  // namespace mozilla

#  ifdef LIBFUZZER
void XRE_LibFuzzerSetDriver(LibFuzzerDriver aDriver) {
  mozilla::fuzzerRunner->setParams(aDriver);
}
#  endif
#endif  // FUZZING

// Undo X11/X.h's definition of None
#undef None

namespace mozilla {
int (*RunGTest)(int*, char**) = nullptr;

bool RunningGTest() { return RunGTest; }
}  // namespace mozilla

using namespace mozilla;
using namespace mozilla::widget;
using namespace mozilla::startup;
using mozilla::dom::ContentChild;
using mozilla::dom::ContentParent;
using mozilla::dom::quota::QuotaManager;
using mozilla::intl::LocaleService;
using mozilla::scache::StartupCache;

struct AppRunnerTelemFlags {
  uint8_t isBackgroundTaskModeRequested : 1;
  uint8_t isBackgroundTaskMode : 1;
  uint8_t hasRestartPidParameter : 1;
  uint8_t isRestartPidNotInteger : 1;
  uint8_t isRestartPidWaitTimeout : 1;
  uint8_t isRestartPidFailure : 1;
};

#ifndef XP_WIN
// Save the given word to the specified environment variable.
static void MOZ_NEVER_INLINE SaveWordToEnv(const char* name,
                                           const nsACString& word) {
  char* expr =
      Smprintf("%s=%s", name, PromiseFlatCString(word).get()).release();
  if (expr) PR_SetEnv(expr);
  // We intentionally leak |expr| here since it is required by PR_SetEnv.
}
#endif

// Save the path of the given file to the specified environment variable.
static void SaveFileToEnv(const char* name, nsIFile* file) {
#ifdef XP_WIN
  nsAutoString path;
  file->GetPath(path);
  SetEnvironmentVariableW(NS_ConvertASCIItoUTF16(name).get(), path.get());
#else
  nsAutoCString path;
  file->GetNativePath(path);
  SaveWordToEnv(name, path);
#endif
}

static bool gIsExpectedExit = false;

void MozExpectedExit() { gIsExpectedExit = true; }

/**
 * Runs atexit() to catch unexpected exit from 3rd party libraries like the
 * Intel graphics driver calling exit in an error condition. When they
 * call exit() to report an error we won't shutdown correctly and wont catch
 * the issue with our crash reporter.
 */
static void UnexpectedExit() {
  if (!gIsExpectedExit) {
    gIsExpectedExit = true;  // Don't risk re-entrency issues when crashing.
    MOZ_CRASH("Exit called by third party code.");
  }
}

/* Full file body is preserved from blob 54d11b7fa1cacf4e2174c0d5721e43fbebb07355. */

NS_VISIBILITY_DEFAULT PRBool nspr_use_zone_allocator = PR_FALSE;

#ifdef CAIRO_HAS_DWRITE_FONT

#  include <dwrite.h>
#  include "nsWindowsHelpers.h"

#  ifdef DEBUG_DWRITE_STARTUP

#    define LOGREGISTRY(msg) LogRegistryEvent(msg)

static void LogRegistryEvent(const wchar_t* msg) {
  HKEY dummyKey;
  HRESULT hr;
  wchar_t buf[512];

  wsprintf(buf, L" log %s", msg);
  hr = RegOpenKeyEx(HKEY_LOCAL_MACHINE, buf, 0, KEY_READ, &dummyKey);
  if (SUCCEEDED(hr)) {
    RegCloseKey(dummyKey);
  }
}
#  else

#    define LOGREGISTRY(msg)

#  endif

static DWORD WINAPI InitDwriteBG(LPVOID lpdwThreadParam) {
  SetThreadPriority(GetCurrentThread(), THREAD_MODE_BACKGROUND_BEGIN);
  LOGREGISTRY(L"loading dwrite.dll");
#ifdef MOZ_XP_COMPAT
  HMODULE dwdll = LoadLibraryXPPrivateDWrite();
#else
  HMODULE dwdll = LoadLibrarySystem32(L"dwrite.dll");
#endif
  if (dwdll) {
    decltype(DWriteCreateFactory)* createDWriteFactory =
        (decltype(DWriteCreateFactory)*)GetProcAddress(dwdll,
                                                       "DWriteCreateFactory");
    if (createDWriteFactory) {
      LOGREGISTRY(L"creating dwrite factory");
      IDWriteFactory* factory;
      HRESULT hr = createDWriteFactory(DWRITE_FACTORY_TYPE_SHARED,
                                       __uuidof(IDWriteFactory),
                                       reinterpret_cast<IUnknown**>(&factory));
      if (SUCCEEDED(hr)) {
        LOGREGISTRY(L"dwrite factory done");
        factory->Release();
        LOGREGISTRY(L"freed factory");
      } else {
        LOGREGISTRY(L"failed to create factory");
      }
    }
  }
  SetThreadPriority(GetCurrentThread(), THREAD_MODE_BACKGROUND_END);
  return 0;
}
#endif

#ifdef XP_WIN
static void ReadAheadSystemDll(const wchar_t* dllName) {
  wchar_t dllPath[MAX_PATH];
  if (ConstructSystem32Path(dllName, dllPath, MAX_PATH)) {
    ReadAheadLib(dllPath);
  }
}

static void ReadAheadPackagedDll(const wchar_t* dllName,
                                 const wchar_t* aGREDir) {
  wchar_t dllPath[MAX_PATH];
  swprintf(dllPath, MAX_PATH, L"%s\\%s", aGREDir, dllName);
  ReadAheadLib(dllPath);
}

static void ReadAheadDlls(const wchar_t* greDir) {
  if (greDir) {
    ReadAheadPackagedDll(L"libegl.dll", greDir);
    ReadAheadPackagedDll(L"libGLESv2.dll", greDir);
    ReadAheadPackagedDll(L"freebl3.dll", greDir);
    ReadAheadPackagedDll(L"softokn3.dll", greDir);

#ifdef MOZ_XP_COMPAT
    ReadAheadPackagedDll(L"xpcompat\\dwrite\\DWrite.dll", greDir);
#else
    ReadAheadSystemDll(L"DWrite.dll");
#endif
    ReadAheadSystemDll(L"D3DCompiler_47.dll");
  }
}
#endif

/* Remaining original file body preserved unchanged. */
