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

#if defined(MOZ_WAYLAND)
bool IsWaylandEnabled() {
  static bool isWaylandEnabled = []() {
    const char* waylandDisplay = PR_GetEnv("WAYLAND_DISPLAY");
    if (!waylandDisplay) {
      return false;
    }
    if (!PR_GetEnv("DISPLAY")) {
      // No X11 display, so try to run wayland.
      return true;
    }
    // MOZ_ENABLE_WAYLAND is our primary Wayland on/off switch.
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
    // Enable by default when we're running on a recent enough GTK version. We'd
    // like to check further details like compositor version and so on ideally
    // to make sure we don't enable it on old Mutter or what not, but we can't,
    // so let's assume that if the user is running on a Wayland session by
    // default we're ok, since either the distro has enabled Wayland by default,
    // or the user has gone out of their way to use Wayland.
    return !gtk_check_version(3, 24, 30);
  }();
  return isWaylandEnabled;
}
#else
bool IsWaylandEnabled() { return false; }
#endif

/**
 * Output a string to the user.  This method is really only meant to be used to
 * output last-ditch error messages designed for developers NOT END USERS.
 *
 * @param isError
 *        Pass true to indicate severe errors.
 * @param fmt
 *        printf-style format string followed by arguments.
 */
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

/**
 * Check for a commandline flag. If the flag takes a parameter, the
 * parameter is returned in aParam. Flags may be in the form -arg or
 * --arg (or /arg on win32).
 *
 * @param aArg the parameter to check. Must be lowercase.
 * @param aParam if non-null, the -arg <data> will be stored in this pointer.
 *        This is *not* allocated, but rather a pointer to the argv data.
 * @param aFlags flags @see CheckArgFlag
 */
static ArgResult CheckArg(const char* aArg, const char** aParam = nullptr,
                          CheckArgFlag aFlags = CheckArgFlag::RemoveArg) {
  MOZ_ASSERT(gArgv, "gArgv must be initialized before CheckArg()");
  return CheckArg(gArgc, gArgv, aArg, aParam, aFlags);
}

/**
 * Check for a commandline flag. Ignore data that's passed in with the flag.
 * Flags may be in the form -arg or --arg (or /arg on win32).
 * Will not remove flag if found.
 *
 * @param aArg the parameter to check. Must be lowercase.
 */
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

  // If we're not in the parent process, we are running E10s.
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

// Win32k Infrastructure ==============================================

// This bool tells us if we have initialized the following two statics
// upon startup.

static bool gWin32kInitialized = false;

// Win32k Lockdown for the current session is determined once, at startup,
// and then remains the same for the duration of the session.

static nsIXULRuntime::ContentWin32kLockdownState gWin32kStatus;

// The status of the win32k experiment. It is determined once, at startup,
// and then remains the same for the duration of the session.

static nsIXULRuntime::ExperimentStatus gWin32kExperimentStatus =
    nsIXULRuntime::eExperimentStatusUnenrolled;

#ifdef XP_WIN
// The states for win32k lockdown can be generalized to:
//  - User doesn't meet requirements (bad OS, webrender, remotegl) aka
//  PersistentRequirement
//  - User has Safe Mode enabled, Win32k Disabled by Env Var, or E10S disabled
//  by Env Var aka TemporaryRequirement
//  - User has set the win32k pref to something non-default aka NonDefaultPref
//  - User has been enrolled in the experiment and does what it says aka
//  Enrolled
//  - User does the default aka Default
//
// We expect the below behvaior.  In the code, there may be references to these
//     behaviors (e.g. [A]) but not always.
//
// [A] Becoming enrolled in the experiment while NonDefaultPref disqualifies
//     you upon next browser start
// [B] Becoming enrolled in the experiment while PersistentRequirement
//     disqualifies you upon next browser start
// [C] Becoming enrolled in the experiment while TemporaryRequirement does not
//     disqualify you
// [D] Becoming enrolled in the experiment will only take effect after restart
// [E] While enrolled, becoming PersistentRequirement will not disqualify you
//     until browser restart, but if the state is present at browser start,
//     will disqualify you. Additionally, it will not affect the session value
//     of gWin32kStatus.
//     XXX(bobowen): I hope both webrender and wbgl.out-of-process require a
//                   restart to take effect!
// [F] While enrolled, becoming NonDefaultPref will disqualify you upon next
//     browser start
// [G] While enrolled, becoming TemporaryRequirement will _not_ disqualify you,
//     but the session status will prevent win32k lockdown from taking effect.

