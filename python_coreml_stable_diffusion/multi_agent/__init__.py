#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Multi-agent task coordination system for ml-stable-diffusion.

Public API
----------
Core abstractions::

    from python_coreml_stable_diffusion.multi_agent import (
        Task, TaskStatus, AgentCapability,
        Message, MessageBus, MessageType,
        Agent,
        LeaderAgent,
        MultiAgentCoordinator,
    )

Stable-Diffusion-specific agents::

    from python_coreml_stable_diffusion.multi_agent import (
        DataPreprocessingAgent,
        ModelFineTuningAgent,
        ImageGenerationAgent,
        QualityEvaluationAgent,
    )

Quick-start example::

    coordinator = MultiAgentCoordinator("sd-coordinator")
    leader = coordinator.add_leader("main-leader")
    coordinator.add_agent(DataPreprocessingAgent("prep-1"), "main-leader")
    coordinator.add_agent(ImageGenerationAgent("gen-1"), "main-leader")
    coordinator.add_agent(QualityEvaluationAgent("eval-1"), "main-leader")

    tasks = coordinator.run_workflow(
        "Stable Diffusion image generation",
        [
            {"description": "Preprocess training data",
             "capability": AgentCapability.DATA_PREPROCESSING,
             "metadata": {"input_path": "/data/raw", "output_path": "/data/processed"}},
            {"description": "Generate image from prompt",
             "capability": AgentCapability.IMAGE_GENERATION,
             "metadata": {"prompt": "astronaut riding a horse", "seed": 42,
                          "output_path": "/output/image.png"}},
            {"description": "Evaluate generated image quality",
             "capability": AgentCapability.QUALITY_EVALUATION,
             "metadata": {"image_path": "/output/image.png",
                          "reference_prompt": "astronaut riding a horse"}},
        ],
    )

    report = coordinator.compile_all_results()
"""

from .agent import Agent
from .communication import Message, MessageBus, MessageType
from .coordinator import MultiAgentCoordinator
from .leader import LeaderAgent
from .stable_diffusion_agents import (
    DataPreprocessingAgent,
    ImageGenerationAgent,
    ModelFineTuningAgent,
    QualityEvaluationAgent,
)
from .task import AgentCapability, Task, TaskStatus

__all__ = [
    # Task primitives
    "Task",
    "TaskStatus",
    "AgentCapability",
    # Communication
    "Message",
    "MessageBus",
    "MessageType",
    # Agents
    "Agent",
    "LeaderAgent",
    # Coordinator
    "MultiAgentCoordinator",
    # SD-specific agents
    "DataPreprocessingAgent",
    "ModelFineTuningAgent",
    "ImageGenerationAgent",
    "QualityEvaluationAgent",
]