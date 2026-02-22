#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Task definitions for the multi-agent coordination system."""

import uuid
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Any, Optional


class TaskStatus(Enum):
    """Lifecycle states of a task."""
    PENDING = auto()
    IN_PROGRESS = auto()
    COMPLETED = auto()
    FAILED = auto()


class AgentCapability(Enum):
    """Capabilities that an agent may possess."""
    DATA_PREPROCESSING = auto()
    MODEL_FINETUNING = auto()
    IMAGE_GENERATION = auto()
    QUALITY_EVALUATION = auto()
    GENERAL = auto()


@dataclass
class Task:
    """Represents a unit of work to be executed by an agent.

    Attributes:
        description: Human-readable description of the work.
        required_capability: The capability an agent must have to handle this task.
        task_id: Unique identifier, auto-generated if not provided.
        status: Current lifecycle state.
        assigned_to: ID of the agent the task is assigned to, or ``None``.
        result: Output produced upon completion.
        error: Error message if the task failed.
        metadata: Arbitrary extra context (e.g. hyperparameters, file paths).
    """
    description: str
    required_capability: AgentCapability = AgentCapability.GENERAL
    task_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    status: TaskStatus = field(default=TaskStatus.PENDING)
    assigned_to: Optional[str] = None
    result: Any = None
    error: Optional[str] = None
    metadata: dict = field(default_factory=dict)

    def mark_in_progress(self, agent_id: str) -> None:
        """Transition task to IN_PROGRESS and record the assigned agent."""
        self.status = TaskStatus.IN_PROGRESS
        self.assigned_to = agent_id

    def mark_completed(self, result: Any = None) -> None:
        """Transition task to COMPLETED and store the result."""
        self.status = TaskStatus.COMPLETED
        self.result = result

    def mark_failed(self, error: str) -> None:
        """Transition task to FAILED and store the error message."""
        self.status = TaskStatus.FAILED
        self.error = error

    def is_done(self) -> bool:
        """Return ``True`` if the task has reached a terminal state."""
        return self.status in (TaskStatus.COMPLETED, TaskStatus.FAILED)