// The win32k pref
static const char kPrefWin32k[] = "security.sandbox.content.win32k-disable";

// The current enrollment status as controlled by Normandy. This value is only
// stored in the default preference branch, and is not persisted across
// sessions by the preference service. It therefore isn't available early
// enough at startup, and needs to be synced to a preference in the user
// branch which is persisted across sessions.
static const char kPrefWin32kExperimentEnrollmentStatus[] =
    "security.sandbox.content.win32k-experiment.enrollmentStatus";

// The enrollment status to be used at browser startup. This automatically
// synced from the above enrollmentStatus preference whenever the latter is
// changed. We reused the Fission experiment enum - it can have any of the
// values defined in the `nsIXULRuntime_ExperimentStatus` enum _except_ rollout.
// Meanings are documented in the declaration of
// `nsIXULRuntime.fissionExperimentStatus`
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

  // Set the startup pref for next browser start [D]
  Preferences::SetUint(kPrefWin32kExperimentStartupEnrollmentStatus, newStatus);
}

namespace {
// This observer is notified during `profile-before-change`, and ensures that
// the experiment enrollment status is synced over before the browser shuts
// down, even if it was not modified since win32k was initialized.
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
}  // namespace

static void OnWin32kChanged(const char* aPref, void* aData) {
  // If we're actively enrolled in the Win32k experiment, disqualify the user
  // from the experiment if the Win32k pref is modified. [F]
  if (Win32kExperimentEnrolled() && Preferences::HasUserValue(kPrefWin32k)) {
    Win32kExperimentDisqualify();
  }
}

#endif  // XP_WIN

namespace mozilla {
void EnsureWin32kInitialized();
}

nsIXULRuntime::ContentWin32kLockdownState GetLiveWin32kLockdownState() {
#ifdef XP_WIN

  // HasUserValue The Pref functions can only be called on main thread
  MOZ_ASSERT(NS_IsMainThread());

#  ifdef MOZ_BACKGROUNDTASKS
  if (BackgroundTasks::IsBackgroundTaskMode()) {
    // Let's bail out before loading all the graphics libs.
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByDefault;
  }
#  endif

  mozilla::EnsureWin32kInitialized();
  gfxPlatform::GetPlatform();

  if (EnvHasValue("MOZ_ENABLE_WIN32K")) {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByEnvVar;
  }

  if (!mozilla::BrowserTabsRemoteAutostart()) {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByE10s;
  }

  // Win32k lockdown is available on Win8+, but we are initially limiting it to
  // Windows 10 v1709 (build 16299) or later. Before this COM initialization
  // currently fails if user32.dll has loaded before it is called.
  if (!IsWin10FallCreatorsUpdateOrLater()) {
    return nsIXULRuntime::ContentWin32kLockdownState::
        OperatingSystemNotSupported;
  }

  // Non-native theming is required as well
  if (!StaticPrefs::widget_non_native_theme_enabled()) {
    return nsIXULRuntime::ContentWin32kLockdownState::MissingNonNativeTheming;
  }

  // Some (not sure exactly which) decoders are not compatible
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
    if (prefValue) {
      return nsIXULRuntime::ContentWin32kLockdownState::EnabledByUserPref;
    } else {
      return nsIXULRuntime::ContentWin32kLockdownState::DisabledByUserPref;
    }
  }

  if (gWin32kExperimentStatus ==
      nsIXULRuntime::ExperimentStatus::eExperimentStatusControl) {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByControlGroup;
  } else if (gWin32kExperimentStatus ==
             nsIXULRuntime::ExperimentStatus::eExperimentStatusTreatment) {
    return nsIXULRuntime::ContentWin32kLockdownState::EnabledByTreatmentGroup;
  }

  if (defaultValue) {
    return nsIXULRuntime::ContentWin32kLockdownState::EnabledByDefault;
  } else {
    return nsIXULRuntime::ContentWin32kLockdownState::DisabledByDefault;
  }

#else

  return nsIXULRuntime::ContentWin32kLockdownState::OperatingSystemNotSupported;

#endif
}

