"""LiDAR-calibrated monocular depth fusion with SAM 2 boundary priors."""

from __future__ import annotations

import numpy as np


MIN_DEPTH_METERS = 0.15
MAX_DEPTH_METERS = 12.0


def _fit_affine(candidate: np.ndarray, lidar: np.ndarray, valid: np.ndarray) -> tuple[np.ndarray, float]:
    x = candidate[valid].astype(np.float64, copy=False)
    y = lidar[valid].astype(np.float64, copy=False)
    if x.size > 20_000:
        indices = np.linspace(0, x.size - 1, 20_000, dtype=np.int64)
        x = x[indices]
        y = y[indices]

    design = np.column_stack((x, np.ones_like(x)))
    scale, offset = np.linalg.lstsq(design, y, rcond=None)[0]
    prediction = candidate * np.float32(scale) + np.float32(offset)
    residual = np.abs(prediction[valid] - lidar[valid])
    cutoff = np.quantile(residual, 0.85)
    refined = np.zeros_like(valid)
    refined[valid] = residual <= cutoff
    if np.count_nonzero(refined) >= 128:
        x = candidate[refined].astype(np.float64, copy=False)
        y = lidar[refined].astype(np.float64, copy=False)
        design = np.column_stack((x, np.ones_like(x)))
        scale, offset = np.linalg.lstsq(design, y, rcond=None)[0]
        prediction = candidate * np.float32(scale) + np.float32(offset)

    score = float(np.median(np.abs(prediction[valid] - lidar[valid])))
    return prediction.astype(np.float32, copy=False), score


def align_relative_depth(relative: np.ndarray, lidar: np.ndarray) -> np.ndarray:
    """Resolve relative-depth direction and affine scale from real LiDAR metres."""
    valid = (
        np.isfinite(lidar)
        & (lidar >= MIN_DEPTH_METERS)
        & (lidar <= MAX_DEPTH_METERS)
        & np.isfinite(relative)
    )
    if np.count_nonzero(valid) < 128:
        fallback = lidar.astype(np.float32, copy=True)
        fallback[~np.isfinite(fallback)] = 0
        return fallback

    normalized = relative.astype(np.float32, copy=False)
    inverse = 1.0 / np.maximum(normalized, np.float32(1e-4))
    direct_result, direct_score = _fit_affine(normalized, lidar, valid)
    inverse_result, inverse_score = _fit_affine(inverse, lidar, valid)
    return direct_result if direct_score <= inverse_score else inverse_result


def _mask_edge(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="edge")
    eroded = np.ones_like(mask, dtype=bool)
    for y_offset in range(3):
        for x_offset in range(3):
            eroded &= padded[
                y_offset : y_offset + mask.shape[0],
                x_offset : x_offset + mask.shape[1],
            ]
    return mask & ~eroded


def fuse_depth(relative: np.ndarray, lidar: np.ndarray, masks: list[np.ndarray]) -> np.ndarray:
    """Keep reliable LiDAR, fill holes with AI, and sharpen SAM 2 boundaries."""
    aligned = align_relative_depth(relative, lidar)
    lidar_valid = (
        np.isfinite(lidar)
        & (lidar >= MIN_DEPTH_METERS)
        & (lidar <= MAX_DEPTH_METERS)
    )

    # Calibrate each sufficiently observed SAM object independently. This prevents
    # a table and the wall behind it from sharing one monocular-depth offset.
    boundary = np.zeros(lidar.shape, dtype=bool)
    for mask in masks:
        if mask.shape != lidar.shape:
            continue
        region = mask & lidar_valid & np.isfinite(aligned)
        if np.count_nonzero(region) >= 32:
            offset = np.median(lidar[region] - aligned[region])
            aligned[mask] += np.float32(offset)
        boundary |= _mask_edge(mask)

    fused = aligned.astype(np.float32, copy=True)
    regular = lidar_valid & ~boundary
    fused[regular] = lidar[regular] * 0.90 + aligned[regular] * 0.10
    edge_valid = lidar_valid & boundary
    fused[edge_valid] = lidar[edge_valid] * 0.35 + aligned[edge_valid] * 0.65
    fused[~np.isfinite(fused)] = 0
    invalid_range = (fused < MIN_DEPTH_METERS) | (fused > MAX_DEPTH_METERS)
    fused[invalid_range] = 0
    return np.ascontiguousarray(fused, dtype=np.float32)
