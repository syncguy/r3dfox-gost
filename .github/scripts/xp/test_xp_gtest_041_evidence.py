#!/usr/bin/env python3
"""No-CI, no-browser-build self-tests for GTest 041 fail-closed evidence gates."""
import importlib.util
import json
import pathlib
import subprocess
import tempfile
import types
import unittest
from unittest import mock

SCRIPT = pathlib.Path(__file__).with_name("xp-gtest-041-evidence.py")
spec = importlib.util.spec_from_file_location("xp_gtest_041_evidence", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

TARGET = "JumpListBuilder.PopulateJumpListOnlyTasks"


def events(*rows):
    return ("\n".join(json.dumps(row) for row in rows) + "\n").encode()


def good_events():
    return [
        {"action": "suite_start", "source": "gtest", "name": "gtest"},
        {"action": "group_start", "name": "JumpListBuilder"},
        {"action": "test_start", "test": TARGET},
        {"action": "test_status", "test": TARGET, "subtest": "",
         "status": "PASS", "message": "ok"},
        {"action": "test_end", "test": TARGET, "status": "PASS"},
        {"action": "group_end", "name": "JumpListBuilder"},
        {"action": "suite_end", "source": "gtest"}
    ]


class GateTests(unittest.TestCase):
    def evaluate(self, rows, exit_code=0, timeout=False):
        return module.evaluate_gtest(events(*rows), b"", exit_code, timeout)

    def test_exact_one_succeeds(self):
        self.assertEqual(self.evaluate(good_events())["verdict"], "PASS")

    def test_second_test_rejected(self):
        rows = good_events()
        rows[5:5] = [{"action": "test_start", "test": "OtherSuite.Other"},
                     {"action": "test_end", "test": "OtherSuite.Other", "status": "PASS"}]
        self.assertEqual(self.evaluate(rows)["verdict"], "FAIL")

    def test_failed_subtest_rejected(self):
        rows = good_events()
        rows.insert(4, {"action": "test_status", "test": TARGET, "status": "FAIL"})
        self.assertEqual(self.evaluate(rows)["verdict"], "FAIL")

    def test_out_of_order_rejected(self):
        rows = good_events()
        rows[2], rows[4] = rows[4], rows[2]
        self.assertEqual(self.evaluate(rows)["verdict"], "FAIL")

    def test_duplicate_or_missing_suite_rejected(self):
        self.assertEqual(self.evaluate(good_events() + good_events())["verdict"], "FAIL")
        self.assertEqual(self.evaluate(good_events()[:-1])["verdict"], "FAIL")

    def test_wrong_process_exit_and_watchdog_rejected(self):
        self.assertEqual(self.evaluate(good_events(), exit_code=1)["verdict"], "FAIL")
        self.assertEqual(self.evaluate(good_events(), timeout=True)["verdict"], "FAIL")

    def test_malformed_json_rejected(self):
        self.assertEqual(module.evaluate_gtest(events(*good_events()) + b'{bad-json\n',
                                               b"", 0)["verdict"], "FAIL")

    def test_baseline_dll_pairs_and_decorated_bad_name(self):
        valid = [
            {"dll": "api-ms-win-core-path-l1-1-0.dll", "name": "PathCchCanonicalize"},
            {"dll": "api-ms-win-core-path-l1-1-0.dll", "name": "PathCchRemoveFileSpec"},
            {"dll": "PROPSYS.dll", "name": "PropVariantToString"}]
        self.assertEqual(len(module.check_imports(
            types.SimpleNamespace(direct=valid, delay=[]), True)["known_direct"]), 3)
        changed = [dict(record) for record in valid]
        changed[0]["dll"] = "foo.dll"
        with self.assertRaises(ValueError):
            module.check_imports(types.SimpleNamespace(direct=changed, delay=[]), True)
        with self.assertRaises(ValueError):
            module.check_imports(types.SimpleNamespace(
                direct=[{"dll": "anything.dll", "name": "__imp__PathCchCanonicalize@12"}],
                delay=[]), False)

    def test_empty_gtest_import_table_rejected_by_audit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            for name in ("r3dfox.exe", "xul.dll", "gtest/xul.dll"):
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(b"mock")
            def fake_pe(path):
                direct = [] if str(path).replace("\\", "/").endswith("gtest/xul.dll") else [
                    {"dll": "kernel32.dll", "name": "GetLastError"}]
                return types.SimpleNamespace(subsystem=(5, 1), direct=direct, delay=[])
            with mock.patch.object(module, "validate_bundle", return_value={
                "dependentlibs.list": [], "dependentlibs.list.gtest": []}), \
                 mock.patch.object(module, "PE", side_effect=fake_pe):
                with self.assertRaisesRegex(ValueError, "empty direct import"):
                    module.audit(types.SimpleNamespace(dist=tmp, report=str(root / "report.json")))

    def test_raw_symlink_materialized_and_directory_link_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            (root / "resource.mjs").write_bytes(b"resource")
            link = root / "linked-resource.mjs"
            try:
                link.symlink_to(root / "resource.mjs")
            except (OSError, NotImplementedError):
                self.skipTest("runner has no symlink privilege")
            rows = module.scan(root)
            self.assertEqual(rows["resource.mjs"]["sha256"], rows["linked-resource.mjs"]["sha256"])
            folder = root / "test-dir"
            folder.mkdir()
            directory_link = root / "dir-link"
            try:
                directory_link.symlink_to(folder, target_is_directory=True)
            except (OSError, NotImplementedError):
                self.skipTest("runner has no directory-symlink privilege")
            with self.assertRaises(ValueError):
                module.scan(root)

    def test_timeout_preserves_partial_logs_and_json(self):
        class FakeProc:
            pid = 4242
            def __init__(self):
                self.calls = 0
                self.dead = False
            def communicate(self, timeout=None):
                self.calls += 1
                if self.calls == 1:
                    raise subprocess.TimeoutExpired(
                        "fake r3dfox", 180, output=b'{"action":"suite_start","source":"gtest"}\n',
                        stderr=b"initial diagnostic\n")
                return b'{"action":"suite_start","source":"gtest"}\n', b"initial diagnostic\n"
            def poll(self):
                return -9 if self.dead else None
            def kill(self):
                self.dead = True
        with tempfile.TemporaryDirectory() as tmp:
            report = pathlib.Path(tmp) / "report"
            report.mkdir()
            with mock.patch.object(module, "verified_extract", return_value=pathlib.Path(tmp)), \
                 mock.patch.object(module.subprocess, "Popen", return_value=FakeProc()), \
                 mock.patch.object(module.subprocess, "run"):
                with self.assertRaises(ValueError):
                    module.run(types.SimpleNamespace(evidence=str(report)))
            verdict = json.loads((report / "jump-list-result.json").read_text())
            self.assertTrue(verdict["timed_out"])
            self.assertEqual(verdict["verdict"], "FAIL")
            self.assertIn(b"suite_start", (report / "jump-list-stdout.log").read_bytes())
            self.assertIn(b"initial diagnostic", (report / "jump-list-stderr.log").read_bytes())


if __name__ == "__main__":
    unittest.main(verbosity=2)
