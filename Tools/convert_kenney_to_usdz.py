"""Convert the selected CC0 Kenney Furniture Kit GLB files to RealityKit USDZ.

Run with Blender 4.5 or newer:
  blender --background --factory-startup --python Tools/convert_kenney_to_usdz.py -- \
    "<Kenney>/Models/GLTF format" "CineAR/RoomAssets"
"""

from pathlib import Path
import sys

import bpy


ASSET_NAMES = (
    "bathtub",
    "bedDouble",
    "chairModernCushion",
    "kitchenStove",
    "kitchenFridge",
    "bathroomSink",
    "loungeDesignSofa",
    "stairs",
    "bookcaseClosedWide",
    "kitchenStoveElectric",
    "table",
    "televisionModern",
    "toilet",
    "washerDryerStacked",
)


def arguments() -> tuple[Path, Path]:
    try:
        separator = sys.argv.index("--")
        source_value, output_value = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <Kenney GLTF directory> <output directory>") from error

    source = Path(source_value).resolve()
    output = Path(output_value).resolve()
    if not source.is_dir():
        raise SystemExit(f"GLTF source directory does not exist: {source}")
    output.mkdir(parents=True, exist_ok=True)
    return source, output


def convert(source: Path, output: Path, name: str) -> None:
    input_url = source / f"{name}.glb"
    output_url = output / f"{name}.usdz"
    if not input_url.is_file():
        raise RuntimeError(f"Missing source model: {input_url}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.import_scene.gltf(filepath=str(input_url))
    if "FINISHED" not in imported:
        raise RuntimeError(f"GLB import failed: {input_url}")

    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found in: {input_url}")

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
    if output_url.stat().st_size < 512:
        raise RuntimeError(f"USDZ output is unexpectedly small: {output_url}")
    print(f"CINEAR_USDZ {name} {output_url.stat().st_size}")


def main() -> None:
    source, output = arguments()
    for asset_name in ASSET_NAMES:
        convert(source, output, asset_name)


if __name__ == "__main__":
    main()
