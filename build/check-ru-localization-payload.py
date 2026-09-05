#!/usr/bin/env python3

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

CYRILLIC_RE = re.compile(r"[А-Яа-яЁё]")
REPRESENTATIVE_SUFFIXES = (
    "browser/browser.ftl",
    "browser/preferences/preferences.ftl",
    "toolkit/neterror/netError.ftl",
)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def has_cyrillic(data: bytes) -> bool:
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return False
    return bool(CYRILLIC_RE.search(text))


def append_evidence(path: Path | None, lines: list[str]) -> None:
    for line in lines:
        print(line)
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as f:
        for line in lines:
            f.write(line + "\n")


def scan_records(records: list[tuple[str, bytes]], label: str, evidence: Path | None, gate: bool) -> None:
    files = [(name, data) for name, data in records if not name.endswith("/")]
    ftl = [(name, data) for name, data in files if name.lower().endswith(".ftl")]
    zeros = [(name, data) for name, data in files if len(data) == 0]
    ftl_zeros = [(name, data) for name, data in ftl if len(data) == 0]
    ftl_nonempty = [(name, data) for name, data in ftl if len(data) > 0]
    ftl_cyrillic = [(name, data) for name, data in ftl_nonempty if has_cyrillic(data)]

    lines = [
        f"[{label}] files={len(files)} nonempty={len(files) - len(zeros)} zero={len(zeros)}",
        f"[{label}] ftl={len(ftl)} nonempty={len(ftl_nonempty)} zero={len(ftl_zeros)} cyrillic={len(ftl_cyrillic)}",
    ]
    lines.extend(f"[{label}] ZERO {name}" for name, _ in zeros)

    representative_hits: dict[str, tuple[str, bytes] | None] = {}
    normalized = [(name.replace("\\", "/"), data) for name, data in files]
    for suffix in REPRESENTATIVE_SUFFIXES:
        hits = [(name, data) for name, data in normalized if name.endswith(suffix)]
        hit = hits[0] if len(hits) == 1 else None
        representative_hits[suffix] = hit
        if hit is None:
            lines.append(f"[{label}] REPRESENTATIVE {suffix} matches={len(hits)}")
        else:
            name, data = hit
            lines.append(
                f"[{label}] REPRESENTATIVE {suffix} path={name} size={len(data)} "
                f"cyrillic={str(has_cyrillic(data)).lower()} sha256={sha256(data)}"
            )

    append_evidence(evidence, lines)

    if not gate:
        return
    failures: list[str] = []
    if not ftl:
        failures.append("no Fluent files found")
    elif len(ftl_zeros) / len(ftl) > 0.10:
        failures.append(f"zero-length Fluent ratio exceeds 10%: {len(ftl_zeros)}/{len(ftl)}")
    for suffix, hit in representative_hits.items():
        if hit is None:
            failures.append(f"representative resource missing or ambiguous: {suffix}")
            continue
        _, data = hit
        if not data:
            failures.append(f"representative resource is zero-length: {suffix}")
        elif not has_cyrillic(data):
            failures.append(f"representative resource has no Cyrillic text: {suffix}")
    if failures:
        raise SystemExit(f"{label} localization payload gate failed: " + "; ".join(failures))


def tree_records(root: Path) -> list[tuple[str, bytes]]:
    if not root.is_dir():
        raise SystemExit(f"Localization tree does not exist: {root}")
    result = []
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        result.append((str(path.resolve()), path.read_bytes()))
    return result


def scan_tree(args: argparse.Namespace) -> None:
    root = Path(args.root).resolve()
    scan_records(tree_records(root), args.label, Path(args.evidence) if args.evidence else None, args.gate)


def locale_records(zf: zipfile.ZipFile, omni: Path, locale: str) -> list[tuple[str, bytes]]:
    prefix = f"localization/{locale}/"
    result = []
    for info in zf.infolist():
        name = info.filename.replace("\\", "/").lstrip("/")
        if info.is_dir() or not name.startswith(prefix):
            continue
        result.append((f"{omni.resolve()}!/{name}", zf.read(info)))
    return result


