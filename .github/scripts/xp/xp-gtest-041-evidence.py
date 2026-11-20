#!/usr/bin/env python3
"""XP GTest 041: independent PE controls, supplier verification, PDB and ZIP evidence.

Controller-only script. Standard-library Python 3; never modifies browser sources.
Evidence states are deliberately scoped: static imports != Windows XP runtime PASS.
"""
import argparse
import collections
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import uuid
import zipfile

SOURCE = "27792a8db5b3de486586b93b634fb7bbed760ef0"
OLD_GTEST = "76fcb3ca258ad127d2812918da29e2d18a68b5d418261c6f9ec01a83b9aae96e"
OLD_ROOT = "2aaf6884d6987857c4fec483c7964181f3b20ea1677be42e5145493cf68cad2f"
FORBIDDEN = {"pathcchcanonicalize", "pathcchremovefilespec", "propvarianttostring"}
SUPPLIERS = ("ucrtbase.dll", "msvcp140.dll", "bcrypt.dll")
REQUIRED = (
    "r3dfox.exe", "xul.dll", "gtest/xul.dll", "application.ini", "platform.ini",
    "dependentlibs.list", "dependentlibs.list.gtest"
)


def stop(message):
    raise ValueError(message)


def u16(data, offset):
    if offset < 0 or offset + 2 > len(data):
        stop("Truncated unsigned short")
    return struct.unpack_from("<H", data, offset)[0]


def u32(data, offset):
    if offset < 0 or offset + 4 > len(data):
        stop("Truncated unsigned integer")
    return struct.unpack_from("<I", data, offset)[0]


def stream_hash(path):
    length = 0
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(4 * 1024 * 1024)
            if not chunk:
                break
            length += len(chunk)
            digest.update(chunk)
    return {"size_bytes": length, "sha256": digest.hexdigest()}


def cstring(data, off, limit=4096):
    if off < 0 or off >= len(data):
        stop("Invalid string location")
    end = data.find(b"\0", off, min(len(data), off + limit))
    if end < 0:
        stop("Unterminated PE string")
    return data[off:end].decode("ascii", "strict")


