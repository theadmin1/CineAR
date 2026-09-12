"""Compile real Swift kernels, run Debug/Release regressions, then parse app sources.

Works on Linux or macOS. Parsing does NOT type-check ARKit/RealityKit; the separate
unsigned iOS build in Codemagic is required for that check.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(command, cwd):
    print("+ " + " ".join(map(str, command)), flush=True)
    subprocess.run(list(map(str, command)), cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swiftc", default=shutil.which("swiftc"))
    args = parser.parse_args()
    if not args.swiftc:
        parser.error("Swift compiler missing; supply --swiftc /path/to/swiftc")
    root = Path(__file__).resolve().parents[1]
    suites = [
        ("wall", ["-D", "WALL_GEOMETRY_TESTS"], "CineAR/WallCladdingGeometry.swift", "Tools/test_wall_cladding_geometry.swift"),
        ("depth", [], "CineAR/LiveDepthGeometry.swift", "Tools/test_live_depth_geometry.swift"),
        ("spatial", [], "CineAR/SpatialValidation.swift", "Tools/test_spatial_validation.swift"),
        ("custom-ar", [], "CineAR/CustomARDesign.swift", "Tools/test_custom_ar_geometry.swift"),
    ]
    run([args.swiftc, "--version"], root)
    with tempfile.TemporaryDirectory(prefix="cinear-swift-tests-") as output:
        for mode, optimization in [("Debug", "-Onone"), ("Release", "-O")]:
            for name, definitions, source, test in suites:
                executable = Path(output) / (name + "-" + mode)
                run([args.swiftc, "-swift-version", "5", "-warnings-as-errors", optimization,
                     *definitions, source, test, "-o", executable], root)
                run([executable], root)
        sources = sorted((root / "CineAR").glob("*.swift"))
        run([args.swiftc, "-frontend", "-parse", "-swift-version", "5", *sources], root)
    print(f"PASS: {len(suites) * 2} compiled test runs; {len(sources)} app files parsed.", flush=True)
    print("iOS SDK type-check and physical-device behavior remain separate checks.", flush=True)


if __name__ == "__main__":
    main()
