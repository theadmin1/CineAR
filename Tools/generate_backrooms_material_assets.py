"""Package the approved Backrooms PBR materials as mobile RealityKit USDZ files.

The source folder contains the official 3DTextures.me CC0 Wallpaper Backrooms
001 maps and Yasu's CC BY 4.0 Backrooms Material Pack. Source files stay in the
ignored asset cache. Only 1K color, OpenGL-normal and roughness maps are shipped.

    $env:PYTHONPATH = (Resolve-Path '.tools-cache/usd-core').Path
    python Tools/generate_backrooms_material_assets.py \
        --source .asset-cache/backrooms-materials --output CineAR/RoomAssets
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from pxr import Gf, Sdf, Usd, UsdGeom, UsdShade, UsdUtils, Vt


MAX_TEXTURE_EDGE = 1024
MAX_PACKAGE_BYTES = 3 * 1024 * 1024


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def material_specs(source_root: Path) -> list[tuple[str, Path, Path, Path, float]]:
    yasu = source_root / "Yasu's_Backrooms_Material_Pack"
    specs: list[tuple[str, Path, Path, Path, float]] = [
        (
            "wall_cladding_backrooms_001",
            source_root / "Wallpaper_Backrooms_001_basecolor.png",
            source_root / "Wallpaper_Backrooms_001_normal.png",
            source_root / "Wallpaper_Backrooms_001_roughness.png",
            1.25,
        )
    ]
    for index in range(1, 10):
        stem = f"Backrooms_Wallpaper_{index:02d}"
        specs.append((
            f"backrooms_yasu_wall_{index:02d}",
            yasu / "Walls" / f"{stem}_Color.jpg",
            yasu / "Walls" / f"{stem}_Normal.jpg",
            yasu / "Walls" / f"{stem}_Roughness.jpg",
            1.25,
        ))
    for index in range(1, 5):
        stem = f"Backrooms_Ceiling_{index:02d}"
        specs.append((
            f"backrooms_yasu_ceiling_{index:02d}",
            yasu / "Ceilings" / f"{stem}_Color.jpg",
            yasu / "Ceilings" / f"{stem}_Normal.jpg",
            yasu / "Ceilings" / f"{stem}_Roughness.jpg",
            1.20,
        ))
    stem = "Backrooms_Carpet_01"
    specs.append((
        "backrooms_yasu_floor_01",
        yasu / "Floors" / f"{stem}_Color.jpg",
        yasu / "Floors" / f"{stem}_Normal.jpg",
        yasu / "Floors" / f"{stem}_Roughness.jpg",
        1.50,
    ))
    return specs


def convert_texture(source: Path, destination: Path, *, color: bool) -> None:
    if not source.is_file():
        raise RuntimeError(f"Missing source texture: {source}")
    converter = shutil.which("magick")
    if converter is None:
        raise RuntimeError("ImageMagick `magick` is required")
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        converter, str(source), "-strip", "-alpha", "off", "-depth", "8",
        "-resize", f"{MAX_TEXTURE_EDGE}x{MAX_TEXTURE_EDGE}>",
    ]
    if color:
        command += ["-sampling-factor", "4:2:0", "-quality", "88"]
    else:
        command += ["-colorspace", "sRGB", "-sampling-factor", "4:4:4", "-quality", "90"]
    command.append(str(destination))
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if destination.stat().st_size < 128:
        raise RuntimeError(f"Texture conversion failed: {source}")


def texture_shader(
    material: UsdShade.Material,
    name: str,
    file_name: str,
    uv_reader: UsdShade.Shader,
    color_space: str,
) -> UsdShade.Shader:
    shader = UsdShade.Shader.Define(material.GetPrim().GetStage(), material.GetPath().AppendChild(name))
    shader.CreateIdAttr("UsdUVTexture")
    shader.CreateInput("file", Sdf.ValueTypeNames.Asset).Set(Sdf.AssetPath(f"./textures/{file_name}"))
    shader.CreateInput("sourceColorSpace", Sdf.ValueTypeNames.Token).Set(color_space)
    shader.CreateInput("wrapS", Sdf.ValueTypeNames.Token).Set("repeat")
    shader.CreateInput("wrapT", Sdf.ValueTypeNames.Token).Set("repeat")
    shader.CreateInput("st", Sdf.ValueTypeNames.Float2).ConnectToSource(
        uv_reader.ConnectableAPI(), "result"
    )
    shader.CreateOutput("rgb", Sdf.ValueTypeNames.Float3)
    shader.CreateOutput("r", Sdf.ValueTypeNames.Float)
    return shader


def build_stage(stage_path: Path, asset_name: str, tile_meters: float) -> None:
    stage = Usd.Stage.CreateNew(str(stage_path))
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)
    root = UsdGeom.Xform.Define(stage, "/SynapMantisAsset")
    stage.SetDefaultPrim(root.GetPrim())

    mesh = UsdGeom.Mesh.Define(stage, f"/SynapMantisAsset/{asset_name}")
    mesh.CreatePointsAttr(Vt.Vec3fArray([
        Gf.Vec3f(-1.2, -1.25, 0), Gf.Vec3f(1.2, -1.25, 0),
        Gf.Vec3f(1.2, 1.25, 0), Gf.Vec3f(-1.2, 1.25, 0),
    ]))
    mesh.CreateFaceVertexCountsAttr(Vt.IntArray([3, 3]))
    mesh.CreateFaceVertexIndicesAttr(Vt.IntArray([0, 1, 2, 0, 2, 3]))
    mesh.CreateExtentAttr(Vt.Vec3fArray([
        Gf.Vec3f(-1.2, -1.25, 0), Gf.Vec3f(1.2, 1.25, 0),
    ]))
    mesh.CreateSubdivisionSchemeAttr().Set(UsdGeom.Tokens.none)
    mesh.CreateDoubleSidedAttr().Set(True)
    mesh.CreateNormalsAttr(Vt.Vec3fArray([Gf.Vec3f(0, 0, 1)] * 4))
    mesh.SetNormalsInterpolation(UsdGeom.Tokens.vertex)
    st = UsdGeom.PrimvarsAPI(mesh).CreatePrimvar(
        "st", Sdf.ValueTypeNames.TexCoord2fArray, UsdGeom.Tokens.vertex
    )
    st.Set(Vt.Vec2fArray([
        Gf.Vec2f(0, 0), Gf.Vec2f(2.4 / tile_meters, 0),
        Gf.Vec2f(2.4 / tile_meters, 2.5 / tile_meters),
        Gf.Vec2f(0, 2.5 / tile_meters),
    ]))

    material = UsdShade.Material.Define(stage, "/SynapMantisAsset/Materials/PBR")
    preview = UsdShade.Shader.Define(stage, material.GetPath().AppendChild("PreviewSurface"))
    preview.CreateIdAttr("UsdPreviewSurface")
    preview.CreateInput("metallic", Sdf.ValueTypeNames.Float).Set(0.0)
    preview.CreateInput("ior", Sdf.ValueTypeNames.Float).Set(1.5)
    preview.CreateOutput("surface", Sdf.ValueTypeNames.Token)

    uv_reader = UsdShade.Shader.Define(stage, material.GetPath().AppendChild("UVReader"))
    uv_reader.CreateIdAttr("UsdPrimvarReader_float2")
    uv_reader.CreateInput("varname", Sdf.ValueTypeNames.Token).Set("st")
    uv_reader.CreateOutput("result", Sdf.ValueTypeNames.Float2)

    color = texture_shader(material, "Color", "Color.jpg", uv_reader, "sRGB")
    roughness = texture_shader(material, "Roughness", "Roughness.jpg", uv_reader, "raw")
    normal = texture_shader(material, "Normal", "Normal.jpg", uv_reader, "raw")
    normal.CreateInput("bias", Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(-1, -1, -1, -1))
    normal.CreateInput("scale", Sdf.ValueTypeNames.Float4).Set(Gf.Vec4f(2, 2, 2, 2))

    preview.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).ConnectToSource(
        color.ConnectableAPI(), "rgb"
    )
    preview.CreateInput("roughness", Sdf.ValueTypeNames.Float).ConnectToSource(
        roughness.ConnectableAPI(), "r"
    )
    preview.CreateInput("normal", Sdf.ValueTypeNames.Normal3f).ConnectToSource(
        normal.ConnectableAPI(), "rgb"
    )
    material.CreateSurfaceOutput().ConnectToSource(preview.ConnectableAPI(), "surface")
    UsdShade.MaterialBindingAPI.Apply(mesh.GetPrim()).Bind(material)
    stage.GetRootLayer().Save()
    # Release the Windows file handle before packaging or temporary cleanup.
    stage = None


def package_one(
    output_root: Path,
    asset_name: str,
    color: Path,
    normal: Path,
    roughness: Path,
    tile_meters: float,
) -> None:
    with tempfile.TemporaryDirectory(
        prefix=f"{asset_name}-", ignore_cleanup_errors=True
    ) as temporary:
        work = Path(temporary)
        textures = work / "textures"
        convert_texture(color, textures / "Color.jpg", color=True)
        convert_texture(normal, textures / "Normal.jpg", color=False)
        convert_texture(roughness, textures / "Roughness.jpg", color=False)
        stage_path = work / f"{asset_name}.usdc"
        build_stage(stage_path, asset_name, tile_meters)
        output = output_root / f"{asset_name}.usdz"
        output.unlink(missing_ok=True)
        previous = Path.cwd()
        try:
            os.chdir(work)
            created = UsdUtils.CreateNewUsdzPackage(
                Sdf.AssetPath(stage_path.name), str(output.resolve()), stage_path.name
            )
        finally:
            os.chdir(previous)
        if not created or not output.is_file():
            raise RuntimeError(f"Failed to package {asset_name}")
        if output.stat().st_size > MAX_PACKAGE_BYTES:
            raise RuntimeError(f"Mobile package too large: {output}")
        if not Usd.Stage.Open(str(output.resolve())):
            raise RuntimeError(f"Packaged stage cannot be reopened: {output}")
        print(f"SYNAPMANTIS_BACKROOMS_USDZ {asset_name} {output.stat().st_size}")


def main() -> None:
    options = arguments()
    source_root = options.source.resolve()
    output_root = options.output.resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    for asset_name, color, normal, roughness, tile_meters in material_specs(source_root):
        package_one(output_root, asset_name, color, normal, roughness, tile_meters)


if __name__ == "__main__":
    main()
