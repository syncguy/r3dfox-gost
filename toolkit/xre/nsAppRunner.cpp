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
static void MOZ_NEVER_INLINE SaveWordToEnv(const char* name,
                                           const nsACString& word) {
  char* expr =
      Smprintf("%s=%s", name, PromiseFlatCString(word).get()).release();
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
    if (!waylandDisplay) {
      return false;
    }
    if (!PR_GetEnv("DISPLAY")) {
      return true;
    }
    if (const char* waylandPref = PR_GetEnv("MOZ_ENABLE_WAYLAND")) {
      return *waylandPref == '1';
    }
    if (const char* backendPref = PR_GetEnv("GDK_BACKEND")) {
      if (!strncmp(backendPref, "wayland", 7)) {
        NS_WARNING(
            "Wayland backend should be enabled by MOZ_ENABLE_WAYLAND=1."
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

enum E10sStatus {
  kE10sEnabledByDefault,
  kE10sForceDisabled,
};

static bool gBrowserTabsRemoteAutostart = false;
static E10sStatus gBrowserTabsRemoteStatus;
static bool gBrowserTabsRemoteAutostartInitialized = false;
const char* kForceDisableE10sPref = "browser.e10s.disabled";

namespace mozilla {

bool BrowserTabsRemoteAutostart() {
  if (gBrowserTabsRemoteAutostartInitialized) {
    return gBrowserTabsRemoteAutostart;
  }
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

}  // namespace mozilla

static bool gWin32kInitialized = false;
static nsIXULRuntime::ContentWin32kLockdownState gWin32kStatus;
static nsIXULRuntime::ExperimentStatus gWin32kExperimentStatus =
    nsIXULRuntime::eExperimentStatusUnenrolled;

#ifdef XP_WIN
static const char kPrefWin32k[] = "security.sandbox.content.win32k-disable";
static const char kPrefWin32kExperimentEnrollmentStatus[] =
    "security.sandbox.content.win32k-experiment.enrollmentStatus";
static const char kPrefWin32kExperimentStartupEnrollmentStatus[] =
    "security.sandbox.content.win32k-experiment.startupEnrollmentStatus";

namespace mozilla {
bool Win32kExperimentEnrolled() {
  MOZ_ASSERT(XRE_IsParentProcess());
  return gWin32kExperimentStatus == nsIXULRuntime::eExperimentStatusControl ||
         gWin32kExperimentStatus == nsIXULRuntime::eExperimentStatusTreatment;
}
}  // namespace mozilla

static bool Win32kRequirementsUnsatisfied(
    nsIXULRuntime::ContentWin32kLockdownState aStatus) {
  return aStatus == nsIXULRuntime::ContentWin32kLockdownState::
                        OperatingSystemNotSupported ||
         aStatus ==
             nsIXULRuntime::ContentWin32kLockdownState::MissingWebRender ||
         aStatus ==
             nsIXULRuntime::ContentWin32kLockdownState::DecodersArentRemote;
}

static void Win32kExperimentDisqualify() {
  MOZ_ASSERT(XRE_IsParentProcess());
  Preferences::SetUint(kPrefWin32kExperimentEnrollmentStatus,
                       nsIXULRuntime::eExperimentStatusDisqualified);
}

static void OnWin32kEnrollmentStatusChanged(const char* aPref, void* aData) {
  auto newStatusInt =
      Preferences::GetUint(kPrefWin32kExperimentEnrollmentStatus,
                           nsIXULRuntime::eExperimentStatusUnenrolled);
  auto newStatus = newStatusInt < nsIXULRuntime::eExperimentStatusCount
                       ? nsIXULRuntime::ExperimentStatus(newStatusInt)
                       : nsIXULRuntime::eExperimentStatusDisqualified;
  Preferences::SetUint(kPrefWin32kExperimentStartupEnrollmentStatus, newStatus);
}

namespace {
class Win32kEnrollmentStatusShutdownObserver final : public nsIObserver {
 public:
  NS_DECL_ISUPPORTS
  NS_IMETHOD Observe(nsISupports* aSubject, const char* aTopic,
                     const char16_t* aData) override {
    MOZ_ASSERT(!strcmp("profile-before-change", aTopic));
    OnWin32kEnrollmentStatusChanged(kPrefWin32kExperimentEnrollmentStatus,
                                    nullptr);
    return NS_OK;
  }
 private:
  ~Win32kEnrollmentStatusShutdownObserver() = default;
};
NS_IMPL_ISUPPORTS(Win32kEnrollmentStatusShutdownObserver, nsIObserver)
}

static void OnWin32kChanged(const char* aPref, void* aData) {
  if (Win32kExperimentEnrolled() && Preferences::HasUserValue(kPrefWin32k)) {
    Win32kExperimentDisqualify();
  }
}
#endif

namespace mozilla {
void EnsureWin32kInitialized();
}

nsIXULRuntime::ContentWin32kLockdownState GetLiveWin32kLockdownState() {
#ifdef XP_WIN
  MOZ_ASSERT(NS_IsMainThread());
#  ifdef MOZ_BACKGROUNDTASKS
  if (BackgroundTasks::IsBackgroundTaskMode()) {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByDefault;
  }
#  endif
  mozilla::EnsureWin32kInitialized();
  gfxPlatform::GetPlatform();
  if (EnvHasValue("MOZ_ENABLE_WIN32K")) {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByEnvVar;
  }
  if (!mozilla::BrowserTabsRemoteAutostart()) {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByE10S;
  }
  if (!IsWin10FallCreatorsUpdateOrLater()) {
    return nsIXULRuntime::ContentWin32kLockdownState::OperatingSystemNotSupported;
  }
  if (!StaticPrefs::widget_non_native_theme_enabled()) {
    return nsIXULRuntime::ContentWin32kLockdownState::MissingNonNativeTheming;
  }
  if (!PDMFactory::AllDecodersAreRemote()) {
    return nsIXULRuntime::ContentWin32kLockdownState::DecodersArentRemote;
  }
  bool prefSetByUser =
      Preferences::HasUserValue("security.sandbox.content.win32k-disable");
  bool prefValue = Preferences::GetBool(
      "security.sandbox.content.win32k-disable", false, PrefValueKind::User);
  bool defaultValue = Preferences::GetBool(
      "security.sandbox.content.win32k-disable", false, PrefValueKind::Default);
  if (prefSetByUser) {
    return prefValue ? nsIXULRuntime::ContentWin32kLockdownState::EnabledByUserPref
                     : nsIXULRuntime::ContentWin32kLockdownState::DisabledByUserPref;
  }
  if (gWin32kExperimentStatus == nsIXULRuntime::ExperimentStatus::eExperimentStatusControl) {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByControlGroup;
  }
  if (gWin32kExperimentStatus == nsIXULRuntime::ExperimentStatus::eExperimentStatusTreatment) {
    return nsIXULRuntime::ContentWin32kLockdownState::EnabledByTreatmentGroup;
  }
  return defaultValue ? nsIXULRuntime::ContentWin32kLockdownState::EnabledByDefault
                      : nsIXULRuntime::ContentWin32kLockdownState::DisabledByDefault;
#else
  return nsIXULRuntime::ContentWin32kLockdownState::OperatingSystemNotSupported;
#endif
}

namespace mozilla {
void EnsureWin32kInitialized() {
  if (gWin32kInitialized) return;
  gWin32kInitialized = true;
#ifdef XP_WIN
  uint32_t experimentRaw = Preferences::GetUint(
      kPrefWin32kExperimentStartupEnrollmentStatus,
      nsIXULRuntime::eExperimentStatusUnenrolled);
  gWin32kExperimentStatus = experimentRaw < nsIXULRuntime::eExperimentStatusCount
                                ? nsIXULRuntime::ExperimentStatus(experimentRaw)
                                : nsIXULRuntime::eExperimentStatusDisqualified;
  Preferences::RegisterCallback(&OnWin32kEnrollmentStatusChanged,
                                kPrefWin32kExperimentEnrollmentStatus);
  if (nsCOMPtr<nsIObserverService> observerService =
          mozilla::services::GetObserverService()) {
    nsCOMPtr<nsIObserver> shutdownObserver =
        new Win32kEnrollmentStatusShutdownObserver();
    observerService->AddObserver(shutdownObserver, "profile-before-change", false);
  }
  auto tmpStatus = GetLiveWin32kLockdownState();
  if (Win32kExperimentEnrolled() && Win32kRequirementsUnsatisfied(tmpStatus)) {
    Win32kExperimentDisqualify();
    gWin32kExperimentStatus = nsIXULRuntime::eExperimentStatusDisqualified;
  }
  if (Preferences::HasUserValue(kPrefWin32k) && Win32kExperimentEnrolled()) {
    Win32kExperimentDisqualify();
    gWin32kExperimentStatus = nsIXULRuntime::eExperimentStatusDisqualified;
  }
  Preferences::RegisterCallback(&OnWin32kChanged, kPrefWin32k);
  gWin32kStatus = GetLiveWin32kLockdownState();
#else
  gWin32kStatus = nsIXULRuntime::ContentWin32kLockdownState::OperatingSystemNotSupported;
  gWin32kExperimentStatus = nsIXULRuntime::eExperimentStatusUnenrolled;
#endif
}

nsIXULRuntime::ContentWin32kLockdownState GetWin32kLockdownState() {
#ifdef XP_WIN
  mozilla::EnsureWin32kInitialized();
  return gWin32kStatus;
#else
  return nsIXULRuntime::ContentWin32kLockdownState::OperatingSystemNotSupported;
#endif
}
}  // namespace mozilla

static const char kPrefFissionAutostart[] = "fission.autostart";
static const char kPrefFissionAutostartSession[] = "fission.autostart.session";
static bool gFissionAutostart = false;
static bool gFissionAutostartInitialized = false;
static nsIXULRuntime::FissionDecisionStatus gFissionDecisionStatus;
static void EnsureFissionAutostartInitialized() {
  if (gFissionAutostartInitialized) return;
  gFissionAutostartInitialized = true;
  if (!XRE_IsParentProcess()) {
    gFissionAutostart = Preferences::GetBool(kPrefFissionAutostartSession,
                                             false, PrefValueKind::Default);
    return;
  }
  if (!BrowserTabsRemoteAutostart()) {
    gFissionAutostart = false;
    gFissionDecisionStatus = gBrowserTabsRemoteStatus == kE10sForceDisabled
                                 ? nsIXULRuntime::eFissionDisabledByE10sEnv
                                 : nsIXULRuntime::eFissionDisabledByE10sOther;
  } else if (EnvHasValue("MOZ_FORCE_ENABLE_FISSION")) {
    gFissionAutostart = true;
    gFissionDecisionStatus = nsIXULRuntime::eFissionEnabledByEnv;
  } else if (EnvHasValue("MOZ_FORCE_DISABLE_FISSION")) {
    gFissionAutostart = false;
    gFissionDecisionStatus = nsIXULRuntime::eFissionDisabledByEnv;
  } else {
    gFissionAutostart = Preferences::GetBool(kPrefFissionAutostart, false);
    if (Preferences::HasUserValue(kPrefFissionAutostart)) {
      gFissionDecisionStatus = gFissionAutostart
                                   ? nsIXULRuntime::eFissionEnabledByUserPref
                                   : nsIXULRuntime::eFissionDisabledByUserPref;
    } else {
      gFissionDecisionStatus = gFissionAutostart
                                   ? nsIXULRuntime::eFissionEnabledByDefault
                                   : nsIXULRuntime::eFissionDisabledByDefault;
    }
  }
  Preferences::Unlock(kPrefFissionAutostartSession);
  Preferences::ClearUser(kPrefFissionAutostartSession);
  Preferences::SetBool(kPrefFissionAutostartSession, gFissionAutostart,
                       PrefValueKind::Default);
  Preferences::Lock(kPrefFissionAutostartSession);
}

namespace mozilla {
bool FissionAutostart() {
  EnsureFissionAutostartInitialized();
  return gFissionAutostart;
}
bool SessionStorePlatformCollection() {
  return !StaticPrefs::browser_sessionstore_disable_platform_collection_AtStartup_DoNotUseDirectly();
}
bool BFCacheInParent() {
  return StaticPrefs::fission_bfcacheInParent_DoNotUseDirectly();
}
}  // namespace mozilla

class nsXULAppInfo : public nsIXULAppInfo,
#ifdef XP_WIN
                     public nsIWinAppHelper,
#endif
                     public nsICrashReporter,
                     public nsIFinishDumpingCallback,
                     public nsIXULRuntime {
 public:
  constexpr nsXULAppInfo() = default;
  NS_DECL_ISUPPORTS_INHERITED
  NS_DECL_NSIPLATFORMINFO
  NS_DECL_NSIXULAPPINFO
  NS_DECL_NSIXULRUNTIME
  NS_DECL_NSICRASHREPORTER
  NS_DECL_NSIFINISHDUMPINGCALLBACK
#ifdef XP_WIN
  NS_DECL_NSIWINAPPHELPER
#endif
};

NS_INTERFACE_MAP_BEGIN(nsXULAppInfo)
  NS_INTERFACE_MAP_ENTRY_AMBIGUOUS(nsISupports, nsIXULRuntime)
  NS_INTERFACE_MAP_ENTRY(nsIXULRuntime)
#ifdef XP_WIN
  NS_INTERFACE_MAP_ENTRY(nsIWinAppHelper)
#endif
  NS_INTERFACE_MAP_ENTRY(nsICrashReporter)
  NS_INTERFACE_MAP_ENTRY(nsIFinishDumpINGCallback)
  NS_INTERFACE_MAP_ENTRY(nsIPlatformInfo)
  NS_INTERFACE_MAP_ENTRY_CONDITIONAL(nsIXULAppInfo,
                                     gAppData || XRE_IsContentProcess())
NS_INTERFACE_MAP_END

NS_IMETHODIMP_(MozExternalRefCountType) nsXULAppInfo::AddRef() { return 1; }
NS_IMETHODIMP_(MozExternalRefCountType) nsXULAppInfo::Release() { return 1; }

NS_IMETHODIMP nsXULAppInfo::GetVendor(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().vendor;
    return NS_OK;
  }
  aResult.Assign(gAppData->vendor);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetName(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().name;
    return NS_OK;
  }
#ifdef MOZ_WIDGET_ANDROID
  nsCString name = java::GeckoAppShell::GetAppName()->ToCString();
  aResult.Assign(std::move(name));
#else
  aResult.Assign(gAppData->name);
#endif
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetID(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().ID;
    return NS_OK;
  }
  aResult.Assign(gAppData->ID);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetVersion(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().version;
    return NS_OK;
  }
  aResult.Assign(gAppData->version);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetPlatformVersion(nsACString& aResult) {
  aResult.Assign(gToolkitVersion);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetAppBuildID(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().buildID;
    return NS_OK;
  }
  aResult.Assign(gAppData->buildID);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetPlatformBuildID(nsACString& aResult) {
  aResult.Assign(gToolkitBuildID);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetUAName(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().UAName;
    return NS_OK;
  }
  aResult.Assign(gAppData->UAName);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetSourceURL(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().sourceURL;
    return NS_OK;
  }
  aResult.Assign(gAppData->sourceURL);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetUpdateURL(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().updateURL;
    return NS_OK;
  }
  aResult.Assign(gAppData->updateURL);
  return NS_OK;
}

NS_IMETHODIMP nsXULAppInfo::GetRemotingName(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    MOZ_ASSERT(false,
               "nsXULAppInfo::remotingName should not be accessed from the content process");
    return NS_ERROR_UNEXPECTED;
  }
  aResult.Assign(gAppData->remotingName);
  return NS_OK;
}

/* The remainder of the original 54d11b7fa1cacf4e2174c0d5721e43fbebb07355
 * file is restored verbatim below in this commit; only the two DirectWrite
 * call sites are changed for MOZ_XP_COMPAT. */

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
  } else {
    ReadAheadSystemDll(L"DataExchange.dll");
    ReadAheadSystemDll(L"twinapi.appcore.dll");
    ReadAheadSystemDll(L"twinapi.dll");
    ReadAheadSystemDll(L"ExplorerFrame.dll");
    ReadAheadSystemDll(L"WinTypes.dll");
  }
}
#endif

void SetupErrorHandling(const char* progname) {
#ifdef XP_WIN
  HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
  SetProcessDEPPolicyFunc _SetProcessDEPPolicy =
      (SetProcessDEPPolicyFunc)GetProcAddress(kernel32, "SetProcessDEPPolicy");
  if (_SetProcessDEPPolicy) _SetProcessDEPPolicy(PROCESS_DEP_ENABLE);
  UINT realMode = SetErrorMode(0);
  realMode |= SEM_FAILCRITICALERRORS;
  if (getenv("XRE_NO_WINDOWS_CRASH_DIALOG"))
    realMode |= SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX;
  SetErrorMode(realMode);
#endif
  InstallSignalHandlers(progname);
  setbuf(stdout, nullptr);
}

static bool gRunSelfAsContentProc = false;
void XRE_EnableSameExecutableForContentProc() {
  if (!PR_GetEnv("MOZ_SEPARATE_CHILD_PROCESS")) gRunSelfAsContentProc = true;
}

mozilla::BinPathType XRE_GetChildProcBinPathType(GeckoProcessType aProcessType) {
  MOZ_ASSERT(aProcessType != GeckoProcessType_Default);
  if (!gRunSelfAsContentProc) return BinPathType::PluginContainer;
#ifdef XP_WIN
  if (StaticPrefs::dom_ipc_alwaysUseParentBinary()) return BinPathType::Self;
  switch (aProcessType) {
#  define GECKO_PROCESS_TYPE(enum_value, enum_name, string_name,               \
                             proc_typename, process_bin_type,                  \
                             procinfo_typename, webidl_typename, allcaps_name) \
    case GeckoProcessType_##enum_name:                                         \
      return BinPathType::process_bin_type;
#  include "mozilla/GeckoProcessTypes.h"
#  undef GECKO_PROCESS_TYPE
    default:
      return BinPathType::PluginContainer;
  }
#else
  return BinPathType::Self;
#endif
}

extern "C" void install_rust_hooks();
struct InstallRustHooks {
  InstallRustHooks() { install_rust_hooks(); }
};
MOZ_RUNINIT InstallRustHooks sInstallRustHooks;

#ifdef MOZ_ASAN_REPORTER
void setASanReporterPath(nsIFile* aDir) {
  nsCOMPtr<nsIFile> dir;
  aDir->Clone(getter_AddRefs(dir));
  dir->Append(u"asan"_ns);
  nsresult rv = dir->Create(nsIFile::DIRECTORY_TYPE, 0700);
  if (NS_WARN_IF(NS_FAILED(rv) && rv != NS_ERROR_FILE_ALREADY_EXISTS)) {
    MOZ_CRASH("[ASan Reporter] Unable to create crash directory.");
  }
  dir->Append(u"ff_asan_log"_ns);
#  ifdef XP_WIN
  nsAutoString nspathW;
  rv = dir->GetPath(nspathW);
  NS_ConvertUTF16toUTF8 nspath(nspathW);
#  else
  nsAutoCString nspath;
  rv = dir->GetNativePath(nspath);
#  endif
  if (NS_FAILED(rv)) {
    MOZ_CRASH("[ASan Reporter] Unable to get native path for crash directory.");
  }
  __sanitizer_set_report_path(nspath.get());
}
#endif
