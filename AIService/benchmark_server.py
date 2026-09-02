"""Measure CineAR's real HTTP depth path, including upload and response time."""

from __future__ import annotations

import argparse
from io import BytesIO
import json
import time
from urllib.request import Request, urlopen
from uuid import uuid4

import numpy as np
from PIL import Image


def multipart_body(
    fields: dict[str, str],
    files: dict[str, tuple[str, bytes, str]],
) -> tuple[bytes, str]:
    boundary = f"cinear-{uuid4().hex}"
    chunks: list[bytes] = []
    for name, value in fields.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
                value.encode(),
                b"\r\n",
            ]
        )
    for name, (filename, content, content_type) in files.items():
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                (
                    f'Content-Disposition: form-data; name="{name}"; '
                    f'filename="{filename}"\r\n'
                ).encode(),
                f"Content-Type: {content_type}\r\n\r\n".encode(),
                content,
                b"\r\n",
            ]
        )
    chunks.append(f"--{boundary}--\r\n".encode())
    return b"".join(chunks), boundary


def phone_like_payload() -> tuple[bytes, bytes]:
    width, height = 512, 384
    horizontal = np.linspace(0, 255, width, dtype=np.uint8)
    vertical = np.linspace(0, 255, height, dtype=np.uint8)
    pixels = np.empty((height, width, 3), dtype=np.uint8)
    pixels[..., 0] = horizontal[None, :]
    pixels[..., 1] = vertical[:, None]
    pixels[..., 2] = (
        (pixels[..., 0].astype(np.uint16) + pixels[..., 1].astype(np.uint16)) // 2
    ).astype(np.uint8)
    image_bytes = BytesIO()
    Image.fromarray(pixels, mode="RGB").save(image_bytes, format="JPEG", quality=90)
    lidar_bytes = np.full((192, 256), 2.0, dtype="<f4").tobytes()
    return image_bytes.getvalue(), lidar_bytes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8765")
    parser.add_argument("--requests", type=int, default=3)
    parser.add_argument("--deadline-ms", type=float, default=350.0)
    args = parser.parse_args()

    with urlopen(f"{args.url}/health", timeout=10) as response:
        health = json.load(response)
    print("health:", json.dumps(health, ensure_ascii=False))
    if not health.get("ready"):
        raise RuntimeError(f"Server is not ready: {health.get('error')}")

    image_bytes, lidar_bytes = phone_like_payload()
    http_times: list[float] = []
    inference_times: list[float] = []
    expected_response_bytes = 192 * 256 * np.dtype("<f4").itemsize
    for index in range(args.requests):
        body, boundary = multipart_body(
            {
                "frame_id": str(index),
                "depth_width": "256",
                "depth_height": "192",
            },
            {
                "image": ("frame.jpg", image_bytes, "image/jpeg"),
                "lidar": ("depth.bin", lidar_bytes, "application/octet-stream"),
            },
        )
        request = Request(
            f"{args.url}/v1/depth",
            data=body,
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
            method="POST",
        )
        started = time.perf_counter()
        with urlopen(request, timeout=15) as response:
            result = response.read()
            inference_times.append(float(response.headers["X-CineAR-Inference-MS"]))
        http_times.append((time.perf_counter() - started) * 1_000)
        if len(result) != expected_response_bytes:
            raise RuntimeError(
                f"Depth response is {len(result)} bytes; expected {expected_response_bytes}"
            )

    print("http_ms:", [round(value, 1) for value in http_times])
    print("inference_ms:", inference_times)
    passed = max(http_times) < args.deadline_ms
    print(f"deadline_{args.deadline_ms:g}_ms:", "PASS" if passed else "FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
