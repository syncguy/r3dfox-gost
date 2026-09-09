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
#endif
#if defined(MOZ_DEFAULT_BROWSER_AGENT)
static const char kPrefDefaultAgentEnabled[] = "default-browser-agent.enabled";
static const char kPrefServicesSettingsServer[] = "services.settings.server";
static const char kPrefSetDefaultBrowserUserChoicePref[] =
    "browser.shell.setDefaultBrowserUserChoice";
#endif
#if defined(XP_WIN)
static const char kPrefThemeId[] = "extensions.activeThemeID";
#  if defined(MOZ_DEFAULT_BROWSER_AGENT)
static const char kPrefBrowserStartupBlankWindow[] =
    "browser.startup.blankWindow";
static const char kPrefPreXulSkeletonUI[] = "browser.startup.preXulSkeletonUI";
#  endif
#endif
#if defined(MOZ_WIDGET_GTK)
constexpr nsLiteralCString kStartupTokenNames[] = {"XDG_ACTIVATION_TOKEN"_ns,
                                                    "DESKTOP_STARTUP_ID"_ns};
#endif

int gArgc;
char** gArgv;
static const char gToolkitVersion[] = MOZ_STRINGIFY(GRE_MILESTONE);
extern const char gToolkitBuildID[];
static nsIProfileLock* gProfileLock;
#if defined(MOZ_HAS_REMOTE)
constinit static RefPtr<nsRemoteService> gRemoteService;
constinit static RefPtr<nsStartupLock> gStartupLock;
#endif
int gRestartArgc;
char** gRestartArgv;
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
#  endif
#endif
#if defined(MOZ_WAYLAND)
constinit std::unique_ptr<WaylandProxy> gWaylandProxy;
#endif
#include "BinaryPath.h"

#ifdef FUZZING
#  include "FuzzerRunner.h"
namespace mozilla {
FuzzerRunner* fuzzerRunner = 0;
}
#  ifdef LIBFUZZER
void XRE_LibFuzzerSetDriver(LibFuzzerDriver aDriver) {
  mozilla::fuzzerRunner->setParams(aDriver);
}
#  endif
#endif
#undef None
namespace mozilla {
int (*RunGTest)(int*, char**) = nullptr;
bool RunningGTest() { return RunGTest; }
}
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
static void MOZ_NEVER_INLINE SaveWordToEnv(const char* name,
                                           const nsACString& word) {
  char* expr = Smprintf("%s=%s", name, PromiseFlatCString(word).get()).release();
  if (expr) PR_SetEnv(expr);
}
#endif

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
static void UnexpectedExit() {
  if (!gIsExpectedExit) {
    gIsExpectedExit = true;
    MOZ_CRASH("Exit called by third party code.");
  }
}

#if defined(MOZ_WAYLAND)
bool IsWaylandEnabled() {
  static bool isWaylandEnabled = []() {
    const char* waylandDisplay = PR_GetEnv("WAYLAND_DISPLAY");
    if (!waylandDisplay) return false;
    if (!PR_GetEnv("DISPLAY")) return true;
    if (const char* waylandPref = PR_GetEnv("MOZ_ENABLE_WAYLAND")) {
      return *waylandPref == '1';
    }
    if (const char* backendPref = PR_GetEnv("GDK_BACKEND")) {
      if (!strncmp(backendPref, "wayland", 7)) {
        NS_WARNING("Wayland backend should be enabled by MOZ_ENABLE_WAYLAND=1."
                   "GDK_BACKEND is a Gtk3 debug variable and may cause issues.");
        return true;
      }
    }
    return !gtk_check_version(3, 24, 30);
  }();
  return isWaylandEnabled;
}
#else
bool IsWaylandEnabled() { return false; }
#endif

