"""Headless Blender smoke test for every bundled CineAR USDZ asset."""

from math import isfinite
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def asset_directory() -> Path:
    try:
        separator = sys.argv.index("--")
        return Path(sys.argv[separator + 1]).resolve()
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <RoomAssets directory>") from error


def validate(url: Path) -> None:
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
    if not all(isfinite(value) and value > 0.0001 for value in size):
        raise RuntimeError(f"Invalid visual bounds in USDZ: {url}, size={tuple(size)}")
    if material_slots <= 0:
        raise RuntimeError(f"No material slots in USDZ: {url}")

    print(
        "CINEAR_USDZ_OK",
        url.name,
        f"meshes={len(meshes)}",
        f"vertices={vertices}",
        f"triangles={triangles}",
        f"materials={material_slots}",
        "size=" + "x".join(f"{value:.4f}" for value in size),
    )


def main() -> None:
    directory = asset_directory()
    urls = sorted(directory.glob("*.usdz"))
    if not urls:
        raise SystemExit(f"No USDZ files found: {directory}")
    for url in urls:
        validate(url)


if __name__ == "__main__":
    main()
