#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Unit tests for the neural_engine detection module."""

import platform
import sys
import unittest

from python_coreml_stable_diffusion import neural_engine


class TestNeuralEngineDetection(unittest.TestCase):
    """Tests for python_coreml_stable_diffusion.neural_engine."""

    def test_is_apple_silicon_returns_bool(self):
        result = neural_engine.is_apple_silicon()
        self.assertIsInstance(result, bool)

    def test_is_apple_silicon_consistent_with_platform(self):
        expected = sys.platform == "darwin" and platform.machine() == "arm64"
        self.assertEqual(neural_engine.is_apple_silicon(), expected)

    def test_has_neural_engine_equals_is_apple_silicon(self):
        self.assertEqual(neural_engine.has_neural_engine(), neural_engine.is_apple_silicon())

    def test_get_chip_generation_returns_valid_value_or_none(self):
        result = neural_engine.get_chip_generation()
        valid = {None, "M1", "M2", "M3", "M4"}
        self.assertIn(result, valid, f"Unexpected chip generation: {result}")

    def test_get_chip_generation_none_on_non_apple_silicon(self):
        if not neural_engine.is_apple_silicon():
            self.assertIsNone(neural_engine.get_chip_generation())

    def test_get_chip_generation_string_on_apple_silicon_if_known(self):
        if neural_engine.is_apple_silicon():
            gen = neural_engine.get_chip_generation()
            # If the chip is in the M1–M4 range it must return a non-None string;
            # truly unknown (future) chips may still return None.
            if gen is not None:
                self.assertIsInstance(gen, str)

    def test_is_m4_or_newer_consistent_with_get_chip_generation(self):
        gen = neural_engine.get_chip_generation()
        expected_m4 = gen == "M4"
        self.assertEqual(neural_engine.is_m4_or_newer(), expected_m4)

    def test_get_recommended_compute_unit_returns_valid_string(self):
        result = neural_engine.get_recommended_compute_unit()
        self.assertIn(result, ("CPU_AND_NE", "CPU_AND_GPU"))

    def test_get_recommended_compute_unit_cpu_and_ne_on_apple_silicon(self):
        if neural_engine.is_apple_silicon():
            self.assertEqual(neural_engine.get_recommended_compute_unit(), "CPU_AND_NE")

    def test_get_recommended_compute_unit_cpu_and_gpu_on_non_apple_silicon(self):
        if not neural_engine.is_apple_silicon():
            self.assertEqual(neural_engine.get_recommended_compute_unit(), "CPU_AND_GPU")

    def test_get_optimization_hints_returns_dict_or_none(self):
        result = neural_engine.get_optimization_hints()
        self.assertTrue(result is None or isinstance(result, dict))

    def test_get_optimization_hints_none_on_non_apple_silicon(self):
        if not neural_engine.is_apple_silicon():
            self.assertIsNone(neural_engine.get_optimization_hints())

    def test_get_available_compute_units_includes_auto(self):
        from python_coreml_stable_diffusion.coreml_model import get_available_compute_units
        units = get_available_compute_units()
        self.assertIn("AUTO", units, "AUTO must be listed as a valid compute unit option")

    def test_get_available_compute_units_includes_standard_options(self):
        from python_coreml_stable_diffusion.coreml_model import get_available_compute_units
        units = get_available_compute_units()
        for expected in ("ALL", "CPU_AND_NE", "CPU_AND_GPU", "CPU_ONLY"):
            self.assertIn(expected, units, f"{expected} must remain available")


if __name__ == "__main__":
    unittest.main()
