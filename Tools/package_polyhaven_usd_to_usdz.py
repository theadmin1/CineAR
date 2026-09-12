"""Fetch selected Poly Haven 1K USD assets and package verified mobile USDZ files.

This path preserves the author's native USD geometry/material setup and avoids a
Blender round trip. It requires the official ``usd-core`` Python package:

    python -m pip install usd-core==26.8
    python Tools/package_polyhaven_usd_to_usdz.py \
        --cache .asset-cache/polyhaven-usd --output CineAR/RoomAssets

Downloads are verified against Poly Haven's API-provided MD5 hashes. The output
package is then reopened through OpenUSD before it is accepted.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tempfile
from urllib.parse import urlparse
from urllib.request import Request, urlopen

try:
    from pxr import Sdf, Usd, UsdShade, UsdUtils
except ImportError as error:
    raise SystemExit(
        "OpenUSD is required. Install the pinned tool with: "
        "python -m pip install usd-core==26.8"
    ) from error


API_ROOT = "https://api.polyhaven.com/files"
USER_AGENT = "SynapMantisAssetPipeline/1.0"
DEFAULT_ASSET_IDS = (
    "modern_ceiling_lamp_01",
    "hanging_picture_frame_01",
)
MAX_USDZ_BYTES = 8 * 1024 * 1024


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("asset_ids", nargs="*", default=DEFAULT_ASSET_IDS)
    return parser.parse_args()


def api_json(asset_id: str) -> dict:
    request = Request(f"{API_ROOT}/{asset_id}", headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=60) as response:
        return json.load(response)


def safe_destination(root: Path, relative_name: str) -> Path:
    relative = PurePosixPath(relative_name)
    if relative.is_absolute() or ".." in relative.parts:
        raise RuntimeError(f"Unsafe dependency path: {relative_name}")
    destination = (root / Path(*relative.parts)).resolve()
    if root.resolve() not in destination.parents:
        raise RuntimeError(f"Dependency escapes asset directory: {relative_name}")
    return destination


def md5(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download_verified(url: str, destination: Path, expected_md5: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and md5(destination) == expected_md5.lower():
        return

    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=120) as response:
        with tempfile.NamedTemporaryFile(
            dir=destination.parent, prefix=destination.name, delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
            while block := response.read(1024 * 1024):
                temporary.write(block)

    try:
        actual_md5 = md5(temporary_path)
        if actual_md5 != expected_md5.lower():
            raise RuntimeError(
                f"MD5 mismatch for {destination.name}: "
                f"expected {expected_md5}, got {actual_md5}"
            )
        temporary_path.replace(destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def fetch_native_usd(asset_id: str, cache_root: Path) -> Path:
    files = api_json(asset_id)
    try:
        entry = files["usd"]["1k"]["usd"]
    except KeyError as error:
        raise RuntimeError(f"Poly Haven has no native 1K USD for {asset_id}") from error

    asset_root = (cache_root / asset_id).resolve()
    asset_root.mkdir(parents=True, exist_ok=True)
    main_name = Path(urlparse(entry["url"]).path).name
    main_path = safe_destination(asset_root, main_name)
    download_verified(entry["url"], main_path, entry["md5"])

    for relative_name, dependency in entry.get("include", {}).items():
        destination = safe_destination(asset_root, relative_name)
        download_verified(dependency["url"], destination, dependency["md5"])

    # Some Poly Haven native-USD entries currently list a JPG variant in their
    # immediate `include` map even though the USDC material points to the EXR
    # variant. Resolve the material's actual file inputs against the complete API
    # response so the package never ships with a missing texture.
    resources_by_name: dict[str, dict] = {}

    def index_resources(value: object) -> None:
        if isinstance(value, dict):
            url = value.get("url")
            expected_md5 = value.get("md5")
            if isinstance(url, str) and isinstance(expected_md5, str):
                resources_by_name[Path(urlparse(url).path).name] = value
            for child in value.values():
                index_resources(child)
        elif isinstance(value, list):
            for child in value:
                index_resources(child)

    index_resources(files)
    stage = Usd.Stage.Open(str(main_path))
    if not stage:
        raise RuntimeError(f"Native USD did not open: {main_path}")
    for prim in stage.Traverse():
        if not prim.IsA(UsdShade.Shader):
            continue
        for shader_input in UsdShade.Shader(prim).GetInputs():
            if shader_input.GetTypeName() != Sdf.ValueTypeNames.Asset:
                continue
            asset_path = shader_input.Get()
            if not asset_path or not asset_path.path:
                continue
            relative_name = asset_path.path.removeprefix("./")
            destination = safe_destination(asset_root, relative_name)
            if destination.is_file():
                continue
            resource = resources_by_name.get(Path(relative_name).name)
            if resource is None:
                raise RuntimeError(
                    f"Poly Haven API did not describe USD dependency: {relative_name}"
                )
            download_verified(resource["url"], destination, resource["md5"])
    return main_path


def package_usdz(source: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    previous_directory = Path.cwd()
    try:
        os.chdir(source.parent)
        stage = Usd.Stage.Open(source.name)
        if not stage or not stage.GetPseudoRoot().GetChildren():
            raise RuntimeError(f"Native USD did not open or has no root prim: {source}")
        created = UsdUtils.CreateNewUsdzPackage(
            Sdf.AssetPath(source.name), str(output.resolve()), source.name
        )
    finally:
        os.chdir(previous_directory)

    if not created or not output.is_file():
        raise RuntimeError(f"USDZ packaging failed: {output}")
    if output.stat().st_size > MAX_USDZ_BYTES:
        output.unlink(missing_ok=True)
        raise RuntimeError(f"USDZ exceeds mobile budget ({MAX_USDZ_BYTES} bytes): {output}")

    packaged_stage = Usd.Stage.Open(str(output.resolve()))
    if not packaged_stage or not packaged_stage.GetPseudoRoot().GetChildren():
        output.unlink(missing_ok=True)
        raise RuntimeError(f"Packaged USDZ could not be reopened: {output}")


def main() -> None:
    options = arguments()
    cache_root = options.cache.resolve()
    output_root = options.output.resolve()
    for asset_id in options.asset_ids:
        source = fetch_native_usd(asset_id, cache_root)
        output = output_root / f"{asset_id}.usdz"
        package_usdz(source, output)
        print(f"SYNAPMANTIS_USDZ {asset_id} {output.stat().st_size}")


if __name__ == "__main__":
    main()