class PE:
    def __init__(self, path):
        self.data = Path(path).read_bytes()
        d = self.data
        if len(d) < 0x100 or d[:2] != b"MZ":
            stop("Invalid DOS header")
        peoff = u32(d, 0x3c)
        if peoff + 24 > len(d) or d[peoff:peoff + 4] != b"PE\0\0":
            stop("Invalid PE signature")
        self.machine = u16(d, peoff + 4)
        count = u16(d, peoff + 6)
        opt_size = u16(d, peoff + 20)
        opt = peoff + 24
        if count < 1 or count > 96 or opt + opt_size > len(d):
            stop("Invalid optional header or section count")
        if u16(d, opt) != 0x10b or self.machine != 0x14c or opt_size < 224:
            stop("Not PE32/i386")
        self.image_base = u32(d, opt + 28)
        self.subsystem = (u16(d, opt + 48), u16(d, opt + 50))
        self.size_headers = u32(d, opt + 60)
        if u32(d, opt + 92) < 14:
            stop("Required PE directory slots are missing")
        self.directories = [(u32(d, opt + 96 + i * 8), u32(d, opt + 100 + i * 8))
                            for i in range(14)]
        self.sections = []
        for i in range(count):
            off = opt + opt_size + i * 40
            if off + 40 > len(d):
                stop("Truncated section headers")
            self.sections.append((u32(d, off + 12), u32(d, off + 8),
                                  u32(d, off + 20), u32(d, off + 16)))
        self.direct = self.imports(1)
        self.delay = self.imports(13)

    def rva(self, address, size=1):
        d = self.data
        if address < self.size_headers:
            if address + size <= len(d):
                return address
            stop("PE header RVA out of bounds")
        for va, virtual_size, raw, raw_size in self.sections:
            if va <= address and address + size <= va + max(virtual_size, raw_size):
                off = raw + address - va
                if address + size > va + raw_size or off + size > len(d):
                    stop("PE RVA falls in unbacked virtual memory")
                return off
        stop("PE RVA outside mapped sections: " + hex(address))

    def string(self, address):
        return cstring(self.data, self.rva(address))

    def imports(self, directory):
        rva, size = self.directories[directory]
        if not rva or not size:
            return []
        delay = directory == 13
        stride = 32 if delay else 20
        results = []
        terminated = False
        for n in range(min(1000, size // stride + 1)):
            off = self.rva(rva + n * stride, stride)
            words = struct.unpack_from("<" + "I" * (stride // 4), self.data, off)
            if not any(words):
                terminated = True
                break
            if delay:
                attrs, dllrva, _, iat, int_rva = words[:5]
                if attrs not in (0, 1):
                    stop("Unknown delay import address encoding")
                if attrs == 0:
                    dllrva -= self.image_base
                    int_rva -= self.image_base
                    iat -= self.image_base
                thunk_rva = int_rva or iat
            else:
                original, _, _, dllrva, iat = words
                thunk_rva = original or iat
            if not dllrva or not thunk_rva:
                stop("Import descriptor missing DLL name or thunks")
            dll = self.string(dllrva)
            ended = False
            for index in range(25000):
                thunk = u32(self.data, self.rva(thunk_rva + index * 4, 4))
                if thunk == 0:
                    ended = True
                    break
                if thunk & 0x80000000:
                    symbol = {"ordinal": thunk & 0xffff}
                else:
                    off_name = self.rva(thunk, 3)
                    symbol = {"name": cstring(self.data, off_name + 2)}
                results.append({"dll": dll, **symbol})
            if not ended:
                stop("Import thunk array lacks terminator")
        if not terminated:
            stop("Import descriptor array lacks terminator")
        return results

    def exports(self):
        rva, size = self.directories[0]
        if not rva or not size:
            return set(), set()
        off = self.rva(rva, 40)
        ordinal_base = u32(self.data, off + 16)
        function_count = u32(self.data, off + 20)
        name_count = u32(self.data, off + 24)
        functions_rva = u32(self.data, off + 28)
        names_rva = u32(self.data, off + 32)
        ordinals = {ordinal_base + i for i in range(function_count)
                    if u32(self.data, self.rva(functions_rva + 4 * i, 4)) != 0}
        names = set()
        for i in range(name_count):
            nrva = u32(self.data, self.rva(names_rva + i * 4, 4))
            names.add(self.string(nrva))
        return names, ordinals

    def rsds(self):
        rva, size = self.directories[6]
        if not rva or not size:
            stop("PE lacks debug directory")
        for n in range(size // 28):
            off = self.rva(rva + n * 28, 28)
            dtype = u32(self.data, off + 12)
            length = u32(self.data, off + 16)
            rawptr = u32(self.data, off + 24)
            if dtype == 2 and length >= 24:
                if rawptr + length > len(self.data):
                    stop("CodeView raw pointer outside PE")
                if self.data[rawptr:rawptr + 4] != b"RSDS":
                    stop("Unsupported CodeView record")
                guid = str(uuid.UUID(bytes_le=self.data[rawptr + 4:rawptr + 20])).upper()
                age = u32(self.data, rawptr + 20)
                return guid, age
        stop("PE lacks CodeView RSDS")


def pdb_rsds(path):
    with open(path, "rb") as f:
        head = f.read(64)
        if len(head) < 56 or not head.startswith(b"Microsoft C/C++ MSF 7.00"):
            stop("Unsupported PDB format")
        page = u32(head, 32)
        pages = u32(head, 40)
        directory_bytes = u32(head, 44)
        map_page = u32(head, 52)
        if page < 512 or page > 65536 or page & (page - 1) or not pages:
            stop("Invalid PDB page geometry")
        total = os.fstat(f.fileno()).st_size
        if pages * page > total or directory_bytes > 64 * 1024 * 1024:
            stop("PDB page count or directory size invalid")
        dir_pages = math.ceil(directory_bytes / page)
        if dir_pages * 4 > page:
            stop("PDB block map exceeds one page; unsupported")
        f.seek(map_page * page)
        block_map = f.read(dir_pages * 4)
        if len(block_map) != dir_pages * 4:
            stop("Truncated PDB block map")
        blocks = struct.unpack("<" + "I" * dir_pages, block_map)
        directory = bytearray()
        for block in blocks:
            if block >= pages:
                stop("PDB directory block out of bounds")
            f.seek(block * page)
            directory += f.read(page)
        directory = directory[:directory_bytes]
        stream_count = u32(directory, 0)
        if stream_count < 2 or stream_count > 100000:
            stop("Invalid PDB stream count")
        sizes = [u32(directory, 4 + 4 * i) for i in range(stream_count)]
        cursor = 4 + stream_count * 4
        info_blocks = None
        for i, length in enumerate(sizes):
            count = 0 if length == 0xffffffff else math.ceil(length / page)
            if cursor + count * 4 > len(directory):
                stop("PDB stream block list truncated")
            if i == 1:
                if length < 28 or count < 1:
                    stop("PDB info stream is missing")
                info_blocks = [u32(directory, cursor + 4 * k) for k in range(count)]
            cursor += count * 4
        if not info_blocks or info_blocks[0] >= pages:
            stop("Invalid PDB info block")
        f.seek(info_blocks[0] * page)
        info = f.read(28)
    if len(info) < 28:
        stop("Truncated PDB info header")
    age = u32(info, 8)
    guid = str(uuid.UUID(bytes_le=info[12:28])).upper()
    return guid, age


def check_imports(pe, must_have):
    found = {rec.get("name", "").lower() for rec in pe.direct if "name" in rec}
    delay = {rec.get("name", "").lower() for rec in pe.delay if "name" in rec}
    forbidden_found = sorted(found & FORBIDDEN)
    forbidden_delay = sorted(delay & FORBIDDEN)
    if must_have and set(forbidden_found) != FORBIDDEN:
        stop("Baseline positive import control FAILED: " + repr(forbidden_found))
    if not must_have and (forbidden_found or forbidden_delay):
        stop("Forbidden GTest imports: direct=" + repr(forbidden_found) +
             " delay=" + repr(forbidden_delay))
    return {"direct_count": len(pe.direct), "delay_count": len(pe.delay),
            "known_direct": forbidden_found, "known_delay": forbidden_delay}


def control(args):
    base = Path(args.baseline)
    output = {}
    for rel, expected, positive in (
        ("gtest/xul.dll", OLD_GTEST, True), ("xul.dll", OLD_ROOT, False)
    ):
        path = base / rel
        identity = stream_hash(path)
        if identity["sha256"] != expected:
            stop("038 baseline SHA256 mismatch: " + rel)
        pe = PE(path)
        status = check_imports(pe, positive)
        if positive and status["known_delay"]:
            stop("Unexpected 038 GTest delayed forbidden import")
        output[rel] = {**identity, **status}
    print("XP_GTEST041_OLD_IMPORT_CONTROLS_PASS")
    print(json.dumps(output, sort_keys=True))


def stage(args):
    root = Path(args.dist)
    crt = Path(os.environ["MSVCR14X_RELEASE"])
    bcrypt = Path(os.environ["PROVEN_XP_BCRYPT"])
    root.mkdir(parents=True, exist_ok=True)
    for name, source in (("ucrtbase.dll", crt / "ucrtbase.dll"),
                         ("msvcp140.dll", crt / "msvcp140.dll"),
                         ("bcrypt.dll", bcrypt)):
        if name == "bcrypt.dll" and stream_hash(source)["sha256"] != os.environ["BCRYPT_SHA256"].lower():
            stop("Pinned bcrypt SHA256 mismatch before staging")
        PE(source)
        destination = root / name
        shutil.copyfile(source, destination)
        if stream_hash(source) != stream_hash(destination):
            stop("Staged XP provider bytes differ from verified supplier: " + name)
        print("STAGED_XP_SUPPLIER " + name + " " + json.dumps(stream_hash(destination)))
    print("XP_GTEST041_SUPPLIER_STAGE_PASS")


def validate_bundle(root):
    for rel in REQUIRED + SUPPLIERS:
        if not (root / rel).is_file():
            stop("Missing required runtime file: " + rel)
    if not ((root / "chrome.manifest").is_file() and (root / "browser/chrome.manifest").is_file()
            or (root / "omni.ja").is_file()):
        stop("No supported unpacked or omni.ja runtime resource layout")
    lists = {}
    for name, last in (("dependentlibs.list", "xul.dll"),
                       ("dependentlibs.list.gtest", "gtest/xul.dll")):
        values = [line.strip().replace("\\", "/") for line in
                  (root / name).read_text(encoding="utf-8-sig").splitlines() if line.strip()]
        if len(values) < 2 or values[-1].lower() != last:
            stop("Wrong loader manifest tail: " + name)
        if len({v.lower() for v in values}) != len(values):
            stop("Duplicate loader dependency: " + name)
        for rel in values:
            if rel.startswith("/") or ".." in Path(rel).parts or not (root / rel).is_file():
                stop("Missing or unsafe loader entry: " + rel)
        lists[name] = values
    return lists


def audit(args):
    root = Path(args.dist)
    lists = validate_bundle(root)
    pefiles = {}
    for rel in ("r3dfox.exe", "xul.dll", "gtest/xul.dll"):
        p = PE(root / rel)
        if p.subsystem > (5, 1):
            stop("Subsystem exceeds XP 5.01: " + rel)
        status = check_imports(p, False)
        pefiles[rel] = {"machine": "i386", "subsystem": p.subsystem,
                        "imports": status, "sha256": stream_hash(root / rel)["sha256"]}
    exports = {name.lower(): PE(root / name).exports() for name in SUPPLIERS}
    matches = collections.Counter()
    for rel in {"r3dfox.exe", "xul.dll", "gtest/xul.dll", *lists["dependentlibs.list"],
                *lists["dependentlibs.list.gtest"]}:
        p = PE(root / rel)
        for record in p.direct:
            dll = record["dll"].lower()
            if dll not in exports:
                continue
            names, ordinals = exports[dll]
            if "name" in record and record["name"] not in names:
                stop("Unresolved XP supplier export: " + dll + "!" + record["name"])
            if "ordinal" in record and record["ordinal"] not in ordinals:
                stop("Unresolved XP supplier ordinal: " + dll + "!" + str(record["ordinal"]))
            matches[dll] += 1
    if not all(matches[name] > 0 for name in SUPPLIERS):
        stop("No consumer references to one or more mandatory XP suppliers")
    report = {"schema": "xp-gtest-041-import-audit-v1",
              "source_under_test_sha": SOURCE, "pe": pefiles,
              "supplier_reference_count": dict(matches),
              "system_xp_exports": "NOT_CHECKED",
              "physical_xp_runtime": "NOT_CHECKED"}
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")
    print("XP_GTEST041_IMPORT_AND_SUPPLIER_EXPORT_PASS")


def pdb(args):
    root = Path(args.objdir)
    evidence = Path(args.evidence)
    evidence.mkdir(parents=True, exist_ok=True)
    targets = (
        ("dist/bin/r3dfox.exe", "browser/app/r3dfox.pdb", "r3dfox.pdb"),
        ("dist/bin/xul.dll", "toolkit/library/build/xul.pdb", "root-xul.pdb"),
        ("dist/bin/gtest/xul.dll", "toolkit/library/gtest/xul.pdb", "gtest-xul.pdb"),
    )
    results = []
    for pe_rel, pdb_rel, name in targets:
        exe = root / pe_rel
        symbol = root / pdb_rel
        if not symbol.is_file():
            stop("Missing required PDB: " + pdb_rel)
        pe_guid, pe_age = PE(exe).rsds()
        pdb_guid, pdb_age = pdb_rsds(symbol)
        if (pe_guid, pe_age) != (pdb_guid, pdb_age):
            stop("RSDS/PDB GUID+Age mismatch: " + pe_rel)
        dest = evidence / "symbols" / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(symbol, dest)
        results.append({"pe": pe_rel, "pdb": pdb_rel, "guid": pe_guid, "age": pe_age,
                        "pe_identity": stream_hash(exe), "pdb_identity": stream_hash(dest)})
    (evidence / "symbols.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    print("XP_GTEST041_PDB_GUID_AGE_PASS")


def scan(root):
    files = {}
    for item in root.rglob("*"):
        if item.is_symlink():
            stop("Unexpected symlink in runtime bundle")
        if not item.is_file():
            continue
        rel = item.relative_to(root).as_posix()
        folded = rel.casefold()
        if folded in files:
            stop("Case-insensitive filename collision: " + rel)
        files[folded] = {"path": rel, **stream_hash(item)}
    return files


def package(args):
    root = Path(args.dist)
    evidence = Path(args.evidence)
    evidence.mkdir(parents=True, exist_ok=True)
    validate_bundle(root)
    original = scan(root)
    if len(original) < 10:
        stop("Unexpectedly small runtime closure")
    archive = evidence / "xp-gtest-041-dist.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=1, allowZip64=True) as target:
        for rel in sorted(original):
            target.write(root / original[rel]["path"], original[rel]["path"])
    with tempfile.TemporaryDirectory(prefix="xp-gtest-041-extract-") as tmp:
        extracted = Path(tmp)
        with zipfile.ZipFile(archive) as target:
            infos = target.infolist()
            zip_names = [item.filename for item in infos if not item.is_dir()]
            if len(zip_names) != len({n.casefold() for n in zip_names}):
                stop("ZIP has duplicate case-insensitive paths")
            if set(n.casefold() for n in zip_names) != set(original):
                stop("ZIP filename set differs from original bundle")
            for item in infos:
                rel = Path(item.filename)
                if rel.is_absolute() or ".." in rel.parts or ":" in item.filename:
                    stop("Unsafe path in ZIP")
            target.extractall(extracted)
        copied = scan(extracted)
        if original != copied:
            diff = [x for x in set(original) | set(copied) if original.get(x) != copied.get(x)]
            stop("Extracted ZIP hash/size/filename mismatch: " + repr(diff[:12]))
        validate_bundle(extracted)
        for name in SUPPLIERS:
            if stream_hash(root / name) != stream_hash(extracted / name):
                stop("XP supplier differs after ZIP extraction: " + name)
    manifest = {"schema": "xp-gtest-041-stream-size-and-hash-v1",
                "source_under_test_sha": SOURCE,
                "controller_sha": os.environ.get("GITHUB_SHA", "LOCAL"),
                "run_id": os.environ.get("GITHUB_RUN_ID", "LOCAL"),
                "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT", "LOCAL"),
                "job_key": os.environ.get("GITHUB_JOB", "LOCAL"),
                "numeric_job_id": "FROM_GITHUB_ACTIONS_API_AFTER_RUN",
                "physical_xp_runtime": "NOT_CHECKED",
                "file_count": len(original),
                "archive_identity": stream_hash(archive),
                "files": [original[key] for key in sorted(original)]}
    (evidence / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
    print("XP_GTEST041_REEXTRACT_ALL_HASHES_AND_SIZES_PASS files=" + str(len(original)))


def run(args):
    root = Path(args.dist).resolve()
    evidence = Path(args.evidence)
    evidence.mkdir(parents=True, exist_ok=True)
    validate_bundle(root)
    env = os.environ.copy()
    env.update({"MOZ_XRE_DIR": str(root), "MOZ_RUN_GTEST": "True",
                "GTEST_FILTER": "JumpListBuilder.PopulateJumpListOnlyTasks",
                "MOZ_GMP_PATH": os.pathsep.join([str(root / "gmp-fake/1.0"),
                                                str(root / "gmp-fakeopenh264/1.0")]),
                "MOZ_WEBRENDER": "0", "MOZ_HEADLESS": "1",
                "MOZ_CRASHREPORTER_DISABLE": "1", "GTEST_COLOR": "no"})
    flags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
    command = [str(root / "r3dfox.exe"), "-unittest",
               "--gtest_death_test_style=threadsafe", "--wait-for-browser"]
    proc = subprocess.Popen(command, cwd=str(root), env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, creationflags=flags)
    try:
        out, err = proc.communicate(timeout=180)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        proc.kill()
        out, err = proc.communicate()
        stop("Hosted JumpList gtest timeout")
    (evidence / "jump-list-stdout.log").write_bytes(out)
    (evidence / "jump-list-stderr.log").write_bytes(err)
    events = []
    for line in (out + b"\n" + err).decode("utf-8", "replace").splitlines():
        if line.strip().startswith("{"):
            try:
                v = json.loads(line)
                if isinstance(v, dict):
                    events.append(v)
            except json.JSONDecodeError:
                pass
    target = "JumpListBuilder.PopulateJumpListOnlyTasks"
    starts = [e for e in events if e.get("test") == target and e.get("action") == "test_start"]
    ends = [e for e in events if e.get("test") == target and e.get("action") == "test_end"]
    finished = any(e.get("action") == "suite_end" and e.get("source") == "gtest" for e in events)
    ok = (proc.returncode == 0 and len(starts) == len(ends) == 1
          and ends[0].get("status") == "PASS" and finished
          and b"TEST-UNEXPECTED-FAIL" not in out + err)
    record = {"schema": "xp-gtest-041-hosted-jumplist-v1", "exit_code": proc.returncode,
              "test": target, "started": len(starts), "ended": len(ends),
              "suite_end": finished, "verdict": "PASS" if ok else "FAIL",
              "physical_xp_runtime": "NOT_CHECKED"}
    (evidence / "jump-list-result.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    if not ok:
        stop("Hosted JumpList 1/1 acceptance failed: " + json.dumps(record))
    print("XP_GTEST041_HOSTED_PKEY_TITLE_PASS_1_OF_1")


def main():
    parser = argparse.ArgumentParser()
    subs = parser.add_subparsers(dest="action", required=True)
    def action(name, **fields):
        command = subs.add_parser(name)
        for field, mandatory in fields.items():
            command.add_argument("--" + field.replace("_", "-"), required=mandatory)
        return command
    action("control", baseline=True)
    action("stage", dist=True)
    action("audit", dist=True, report=True)
    action("pdb", objdir=True, evidence=True)
    action("package", dist=True, evidence=True)
    action("run", dist=True, evidence=True)
    args = parser.parse_args()
    globals()[args.action](args)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        print("XP_GTEST041_BLOCKED_OR_FAILED " + str(error), file=sys.stderr)
        sys.exit(1)
