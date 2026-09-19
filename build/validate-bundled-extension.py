#!/usr/bin/env python3
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

REQUIRED_SIGNATURE_FILES = (
    "META-INF/manifest.mf",
    "META-INF/mozilla.sf",
    "META-INF/mozilla.rsa",
)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def manifest_id(manifest):
    settings = manifest.get("browser_specific_settings", {}).get("gecko", {})
    legacy = manifest.get("applications", {}).get("gecko", {})
    return settings.get("id") or legacy.get("id")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("xpi", type=Path)
    parser.add_argument("--expected-id", required=True)
    parser.add_argument("--expected-version")
    parser.add_argument("--require-permission", action="append", default=[])
    parser.add_argument("--require-native-host")
    parser.add_argument("--metadata", type=Path)
    args = parser.parse_args()

    with zipfile.ZipFile(args.xpi) as archive:
        bad_member = archive.testzip()
        if bad_member:
            raise SystemExit(f"XPI ZIP CRC failure: {bad_member}")
        names = set(archive.namelist())
        missing = [name for name in REQUIRED_SIGNATURE_FILES if name not in names]
        if missing:
            raise SystemExit("XPI signature structure is incomplete: " + ", ".join(missing))
        manifest = json.loads(archive.read("manifest.json").decode("utf-8"))
        addon_id = manifest_id(manifest)
        version = manifest.get("version")
        permissions = manifest.get("permissions", [])
        for permission in args.require_permission:
            if permission not in permissions:
                raise SystemExit(f"Required permission is missing: {permission}")
        if args.require_native_host:
            needle = args.require_native_host.encode("utf-8")
            if not any(
                name.endswith((".js", ".mjs")) and needle in archive.read(name)
                for name in names
            ):
                raise SystemExit(f"Native host reference is missing: {args.require_native_host}")

    if addon_id != args.expected_id:
        raise SystemExit(f"Unexpected extension ID: {addon_id!r}")
    if args.expected_version and version != args.expected_version:
        raise SystemExit(f"Unexpected extension version: {version!r}")

    result = {
        "id": addon_id,
        "version": version,
        "sha256": sha256(args.xpi),
        "size": args.xpi.stat().st_size,
        "manifest_version": manifest.get("manifest_version"),
        "permissions": permissions,
        "update_url": (
            manifest.get("browser_specific_settings", {}).get("gecko", {}).get("update_url")
            or manifest.get("applications", {}).get("gecko", {}).get("update_url")
        ),
        "has_cose_signature": all(
            name in names for name in ("META-INF/cose.manifest", "META-INF/cose.sig")
        ),
    }
    if args.metadata:
        args.metadata.parent.mkdir(parents=True, exist_ok=True)
        args.metadata.write_text(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
