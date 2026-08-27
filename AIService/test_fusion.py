import unittest

import numpy as np

from AIService.fusion import fuse_depth


class FusionTests(unittest.TestCase):
    def test_relative_depth_is_calibrated_to_lidar_metres(self):
        y, x = np.mgrid[0:24, 0:32]
        lidar = (0.8 + x * 0.03 + y * 0.01).astype(np.float32)
        relative_inverse = 1.0 / ((lidar - 0.2) / 1.7)
        result = fuse_depth(relative_inverse, lidar, [])
        self.assertLess(float(np.median(np.abs(result - lidar))), 0.01)

    def test_ai_fills_invalid_lidar_hole(self):
        lidar = np.full((24, 32), 2.0, dtype=np.float32)
        relative = np.full_like(lidar, 5.0)
        relative[:, 16:] = 3.0
        lidar[8:16, 10:22] = 0
        result = fuse_depth(relative, lidar, [])
        self.assertTrue(np.all(result[8:16, 10:22] > 0.15))


if __name__ == "__main__":
    unittest.main()
