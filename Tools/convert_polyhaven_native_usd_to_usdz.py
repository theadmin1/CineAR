"""Re-export native Poly Haven USD assets as RealityKit-safe mobile USDZ.

The native files contain both MaterialX and USD Preview Surface networks. RealityKit
can expose the mesh while dropping those materials on device. Blender imports the
authored PBR textures and writes one compact USD Preview Surface network, matching
the proven pipeline used by the rest of SynapMantis' phone-only asset catalog.

Run with Blender 4.5 or newer:
  blender --background --factory-startup \
    --python Tools/convert_polyhaven_native_usd_to_usdz.py -- \
    .asset-cache/polyhaven-usd CineAR/RoomAssets
"""

from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from convert_polyhaven_to_usdz import export_mobile_usdz


ASSET_IDS = (
    "modern_ceiling_lamp_01",
    "hanging_picture_frame_01",
    "mounted_fluorescent_lights",
    "hanging_picture_frame_02",
    "fancy_picture_frame_01",
    "hanging_picture_frame_03",
    "painted_wooden_cabinet_02",
    "vintage_suitcase",
    "cassette_player",
    "vintage_radio_transceiver",
    "painted_wooden_sofa",
    "office_notepads",
    "security_light",
)
MAX_USDZ_BYTES = 8 * 1024 * 1024


def arguments() -> tuple[Path, Path, tuple[str, ...]]:
    try:
        separator = sys.argv.index("--")
        source_value, output_value = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <native USD cache> <output directory> [asset IDs]") from error
    source = Path(source_value).resolve()
    output = Path(output_value).resolve()
    requested = tuple(sys.argv[separator + 3 :])
    unknown = sorted(set(requested) - set(ASSET_IDS))
    if unknown:
        raise SystemExit("Unknown asset IDs: " + ", ".join(unknown))
    if not source.is_dir():
        raise SystemExit(f"Native USD cache does not exist: {source}")
    output.mkdir(parents=True, exist_ok=True)
    return source, output, requested or ASSET_IDS


def source_stage(asset_root: Path, asset_id: str) -> Path:
    preferred = asset_root / f"{asset_id}_package_yup.usda"
    fallback = asset_root / f"{asset_id}_1k_yup.usda"
    for candidate in (preferred, fallback):
        if candidate.is_file():
            return candidate
    raise RuntimeError(f"No normalized Y-up source for {asset_id}: {asset_root}")


def convert(cache: Path, output: Path, asset_id: str) -> None:
    source = source_stage(cache / asset_id, asset_id)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.wm.usd_import(filepath=str(source))
    if "FINISHED" not in imported:
        raise RuntimeError(f"USD import failed: {source}")

    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found in native USD: {source}")
    materials = [slot.material for item in meshes for slot in item.material_slots if slot.material]
    texture_images = [
        image for image in bpy.data.images
        if image.type != "RENDER_RESULT" and min(image.size) > 0
    ]
    if not materials or not texture_images:
        raise RuntimeError(
            f"PBR material import failed for {asset_id}: "
            f"materials={len(materials)}, textures={len(texture_images)}"
        )

    for item in list(bpy.context.scene.objects):
        if item.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(item, do_unlink=True)

    destination = output / f"{asset_id}.usdz"
    export_mobile_usdz(destination)
    if destination.stat().st_size > MAX_USDZ_BYTES:
        destination.unlink(missing_ok=True)
        raise RuntimeError(f"USDZ exceeds mobile budget: {destination}")
    print(
        "SYNAPMANTIS_REALITYKIT_USDZ",
        asset_id,
        f"meshes={len(meshes)}",
        f"materials={len(materials)}",
        f"textures={len(texture_images)}",
        f"bytes={destination.stat().st_size}",
    )


def main() -> None:
    cache, output, asset_ids = arguments()
    for asset_id in asset_ids:
        convert(cache, output, asset_id)


if __name__ == "__main__":
    main()
