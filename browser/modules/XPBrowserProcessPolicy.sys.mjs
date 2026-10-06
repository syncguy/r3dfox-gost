/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import { AppConstants } from "resource://gre/modules/AppConstants.sys.mjs";

const PREF_NAME = "browser.tabs.remote.xpHybrid.enabled";

function isWindowsXP() {
  if (AppConstants.platform != "win") {
    return false;
  }

  try {
    return Services.sysinfo.getProperty("version").startsWith("5.1");
  } catch (e) {
    return false;
  }
}

function windowFeatureNames(features) {
  return new Set(
    String(features ?? "")
      .split(",")
      .map(feature => feature.trim().split("=", 1)[0].toLowerCase())
      .filter(Boolean)
  );
}

function hasRemotenessOverride(features) {
  const names = windowFeatureNames(features);
  return names.has("remote") || names.has("non-remote");
}

function hasFissionOverride(features) {
  const names = windowFeatureNames(features);
  return names.has("fission") || names.has("non-fission");
}

function appendFeature(features, feature) {
  return features ? `${features},${feature}` : feature;
}

// The mode is intentionally snapshotted when this module is first loaded.
// Browser-window process capability cannot be changed safely underneath
// already-created windows, so changing the pref takes effect after restart.
const prefEnabled = Services.prefs.getBoolPref(PREF_NAME, false);
const windowsXP = isWindowsXP();
const globalRemoteAutostart =
  Services.appinfo.browserTabsRemoteAutostart;
const enabled = prefEnabled && windowsXP && !globalRemoteAutostart;

export const XPBrowserProcessPolicy = Object.freeze({
  PREF_NAME,
  prefEnabled,
  windowsXP,
  globalRemoteAutostart,
  enabled,

  /**
   * Apply the hybrid capability only as the default. Explicit structured
   * options or textual WindowWatcher features always win.
   */
  getWindowOptions({ features, remote, fission } = {}) {
    if (!enabled) {
      return { remote, fission };
    }

    if (remote === undefined && !hasRemotenessOverride(features)) {
      remote = true;
    }

    if (fission === undefined && !hasFissionOverride(features)) {
      fission = false;
    }

    return { remote, fission };
  },

  /**
   * Apply the same default policy to callers that construct a WindowWatcher
   * feature string directly.
   */
  applyWindowFeatureDefaults(features) {
    if (!enabled) {
      return features;
    }

    let result = features ?? "";
    if (!hasRemotenessOverride(result)) {
      result = appendFeature(result, "remote");
    }
    if (!hasFissionOverride(result)) {
      result = appendFeature(result, "non-fission");
    }
    return result;
  },
});
