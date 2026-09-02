"""CineAR LAN inference service: Depth Anything V2 + SAM 2.1 + LiDAR fusion."""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager, nullcontext
from io import BytesIO
import os
import socket
from threading import Lock
import time

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
import numpy as np
from PIL import Image
import torch
import torch.nn.functional as torch_functional
from transformers import AutoImageProcessor, AutoModelForDepthEstimation
from zeroconf import IPVersion, ServiceInfo, Zeroconf

from AIService.fusion import fuse_depth


DEPTH_MODEL_ID = os.environ.get(
    "CINEAR_DEPTH_MODEL",
    "depth-anything/Depth-Anything-V2-Small-hf",
)
SAM_MODEL_ID = os.environ.get("CINEAR_SAM_MODEL", "facebook/sam2.1-hiera-tiny")
SAM_ENABLED = os.environ.get("CINEAR_SAM_ENABLED", "0").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}
SAM_POINTS_PER_SIDE = int(os.environ.get("CINEAR_SAM_POINTS", "6"))
SAM_MAX_SIDE = int(os.environ.get("CINEAR_SAM_MAX_SIDE", "448"))
DEPTH_INPUT_SIZE = min(max(int(os.environ.get("CINEAR_DEPTH_INPUT_SIZE", "322")), 224), 518)
MAX_PIXELS = 640 * 480
SERVICE_PORT = 8765
BONJOUR_SERVICE_TYPE = "_cinear-ai._tcp.local."
BONJOUR_REFRESH_SECONDS = 5
bonjour_url: str | None = None


def make_bonjour_service(address: str, hostname: str | None = None) -> ServiceInfo:
    """Build the DNS-SD record advertised to CineAR on the same LAN."""
    socket.inet_aton(address)
    hostname = (hostname or socket.gethostname()).strip() or "cinear-pc"
    service_url = f"http://{address}:{SERVICE_PORT}"
    return ServiceInfo(
        type_=BONJOUR_SERVICE_TYPE,
        name=f"CineAR AI {hostname}.{BONJOUR_SERVICE_TYPE}",
        addresses=[socket.inet_aton(address)],
        port=SERVICE_PORT,
        properties={"url": service_url, "api": "1"},
        server=f"{hostname}.local.",
    )


