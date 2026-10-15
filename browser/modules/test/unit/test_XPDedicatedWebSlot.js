/* Any copyright is dedicated to the Public Domain.
 * http://creativecommons.org/publicdomain/zero/1.0/ */

"use strict";

const { XPDedicatedWebSlot } = ChromeUtils.importESModule(
  "resource:///modules/XPDedicatedWebSlot.sys.mjs"
);

add_task(function test_reservation_is_parent_owned_and_exclusive() {
  const slot = new XPDedicatedWebSlot();
  const root = {};
  const outsider = {};
  Assert.throws(() => slot.reserve(null), /parent-owned root/);
  const ticket = slot.reserve(root);
  Assert.equal(slot.phase, "STARTING");
  Assert.equal(ticket.generation, 1);
  Assert.equal(slot.reserve(outsider), null, "No concurrent W1 slot");
  Assert.ok(slot.owns(ticket, root), "Only the reserved owner matches");
  Assert.ok(!slot.owns(ticket, outsider), "Another tab cannot inherit permission");
  Assert.ok(!slot.admits(ticket, root, {}), "Cannot admit before activation");
  Assert.ok(slot.beginDraining(ticket));
  Assert.ok(!slot.owns(ticket, root), "DRAINING rejects further owner use");
  Assert.equal(slot.reserve(outsider), null, "DRAINING remains occupied");
  Assert.ok(!slot.confirmNeverLaunched(ticket, false), "No unproven cancellation");
  Assert.ok(slot.confirmNeverLaunched(ticket, true), "Only a proven no-launch can free");
  Assert.equal(slot.phase, "FREE");
});

add_task(function test_actual_child_retirement_and_generation() {
  const slot = new XPDedicatedWebSlot();
  const root = {};
  const process = {};
  const other = {};
  const ticket = slot.reserve(root);
  Assert.ok(!slot.activate(ticket, process), "Cannot activate before process binding");
  Assert.ok(slot.bindProcess(ticket, process));
  Assert.ok(!slot.bindProcess(ticket, other), "No process swap");
  Assert.ok(slot.activate(ticket, process));
  Assert.ok(slot.admits(ticket, root, process));
  Assert.ok(!slot.admits(ticket, {}, process), "No second tab owner");
  Assert.ok(!slot.admits(ticket, root, other), "No direct process admission");
  Assert.ok(slot.beginDraining(ticket));
  Assert.ok(!slot.admits(ticket, root, process), "Drain revokes new admission");
  Assert.equal(slot.reserve({}), null, "Tab close or pool removal does not free W1");
  Assert.ok(!slot.confirmNeverLaunched(ticket, true), "Bound child cannot use no-launch");
  Assert.ok(!slot.confirmProcessRetired(ticket, process, false), "ActorDestroy is not OS exit");
  Assert.ok(!slot.confirmProcessRetired(ticket, other, true), "Wrong child cannot free slot");
  Assert.equal(slot.phase, "DRAINING");
  Assert.ok(slot.confirmProcessRetired(ticket, process, true));
  Assert.equal(slot.phase, "FREE");
  const next = slot.reserve({});
  Assert.equal(next.generation, ticket.generation + 1);
  Assert.ok(!slot.beginDraining(ticket), "Stale callbacks cannot drain later owner");
  Assert.ok(!slot.confirmProcessRetired(ticket, process, true), "Stale exit cannot free new slot");
  Assert.equal(slot.phase, "STARTING");
  Assert.ok(slot.beginDraining(next));
  Assert.ok(slot.confirmNeverLaunched(next, true));
});
