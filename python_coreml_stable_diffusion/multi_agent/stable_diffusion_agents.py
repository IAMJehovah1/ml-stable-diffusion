#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Concrete agents specialised for Stable Diffusion pipeline sub-tasks."""

import logging
from typing import Any, Optional, Set

from .agent import Agent
from .communication import MessageBus
from .task import AgentCapability, Task

logger = logging.getLogger(__name__)


class DataPreprocessingAgent(Agent):
    """Agent responsible for preparing datasets for training or inference.

    Capabilities: ``DATA_PREPROCESSING``.
    """

    def __init__(
        self,
        agent_id: str,
        message_bus: Optional[MessageBus] = None,
        leader_id: Optional[str] = None,
    ) -> None:
        super().__init__(
            agent_id=agent_id,
            capabilities={AgentCapability.DATA_PREPROCESSING},
            message_bus=message_bus,
            leader_id=leader_id,
        )

    def execute_task(self, task: Task) -> Any:
        """Simulate data-preprocessing work.

        In a real deployment this method would normalise images, tokenise
        prompts, compute statistics, etc.  Here it validates that the required
        inputs are present in ``task.metadata`` and returns a summary dict.
        """
        self.report_progress(task.task_id, 0.1, "Starting data preprocessing")

        input_path = task.metadata.get("input_path", "<unspecified>")
        output_path = task.metadata.get("output_path", "<unspecified>")

        self.report_progress(task.task_id, 0.5, "Processing inputs")
        logger.info(
            "DataPreprocessingAgent '%s': preprocessing '%s' → '%s'",
            self.agent_id,
            input_path,
            output_path,
        )

        self.report_progress(task.task_id, 1.0, "Data preprocessing complete")
        return {
            "agent_id": self.agent_id,
            "input_path": input_path,
            "output_path": output_path,
            "status": "preprocessed",
        }


class ModelFineTuningAgent(Agent):
    """Agent responsible for fine-tuning a Stable Diffusion model.

    Capabilities: ``MODEL_FINETUNING``.
    """

    def __init__(
        self,
        agent_id: str,
        message_bus: Optional[MessageBus] = None,
        leader_id: Optional[str] = None,
    ) -> None:
        super().__init__(
            agent_id=agent_id,
            capabilities={AgentCapability.MODEL_FINETUNING},
            message_bus=message_bus,
            leader_id=leader_id,
        )

    def execute_task(self, task: Task) -> Any:
        """Simulate model fine-tuning.

        Real implementations would invoke training loops.  This stub logs the
        configuration and reports synthetic progress.
        """
        self.report_progress(task.task_id, 0.1, "Initialising fine-tuning")

        model_version = task.metadata.get("model_version", "<unspecified>")
        epochs = task.metadata.get("epochs", 1)

        self.report_progress(task.task_id, 0.5, f"Training epoch 1/{epochs}")
        logger.info(
            "ModelFineTuningAgent '%s': fine-tuning '%s' for %d epoch(s)",
            self.agent_id,
            model_version,
            epochs,
        )

        self.report_progress(task.task_id, 1.0, "Fine-tuning complete")
        return {
            "agent_id": self.agent_id,
            "model_version": model_version,
            "epochs_completed": epochs,
            "status": "fine-tuned",
        }


class ImageGenerationAgent(Agent):
    """Agent responsible for generating images with a Stable Diffusion model.

    Capabilities: ``IMAGE_GENERATION``.
    """

    def __init__(
        self,
        agent_id: str,
        message_bus: Optional[MessageBus] = None,
        leader_id: Optional[str] = None,
    ) -> None:
        super().__init__(
            agent_id=agent_id,
            capabilities={AgentCapability.IMAGE_GENERATION},
            message_bus=message_bus,
            leader_id=leader_id,
        )

    def execute_task(self, task: Task) -> Any:
        """Simulate image generation.

        A production version would invoke the Core ML pipeline.  This stub
        returns metadata describing what would have been produced.
        """
        self.report_progress(task.task_id, 0.1, "Loading model")

        prompt = task.metadata.get("prompt", "")
        seed = task.metadata.get("seed", 0)
        output_path = task.metadata.get("output_path", "<unspecified>")

        self.report_progress(task.task_id, 0.6, "Running diffusion steps")
        logger.info(
            "ImageGenerationAgent '%s': generating image for prompt='%s' seed=%d",
            self.agent_id,
            prompt,
            seed,
        )

        self.report_progress(task.task_id, 1.0, "Image generation complete")
        return {
            "agent_id": self.agent_id,
            "prompt": prompt,
            "seed": seed,
            "output_path": output_path,
            "status": "generated",
        }


class QualityEvaluationAgent(Agent):
    """Agent responsible for evaluating the quality of generated images.

    Capabilities: ``QUALITY_EVALUATION``.
    """

    def __init__(
        self,
        agent_id: str,
        message_bus: Optional[MessageBus] = None,
        leader_id: Optional[str] = None,
    ) -> None:
        super().__init__(
            agent_id=agent_id,
            capabilities={AgentCapability.QUALITY_EVALUATION},
            message_bus=message_bus,
            leader_id=leader_id,
        )

    def execute_task(self, task: Task) -> Any:
        """Simulate quality evaluation.

        A production version would compute PSNR / CLIP scores.  This stub
        returns synthetic metrics.
        """
        self.report_progress(task.task_id, 0.1, "Loading evaluation model")

        image_path = task.metadata.get("image_path", "<unspecified>")
        reference_prompt = task.metadata.get("reference_prompt", "")

        self.report_progress(task.task_id, 0.7, "Computing metrics")
        logger.info(
            "QualityEvaluationAgent '%s': evaluating '%s'",
            self.agent_id,
            image_path,
        )

        self.report_progress(task.task_id, 1.0, "Evaluation complete")
        return {
            "agent_id": self.agent_id,
            "image_path": image_path,
            "reference_prompt": reference_prompt,
            "psnr_db": None,       # populated by real implementation
            "clip_score": None,    # populated by real implementation
            "status": "evaluated",
        }