def discover_lan_ipv4(fallback: str | None = None) -> str | None:
    """Return the IPv4 selected by Windows' current default route without sending data."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("192.0.2.1", 9))
        address = probe.getsockname()[0]
        if not address.startswith(("127.", "169.254.")):
            return address
    except OSError:
        pass
    finally:
        probe.close()
    return fallback


def register_bonjour_service(address: str | None = None) -> tuple[Zeroconf, ServiceInfo] | None:
    global bonjour_url
    address = (address or os.environ.get("CINEAR_ADVERTISE_ADDRESS", "")).strip()
    if not address:
        print("CineAR Bonjour: LAN address is unavailable; manual URL remains usable.")
        return None
    zeroconf: Zeroconf | None = None
    try:
        info = make_bonjour_service(address)
        zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
        zeroconf.register_service(info, allow_name_change=True)
        bonjour_url = f"http://{address}:{SERVICE_PORT}"
        print(f"Mevcut ag IPv4 adresi: {address}")
        print(f"iPhone sunucu adresi: {bonjour_url}")
        print(f"CineAR Bonjour: advertising {bonjour_url}")
        return zeroconf, info
    except Exception as error:
        bonjour_url = None
        if zeroconf is not None:
            zeroconf.close()
        print(f"CineAR Bonjour warning: {type(error).__name__}: {error}")
        return None


def unregister_bonjour_service(advertisement: tuple[Zeroconf, ServiceInfo]) -> None:
    global bonjour_url
    zeroconf, info = advertisement
    try:
        zeroconf.unregister_service(info)
    finally:
        zeroconf.close()
        bonjour_url = None


async def monitor_bonjour_address(
    initial_address: str | None,
    initial_advertisement: tuple[Zeroconf, ServiceInfo] | None,
) -> None:
    """Republish the service when DHCP, Wi-Fi, or hotspot changes the PC address."""
    current_address = initial_address if initial_advertisement is not None else None
    advertisement = initial_advertisement
    try:
        while True:
            await asyncio.sleep(BONJOUR_REFRESH_SECONDS)
            detected_address = await asyncio.to_thread(
                discover_lan_ipv4,
                current_address or initial_address,
            )
            if not detected_address or detected_address == current_address:
                continue
            if advertisement is not None:
                previous_advertisement = advertisement
                advertisement = None
                current_address = None
                await asyncio.to_thread(
                    unregister_bonjour_service,
                    previous_advertisement,
                )
            advertisement = await asyncio.to_thread(
                register_bonjour_service,
                detected_address,
            )
            current_address = detected_address if advertisement is not None else None
    finally:
        if advertisement is not None:
            await asyncio.to_thread(unregister_bonjour_service, advertisement)


class InferenceModels:
    def __init__(self) -> None:
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        if self.device.type == "cuda":
            torch.backends.cuda.matmul.allow_tf32 = True
            torch.backends.cudnn.allow_tf32 = True
            torch.backends.cudnn.benchmark = True
        self.depth_processor = None
        self.depth_model = None
        self.mask_generator = None
        self.ready = False
        self.load_error: str | None = None
        self.warmup_milliseconds = 0.0
        self.lock = Lock()

    def load(self) -> None:
        try:
            self.depth_processor = AutoImageProcessor.from_pretrained(DEPTH_MODEL_ID)
            self.depth_model = AutoModelForDepthEstimation.from_pretrained(DEPTH_MODEL_ID)
            self.depth_model = self.depth_model.to(self.device).eval()

            if SAM_ENABLED:
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
            # Pay the CUDA graph/kernel startup cost before /health reports ready.
            # Without this warm-up the first phone frame takes about one second on an
            # RTX 3050 and is correctly rejected by the iPhone as stale.
            warmup_started = time.perf_counter()
            # Match the phone request geometry and exercise interpolation/fusion too.
            # A tiny, flat image did not initialise every CUDA kernel: the first real
            # 512x384 frame could still miss the iPhone's 350 ms freshness deadline.
            warmup_width, warmup_height = 512, 384
            warmup_depth_width, warmup_depth_height = 256, 192
            horizontal = np.linspace(0, 255, warmup_width, dtype=np.uint8)
            vertical = np.linspace(0, 255, warmup_height, dtype=np.uint8)
            warmup_pixels = np.empty((warmup_height, warmup_width, 3), dtype=np.uint8)
            warmup_pixels[..., 0] = horizontal[None, :]
            warmup_pixels[..., 1] = vertical[:, None]
            warmup_pixels[..., 2] = 127
            warmup_image = Image.fromarray(warmup_pixels, mode="RGB")
            warmup_lidar = np.full(
                (warmup_depth_height, warmup_depth_width),
                2.0,
                dtype=np.float32,
            )
            for _ in range(2):
                relative = self._relative_depth(
                    warmup_image,
                    warmup_depth_height,
                    warmup_depth_width,
                )
                masks = self._sam_masks(
                    warmup_image,
                    warmup_depth_height,
                    warmup_depth_width,
                )
                _ = fuse_depth(relative, warmup_lidar, masks)
            if self.device.type == "cuda":
                torch.cuda.synchronize()
            self.warmup_milliseconds = (time.perf_counter() - warmup_started) * 1_000
            self.ready = True
        except Exception as error:  # surfaced by /health and startup log
            self.load_error = f"{type(error).__name__}: {error}"
            raise

    def _autocast(self):
        if self.device.type == "cuda":
            return torch.autocast(device_type="cuda", dtype=torch.float16)
        return nullcontext()

    def _relative_depth(self, image: Image.Image, height: int, width: int) -> np.ndarray:
        inputs = self.depth_processor(
            images=image,
            return_tensors="pt",
            size={"height": DEPTH_INPUT_SIZE, "width": DEPTH_INPUT_SIZE},
        )
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
        if self.mask_generator is None:
            return []
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
    configured_address = os.environ.get("CINEAR_ADVERTISE_ADDRESS", "").strip() or None
    initial_address = await asyncio.to_thread(discover_lan_ipv4, configured_address)
    advertisement = await asyncio.to_thread(register_bonjour_service, initial_address)
    bonjour_monitor = asyncio.create_task(
        monitor_bonjour_address(initial_address, advertisement)
    )
    try:
        yield
    finally:
        bonjour_monitor.cancel()
        try:
            await bonjour_monitor
        except asyncio.CancelledError:
            pass


app = FastAPI(title="CineAR AI Depth", version="1.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "ready": models.ready,
        "device": str(models.device),
        "depth_model": DEPTH_MODEL_ID,
        "sam_model": SAM_MODEL_ID,
        "sam_enabled": SAM_ENABLED,
        "sam_points_per_side": SAM_POINTS_PER_SIDE,
        "sam_max_side": SAM_MAX_SIDE,
        "depth_input_size": DEPTH_INPUT_SIZE,
        "warmup_milliseconds": round(models.warmup_milliseconds, 1),
        "bonjour_url": bonjour_url,
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