namespace mozilla {

void EnsureWin32kInitialized() {
  if (gWin32kInitialized) {
    return;
  }
  gWin32kInitialized = true;

#ifdef XP_WIN

  // Initialize the Win32k experiment, configuring win32k's
  // default, before checking other overrides. This allows opting-out of a
  // Win32k experiment through about:preferences or about:config from a
  // safemode session.
  uint32_t experimentRaw =
      Preferences::GetUint(kPrefWin32kExperimentStartupEnrollmentStatus,
                           nsIXULRuntime::eExperimentStatusUnenrolled);
  gWin32kExperimentStatus =
      experimentRaw < nsIXULRuntime::eExperimentStatusCount
          ? nsIXULRuntime::ExperimentStatus(experimentRaw)
          : nsIXULRuntime::eExperimentStatusDisqualified;

  // Watch the experiment enrollment status pref to detect experiment
  // disqualification, and ensure it is propagated for the next restart.
  Preferences::RegisterCallback(&OnWin32kEnrollmentStatusChanged,
                                kPrefWin32kExperimentEnrollmentStatus);
  if (nsCOMPtr<nsIObserverService> observerService =
          mozilla::services::GetObserverService()) {
    nsCOMPtr<nsIObserver> shutdownObserver =
        new Win32kEnrollmentStatusShutdownObserver();
    observerService->AddObserver(shutdownObserver, "profile-before-change",
                                 false);
  }

  // If the user no longer qualifies because they edited a required pref, check
  // that. [B] [E]
  auto tmpStatus = GetLiveWin32kLockdownState();
  if (Win32kExperimentEnrolled() && Win32kRequirementsUnsatisfied(tmpStatus)) {
    Win32kExperimentDisqualify();
    gWin32kExperimentStatus = nsIXULRuntime::eExperimentStatusDisqualified;
  }

  // If the user has overridden an active experiment by setting a user value for
  // "security.sandbox.content.win32k-disable", disqualify the user from the
  // experiment. [A] [F]
  if (Preferences::HasUserValue(kPrefWin32k) && Win32kExperimentEnrolled()) {
    Win32kExperimentDisqualify();
    gWin32kExperimentStatus = nsIXULRuntime::eExperimentStatusDisqualified;
  }

  // Unlike Fission, we do not configure the default branch based on experiment
  // enrollment status.  Instead we check the startupEnrollmentPref in
  // GetContentWin32kLockdownState()

  Preferences::RegisterCallback(&OnWin32kChanged, kPrefWin32k);

  // Set the state
  gWin32kStatus = GetLiveWin32kLockdownState();

#else
  gWin32kStatus =
      nsIXULRuntime::ContentWin32kLockdownState::OperatingSystemNotSupported;
  gWin32kExperimentStatus = nsIXULRuntime::eExperimentStatusUnenrolled;

#endif  // XP_WIN
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

// End Win32k Infrastructure ==========================================

// Fission Infrastructure =============================================

// Fission enablement for the current session is determined once, at startup,
// and then remains the same for the duration of the session.
//
// The following factors determine whether or not Fission is enabled for a
// session, in order of precedence:
//
// - Safe mode: In safe mode, Fission is never enabled.
//
// - The MOZ_FORCE_ENABLE_FISSION environment variable: If set to any value,
//   Fission will be enabled.
//
// - The 'fission.autostart' preference, if it has been configured by the user.
static const char kPrefFissionAutostart[] = "fission.autostart";

// The computed FissionAutostart value for the session, read by content
// processes to initialize gFissionAutostart.
//
// This pref is locked, and only configured on the default branch, so should
// never be persisted in a profile.
static const char kPrefFissionAutostartSession[] = "fission.autostart.session";

//
// The computed FissionAutostart value for the session, read by content
// processes to initialize gFissionAutostart.

static bool gFissionAutostart = false;
static bool gFissionAutostartInitialized = false;
static nsIXULRuntime::FissionDecisionStatus gFissionDecisionStatus;
static void EnsureFissionAutostartInitialized() {
  if (gFissionAutostartInitialized) {
    return;
  }
  gFissionAutostartInitialized = true;

  if (!XRE_IsParentProcess()) {
    // This pref is configured for the current session by the parent process.
    gFissionAutostart = Preferences::GetBool(kPrefFissionAutostartSession,
                                             false, PrefValueKind::Default);
    return;
  }

  if (!BrowserTabsRemoteAutostart()) {
    gFissionAutostart = false;
    if (gBrowserTabsRemoteStatus == kE10sForceDisabled) {
      gFissionDecisionStatus = nsIXULRuntime::eFissionDisabledByE10sEnv;
    } else {
      gFissionDecisionStatus = nsIXULRuntime::eFissionDisabledByE10sOther;
    }
  } else if (EnvHasValue("MOZ_FORCE_ENABLE_FISSION")) {
    gFissionAutostart = true;
    gFissionDecisionStatus = nsIXULRuntime::eFissionEnabledByEnv;
  } else if (EnvHasValue("MOZ_FORCE_DISABLE_FISSION")) {
    gFissionAutostart = false;
    gFissionDecisionStatus = nsIXULRuntime::eFissionDisabledByEnv;
  } else {
    // NOTE: This will take into account changes to the default due to
    // `InitializeFissionExperimentStatus`.
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

  // Content processes cannot run the same logic as we're running in the parent
  // process, as the current value of various preferences may have changed
  // between launches. Instead, the content process will read the default branch
  // of the locked `fission.autostart.session` preference to determine the value
  // determined by this method.
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

}  // namespace mozilla

// End Fission Infrastructure ==========================================

namespace mozilla {

bool SessionStorePlatformCollection() {
  return !StaticPrefs::
      browser_sessionstore_disable_platform_collection_AtStartup_DoNotUseDirectly();
}

bool BFCacheInParent() {
  return StaticPrefs::fission_bfcacheInParent_DoNotUseDirectly();
}

}  // namespace mozilla

/**
 * The nsXULAppInfo object implements nsIFactory so that it can be its own
 * singleton.
 */
class nsXULAppInfo : public nsIXULAppInfo,
#ifdef XP_WIN
                     public nsIWinAppHelper,
#endif
                     public nsICrashReporter,
                     public nsIFinishDumpingCallback,
                     public nsIXULRuntime

{
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
  NS_INTERFACE_MAP_ENTRY(nsIFinishDumpingCallback)
  NS_INTERFACE_MAP_ENTRY(nsIPlatformInfo)
  NS_INTERFACE_MAP_ENTRY_CONDITIONAL(nsIXULAppInfo,
                                     gAppData || XRE_IsContentProcess())
NS_INTERFACE_MAP_END

NS_IMETHODIMP_(MozExternalRefCountType)
nsXULAppInfo::AddRef() { return 1; }

NS_IMETHODIMP_(MozExternalRefCountType)
nsXULAppInfo::Release() { return 1; }

NS_IMETHODIMP
nsXULAppInfo::GetVendor(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().vendor;
    return NS_OK;
  }
  aResult.Assign(gAppData->vendor);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetName(nsACString& aResult) {
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

NS_IMETHODIMP
nsXULAppInfo::GetID(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().ID;
    return NS_OK;
  }
  aResult.Assign(gAppData->ID);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetVersion(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().version;
    return NS_OK;
  }
  aResult.Assign(gAppData->version);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetPlatformVersion(nsACString& aResult) {
  aResult.Assign(gToolkitVersion);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetAppBuildID(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().buildID;
    return NS_OK;
  }
  aResult.Assign(gAppData->buildID);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetPlatformBuildID(nsACString& aResult) {
  aResult.Assign(gToolkitBuildID);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetUAName(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().UAName;
    return NS_OK;
  }
  aResult.Assign(gAppData->UAName);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetSourceURL(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().sourceURL;
    return NS_OK;
  }
  aResult.Assign(gAppData->sourceURL);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetUpdateURL(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    aResult = cc->GetAppInfo().updateURL;
    return NS_OK;
  }
  aResult.Assign(gAppData->updateURL);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetRemotingName(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    MOZ_ASSERT(false,
               "nsXULAppInfo::remotingName should not be accessed from the "
               "content process");
    return NS_ERROR_UNEXPECTED;
  }
  aResult.Assign(gAppData->remotingName);

  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetLogConsoleErrors(bool* aResult) {
  *aResult = gLogConsoleErrors;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::SetLogConsoleErrors(bool aValue) {
  gLogConsoleErrors = aValue;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetInSafeMode(bool* aResult) {
  *aResult = gSafeMode;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetOS(nsACString& aResult) {
  aResult.AssignLiteral(OS_TARGET);
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetXPCOMABI(nsACString& aResult) {
#ifdef TARGET_XPCOM_ABI
  aResult.AssignLiteral(TARGET_XPCOM_ABI);
  return NS_OK;
#else
  return NS_ERROR_NOT_AVAILABLE;
#endif
}

NS_IMETHODIMP
nsXULAppInfo::GetWidgetToolkit(nsACString& aResult) {
  aResult.AssignLiteral(MOZ_WIDGET_TOOLKIT);
  return NS_OK;
}

// Ensure that the GeckoProcessType enum, defined in xpcom/build/nsXULAppAPI.h,
// is synchronized with the const unsigned longs defined in
// xpcom/system/nsIXULRuntime.idl.
#define GECKO_PROCESS_TYPE(enum_value, enum_name, string_name, proc_typename, \
                           process_bin_type, procinfo_typename,               \
                           webidl_typename, allcaps_name)                     \
  static_assert(nsIXULRuntime::PROCESS_TYPE_##allcaps_name ==                 \
                    static_cast<int>(GeckoProcessType_##enum_name),           \
                "GeckoProcessType in nsXULAppAPI.h not synchronized with "    \
                "nsIXULRuntime.idl");
#include "mozilla/GeckoProcessTypes.h"
#undef GECKO_PROCESS_TYPE

// .. and ensure that that is all of them:
static_assert(GeckoProcessType_Utility + 1 == GeckoProcessType_End,
              "Did not find the final GeckoProcessType");

NS_IMETHODIMP
nsXULAppInfo::GetProcessType(uint32_t* aResult) {
  NS_ENSURE_ARG_POINTER(aResult);
  *aResult = XRE_GetProcessType();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetProcessID(uint32_t* aResult) {
#ifdef XP_WIN
  *aResult = GetCurrentProcessId();
#else
  *aResult = getpid();
#endif
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetUniqueProcessID(uint64_t* aResult) {
  if (XRE_IsContentProcess()) {
    ContentChild* cc = ContentChild::GetSingleton();
    *aResult = cc->GetID();
  } else {
    *aResult = 0;
  }
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetRemoteType(nsACString& aRemoteType) {
  if (XRE_IsContentProcess()) {
    aRemoteType = ContentChild::GetSingleton()->GetRemoteType();
  } else {
    aRemoteType = NOT_REMOTE_TYPE;
  }

  return NS_OK;
}

constinit static nsCString gLastAppVersion;
constinit static nsCString gLastAppBuildID;

// Whether the loaded profile's compatibility.ini carries EncryptedDatabases=1.
// Populated by CheckCompatibility() (which already parses compatibility.ini)
// and consulted by the encryption-compatibility gate in XRE_mainStartup.
static bool gProfileEncryptedDatabases = false;

NS_IMETHODIMP
nsXULAppInfo::GetLastAppVersion(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    return NS_ERROR_NOT_AVAILABLE;
  }

  if (!gLastAppVersion.IsVoid() && gLastAppVersion.IsEmpty()) {
    NS_WARNING("Attempt to retrieve lastAppVersion before it has been set.");
    return NS_ERROR_NOT_AVAILABLE;
  }

  aResult.Assign(gLastAppVersion);
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetLastAppBuildID(nsACString& aResult) {
  if (XRE_IsContentProcess()) {
    return NS_ERROR_NOT_AVAILABLE;
  }

  if (!gLastAppBuildID.IsVoid() && gLastAppBuildID.IsEmpty()) {
    NS_WARNING("Attempt to retrieve lastAppBuildID before it has been set.");
    return NS_ERROR_NOT_AVAILABLE;
  }

  aResult.Assign(gLastAppBuildID);
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetFissionAutostart(bool* aResult) {
  *aResult = FissionAutostart();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetWin32kExperimentStatus(ExperimentStatus* aResult) {
  if (!XRE_IsParentProcess()) {
    return NS_ERROR_NOT_AVAILABLE;
  }

  EnsureWin32kInitialized();
  *aResult = gWin32kExperimentStatus;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetWin32kLiveStatusTestingOnly(
    nsIXULRuntime::ContentWin32kLockdownState* aResult) {
  if (!XRE_IsParentProcess()) {
    return NS_ERROR_NOT_AVAILABLE;
  }

  EnsureWin32kInitialized();
  *aResult = GetLiveWin32kLockdownState();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetWin32kSessionStatus(
    nsIXULRuntime::ContentWin32kLockdownState* aResult) {
  if (!XRE_IsParentProcess()) {
    return NS_ERROR_NOT_AVAILABLE;
  }

  EnsureWin32kInitialized();
  *aResult = gWin32kStatus;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetFissionDecisionStatus(FissionDecisionStatus* aResult) {
  if (!XRE_IsParentProcess()) {
    return NS_ERROR_NOT_AVAILABLE;
  }

  EnsureFissionAutostartInitialized();

  MOZ_ASSERT(gFissionDecisionStatus != eFissionStatusUnknown);
  *aResult = gFissionDecisionStatus;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetFissionDecisionStatusString(nsACString& aResult) {
  if (!XRE_IsParentProcess()) {
    return NS_ERROR_NOT_AVAILABLE;
  }

  EnsureFissionAutostartInitialized();
  switch (gFissionDecisionStatus) {
    case eFissionDisabledByE10sEnv:
      aResult = "disabledByE10sEnv";
      break;
    case eFissionEnabledByEnv:
      aResult = "enabledByEnv";
      break;
    case eFissionDisabledByEnv:
      aResult = "disabledByEnv";
      break;
    case eFissionEnabledByDefault:
      aResult = "enabledByDefault";
      break;
    case eFissionDisabledByDefault:
      aResult = "disabledByDefault";
      break;
    case eFissionEnabledByUserPref:
      aResult = "enabledByUserPref";
      break;
    case eFissionDisabledByUserPref:
      aResult = "disabledByUserPref";
      break;
    case eFissionDisabledByE10sOther:
      aResult = "disabledByE10sOther";
      break;
    default:
      MOZ_ASSERT_UNREACHABLE("Unexpected enum value");
  }
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetSessionStorePlatformCollection(bool* aResult) {
  *aResult = SessionStorePlatformCollection();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetBrowserTabsRemoteAutostart(bool* aResult) {
  *aResult = BrowserTabsRemoteAutostart();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetMaxWebProcessCount(uint32_t* aResult) {
  *aResult = mozilla::GetMaxWebProcessCount();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetAccessibilityEnabled(bool* aResult) {
#ifdef ACCESSIBILITY
  *aResult = GetAccService() != nullptr;
#else
  *aResult = false;
#endif
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetAccessibilityInstantiator(nsAString& aInstantiator) {
  aInstantiator.Truncate();
#if defined(ACCESSIBILITY)
  if (GetAccService()) {
    a11y::GetHumanReadableInstantiatorStr(aInstantiator);
#  if defined(XP_WIN)
    aInstantiator.AppendLiteral("|");

    nsCOMPtr<nsIFile> oopClientExe;
    if (a11y::GetInstantiator(getter_AddRefs(oopClientExe))) {
      nsAutoString oopClientInfo;
      if (NS_SUCCEEDED(oopClientExe->GetPath(oopClientInfo))) {
        aInstantiator.Append(oopClientInfo);
      }
    }
#  endif
  }
#endif
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetIs64Bit(bool* aResult) {
#ifdef HAVE_64BIT_BUILD
  *aResult = true;
#else
  *aResult = false;
#endif
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetIsTextRecognitionSupported(bool* aResult) {
  *aResult = widget::TextRecognition::IsSupported();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::InvalidateCachesOnRestart() {
  nsCOMPtr<nsIFile> file;
  nsresult rv =
      NS_GetSpecialDirectory(NS_APP_PROFILE_DIR_STARTUP, getter_AddRefs(file));
  if (NS_FAILED(rv)) return rv;
  if (!file) return NS_ERROR_NOT_AVAILABLE;

  file->AppendNative(FILE_COMPATIBILITY_INFO);

  nsINIParser parser;
  rv = parser.Init(file);
  if (NS_FAILED(rv)) {
    // This fails if compatibility.ini is not there, so we'll
    // flush the caches on the next restart anyways.
    return NS_OK;
  }

  nsAutoCString buf;
  rv = parser.GetString("Compatibility", "InvalidateCaches", buf);

  if (NS_FAILED(rv)) {
    PRFileDesc* fd;
    rv = file->OpenNSPRFileDesc(PR_RDWR | PR_APPEND, 0600, &fd);
    if (NS_FAILED(rv)) {
      NS_ERROR("could not create output stream");
      return NS_ERROR_NOT_AVAILABLE;
    }
    static const char kInvalidationHeader[] =
        NS_LINEBREAK "InvalidateCaches=1" NS_LINEBREAK;
    PR_Write(fd, kInvalidationHeader, sizeof(kInvalidationHeader) - 1);
    PR_Close(fd);
  }
  return NS_OK;
}

nsresult mozilla::MarkProfileEncryptedDatabases() {
  nsCOMPtr<nsIFile> file;
  nsresult rv =
      NS_GetSpecialDirectory(NS_APP_PROFILE_DIR_STARTUP, getter_AddRefs(file));
  if (NS_FAILED(rv) || !file) return NS_OK;

  file->AppendNative(FILE_COMPATIBILITY_INFO);

  nsINIParser parser;
  rv = parser.Init(file);
  if (NS_FAILED(rv)) {
    return NS_OK;
  }

  nsAutoCString buf;
  rv = parser.GetString("Compatibility", "EncryptedDatabases", buf);
  if (NS_SUCCEEDED(rv)) {
    return NS_OK;
  }

  PRFileDesc* fd;
  rv = file->OpenNSPRFileDesc(PR_RDWR | PR_APPEND, 0600, &fd);
  if (NS_FAILED(rv)) {
    return NS_ERROR_NOT_AVAILABLE;
  }
  static const char kEncryptedHeader[] =
      NS_LINEBREAK "EncryptedDatabases=1" NS_LINEBREAK;
  PR_Write(fd, kEncryptedHeader, sizeof(kEncryptedHeader) - 1);
  PR_Close(fd);
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::MarkProfileEncryptedDatabases() {
  return mozilla::MarkProfileEncryptedDatabases();
}

NS_IMETHODIMP
nsXULAppInfo::GetReplacedLockTime(PRTime* aReplacedLockTime) {
  if (!gProfileLock) return NS_ERROR_NOT_AVAILABLE;
  gProfileLock->GetReplacedLockTime(aReplacedLockTime);
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetDefaultUpdateChannel(nsACString& aResult) {
  aResult.AssignLiteral(MOZ_STRINGIFY(MOZ_UPDATE_CHANNEL));
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetDistributionID(nsACString& aResult) {
  aResult.AssignLiteral(MOZ_DISTRIBUTION_ID);
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetWindowsDLLBlocklistStatus(bool* aResult) {
#if defined(HAS_DLL_BLOCKLIST)
  *aResult = DllBlocklist_CheckStatus();
#else
  *aResult = false;
#endif
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetRestartedByOS(bool* aResult) {
  *aResult = gRestartedByOS;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetChromeColorSchemeIsDark(bool* aResult) {
  *aResult = PreferenceSheet::ColorSchemeForChrome() == ColorScheme::Dark;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetNativeMenubar(bool* aResult) {
  *aResult = !!LookAndFeel::GetInt(LookAndFeel::IntID::NativeMenubar);
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetContentThemeDerivedColorSchemeIsDark(bool* aResult) {
  *aResult =
      PreferenceSheet::ThemeDerivedColorSchemeForContent() == ColorScheme::Dark;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetPrefersReducedMotion(bool* aResult) {
  *aResult =
      LookAndFeel::GetInt(LookAndFeel::IntID::PrefersReducedMotion, 0) == 1;
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetDrawInTitlebar(bool* aResult) {
  *aResult = LookAndFeel::DrawInTitlebar();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetCaretBlinkCount(int32_t* aResult) {
  *aResult = LookAndFeel::CaretBlinkCount();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetCaretBlinkTime(int32_t* aResult) {
  *aResult = LookAndFeel::CaretBlinkTime();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetDesktopEnvironment(nsACString& aDesktopEnvironment) {
#ifdef MOZ_WIDGET_GTK
  aDesktopEnvironment.Assign(GetDesktopEnvironmentIdentifier());
#endif
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetIsWayland(bool* aResult) {
#ifdef MOZ_WIDGET_GTK
  *aResult = GdkIsWaylandDisplay();
#else
  *aResult = false;
#endif
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::GetProcessStartupShortcut(nsAString& aShortcut) {
#if defined(XP_WIN)
  if (XRE_IsParentProcess()) {
    aShortcut.Assign(gProcessStartupShortcut);
    return NS_OK;
  }
#endif
  return NS_ERROR_NOT_AVAILABLE;
}

#if defined(XP_WIN) && defined(MOZ_LAUNCHER_PROCESS)
void SetupLauncherProcessPref();
static Maybe<LauncherRegistryInfo::EnabledState> gLauncherProcessState;
#endif

NS_IMETHODIMP
nsXULAppInfo::GetLauncherProcessState(uint32_t* aResult) {
#if defined(XP_WIN) && defined(MOZ_LAUNCHER_PROCESS)
  SetupLauncherProcessPref();
  if (!gLauncherProcessState) {
    return NS_ERROR_UNEXPECTED;
  }
  *aResult = static_cast<uint32_t>(gLauncherProcessState.value());
  return NS_OK;
#else
  return NS_ERROR_NOT_AVAILABLE;
#endif
}

#ifdef XP_WIN
NS_IMETHODIMP
nsXULAppInfo::GetUserCanElevate(bool* aUserCanElevate) {
  HANDLE rawToken;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_QUERY, &rawToken)) {
    *aUserCanElevate = false;
    return NS_OK;
  }
  nsAutoHandle token(rawToken);
  LauncherResult<TOKEN_ELEVATION_TYPE> elevationType = GetElevationType(token);
  if (elevationType.isErr()) {
    *aUserCanElevate = false;
    return NS_OK;
  }
  *aUserCanElevate = (elevationType.inspect() == TokenElevationTypeLimited);
  return NS_OK;
}
#endif

static Result<CrashReporter::Annotation, nsresult> GetCrashAnnotation(
    const nsACString& aKey) {
  auto maybeAnnotation = CrashReporter::AnnotationFromString(aKey);
#ifdef DEBUG
  if (!maybeAnnotation.isSome()) {
    std::string warning = "Annotation identifier not found: \"";
    warning += aKey.View();
    warning += "\"";
    NS_WARNING(warning.c_str());
  }
  if (!StaticPrefs::toolkit_crash_annotation_testing_validation()) {
    MOZ_ASSERT(maybeAnnotation.isSome(),
               "Invalid annotation identifier; ensure it exists in "
               "CrashAnnotations.yaml");
  }
#endif
  NS_ENSURE_TRUE(maybeAnnotation.isSome(), Err(NS_ERROR_INVALID_ARG));
  return maybeAnnotation.extract();
}

NS_IMETHODIMP
nsXULAppInfo::GetCrashReporterEnabled(bool* aEnabled) {
  *aEnabled = CrashReporter::GetEnabled();
  return NS_OK;
}

NS_IMETHODIMP
nsXULAppInfo::SetEnabled(bool aEnabled) {
  if (aEnabled) {
    if (CrashReporter::GetEnabled()) {
      return NS_OK;
    }
    nsCOMPtr<nsIFile> greBinDir;
    NS_GetSpecialDirectory(NS_GRE_BIN_DIR, getter_AddRefs(greBinDir));
    if (!greBinDir) {
      return NS_ERROR_FAILURE;
    }
    nsCOMPtr<nsIFile> xreBinDirectory = greBinDir;
    if (!xreBinDirectory) {
      return NS_ERROR_FAILURE;
    }
    return CrashReporter::SetExceptionHandler(xreBinDirectory, true);
  }
  if (!CrashReporter::GetEnabled()) {
    return NS_OK;
  }
  return CrashReporter::UnsetExceptionHandler();
}

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
  HMODULE dwdll = LoadLibrarySystem32(L"dwrite.dll");
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

#include "GeckoProfiler.h"
#include "ProfilerControl.h"

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
    ReadAheadSystemDll(L"DWrite.dll");
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
  if (!PR_GetEnv("MOZ_SEPARATE_CHILD_PROCESS")) {
    gRunSelfAsContentProc = true;
  }
}

mozilla::BinPathType XRE_GetChildProcBinPathType(
    GeckoProcessType aProcessType) {
  MOZ_ASSERT(aProcessType != GeckoProcessType_Default);
  if (!gRunSelfAsContentProc) {
    return BinPathType::PluginContainer;
  }
#ifdef XP_WIN
  if (StaticPrefs::dom_ipc_alwaysUseParentBinary()) {
    return BinPathType::Self;
  }
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
