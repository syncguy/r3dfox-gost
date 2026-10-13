/* Any copyright is dedicated to the Public Domain.
 * http://creativecommons.org/publicdomain/zero/1.0/ */

"use strict";

// The manual shared-web drain is an XP hybrid-only feature. Running this test
// on standard e10s/non-hybrid CI must not discard any tabs.
add_task(async function test_xp_manual_drain_not_available_in_other_modes() {
  const { XPBrowserProcessPolicy } = ChromeUtils.importESModule(
    "resource:///modules/XPBrowserProcessPolicy.sys.mjs"
  );
  const { TabUnloader } = ChromeUtils.importESModule(
    "resource:///modules/TabUnloader.sys.mjs"
  );

  if (XPBrowserProcessPolicy.enabled) {
    info("XP hybrid drain is enabled; exercise full behavior on physical XP.");
    return;
  }

  await Assert.rejects(
    TabUnloader.unloadAllWebTabsForXP(),
    /XP hybrid web-tab recovery is not enabled/,
    "Outside XP hybrid mode, the manual drain must reject without side effects"
  );
});
