/* Any copyright is dedicated to the Public Domain.
 * http://creativecommons.org/publicdomain/zero/1.0/ */

"use strict";

const { XPBrowserProcessPolicy } = ChromeUtils.importESModule(
  "resource:///modules/XPBrowserProcessPolicy.sys.mjs"
);
const { TabUnloader } = ChromeUtils.importESModule(
  "moz-src:///browser/components/tabbrowser/TabUnloader.sys.mjs"
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

  const manifest = TabUnloader.inspectSharedWebRecycleForXP(gBrowser.selectedTab);
  is(manifest.supported, false, "Process preflight is inert outside XP");
  is(manifest.reason, "xp-hybrid-disabled", "Non-XP rejection is explicit");
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

add_task(async function test_single_selected_web_tab_drain_on_xp_hybrid() {
  if (!XPBrowserProcessPolicy.enabled) {
    return;
  }

  const url =
    "http://mochi.test:8888/browser/browser/components/tabbrowser/test/browser/tabs/blank.html";
  const originalSelected = gBrowser.selectedTab;
  const target = BrowserTestUtils.addTab(gBrowser, url);
  const sibling = BrowserTestUtils.addTab(gBrowser, url);

  try {
    await Promise.all([
      BrowserTestUtils.browserLoaded(target.linkedBrowser),
      BrowserTestUtils.browserLoaded(sibling.linkedBrowser),
    ]);
    is(target.linkedBrowser.remoteType, "web", "Target uses shared web");
    is(sibling.linkedBrowser.remoteType, "web", "Sibling uses shared web");
    await BrowserTestUtils.switchTab(gBrowser, target);
    const originalSiblingBrowser = sibling.linkedBrowser;
    const manifest = TabUnloader.inspectSharedWebRecycleForXP(target);
    ok(manifest.supported, "Target shared-web child has a tab manifest");
    is(manifest.reason, "js-tab-manifest-only", "Native actor audit is still required");
    is(manifest.nativeActorsVerified, false, "JS enumeration is not native proof");
    ok(
      manifest.members.some(member => member.tab === target),
      "Selected tab belongs to the exact child manifest"
    );
    ok(
      manifest.members.some(member => member.tab === sibling),
      "Sibling in the same shared child is in the manifest"
    );
    ok(
      manifest.members.every(
        member => String(member.frameLoader.childID) === String(manifest.childID)
      ),
      "Manifest never includes a different content-process generation"
    );

    const result = await TabUnloader.unloadWebTabForXP(target);
    ok(!result.busy, "Single-tab drain completed");
    is(result.found, 1, "Only the requested tab was considered");
    is(result.unloaded, 1, "Selected web tab was discarded");
    is(result.failed, 0, "Selected tab has restorable cached state");
    ok(!target.linkedPanel, "Discarded tab remains in lazy restore state");
    ok(sibling.linkedPanel, "Untargeted sibling tab remains live");
    is(
      sibling.linkedBrowser,
      originalSiblingBrowser,
      "Single-tab drain did not replace the sibling browser"
    );
    ok(
      !gBrowser.selectedTab.linkedBrowser.isRemoteBrowser,
      "Temporary replacement for selected tab is parent-resident"
    );

    const reloaded = BrowserTestUtils.browserLoaded(
      target.linkedBrowser,
      false,
      url
    );
    await BrowserTestUtils.switchTab(gBrowser, target);
    await reloaded;
    is(target.linkedBrowser.currentURI.spec, url, "Target restored its URL");
  } finally {
    if (!originalSelected.closing && originalSelected.parentNode) {
      gBrowser.selectedTab = originalSelected;
    }
    for (const tab of [target, sibling]) {
      if (!tab.closing && tab.parentNode) {
        BrowserTestUtils.removeTab(tab);
      }
    }
  }
});
