#!/usr/bin/env python3
import argparse
import hashlib
import json
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

DEFAULT_ID = "ru.cryptopro.nmcades@cryptopro.ru"
DEFAULT_URL = "https://www.cryptopro.ru/sites/default/files/products/cades/extensions/firefox_cryptopro_extension_latest.xpi"
REQUIRED_SIGNATURE_FILES = (
    "META-INF/manifest.mf",
    "META-INF/mozilla.sf",
    "META-INF/mozilla.rsa",
)


class XPIError(Exception):
    pass


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


def validate_xpi(path, expected_id):
    path = Path(path)
    if not path.is_file():
        raise XPIError(f"XPI does not exist: {path}")
    try:
        with zipfile.ZipFile(path) as archive:
            bad_member = archive.testzip()
            if bad_member:
                raise XPIError(f"XPI ZIP CRC failure: {bad_member}")
            names = set(archive.namelist())
            if "manifest.json" not in names:
                raise XPIError("XPI has no manifest.json")
            missing = [name for name in REQUIRED_SIGNATURE_FILES if name not in names]
            if missing:
                raise XPIError("XPI signature structure is incomplete: " + ", ".join(missing))
            try:
                manifest = json.loads(archive.read("manifest.json").decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                raise XPIError(f"Invalid manifest.json: {exc}") from exc
    except zipfile.BadZipFile as exc:
        raise XPIError(f"Invalid XPI/ZIP: {exc}") from exc

    addon_id = manifest_id(manifest)
    version = manifest.get("version")
    if addon_id != expected_id:
        raise XPIError(f"Unexpected extension ID: {addon_id!r}")
    if not isinstance(version, str) or not version.strip():
        raise XPIError("Extension version is missing")

    return {
        "id": addon_id,
        "version": version,
        "sha256": sha256(path),
        "size": path.stat().st_size,
        "has_cose_signature": all(
            name in names for name in ("META-INF/cose.manifest", "META-INF/cose.sig")
        ),
    }


def download_candidate(url, destination, timeout):
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "r3dfox-gost-cryptopro-extension-smoke/1"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output)


def select_xpi(fallback, url, expected_id, timeout):
    fallback_meta = validate_xpi(fallback, expected_id)
    result = {
        "source": "fallback",
        "fallback": fallback_meta,
        "download_url": url,
        "download_error": None,
        "candidate_error": None,
    }

    with tempfile.TemporaryDirectory(prefix="cryptopro-xpi-") as temp_dir:
        candidate = Path(temp_dir) / "candidate.xpi"
        try:
            download_candidate(url, candidate, timeout)
        except Exception as exc:
            result["download_error"] = f"{type(exc).__name__}: {exc}"
            return fallback, fallback_meta, result

        try:
            candidate_meta = validate_xpi(candidate, expected_id)
        except XPIError as exc:
            result["candidate_error"] = str(exc)
            return fallback, fallback_meta, result

        with tempfile.NamedTemporaryFile(
            prefix="cryptopro-selected-", suffix=".xpi", delete=False
        ) as persisted_file:
            persisted = Path(persisted_file.name)
        shutil.copyfile(candidate, persisted)
        result["source"] = "download"
        result["candidate"] = candidate_meta
        return persisted, candidate_meta, result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fallback", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metadata", required=True, type=Path)
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--expected-id", default=DEFAULT_ID)
    parser.add_argument("--timeout", type=float, default=30.0)
    args = parser.parse_args()

    try:
        selected, selected_meta, result = select_xpi(
            args.fallback, args.url, args.expected_id, args.timeout
        )
    except XPIError as exc:
        print(f"ERROR: committed fallback is invalid: {exc}", file=sys.stderr)
        return 2

    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(selected, args.output)
    final_meta = validate_xpi(args.output, args.expected_id)
    if final_meta["sha256"] != selected_meta["sha256"]:
        print("ERROR: selected XPI changed while being copied", file=sys.stderr)
        return 3

    result["selected"] = final_meta
    args.metadata.parent.mkdir(parents=True, exist_ok=True)
    args.metadata.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(
        f"CryptoPro XPI source={result['source']} "
        f"id={final_meta['id']} version={final_meta['version']} "
        f"sha256={final_meta['sha256']} size={final_meta['size']}"
    )
    if result["download_error"]:
        print(f"Download failed; committed fallback selected: {result['download_error']}")
    if result["candidate_error"]:
        print(f"Downloaded candidate rejected; committed fallback selected: {result['candidate_error']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
