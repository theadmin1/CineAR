"""Convert CineAR's curated Poly Haven CC0 glTF props to mobile USDZ.

Run with Blender 4.5 or newer:
  blender --background --factory-startup --python Tools/convert_polyhaven_to_usdz.py -- \
    ".asset-cache/polyhaven" "CineAR/RoomAssets"
"""

from pathlib import Path
import sys

import bpy


ASSET_IDS = (
    "metal_office_desk",
    "SchoolChair_01",
    "SchoolDesk_01",
    "metal_trash_can",
    "cardboard_box_01",
    "plastic_crate_02",
    "wooden_crate_02",
    "Barrel_02",
    "hand_truck",
    "drawer_cabinet",
    "vintage_wooden_drawer_01",
    "steel_frame_shelves_01",
    "metal_tool_chest",
    "plastic_monobloc_chair_01",
    "wooden_stool_01",
    "WetFloorSign_01",
    "korean_fire_extinguisher_01",
    "security_camera_01",
    "power_box_01",
    "korean_public_payphone_01",
    "wall_clock",
    "caged_hanging_light",
    "hanging_industrial_lamp",
    "ceiling_fan",
    "industrial_wall_lamp",
    "industrial_wall_sconce",
    "desk_lamp_arm_01",
    "classic_laptop",
    "television_02",
    "boombox",
)


def arguments() -> tuple[Path, Path]:
    try:
        separator = sys.argv.index("--")
        source_value, output_value = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <Poly Haven source directory> <output directory>") from error

    source = Path(source_value).resolve()
    output = Path(output_value).resolve()
    if not source.is_dir():
        raise SystemExit(f"Source directory does not exist: {source}")
    output.mkdir(parents=True, exist_ok=True)
    return source, output


def convert(source: Path, output: Path, asset_id: str) -> None:
    asset_directory = source / asset_id
    candidates = sorted(asset_directory.glob("*_1k.gltf"))
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one 1K glTF for {asset_id}, found {len(candidates)}")

    input_url = candidates[0]
    output_url = output / f"{asset_id}.usdz"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.import_scene.gltf(filepath=str(input_url))
    if "FINISHED" not in imported:
        raise RuntimeError(f"glTF import failed: {input_url}")

    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found in: {input_url}")

    # Animation rigs are not needed for static AR props and add runtime overhead.
    for item in list(bpy.context.scene.objects):
        if item.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(item, do_unlink=True)

    exported = bpy.ops.wm.usd_export(
        filepath=str(output_url),
        selected_objects_only=False,
        visible_objects_only=True,
        export_animation=False,
        export_hair=False,
        export_uvmaps=True,
        rename_uvmaps=True,
        export_mesh_colors=True,
        export_normals=True,
        export_materials=True,
        export_subdivision="IGNORE",
        export_armatures=False,
        export_shapekeys=False,
        use_instancing=False,
        evaluation_mode="RENDER",
        generate_preview_surface=True,
        generate_materialx_network=False,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        export_textures=True,
        export_textures_mode="NEW",
        overwrite_textures=True,
        relative_paths=True,
        xform_op_mode="TRS",
        root_prim_path="/CineARAsset",
        export_custom_properties=False,
        author_blender_name=False,
        convert_world_material=False,
        allow_unicode=False,
        export_meshes=True,
        export_lights=False,
        export_cameras=False,
        export_curves=False,
        export_points=False,
        export_volumes=False,
        triangulate_meshes=True,
        quad_method="SHORTEST_DIAGONAL",
        ngon_method="BEAUTY",
        usdz_downscale_size="1024",
        merge_parent_xform=True,
        convert_scene_units="METERS",
        meters_per_unit=1.0,
    )
    if "FINISHED" not in exported or not output_url.is_file():
        raise RuntimeError(f"USDZ export failed: {output_url}")
    if output_url.stat().st_size < 1024:
        raise RuntimeError(f"USDZ output is unexpectedly small: {output_url}")
    print(f"CINEAR_USDZ {asset_id} {output_url.stat().st_size}")


def main() -> None:
    source, output = arguments()
    for asset_id in ASSET_IDS:
        convert(source, output, asset_id)


if __name__ == "__main__":
    main()
