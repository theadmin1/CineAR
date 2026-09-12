#!/usr/bin/env python3
"""Verify that every phone-only USDZ catalog asset is present and intact."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import struct
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


def catalog_references(prop_kind_path: Path, asset_names: set[str]) -> set[str]:
    source = prop_kind_path.read_text(encoding="utf-8")
    references = set(re.findall(r'assetName:\s*"([^"]+)"', source))
    start = source.index("    var bundledAssetName: String?")
    end = source.index("\n    var anchorName:", start)
    references.update(re.findall(r'case\s+\.[A-Za-z0-9_]+:\s*"([^"]+)"', source[start:end]))
    # Renderer-only USDZ material templates are intentionally absent from the
    # user-placeable PropKind list. An exact Swift string reference still counts
    # as usage, so orphaned packages remain a build failure.
    app_source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(prop_kind_path.parent.glob("*.swift"))
    )
    for name in asset_names:
        stem = Path(name).stem
        if f'"{stem}"' in app_source:
            references.add(stem)
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
        members = archive.infolist()
        if not members or Path(members[0].filename).suffix.lower() not in {
            ".usd", ".usda", ".usdc"
        }:
            raise AssertionError(f"USDZ first member is not a native USD scene: {path.name}")
        if not any(Path(name).suffix.lower() in {".usd", ".usda", ".usdc"} for name in archive.namelist()):
            raise AssertionError(f"USDZ contains no USD scene: {path.name}")
        for member in members:
            if member.flag_bits & 0x1:
                raise AssertionError(
                    f"USDZ member is encrypted: {path.name}/{member.filename}"
                )
            if member.compress_type != zipfile.ZIP_STORED:
                raise AssertionError(
                    f"USDZ member is compressed: {path.name}/{member.filename}"
                )
            archive.fp.seek(member.header_offset + 26)
            name_length, extra_length = struct.unpack("<HH", archive.fp.read(4))
            data_offset = member.header_offset + 30 + name_length + extra_length
            if data_offset % 64 != 0:
                raise AssertionError(
                    f"USDZ member is not 64-byte aligned: {path.name}/{member.filename}"
                )


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
        referenced_stems = catalog_references(arguments.prop_kind.resolve(), actual_names)
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
