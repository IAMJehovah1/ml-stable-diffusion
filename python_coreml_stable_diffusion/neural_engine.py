#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Utilities for detecting Apple Neural Engine availability and returning
optimized configurations for Apple Silicon devices, particularly the M4.

The public API consists of:
  - :func:`is_apple_silicon` – architecture check
  - :func:`get_chip_generation` – identify M1/M2/M3/M4 at runtime
  - :func:`has_neural_engine` – True on any Apple Silicon device
  - :func:`is_m4_or_newer` – True when the chip is M4 or later
  - :func:`get_recommended_compute_unit` – ``"CPU_AND_NE"`` or ``"CPU_AND_GPU"``
  - :func:`get_optimization_hints` – coremltools optimization hints dict
"""

import logging
import platform
import subprocess
import sys

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# ARM CPU family identifiers taken from Apple's open-source XNU kernel.
# Each constant identifies the high-performance / efficiency core pair used
# by a particular Apple Silicon chip generation.
# ---------------------------------------------------------------------------
_CPUFAMILY_ARM_FIRESTORM_ICESTORM = 0x1B588BB3  # M1 / A14 Bionic
_CPUFAMILY_ARM_BLIZZARD_AVALANCHE = 0xDA33D83D  # M2 / A15–A16 Bionic
_CPUFAMILY_ARM_EVEREST_SAWTOOTH = 0x8765EDEA    # M3 / A17 Pro
_CPUFAMILY_ARM_DONAN_BRAVA = 0xFA33415E         # M4 / A18

_CHIP_GENERATION_MAP = {
    _CPUFAMILY_ARM_FIRESTORM_ICESTORM: "M1",
    _CPUFAMILY_ARM_BLIZZARD_AVALANCHE: "M2",
    _CPUFAMILY_ARM_EVEREST_SAWTOOTH: "M3",
    _CPUFAMILY_ARM_DONAN_BRAVA: "M4",
}


def is_apple_silicon():
    """Return ``True`` if the current process is running on Apple Silicon (arm64)."""
    return sys.platform == "darwin" and platform.machine() == "arm64"


def get_chip_generation():
    """Identify the Apple Silicon chip generation at runtime.

    Queries the ``hw.cpufamily`` sysctl key and maps the result to a
    human-readable generation string.

    Returns:
        ``"M1"``, ``"M2"``, ``"M3"``, or ``"M4"`` when the chip is
        recognised; ``None`` on non-Apple-Silicon hardware or when the
        chip family is unrecognised (e.g. a future generation).
    """
    if not is_apple_silicon():
        return None
    try:
        result = subprocess.run(
            ["sysctl", "-n", "hw.cpufamily"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        # sysctl may return a signed decimal integer; mask to 32-bit unsigned
        # so the value matches the hex constants defined above.
        raw = int(result.stdout.strip())
        family_id = raw & 0xFFFFFFFF
        generation = _CHIP_GENERATION_MAP.get(family_id)
        if generation:
            logger.debug(
                "Detected Apple Silicon chip generation: %s (cpufamily=0x%08X)",
                generation,
                family_id,
            )
        else:
            logger.debug(
                "Unrecognised Apple Silicon cpufamily: 0x%08X", family_id
            )
        return generation
    except Exception as exc:
        logger.debug("Could not determine chip generation: %s", exc)
        return None


def has_neural_engine():
    """Return ``True`` if the device has a Neural Engine.

    All Apple Silicon devices (M1 and later) include a dedicated Neural
    Engine, so this is equivalent to :func:`is_apple_silicon`.
    """
    return is_apple_silicon()


def is_m4_or_newer():
    """Return ``True`` when running on an M4 chip.

    Detection is based on :func:`get_chip_generation`.  Devices with
    unrecognised chip families (future generations) return ``False`` and
    rely on the general :func:`has_neural_engine` path for compute-unit
    selection.
    """
    return get_chip_generation() == "M4"


def get_recommended_compute_unit():
    """Return the coremltools ``ComputeUnit`` name best suited for this device.

    - ``"CPU_AND_NE"`` – Apple Silicon (Neural Engine available)
    - ``"CPU_AND_GPU"`` – all other platforms

    The returned string is directly usable with ``coremltools.ComputeUnit[name]``.
    """
    if has_neural_engine():
        logger.info(
            "Apple Silicon detected: recommending CPU_AND_NE compute unit."
        )
        return "CPU_AND_NE"
    logger.info(
        "No Neural Engine detected: recommending CPU_AND_GPU compute unit."
    )
    return "CPU_AND_GPU"


def get_optimization_hints():
    """Return Core ML optimization hints appropriate for this device.

    On macOS 15 / iOS 18 and later the ``FastPrediction`` specialisation
    strategy directs the Core ML compiler to maximise Neural Engine
    throughput.  On the M4 this is especially beneficial because the NE
    compute budget is roughly double that of M3 (38 TOPS vs 18 TOPS).

    Returns:
        A dict suitable for the ``optimization_hints`` parameter of
        ``coremltools.models.MLModel``, or ``None`` when the hints are not
        applicable (older OS or non-Apple-Silicon hardware).
    """
    if not has_neural_engine():
        return None
    try:
        import coremltools as ct

        mac_ver_str = platform.mac_ver()[0]
        if not mac_ver_str:
            return None
        # Parse only the numeric components so that pre-release suffixes like
        # "15.0-beta" or "15.1.1" are handled gracefully.
        numeric_parts = []
        for part in mac_ver_str.split("."):
            digits = "".join(ch for ch in part if ch.isdigit())
            if digits:
                numeric_parts.append(int(digits))
            else:
                break  # stop at the first non-numeric segment
        mac_ver = tuple(numeric_parts)
        if mac_ver >= (15, 0):
            hints = {
                "specializationStrategy": ct.SpecializationStrategy.FastPrediction
            }
            logger.debug(
                "Applying FastPrediction optimization hints for Neural Engine."
            )
            return hints
    except Exception as exc:
        logger.debug("Could not build optimization hints: %s", exc)
    return None
