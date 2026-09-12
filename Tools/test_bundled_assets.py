#!/usr/bin/env python3
"""Verify that every phone-only USDZ catalog asset is present and intact."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import zipfile


MAX_USDZ_BYTES = 8 * 1024 * 1024
MANIFEST_LINE = re.compile(r"^([0-9a-f]{64})  ([^/\\]+\.usdz)$")


def parse_manifest(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line:
            continue
        match = MANIFEST_LINE.fullmatch(line)
        if match is None:
            raise AssertionError(f"Invalid manifest line {line_number}: {raw_line!r}")
        digest, name = match.groups()
        if name in entries:
            raise AssertionError(f"Duplicate manifest asset: {name}")
        entries[name] = digest
    if not entries:
        raise AssertionError("Bundled asset manifest is empty")
    return entries


def catalog_references(prop_kind_path: Path) -> set[str]:
    source = prop_kind_path.read_text(encoding="utf-8")
    references = set(re.findall(r'assetName:\s*"([^"]+)"', source))
    start = source.index("    var bundledAssetName: String?")
    end = source.index("\n    var anchorName:", start)
    references.update(re.findall(r'case\s+\.[A-Za-z0-9_]+:\s*"([^"]+)"', source[start:end]))
    return references


def validate_usdz(path: Path, expected_digest: str) -> None:
    size = path.stat().st_size
    if not 0 < size <= MAX_USDZ_BYTES:
        raise AssertionError(f"USDZ size is outside the mobile budget: {path.name} ({size})")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected_digest:
        raise AssertionError(
            f"USDZ checksum mismatch: {path.name}; expected {expected_digest}, got {digest}"
        )
    if not zipfile.is_zipfile(path):
        raise AssertionError(f"USDZ is not a readable ZIP package: {path.name}")
    with zipfile.ZipFile(path) as archive:
        corrupt_member = archive.testzip()
        if corrupt_member is not None:
            raise AssertionError(f"Corrupt USDZ member: {path.name}/{corrupt_member}")
        if not any(Path(name).suffix.lower() in {".usd", ".usda", ".usdc"} for name in archive.namelist()):
            raise AssertionError(f"USDZ contains no USD scene: {path.name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--prop-kind", type=Path)
    arguments = parser.parse_args()

    asset_directory = arguments.assets.resolve()
    manifest = parse_manifest(arguments.manifest.resolve())
    if not asset_directory.is_dir():
        raise AssertionError(f"Bundled RoomAssets directory is missing: {asset_directory}")

    actual_names = {path.name for path in asset_directory.glob("*.usdz") if path.is_file()}
    expected_names = set(manifest)
    if actual_names != expected_names:
        missing = sorted(expected_names - actual_names)
        unexpected = sorted(actual_names - expected_names)
        raise AssertionError(f"Bundled USDZ set mismatch; missing={missing}, unexpected={unexpected}")

    if arguments.prop_kind is not None:
        referenced_stems = catalog_references(arguments.prop_kind.resolve())
        actual_stems = {Path(name).stem for name in actual_names}
        if referenced_stems != actual_stems:
            missing = sorted(referenced_stems - actual_stems)
            unused = sorted(actual_stems - referenced_stems)
            raise AssertionError(f"Catalog/source mismatch; missing={missing}, unused={unused}")

    for name, digest in sorted(manifest.items()):
        validate_usdz(asset_directory / name, digest)
    print(f"Bundled asset tests passed ({len(manifest)} offline USDZ files)")


if __name__ == "__main__":
    main()
