/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * XP hybrid optional dedicated-web one-slot ledger (P1-C source PoC only).
 *
 * This module DOES NOT authorize Gecko process routing by itself, inspect
 * OS process liveness, launch W1, or expose a browser UI. Its callers must
 * validate the canonical root and wire actual child-retirement evidence.
 * Never persist tickets across browser restart. Keep the module unconsumed
 * until native navigation and popup/adoption gates P1-A/P1-B are in place.
 */
export class XPDedicatedWebSlot {
  #phase = "FREE";
  #serial = 0;
  #ticket = null;
  #root = null;
  #process = null;

  get phase() {
    return this.#phase;
  }

  get generation() {
    return this.#ticket?.generation ?? this.#serial;
  }

  reserve(root) {
    if (!root || typeof root !== "object") {
      throw new TypeError("The dedicated slot requires a parent-owned root");
    }
    if (this.#phase !== "FREE") {
      return null;
    }
    const ticket = Object.freeze({ generation: ++this.#serial });
    this.#ticket = ticket;
    this.#root = root;
    this.#process = null;
    this.#phase = "STARTING";
    return ticket;
  }

  owns(ticket, root) {
    return (
      ticket === this.#ticket &&
      root === this.#root &&
      (this.#phase === "STARTING" || this.#phase === "ACTIVE")
    );
  }

  bindProcess(ticket, process) {
    if (
      this.#phase !== "STARTING" ||
      ticket !== this.#ticket ||
      !process ||
      typeof process !== "object" ||
      (this.#process && this.#process !== process)
    ) {
      return false;
    }
    this.#process = process;
    return true;
  }

  activate(ticket, process) {
    if (
      this.#phase !== "STARTING" ||
      ticket !== this.#ticket ||
      !process ||
      this.#process !== process
    ) {
      return false;
    }
    this.#phase = "ACTIVE";
    return true;
  }

  admits(ticket, root, process) {
    return (
      this.#phase === "ACTIVE" &&
      ticket === this.#ticket &&
      root === this.#root &&
      !!process &&
      process === this.#process
    );
  }

  beginDraining(ticket) {
    if (
      ticket !== this.#ticket ||
      (this.#phase !== "STARTING" && this.#phase !== "ACTIVE")
    ) {
      return false;
    }
    this.#phase = "DRAINING";
    return true;
  }

  // Caller MUST establish that no subprocess was spawned and no launch
  // callback remains capable of spawning one for this generation.
  confirmNeverLaunched(ticket, noLaunchOutstanding) {
    if (
      this.#phase !== "DRAINING" ||
      ticket !== this.#ticket ||
      this.#process ||
      noLaunchOutstanding !== true
    ) {
      return false;
    }
    this.#release();
    return true;
  }

  // Only the trusted parent retirement adapter may supply osExitConfirmed.
  // Pool removal, ActorDestroy, IPC shutdown notification, and tab close
  // alone MUST NOT be passed as proof of actual OS subprocess retirement.
  confirmProcessRetired(ticket, process, osExitConfirmed) {
    if (
      this.#phase !== "DRAINING" ||
      ticket !== this.#ticket ||
      !process ||
      process !== this.#process ||
      osExitConfirmed !== true
    ) {
      return false;
    }
    this.#release();
    return true;
  }

  #release() {
    this.#ticket = null;
    this.#root = null;
    this.#process = null;
    this.#phase = "FREE";
  }
}