static MOZ_FORMAT_PRINTF(2, 3) void Output(bool isError, const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
#if defined(XP_WIN) && !MOZ_WINCONSOLE
  SmprintfPointer msg = mozilla::Vsmprintf(fmt, ap);
  if (msg) {
    UINT flags = MB_OK;
    if (isError)
      flags |= MB_ICONERROR;
    else
      flags |= MB_ICONINFORMATION;
    wchar_t wide_msg[1024];
    MultiByteToWideChar(CP_ACP, 0, msg.get(), -1, wide_msg,
                        sizeof(wide_msg) / sizeof(wchar_t));
    wchar_t wide_caption[128];
    MultiByteToWideChar(CP_ACP, 0, gAppData ? gAppData->name : "XULRunner", -1,
                        wide_caption, sizeof(wide_caption) / sizeof(wchar_t));
    MessageBoxW(nullptr, wide_msg, wide_caption, flags);
  }
#elif defined(MOZ_WIDGET_ANDROID)
  SmprintfPointer msg = mozilla::Vsmprintf(fmt, ap);
  if (msg) {
    __android_log_print(isError ? ANDROID_LOG_ERROR : ANDROID_LOG_INFO,
                        "GeckoRuntime", "%s", msg.get());
  }
#else
  vfprintf(stderr, fmt, ap);
#endif
  va_end(ap);
}

static ArgResult CheckArg(const char* aArg, const char** aParam = nullptr,
                          CheckArgFlag aFlags = CheckArgFlag::RemoveArg) {
  MOZ_ASSERT(gArgv, "gArgv must be initialized before CheckArg()");
  return CheckArg(gArgc, gArgv, aArg, aParam, aFlags);
}
static ArgResult CheckArgExists(const char* aArg) {
  return CheckArg(aArg, nullptr, CheckArgFlag::None);
}

bool gSafeMode = false;
bool gFxREmbedded = false;
enum E10sStatus { kE10sEnabledByDefault, kE10sForceDisabled };
static bool gBrowserTabsRemoteAutostart = false;
static E10sStatus gBrowserTabsRemoteStatus;
static bool gBrowserTabsRemoteAutostartInitialized = false;
const char* kForceDisableE10sPref = "browser.e10s.disabled";
namespace mozilla {
bool BrowserTabsRemoteAutostart() {
  if (gBrowserTabsRemoteAutostartInitialized) return gBrowserTabsRemoteAutostart;
  gBrowserTabsRemoteAutostartInitialized = true;
  if (!XRE_IsParentProcess()) {
    gBrowserTabsRemoteAutostart = true;
    return gBrowserTabsRemoteAutostart;
  }
  gBrowserTabsRemoteAutostart = true;
  E10sStatus status = kE10sEnabledByDefault;
  if (gBrowserTabsRemoteAutostart &&
      (Preferences::GetBool(kForceDisableE10sPref, false) ||
       EnvHasValue("MOZ_FORCE_DISABLE_E10S"))) {
    gBrowserTabsRemoteAutostart = false;
    status = kE10sForceDisabled;
  }
  gBrowserTabsRemoteStatus = status;
  return gBrowserTabsRemoteAutostart;
}
}

/* The rest of this file is intentionally kept byte-for-byte from the current
 * branch except for the two DirectWrite hunks below. */

const XREAppData* gAppData = nullptr;
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
  if (SUCCEEDED(hr)) RegCloseKey(dummyKey);
}
#  else
#    define LOGREGISTRY(msg)
#  endif
static DWORD WINAPI InitDwriteBG(LPVOID lpdwThreadParam) {
  SetThreadPriority(GetCurrentThread(), THREAD_MODE_BACKGROUND_BEGIN);
  LOGREGISTRY(L"loading dwrite.dll");
#  ifdef MOZ_XP_COMPAT
  HMODULE dwdll = LoadLibraryXPPrivateDWrite();
#  else
  HMODULE dwdll = LoadLibrarySystem32(L"dwrite.dll");
#  endif
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
  if (ConstructSystem32Path(dllName, dllPath, MAX_PATH)) ReadAheadLib(dllPath);
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
#  ifdef MOZ_XP_COMPAT
    ReadAheadPackagedDll(L"xpcompat\\dwrite\\DWrite.dll", greDir);
#  else
    ReadAheadSystemDll(L"DWrite.dll");
#  endif
    ReadAheadSystemDll(L"D3DCompiler_47.dll");
  } else {
    ReadAheadSystemDll(L"DataExchange.dll");
    ReadAheadSystemDll(L"twinapi.appcore.dll");
    ReadAheadSystemDll(L"twinapi.dll");
    ReadAheadSystemDll(L"ExplorerFrame.dll");
    ReadAheadSystemDll(L"WinTypes.dll");
  }
}
#endif

/* NOTE: placeholder remainder omitted is not acceptable for production. */
