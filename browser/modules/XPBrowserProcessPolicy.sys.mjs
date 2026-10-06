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
    const [major, minor] = String(
      Services.sysinfo.getProperty("version")
    ).split(".");
    return major == "5" && minor == "1";
  } catch (e) {
    return false;
  }
}

// Directly mirror the WindowFeatures::Tokenize algorithm for the feature
// grammar used by WindowWatcher. A separator is ASCII whitespace, "=" or ",".
// Duplicate names intentionally use the last value.
function tokenizeWindowFeatures(features) {
  const tokens = new Map();
  const input = String(features ?? "");
  let position = 0;

  const isASCIIWhitespace = char =>
    char == " " ||
    char == "\t" ||
    char == "\n" ||
    char == "\f" ||
    char == "\r";
  const isFeatureSeparator = char =>
    isASCIIWhitespace(char) || char == "=" || char == ",";

  while (position < input.length) {
    while (
      position < input.length &&
      isFeatureSeparator(input[position])
    ) {
      position++;
    }

    let nameStart = position;
    while (
      position < input.length &&
      !isFeatureSeparator(input[position])
    ) {
      position++;
    }
    let name = input.slice(nameStart, position).toLowerCase();

    if (name == "screenx") {
      name = "left";
    } else if (name == "screeny") {
      name = "top";
    } else if (name == "innerwidth") {
      name = "width";
    } else if (name == "innerheight") {
      name = "height";
    }

    while (
      position < input.length &&
      isASCIIWhitespace(input[position])
    ) {
      position++;
    }

    let value = "";
    if (
      position < input.length &&
      isFeatureSeparator(input[position])
    ) {
      while (
        position < input.length &&
        isFeatureSeparator(input[position]) &&
        input[position] != ","
      ) {
        position++;
      }

      let valueStart = position;
      while (
        position < input.length &&
        !isFeatureSeparator(input[position])
      ) {
        position++;
      }
      value = input.slice(valueStart, position).toLowerCase();
    }

    if (name) {
      tokens.set(name, value);
    }
  }

  return tokens;
}

function parseWindowFeatureBool(value) {
  if (value == "" || value == "yes" || value == "true") {
    return true;
  }

  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? false : parsed != 0;
}

function hasRemotenessOverride(features) {
  const tokens = tokenizeWindowFeatures(features);
  return tokens.has("remote") || tokens.has("non-remote");
}

function hasFissionOverride(features) {
  const tokens = tokenizeWindowFeatures(features);
  return tokens.has("fission") || tokens.has("non-fission");
}

function resultingCapability(
  tokens,
  positiveName,
  negativeName,
  defaultValue
) {
  if (defaultValue) {
    return tokens.has(negativeName)
      ? !parseWindowFeatureBool(tokens.get(negativeName))
      : true;
  }

  return tokens.has(positiveName)
    ? parseWindowFeatureBool(tokens.get(positiveName))
    : false;
}

function appendFeature(features, feature) {
  return features ? `${features},${feature}` : feature;
}

// The mode is intentionally snapshotted when this module is first loaded.
// Browser-window process capability cannot be changed safely underneath
// already-created windows, so changing the pref takes effect after restart.
const prefEnabled = Services.prefs.getBoolPref(PREF_NAME, false);
const windowsXP = isWindowsXP();
const globalRemoteAutostart = Services.appinfo.browserTabsRemoteAutostart;
const globalFissionAutostart = Services.appinfo.fissionAutostart;
const enabled = prefEnabled && windowsXP && !globalRemoteAutostart;

export const XPBrowserProcessPolicy = Object.freeze({
  PREF_NAME,
  prefEnabled,
  windowsXP,
  globalRemoteAutostart,
  globalFissionAutostart,
  enabled,

  /**
   * Return false when textual WindowWatcher features would create a window
   * whose remote-tabs or remote-subframes capability differs from the required
   * source-window capability. This mirrors WindowWatcher's choice of the
   * positive or negative feature based on the session default.
   */
  windowFeaturesMatchCapabilities(features, { remote, fission }) {
    const tokens = tokenizeWindowFeatures(features);

    if (
      (tokens.has("remote") || tokens.has("non-remote")) &&
      resultingCapability(
        tokens,
        "remote",
        "non-remote",
        globalRemoteAutostart
      ) != remote
    ) {
      return false;
    }

    if (
      (tokens.has("fission") || tokens.has("non-fission")) &&
      resultingCapability(
        tokens,
        "fission",
        "non-fission",
        globalFissionAutostart
      ) != fission
    ) {
      return false;
    }

    return true;
  },

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
