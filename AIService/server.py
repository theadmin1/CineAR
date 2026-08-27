"""CineAR LAN inference service: Depth Anything V2 + SAM 2.1 + LiDAR fusion."""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager, nullcontext
from io import BytesIO
import os
from threading import Lock
import time

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
import numpy as np
from PIL import Image
import torch
import torch.nn.functional as torch_functional
from transformers import AutoImageProcessor, AutoModelForDepthEstimation

from AIService.fusion import fuse_depth


DEPTH_MODEL_ID = os.environ.get(
    "CINEAR_DEPTH_MODEL",
    "depth-anything/Depth-Anything-V2-Small-hf",
)
SAM_MODEL_ID = os.environ.get("CINEAR_SAM_MODEL", "facebook/sam2.1-hiera-tiny")
SAM_POINTS_PER_SIDE = int(os.environ.get("CINEAR_SAM_POINTS", "8"))
SAM_MAX_SIDE = int(os.environ.get("CINEAR_SAM_MAX_SIDE", "512"))
MAX_PIXELS = 640 * 480


class InferenceModels:
    def __init__(self) -> None:
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.depth_processor = None
        self.depth_model = None
        self.mask_generator = None
        self.ready = False
        self.load_error: str | None = None
        self.lock = Lock()

    def load(self) -> None:
        try:
            self.depth_processor = AutoImageProcessor.from_pretrained(DEPTH_MODEL_ID)
            self.depth_model = AutoModelForDepthEstimation.from_pretrained(DEPTH_MODEL_ID)
            self.depth_model = self.depth_model.to(self.device).eval()

            from sam2.automatic_mask_generator import SAM2AutomaticMaskGenerator
            from sam2.build_sam import build_sam2_hf

            sam_model = build_sam2_hf(
                SAM_MODEL_ID,
                device=str(self.device),
                apply_postprocessing=False,
            )
            self.mask_generator = SAM2AutomaticMaskGenerator(
                model=sam_model,
                points_per_side=SAM_POINTS_PER_SIDE,
                points_per_batch=16,
                pred_iou_thresh=0.88,
                stability_score_thresh=0.92,
                crop_n_layers=0,
                min_mask_region_area=0,
                output_mode="binary_mask",
            )
            self.ready = True
        except Exception as error:  # surfaced by /health and startup log
            self.load_error = f"{type(error).__name__}: {error}"
            raise

    def _autocast(self):
        if self.device.type == "cuda":
            return torch.autocast(device_type="cuda", dtype=torch.float16)
        return nullcontext()

    def _relative_depth(self, image: Image.Image, height: int, width: int) -> np.ndarray:
        inputs = self.depth_processor(images=image, return_tensors="pt")
        pixel_values = inputs["pixel_values"].to(self.device)
        with torch.inference_mode(), self._autocast():
            prediction = self.depth_model(pixel_values=pixel_values).predicted_depth
            prediction = torch_functional.interpolate(
                prediction.unsqueeze(1),
                size=(height, width),
                mode="bicubic",
                align_corners=False,
            ).squeeze(0).squeeze(0)
        return prediction.float().cpu().numpy().astype(np.float32, copy=False)

    def _sam_masks(self, image: Image.Image, height: int, width: int) -> list[np.ndarray]:
        scale = min(1.0, SAM_MAX_SIDE / max(image.size))
        sam_size = (
            max(32, round(image.width * scale)),
            max(32, round(image.height * scale)),
        )
        sam_image = np.asarray(
            image.resize(sam_size, Image.Resampling.BILINEAR),
            dtype=np.uint8,
        ).copy()
        with torch.inference_mode(), self._autocast():
            records = self.mask_generator.generate(sam_image)
        records.sort(key=lambda item: item["area"], reverse=True)
        masks: list[np.ndarray] = []
        for record in records[:48]:
            binary = Image.fromarray(record["segmentation"].astype(np.uint8) * 255)
            resized = binary.resize((width, height), Image.Resampling.NEAREST)
            mask = np.asarray(resized) > 0
            coverage = float(np.count_nonzero(mask)) / mask.size
            if 0.002 <= coverage <= 0.92:
                masks.append(mask)
        return masks

    def infer(self, image: Image.Image, lidar: np.ndarray) -> tuple[np.ndarray, int, float]:
        if not self.ready:
            raise RuntimeError(self.load_error or "Models are not ready")
        started = time.perf_counter()
        with self.lock:
            relative = self._relative_depth(image, lidar.shape[0], lidar.shape[1])
            masks = self._sam_masks(image, lidar.shape[0], lidar.shape[1])
            fused = fuse_depth(relative, lidar, masks)
        elapsed_ms = (time.perf_counter() - started) * 1_000
        return fused, len(masks), elapsed_ms


models = InferenceModels()


@asynccontextmanager
async def lifespan(_: FastAPI):
    await asyncio.to_thread(models.load)
    yield


app = FastAPI(title="CineAR AI Depth", version="1.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "ready": models.ready,
        "device": str(models.device),
        "depth_model": DEPTH_MODEL_ID,
        "sam_model": SAM_MODEL_ID,
        "error": models.load_error,
    }


@app.post("/v1/depth")
async def depth(
    image: UploadFile = File(...),
    lidar: UploadFile = File(...),
    frame_id: str = Form(...),
    depth_width: int = Form(...),
    depth_height: int = Form(...),
) -> Response:
    if not models.ready:
        raise HTTPException(status_code=503, detail=models.load_error or "Models are loading")
    if depth_width <= 0 or depth_height <= 0 or depth_width * depth_height > MAX_PIXELS:
        raise HTTPException(status_code=400, detail="Invalid depth dimensions")

    image_bytes, lidar_bytes = await asyncio.gather(image.read(), lidar.read())
    expected_bytes = depth_width * depth_height * np.dtype("<f4").itemsize
    if len(lidar_bytes) != expected_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"LiDAR payload is {len(lidar_bytes)} bytes; expected {expected_bytes}",
        )
    try:
        camera_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        camera_image.load()
    except Exception as error:
        raise HTTPException(status_code=400, detail=f"Invalid camera image: {error}") from error

    lidar_depth = np.frombuffer(lidar_bytes, dtype="<f4").reshape(depth_height, depth_width)
    try:
        fused, mask_count, elapsed_ms = await asyncio.to_thread(
            models.infer,
            camera_image,
            lidar_depth,
        )
    except RuntimeError as error:
        if "out of memory" in str(error).lower() and torch.cuda.is_available():
            torch.cuda.empty_cache()
        raise HTTPException(status_code=500, detail=str(error)) from error

    return Response(
        content=fused.astype("<f4", copy=False).tobytes(),
        media_type="application/octet-stream",
        headers={
            "X-CineAR-Frame-ID": frame_id,
            "X-CineAR-Depth-Width": str(depth_width),
            "X-CineAR-Depth-Height": str(depth_height),
            "X-CineAR-SAM-Masks": str(mask_count),
            "X-CineAR-Inference-MS": f"{elapsed_ms:.1f}",
        },
    )
