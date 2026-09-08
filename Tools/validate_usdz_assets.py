"""Headless Blender smoke test for every bundled CineAR USDZ asset."""

from math import isfinite
from pathlib import Path
import sys

import bpy
from mathutils import Vector

MAX_USDZ_BYTES = 8 * 1024 * 1024
MAX_TRIANGLES = 60_000
MAX_MATERIAL_SLOTS = 24
MAX_TEXTURE_EDGE = 1024


def asset_directory() -> Path:
    try:
        separator = sys.argv.index("--")
        return Path(sys.argv[separator + 1]).resolve()
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <RoomAssets directory>") from error


def validate(url: Path) -> None:
    if url.stat().st_size > MAX_USDZ_BYTES:
        raise RuntimeError(
            f"USDZ exceeds mobile bundle budget ({url.stat().st_size} bytes): {url}"
        )
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.wm.usd_import(filepath=str(url))
    if "FINISHED" not in imported:
        raise RuntimeError(f"USDZ import failed: {url}")

    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in USDZ: {url}")

    for item in meshes:
        item.data.calc_loop_triangles()
    vertices = sum(len(item.data.vertices) for item in meshes)
    triangles = sum(len(item.data.loop_triangles) for item in meshes)
    material_slots = sum(len(item.material_slots) for item in meshes)
    points = [item.matrix_world @ Vector(corner) for item in meshes for corner in item.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    size = maximum - minimum
    if vertices <= 0 or triangles <= 0:
        raise RuntimeError(f"Empty geometry in USDZ: {url}")
    if triangles > MAX_TRIANGLES:
        raise RuntimeError(f"Triangle budget exceeded ({triangles}): {url}")
    if not all(isfinite(value) and value > 0.0001 for value in size):
        raise RuntimeError(f"Invalid visual bounds in USDZ: {url}, size={tuple(size)}")
    if material_slots <= 0:
        raise RuntimeError(f"No material slots in USDZ: {url}")
    if material_slots > MAX_MATERIAL_SLOTS:
        raise RuntimeError(f"Material slot budget exceeded ({material_slots}): {url}")

    texture_sizes = [
        tuple(int(value) for value in image.size)
        for image in bpy.data.images
        if image.type != "RENDER_RESULT" and min(image.size) > 0
    ]
    oversized_textures = [
        size for size in texture_sizes if max(size) > MAX_TEXTURE_EDGE
    ]
    if oversized_textures:
        raise RuntimeError(f"Texture budget exceeded {oversized_textures}: {url}")

    print(
        "CINEAR_USDZ_OK",
        url.name,
        f"meshes={len(meshes)}",
        f"vertices={vertices}",
        f"triangles={triangles}",
        f"materials={material_slots}",
        f"textures={len(texture_sizes)}",
        "size=" + "x".join(f"{value:.4f}" for value in size),
    )


def main() -> None:
    directory = asset_directory()
    separator = sys.argv.index("--")
    requested_names = tuple(sys.argv[separator + 2 :])
    urls = (
        [directory / f"{name}.usdz" for name in requested_names]
        if requested_names
        else sorted(directory.glob("*.usdz"))
    )
    if not urls:
        raise SystemExit(f"No USDZ files found: {directory}")
    missing = [str(url) for url in urls if not url.is_file()]
    if missing:
        raise SystemExit("Missing USDZ files: " + ", ".join(missing))
    for url in urls:
        validate(url)


if __name__ == "__main__":
    main()
