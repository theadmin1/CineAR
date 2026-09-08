"""Fail a build if its actual Info.plist lacks required privacy explanations."""
import argparse
from pathlib import Path
import plistlib
import sys


REQUIRED = {
    "NSCameraUsageDescription": ("kamera", "LiDAR", "sanal dekor"),
    "NSMicrophoneUsageDescription": ("mikrofon",),
    "NSSpeechRecognitionUsageDescription": ("konuşma",),
    "NSLocalNetworkUsageDescription": ("yerel ağ",),
}


def validate(path: Path, expected_bundle_id: str | None = None) -> list[str]:
    try:
        with path.open("rb") as handle:
            values = plistlib.load(handle)
    except Exception as error:
        return [f"Info.plist okunamadı: {error}"]
    errors = []
    for key, required_words in REQUIRED.items():
        value = values.get(key)
        if not isinstance(value, str) or len(value.strip()) < 24:
            errors.append(f"{key} eksik, boş veya yeterince açıklayıcı değil")
            continue
        folded = value.casefold()
        for word in required_words:
            if word.casefold() not in folded:
                errors.append(f"{key}, '{word}' amacını açıkça belirtmiyor")
    if expected_bundle_id:
        bundle_id = values.get("CFBundleIdentifier")
        # Source plists legitimately contain the Xcode substitution variable.
        if bundle_id not in (expected_bundle_id, "$(PRODUCT_BUNDLE_IDENTIFIER)"):
            errors.append(f"Bundle ID uyuşmuyor: {bundle_id!r}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plist", required=True, type=Path)
    parser.add_argument("--expected-bundle-id")
    args = parser.parse_args()
    errors = validate(args.plist, args.expected_bundle_id)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"PASS: privacy descriptions verified in {args.plist}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
