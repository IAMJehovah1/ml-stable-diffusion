#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Base Agent class for the multi-agent coordination system."""

import logging
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional, Set

from .communication import Message, MessageBus, MessageType
from .task import AgentCapability, Task, TaskStatus

logger = logging.getLogger(__name__)


class Agent(ABC):
    """Abstract base class for all agents in the coordination system.

    Subclasses must implement :meth:`execute_task` to perform actual work.

    Attributes:
        agent_id: Unique identifier for this agent.
        capabilities: Set of :class:`~task.AgentCapability` values this agent
            supports.
        message_bus: Shared :class:`~communication.MessageBus` used to
            exchange messages with other agents and the leader.
        leader_id: ID of this agent's leader, or ``None`` for leader agents.
        lessons_learned: Accumulated insights from completed tasks that can
            inform future execution (feedback loop).
    """

    def __init__(
        self,
        agent_id: str,
        capabilities: Optional[Set[AgentCapability]] = None,
        message_bus: Optional[MessageBus] = None,
        leader_id: Optional[str] = None,
    ) -> None:
        self.agent_id = agent_id
        self.capabilities: Set[AgentCapability] = (
            capabilities if capabilities is not None
            else {AgentCapability.GENERAL}
        )
        self.message_bus = message_bus or MessageBus()
        self.leader_id = leader_id
        self.lessons_learned: List[Dict[str, Any]] = []
        self._current_tasks: Dict[str, Task] = {}

        # Register this agent's message handler on the shared bus.
        self.message_bus.register(self.agent_id, self._handle_message)

    # ------------------------------------------------------------------
    # Public interface
    # ------------------------------------------------------------------

    @property
    def workload(self) -> int:
        """Number of tasks currently in progress."""
        return sum(
            1 for t in self._current_tasks.values()
            if t.status == TaskStatus.IN_PROGRESS
        )

    def can_handle(self, task: Task) -> bool:
        """Return ``True`` if this agent has the capability for *task*."""
        return (
            task.required_capability == AgentCapability.GENERAL
            or task.required_capability in self.capabilities
        )

    def receive_task(self, task: Task) -> None:
        """Accept *task*, execute it, and report the outcome to the leader."""
        if not self.can_handle(task):
            logger.warning(
                "Agent '%s' cannot handle task '%s' (requires %s)",
                self.agent_id,
                task.task_id,
                task.required_capability,
            )
            return

        task.mark_in_progress(self.agent_id)
        self._current_tasks[task.task_id] = task
        logger.info(
            "Agent '%s' started task '%s'", self.agent_id, task.task_id
        )

        try:
            result = self.execute_task(task)
            task.mark_completed(result)
            self._record_lesson(task, success=True)
            self._notify_result(task)
        except Exception as exc:
            error_msg = str(exc)
            task.mark_failed(error_msg)
            self._record_lesson(task, success=False, error=error_msg)
            self._notify_failure(task)
            logger.error(
                "Agent '%s' failed task '%s': %s",
                self.agent_id,
                task.task_id,
                error_msg,
            )

    @abstractmethod
    def execute_task(self, task: Task) -> Any:
        """Carry out the work described by *task* and return the result.

        Subclasses must override this method with their domain-specific logic.
        Raising any exception will cause the task to be marked as FAILED.
        """

    def report_progress(self, task_id: str, progress: float,
                        message: str = "") -> None:
        """Send a progress update to the leader (0.0 – 1.0 scale)."""
        if self.leader_id is None:
            return
        self.message_bus.dispatch(
            Message(
                sender_id=self.agent_id,
                recipient_id=self.leader_id,
                message_type=MessageType.PROGRESS_REPORT,
                payload={
                    "task_id": task_id,
                    "progress": progress,
                    "message": message,
                },
            )
        )

    def receive_update(self, message: Message) -> None:
        """Handle an incoming :class:`~communication.Message`.

        Override in subclasses to react to specific message types beyond the
        default logging behaviour.
        """
        logger.debug(
            "Agent '%s' received %s from '%s'",
            self.agent_id,
            message.message_type.name,
            message.sender_id,
        )

    def get_capabilities_metadata(self) -> Dict[str, Any]:
        """Return a dictionary describing this agent's capabilities."""
        return {
            "agent_id": self.agent_id,
            "capabilities": [c.name for c in self.capabilities],
            "workload": self.workload,
            "lessons_learned_count": len(self.lessons_learned),
        }

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _handle_message(self, message: Message) -> None:
        self.receive_update(message)

    def _notify_result(self, task: Task) -> None:
        if self.leader_id is None:
            return
        self.message_bus.dispatch(
            Message(
                sender_id=self.agent_id,
                recipient_id=self.leader_id,
                message_type=MessageType.TASK_RESULT,
                payload={"task_id": task.task_id, "result": task.result},
            )
        )

    def _notify_failure(self, task: Task) -> None:
        if self.leader_id is None:
            return
        self.message_bus.dispatch(
            Message(
                sender_id=self.agent_id,
                recipient_id=self.leader_id,
                message_type=MessageType.TASK_FAILURE,
                payload={"task_id": task.task_id, "error": task.error},
            )
        )

    def _record_lesson(self, task: Task, *, success: bool,
                       error: Optional[str] = None) -> None:
        """Append a lesson-learned entry and broadcast it to peers."""
        lesson: Dict[str, Any] = {
            "task_id": task.task_id,
            "description": task.description,
            "capability": task.required_capability.name,
            "success": success,
        }
        if error:
            lesson["error"] = error
        if task.result is not None:
            lesson["result_summary"] = str(task.result)[:200]

        self.lessons_learned.append(lesson)

        self.message_bus.dispatch(
            Message(
                sender_id=self.agent_id,
                recipient_id="broadcast",
                message_type=MessageType.LESSON_LEARNED,
                payload=lesson,
            )
        )
