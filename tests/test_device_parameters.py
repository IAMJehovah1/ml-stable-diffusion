#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""
Unit tests for device parameter handling and causal attention mask generation.

These tests verify:
1. patched_make_causal_mask produces masks with values clamped to -1e4 on CPU.
2. The output tensor device matches the requested device (CPU).
3. The causal structure of the mask is correct (upper-triangle is masked).
4. patched_create_causal_mask (transformers >= 5.x) clamps extreme negative values.
5. Backward-compatible patching applies only when the target attributes exist.
"""

import unittest
import torch


def patched_make_causal_mask(input_ids_shape, dtype, device, past_key_values_length: int = 0):
    """Mirror of the implementation in torch2coreml.patched_make_causal_mask.

    Defined here rather than imported from torch2coreml to avoid the heavy
    coremltools/diffusers/diffusionkit transitive imports that torch2coreml
    requires.  When the production implementation in torch2coreml.py changes,
    this mirror must be updated to match.

    Uses a scalar fill value to avoid device placement issues (e.g., on MPS devices)
    that can arise when constructing fill-value tensors explicitly.
    """
    bsz, tgt_len = input_ids_shape
    mask = torch.full((tgt_len, tgt_len), -1e4, dtype=dtype, device=device)
    mask_cond = torch.arange(mask.size(-1), device=device)
    mask.masked_fill_(mask_cond < (mask_cond + 1).view(mask.size(-1), 1), 0)

    if past_key_values_length > 0:
        mask = torch.cat([torch.zeros(tgt_len, past_key_values_length, dtype=dtype, device=device), mask], dim=-1)
    return mask[None, None, :, :].expand(bsz, 1, tgt_len, tgt_len + past_key_values_length)


class TestPatchedMakeCausalMask(unittest.TestCase):
    """Tests for patched_make_causal_mask used in transformers < 5.0.0."""

    def _make_mask(self, bsz=1, tgt_len=4, dtype=torch.float32,
                   device="cpu", past_key_values_length=0):
        return patched_make_causal_mask(
            (bsz, tgt_len), dtype, device,
            past_key_values_length=past_key_values_length,
        )

    def test_output_device_matches_requested_cpu(self):
        """Mask tensors must reside on the device that was requested."""
        mask = self._make_mask(device="cpu")
        self.assertEqual(mask.device.type, "cpu")

    def test_no_values_below_neg_1e4(self):
        """All mask values must be >= -1e4 (Core ML compatibility requirement)."""
        mask = self._make_mask()
        self.assertTrue(
            (mask >= -1e4).all(),
            "Mask contains values below -1e4, which may cause Core ML inference issues.",
        )

    def test_causal_structure_float32(self):
        """Attended positions are 0; masked (future) positions are -1e4."""
        tgt_len = 5
        mask = self._make_mask(bsz=1, tgt_len=tgt_len)
        # mask shape: (1, 1, tgt_len, tgt_len)
        mask_2d = mask[0, 0]  # (tgt_len, tgt_len)

        for i in range(tgt_len):
            for j in range(tgt_len):
                if j <= i:
                    # Past / current positions should not be masked (value == 0)
                    self.assertEqual(
                        mask_2d[i, j].item(), 0.0,
                        f"Expected 0 at ({i},{j}), got {mask_2d[i,j].item()}"
                    )
                else:
                    # Future positions should be masked (value == -1e4)
                    self.assertAlmostEqual(
                        mask_2d[i, j].item(), -1e4,
                        msg=f"Expected -1e4 at ({i},{j}), got {mask_2d[i,j].item()}"
                    )

    def test_dtype_preserved(self):
        """Output dtype must match the requested dtype."""
        for dtype in (torch.float32, torch.float16):
            mask = self._make_mask(dtype=dtype)
            self.assertEqual(mask.dtype, dtype)

    def test_shape_without_past_key_values(self):
        """Output shape must be (bsz, 1, tgt_len, tgt_len) when no past KV."""
        bsz, tgt_len = 2, 6
        mask = self._make_mask(bsz=bsz, tgt_len=tgt_len)
        self.assertEqual(list(mask.shape), [bsz, 1, tgt_len, tgt_len])

    def test_shape_with_past_key_values(self):
        """With past_key_values_length, last dim = tgt_len + past_key_values_length."""
        bsz, tgt_len, past = 2, 4, 3
        mask = self._make_mask(bsz=bsz, tgt_len=tgt_len, past_key_values_length=past)
        self.assertEqual(list(mask.shape), [bsz, 1, tgt_len, tgt_len + past])

    def test_past_key_values_prefix_is_zero(self):
        """Past token columns should be fully visible (value == 0)."""
        tgt_len, past = 3, 2
        mask = self._make_mask(tgt_len=tgt_len, past_key_values_length=past)
        mask_2d = mask[0, 0]  # (tgt_len, tgt_len + past)
        # All columns 0..past-1 must be 0 (past tokens are always visible)
        prefix = mask_2d[:, :past]
        self.assertTrue(
            (prefix == 0).all(),
            "Past-token columns must be fully visible (zero mask value).",
        )


class TestPatchedCreateCausalMask(unittest.TestCase):
    """Tests for patched_create_causal_mask used in transformers >= 5.0.0."""

    def _apply_patch_and_get_fn(self):
        """Apply the same patching logic as torch2coreml.py to modeling_clip
        and return the installed function.

        The patching logic is reproduced here (rather than imported from
        torch2coreml) to avoid the coremltools/diffusers/diffusionkit imports
        that torch2coreml requires at module level.
        """
        from transformers.models.clip import modeling_clip
        if not hasattr(modeling_clip, 'create_causal_mask'):
            return None

        _original = modeling_clip.create_causal_mask

        def patched_create_causal_mask(config, inputs_embeds, attention_mask,
                                       cache_position, past_key_values, **kwargs):
            mask = _original(config, inputs_embeds, attention_mask,
                             cache_position, past_key_values, **kwargs)
            if mask is not None and isinstance(mask, torch.Tensor):
                mask = mask.clamp(min=-1e4)
            return mask

        modeling_clip.create_causal_mask = patched_create_causal_mask
        return patched_create_causal_mask

    def test_patch_is_applied(self):
        """After calling _apply_patch_and_get_fn(), create_causal_mask is the patched version."""
        from transformers.models.clip import modeling_clip
        if not hasattr(modeling_clip, 'create_causal_mask'):
            self.skipTest("create_causal_mask not present in this transformers version")

        patched_fn = self._apply_patch_and_get_fn()
        self.assertIs(modeling_clip.create_causal_mask, patched_fn)

    def test_clamping_removes_extreme_values(self):
        """The wrapper must clamp extremely negative values to -1e4."""
        from transformers.models.clip import modeling_clip
        if not hasattr(modeling_clip, 'create_causal_mask'):
            self.skipTest("create_causal_mask not present in this transformers version")

        self._apply_patch_and_get_fn()

        from transformers import CLIPTextConfig
        config = CLIPTextConfig()
        seq_len = 8
        inputs_embeds = torch.zeros(1, seq_len, config.hidden_size)
        cache_position = torch.arange(seq_len)

        mask = modeling_clip.create_causal_mask(
            config=config,
            inputs_embeds=inputs_embeds,
            attention_mask=None,
            cache_position=cache_position,
            past_key_values=None,
        )

        if mask is not None and isinstance(mask, torch.Tensor):
            self.assertTrue(
                (mask >= -1e4).all(),
                f"patched_create_causal_mask must clamp all values to >= -1e4, "
                f"but found min={mask.min().item()}",
            )

    def test_causal_structure_preserved(self):
        """The causal masking semantics (future tokens masked) must be preserved."""
        from transformers.models.clip import modeling_clip
        if not hasattr(modeling_clip, 'create_causal_mask'):
            self.skipTest("create_causal_mask not present in this transformers version")

        self._apply_patch_and_get_fn()

        from transformers import CLIPTextConfig
        config = CLIPTextConfig()
        seq_len = 6
        inputs_embeds = torch.zeros(1, seq_len, config.hidden_size)
        cache_position = torch.arange(seq_len)

        mask = modeling_clip.create_causal_mask(
            config=config,
            inputs_embeds=inputs_embeds,
            attention_mask=None,
            cache_position=cache_position,
            past_key_values=None,
        )

        if mask is None or not isinstance(mask, torch.Tensor):
            return  # Non-tensor masks are out of scope for this test

        # mask shape is (bsz, heads, tgt_len, src_len) or (bsz, 1, tgt_len, tgt_len)
        mask_2d = mask[0, 0]  # (tgt_len, src_len)
        rows, cols = mask_2d.shape
        for i in range(rows):
            for j in range(cols):
                if j <= i:
                    self.assertEqual(
                        mask_2d[i, j].item(), 0.0,
                        f"Present/past position ({i},{j}) should not be masked"
                    )
                else:
                    self.assertLessEqual(
                        mask_2d[i, j].item(), 0.0,
                        f"Future position ({i},{j}) should have a negative mask value"
                    )


class TestBackwardCompatiblePatching(unittest.TestCase):
    """Tests that patching is applied only for attributes that exist."""

    def test_old_function_names_not_injected_if_absent(self):
        """We must not inject _make_causal_mask / _create_4d_causal_attention_mask
        as fresh attributes when they don't exist in this transformers version."""
        from transformers.models.clip import modeling_clip
        import transformers

        major_version = int(transformers.__version__.split('.')[0])

        if major_version >= 5:
            self.assertFalse(
                hasattr(modeling_clip, '_make_causal_mask'),
                "_make_causal_mask should NOT be present in transformers >= 5.x",
            )
            self.assertFalse(
                hasattr(modeling_clip, '_create_4d_causal_attention_mask'),
                "_create_4d_causal_attention_mask should NOT be present in transformers >= 5.x",
            )

    def test_patching_logic_without_old_attrs(self):
        """Verify that patching logic respects hasattr guards."""
        import types
        # Simulate a module that only has create_causal_mask (like transformers >= 5.x)
        mock_module = types.ModuleType('mock_modeling_clip')
        original_fn_called = [False]

        def original_create_causal_mask(config, inputs_embeds, attention_mask,
                                        cache_position, past_key_values, **kwargs):
            original_fn_called[0] = True
            # Return a mask with extremely negative values to simulate default behavior
            return torch.full((1, 1, 4, 4), torch.finfo(torch.float32).min)

        mock_module.create_causal_mask = original_create_causal_mask

        # Apply the patch as torch2coreml would do it
        if hasattr(mock_module, '_make_causal_mask'):
            mock_module._make_causal_mask = patched_make_causal_mask

        if hasattr(mock_module, '_create_4d_causal_attention_mask'):
            mock_module._create_4d_causal_attention_mask = patched_make_causal_mask

        if hasattr(mock_module, 'create_causal_mask'):
            _orig = mock_module.create_causal_mask

            def patched(config, inputs_embeds, attention_mask, cache_position,
                        past_key_values, **kwargs):
                m = _orig(config, inputs_embeds, attention_mask, cache_position,
                           past_key_values, **kwargs)
                if m is not None and isinstance(m, torch.Tensor):
                    m = m.clamp(min=-1e4)
                return m

            mock_module.create_causal_mask = patched

        # Old names must not have been added
        self.assertFalse(hasattr(mock_module, '_make_causal_mask'))
        self.assertFalse(hasattr(mock_module, '_create_4d_causal_attention_mask'))
        # New patched function must be installed
        self.assertTrue(hasattr(mock_module, 'create_causal_mask'))
        self.assertIsNot(mock_module.create_causal_mask, original_create_causal_mask)

        # Calling it should clamp extreme values
        result = mock_module.create_causal_mask(None, None, None, None, None)
        self.assertIsNotNone(result)
        self.assertTrue(isinstance(result, torch.Tensor))
        self.assertTrue((result >= -1e4).all(),
                        f"Clamping failed; min={result.min().item()}")
        self.assertTrue(original_fn_called[0], "Original function was not called")


if __name__ == "__main__":
    unittest.main()
