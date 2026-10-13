/* Any copyright is dedicated to the Public Domain.
 * http://creativecommons.org/publicdomain/zero/1.0/ */

"use strict";

const { XPBrowserProcessPolicy } = ChromeUtils.importESModule(
  "resource:///modules/XPBrowserProcessPolicy.sys.mjs"
);
const { TabUnloader } = ChromeUtils.importESModule(
  "resource:///modules/TabUnloader.sys.mjs"
);

add_task(async function test_manual_drain_rejects_non_hybrid_mode() {
  if (XPBrowserProcessPolicy.enabled) {
    return;
  }
  await Assert.rejects(
    TabUnloader.unloadAllWebTabsForXP(),
    /XP hybrid web-tab recovery is not enabled/,
    "Manual all-web drain must have no effect outside XP hybrid mode"
  );
});

add_task(async function test_manual_drain_across_windows_on_xp_hybrid() {
  if (!XPBrowserProcessPolicy.enabled) {
    return;
  }

  const url =
    "http://mochi.test:8888/browser/browser/components/tabbrowser/test/browser/tabs/blank.html";
  const originalSelected = gBrowser.selectedTab;
  const tab = BrowserTestUtils.addTab(gBrowser, url);
  const pinned = BrowserTestUtils.addTab(gBrowser, url);
  let secondWindow;

  try {
    await Promise.all([
      BrowserTestUtils.browserLoaded(tab.linkedBrowser),
      BrowserTestUtils.browserLoaded(pinned.linkedBrowser),
    ]);
    gBrowser.pinTab(pinned);

    secondWindow = await BrowserTestUtils.openNewBrowserWindow();
    const remoteInSecondWindow = BrowserTestUtils.addTab(
      secondWindow.gBrowser,
      url
    );
    await BrowserTestUtils.browserLoaded(remoteInSecondWindow.linkedBrowser);
    secondWindow.gBrowser.selectedTab = remoteInSecondWindow;

    for (const candidate of [tab, pinned, remoteInSecondWindow]) {
      is(
        candidate.linkedBrowser.remoteType,
        "web",
        "XP hybrid test uses real web-process tabs"
      );
    }

    const result = await TabUnloader.unloadAllWebTabsForXP();
    ok(!result.busy, "Manual drain is not blocked");
    is(result.failed, 0, "All test web tabs had recoverable state");
    ok(result.unloaded >= 3, "At least the three test web tabs unloaded");

    for (const candidate of [tab, pinned, remoteInSecondWindow]) {
      ok(!candidate.linkedPanel, "Unloaded tab retains its lazy restore slot");
    }
    ok(
      !secondWindow.gBrowser.selectedTab.linkedBrowser.isRemoteBrowser,
      "The selected second-window recovery tab resides in the parent"
    );
    ok(pinned.pinned, "Pinned status survived the manual drain");

    const restored = BrowserTestUtils.browserLoaded(
      tab.linkedBrowser,
      false,
      url
    );
    await BrowserTestUtils.switchTab(gBrowser, tab);
    await restored;
    ok(tab.linkedPanel, "A lazy tab can be restored after the drain");
    is(tab.linkedBrowser.currentURI.spec, url, "Restored tab retains its URL");
  } finally {
    if (secondWindow && !secondWindow.closed) {
      await BrowserTestUtils.closeWindow(secondWindow);
    }
    for (const candidate of [tab, pinned]) {
      if (!candidate.closing && candidate.parentNode) {
        BrowserTestUtils.removeTab(candidate);
      }
    }
    if (!originalSelected.closing && originalSelected.parentNode) {
      gBrowser.selectedTab = originalSelected;
    }
  }
});
