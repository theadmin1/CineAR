"""Build two 12-triangle wall panels from official CC0 1K PBR textures.

blender --background --factory-startup --python Tools/generate_wall_assets.py -- \
    .asset-cache/wall-textures CineAR/RoomAssets

Blender Z-up panels become Y-up in USDZ; local +Z faces the room in RealityKit.
The runtime contact pivot aligns the FRONT face, leaving thickness in the wall.
"""

from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from convert_polyhaven_to_usdz import export_mobile_usdz

ASSETS = (
    ("brick_wall_001", "wall_cladding_brick", 1.5),
    # Wood source has no published physical scale; use a 2 m design tile.
    ("wood_plank_wall", "wall_cladding_wood", 2.0),
)


def build(source: Path, output: Path, texture_id: str, name: str, tile_meters: float) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_cube_add(size=1)
    panel = bpy.context.object
    panel.name = name
    panel.dimensions = (2.4, 0.06, 2.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Metre-based UVs retain believable brick/plank size without extra geometry.
    uv_layer = panel.data.uv_layers.active
    for polygon in panel.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex = panel.data.vertices[panel.data.loops[loop_index].vertex_index].co
            if abs(polygon.normal.y) > 0.5:
                uv = (vertex.x / tile_meters, vertex.z / tile_meters)
            elif abs(polygon.normal.x) > 0.5:
                uv = (vertex.y / tile_meters, vertex.z / tile_meters)
            else:
                uv = (vertex.x / tile_meters, vertex.y / tile_meters)
            uv_layer.data[loop_index].uv = uv

    material = bpy.data.materials.new(name + "_PBR")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    for map_name, input_name in (("Diffuse", "Base Color"), ("Rough", "Roughness"), ("nor_gl", "Normal")):
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = bpy.data.images.load(str(source / texture_id / f"{map_name}.jpg"))
        texture.extension = "REPEAT"
        if map_name != "Diffuse":
            texture.image.colorspace_settings.name = "Non-Color"
        if map_name == "nor_gl":
            normal = nodes.new("ShaderNodeNormalMap")
            links.new(texture.outputs["Color"], normal.inputs["Color"])
            links.new(normal.outputs["Normal"], shader.inputs["Normal"])
        else:
            links.new(texture.outputs["Color"], shader.inputs[input_name])
    panel.data.materials.append(material)
    output_url = output / f"{name}.usdz"
    export_mobile_usdz(output_url)
    print(f"CINEAR_WALL_ASSET_OK {name} bytes={output_url.stat().st_size}")


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    if len(args) != 2:
        raise SystemExit("Expected: -- <texture directory> <RoomAssets directory>")
    source, output = (Path(value).resolve() for value in args)
    output.mkdir(parents=True, exist_ok=True)
    for texture_id, name, tile_meters in ASSETS:
        build(source, output, texture_id, name, tile_meters)


if __name__ == "__main__":
    main()