def relative_locale_name(full_name: str, locale: str) -> str:
    marker = f"!/localization/{locale}/"
    if marker not in full_name:
        return full_name
    return full_name.split(marker, 1)[1]


def scan_omni(args: argparse.Namespace) -> None:
    root = Path(args.root).resolve()
    evidence = Path(args.evidence) if args.evidence else None
    omni_files = sorted(root.rglob("omni.ja"))
    if not omni_files:
        raise SystemExit(f"No omni.ja found under {root}")

    all_ru: list[tuple[str, bytes]] = []
    all_en: list[tuple[str, bytes]] = []
    failures: list[str] = []
    for omni in omni_files:
        try:
            with zipfile.ZipFile(omni) as zf:
                ru = locale_records(zf, omni, "ru")
                en = locale_records(zf, omni, "en-US")
        except zipfile.BadZipFile as exc:
            raise SystemExit(f"Invalid omni.ja {omni}: {exc}") from exc
        if not ru and not en:
            continue
        label = f"final:{omni.relative_to(root)}:ru"
        scan_records(ru, label, evidence, False)
        en_lines = [
            f"[final:{omni.relative_to(root)}:en-US] files={len(en)} "
            f"nonempty={sum(1 for _, data in en if data)} zero={sum(1 for _, data in en if not data)}"
        ]
        append_evidence(evidence, en_lines)
        all_ru.extend(ru)
        all_en.extend(en)
        ru_ftl = [(n, d) for n, d in ru if n.lower().endswith(".ftl")]
        ru_zero_ftl = [(n, d) for n, d in ru_ftl if not d]
        if args.gate and ru_ftl and len(ru_zero_ftl) / len(ru_ftl) > 0.10:
            failures.append(
                f"{omni}: zero-length Russian Fluent ratio exceeds 10%: {len(ru_zero_ftl)}/{len(ru_ftl)}"
            )

    if not all_ru:
        raise SystemExit("No localization/ru payload found in packaged omni.ja files")
    if not all_en:
        raise SystemExit("No localization/en-US fallback payload found in packaged omni.ja files")

    # Aggregate representative gate across root and browser omni.ja.
    normalized_ru = [(relative_locale_name(name, "ru"), name, data) for name, data in all_ru]
    normalized_en = {relative_locale_name(name, "en-US"): data for name, data in all_en}
    lines: list[str] = []
    for suffix in REPRESENTATIVE_SUFFIXES:
        hits = [(rel, full, data) for rel, full, data in normalized_ru if rel.endswith(suffix)]
        if len(hits) != 1:
            lines.append(f"[final:aggregate] REPRESENTATIVE {suffix} matches={len(hits)}")
            if args.gate:
                failures.append(f"final representative missing or ambiguous: {suffix}")
            continue
        rel, full, data = hits[0]
        identical = rel in normalized_en and normalized_en[rel] == data
        lines.append(
            f"[final:aggregate] REPRESENTATIVE {suffix} path={full} size={len(data)} "
            f"cyrillic={str(has_cyrillic(data)).lower()} sha256={sha256(data)} byte_identical_en_US={str(identical).lower()}"
        )
        if args.gate:
            if not data:
                failures.append(f"final representative is zero-length: {suffix}")
            elif not has_cyrillic(data):
                failures.append(f"final representative has no Cyrillic text: {suffix}")
            if identical:
                failures.append(f"final representative is byte-identical to en-US: {suffix}")
    append_evidence(evidence, lines)
    if failures:
        raise SystemExit("Final Russian localization payload gate failed: " + "; ".join(failures))


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect and gate Russian Firefox localization payloads.")
    sub = parser.add_subparsers(dest="command", required=True)

    tree = sub.add_parser("tree")
    tree.add_argument("--root", required=True)
    tree.add_argument("--label", required=True)
    tree.add_argument("--evidence")
    tree.add_argument("--gate", action="store_true")
    tree.set_defaults(func=scan_tree)

    omni = sub.add_parser("omni")
    omni.add_argument("--root", required=True)
    omni.add_argument("--evidence")
    omni.add_argument("--gate", action="store_true")
    omni.set_defaults(func=scan_omni)

    args = parser.parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
