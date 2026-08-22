"""Render quick Blender thumbnails from the final bundled USDZ files."""

from pathlib import Path
import sys

import bpy
from mathutils import Vector


def arguments() -> tuple[Path, Path]:
    try:
        separator = sys.argv.index("--")
        asset_value, output_value = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <RoomAssets directory> <thumbnail directory>") from error
    assets = Path(asset_value).resolve()
    output = Path(output_value).resolve()
    output.mkdir(parents=True, exist_ok=True)
    return assets, output


def look_at(item: bpy.types.Object, target: Vector) -> None:
    item.rotation_euler = (target - item.location).to_track_quat("-Z", "Y").to_euler()


def render(url: Path, output: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if "FINISHED" not in bpy.ops.wm.usd_import(filepath=str(url)):
        raise RuntimeError(f"USDZ import failed: {url}")
    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found: {url}")

    points = [item.matrix_world @ Vector(corner) for item in meshes for corner in item.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    size = maximum - minimum
    factor = 2.2 / max(size)
    center = (minimum + maximum) * 0.5
    top_level_items = [item for item in bpy.context.scene.objects if item.parent is None]
    bpy.ops.object.empty_add(type="PLAIN_AXES")
    container = bpy.context.object
    container.name = "ThumbnailAssetRoot"
    for item in top_level_items:
        item.parent = container
    container.scale = (factor, factor, factor)
    container.location = -center * factor
    container.location.z += size.z * factor * 0.5

    bpy.ops.object.camera_add(location=(4.2, -6.2, 3.7))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.6
    look_at(camera, Vector((0, 0, 0.8)))
    bpy.context.scene.camera = camera

    for location, energy, size_value in [((4, -4, 6), 950, 5), ((-4, -1, 3), 500, 4)]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size_value
        look_at(light, Vector((0, 0, 0.7)))

    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.015))
    floor = bpy.context.object
    floor_material = bpy.data.materials.new("ThumbnailFloor")
    floor_material.diffuse_color = (0.055, 0.065, 0.08, 1)
    floor.data.materials.append(floor_material)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("ThumbnailWorld")
    scene.world.color = (0.025, 0.03, 0.045)
    scene.render.filepath = str(output / f"{url.stem}.png")
    bpy.ops.render.render(write_still=True)
    print("CINEAR_THUMBNAIL", scene.render.filepath)


def main() -> None:
    assets, output = arguments()
    for url in sorted(assets.glob("*.usdz")):
        render(url, output)


if __name__ == "__main__":
    main()
