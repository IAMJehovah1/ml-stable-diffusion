#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Leader agent responsible for task coordination and result compilation."""

import logging
from typing import Any, Dict, List, Optional

from .agent import Agent
from .communication import Message, MessageBus, MessageType
from .task import AgentCapability, Task, TaskStatus

logger = logging.getLogger(__name__)


class LeaderAgent(Agent):
    """Oversees task allocation, progress monitoring, and result compilation.

    The leader can:

    * **decompose** a high-level description into typed sub-tasks,
    * **assign** sub-tasks to the best available subordinate agent,
    * **monitor** progress via the message bus,
    * **resolve conflicts** when multiple agents compete for the same resource,
    * **compile results** from all completed sub-tasks into a final report.

    A :class:`LeaderAgent` may itself be a subordinate of another leader,
    enabling hierarchical / multi-leader setups.

    Args:
        agent_id: Unique identifier for this leader.
        message_bus: Shared :class:`~communication.MessageBus`.
        leader_id: Parent leader's ID for hierarchical mode, or ``None``.
    """

    def __init__(
        self,
        agent_id: str,
        message_bus: Optional[MessageBus] = None,
        leader_id: Optional[str] = None,
    ) -> None:
        super().__init__(
            agent_id=agent_id,
            capabilities={AgentCapability.GENERAL},
            message_bus=message_bus,
            leader_id=leader_id,
        )
        self._subordinates: Dict[str, Agent] = {}
        self._task_queue: List[Task] = []
        self._completed_tasks: List[Task] = []
        self._failed_tasks: List[Task] = []

    # ------------------------------------------------------------------
    # Subordinate management
    # ------------------------------------------------------------------

    def register_agent(self, agent: Agent) -> None:
        """Add *agent* to this leader's pool of subordinates.

        The agent's ``leader_id`` is updated to point to this leader so that
        result/progress messages are routed correctly.
        """
        agent.leader_id = self.agent_id
        agent.message_bus = self.message_bus
        # Re-register the agent's handler on the (potentially new) bus.
        self.message_bus.register(agent.agent_id, agent._handle_message)
        self._subordinates[agent.agent_id] = agent
        logger.info(
            "Leader '%s': registered subordinate '%s' with capabilities %s",
            self.agent_id,
            agent.agent_id,
            [c.name for c in agent.capabilities],
        )

    def unregister_agent(self, agent_id: str) -> None:
        """Remove *agent_id* from the subordinate pool."""
        self._subordinates.pop(agent_id, None)

    # ------------------------------------------------------------------
    # Task lifecycle
    # ------------------------------------------------------------------

    def decompose_task(
        self,
        description: str,
        subtask_specs: List[Dict[str, Any]],
    ) -> List[Task]:
        """Break a high-level *description* into typed sub-tasks.

        Args:
            description: Human-readable description of the overall goal.
            subtask_specs: Sequence of dicts with keys:

                * ``"description"`` (str) – sub-task description,
                * ``"capability"`` (:class:`~task.AgentCapability`) –
                  required capability,
                * ``"metadata"`` (dict, optional) – extra context.

        Returns:
            List of :class:`~task.Task` objects added to the internal queue.

        Example::

            tasks = leader.decompose_task(
                "Generate image",
                [
                    {"description": "Preprocess data",
                     "capability": AgentCapability.DATA_PREPROCESSING},
                    {"description": "Generate image",
                     "capability": AgentCapability.IMAGE_GENERATION},
                ],
            )
        """
        tasks: List[Task] = []
        for spec in subtask_specs:
            task = Task(
                description=spec["description"],
                required_capability=spec.get(
                    "capability", AgentCapability.GENERAL),
                metadata=spec.get("metadata", {}),
            )
            self._task_queue.append(task)
            tasks.append(task)
            logger.debug(
                "Leader '%s': queued sub-task '%s' (%s)",
                self.agent_id,
                task.task_id,
                task.required_capability.name,
            )

        logger.info(
            "Leader '%s': decomposed '%s' into %d sub-tasks",
            self.agent_id,
            description,
            len(tasks),
        )
        return tasks

    def assign_tasks(self) -> int:
        """Assign all PENDING queued tasks to available subordinates.

        Assignment is greedy: the agent with the **lowest current workload**
        that satisfies the required capability is chosen.

        Returns:
            The number of tasks successfully assigned.
        """
        assigned = 0
        unassigned: List[Task] = []

        for task in self._task_queue:
            if task.status != TaskStatus.PENDING:
                continue
            agent = self._select_agent(task)
            if agent:
                self._assign_to_agent(task, agent)
                assigned += 1
            else:
                unassigned.append(task)
                logger.warning(
                    "Leader '%s': no available agent for task '%s' (requires %s)",
                    self.agent_id,
                    task.task_id,
                    task.required_capability.name,
                )

        # Keep only unassigned tasks in the queue.
        self._task_queue = unassigned
        return assigned

    def monitor_progress(self) -> Dict[str, Any]:
        """Return a snapshot of the overall task-execution status."""
        all_tasks = (
            self._task_queue
            + self._completed_tasks
            + self._failed_tasks
            + [
                t for agent in self._subordinates.values()
                for t in agent._current_tasks.values()
                if not t.is_done()
            ]
        )
        status_counts: Dict[str, int] = {s.name: 0 for s in TaskStatus}
        for task in all_tasks:
            status_counts[task.status.name] += 1

        return {
            "leader_id": self.agent_id,
            "subordinate_count": len(self._subordinates),
            "task_status": status_counts,
            "completed_count": len(self._completed_tasks),
            "failed_count": len(self._failed_tasks),
        }

    def resolve_conflict(self, agent_ids: List[str],
                         resource: str) -> Optional[str]:
        """Resolve a resource conflict by selecting the least-loaded agent.

        Args:
            agent_ids: IDs of agents competing for *resource*.
            resource: A human-readable name for the contested resource.

        Returns:
            The ID of the agent granted access, or ``None`` if no eligible
            agent is found.
        """
        candidates = [
            self._subordinates[aid]
            for aid in agent_ids
            if aid in self._subordinates
        ]
        if not candidates:
            logger.warning(
                "Leader '%s': conflict for '%s' – no known agents",
                self.agent_id,
                resource,
            )
            return None

        winner = min(candidates, key=lambda a: a.workload)
        logger.info(
            "Leader '%s': resolved conflict for '%s' → granted to '%s'",
            self.agent_id,
            resource,
            winner.agent_id,
        )

        # Notify all parties.
        for agent in candidates:
            self.message_bus.dispatch(
                Message(
                    sender_id=self.agent_id,
                    recipient_id=agent.agent_id,
                    message_type=MessageType.CONFLICT_ALERT,
                    payload={
                        "resource": resource,
                        "granted_to": winner.agent_id,
                    },
                )
            )
        return winner.agent_id

    def compile_results(self) -> Dict[str, Any]:
        """Collect results from all completed sub-tasks.

        Returns:
            A report dict with ``"leader_id"``, ``"completed_tasks"`` (list),
            ``"failed_tasks"`` (list), and ``"lessons_learned"`` aggregated
            from every subordinate agent.
        """
        completed = [
            {
                "task_id": t.task_id,
                "description": t.description,
                "result": t.result,
                "assigned_to": t.assigned_to,
            }
            for t in self._completed_tasks
        ]
        failed = [
            {
                "task_id": t.task_id,
                "description": t.description,
                "error": t.error,
                "assigned_to": t.assigned_to,
            }
            for t in self._failed_tasks
        ]
        all_lessons = [
            lesson
            for agent in self._subordinates.values()
            for lesson in agent.lessons_learned
        ]

        report = {
            "leader_id": self.agent_id,
            "completed_tasks": completed,
            "failed_tasks": failed,
            "lessons_learned": all_lessons,
        }
        logger.info(
            "Leader '%s': compiled results – %d completed, %d failed",
            self.agent_id,
            len(completed),
            len(failed),
        )
        return report

    # ------------------------------------------------------------------
    # Agent (abstract) implementation
    # ------------------------------------------------------------------

    def execute_task(self, task: Task) -> Any:
        """Leaders orchestrate rather than execute domain tasks directly.

        When called (e.g. as a subordinate of a higher-level leader) the
        leader decomposes the task, assigns sub-tasks, and compiles results.
        """
        raise NotImplementedError(
            "LeaderAgent.execute_task is not meant to be called directly. "
            "Use decompose_task() → assign_tasks() → compile_results()."
        )

    # ------------------------------------------------------------------
    # Message handling
    # ------------------------------------------------------------------

    def receive_update(self, message: Message) -> None:
        """Process incoming messages from subordinates."""
        super().receive_update(message)

        if message.message_type == MessageType.TASK_RESULT:
            self._on_task_result(message)
        elif message.message_type == MessageType.TASK_FAILURE:
            self._on_task_failure(message)
        elif message.message_type == MessageType.PROGRESS_REPORT:
            payload = message.payload or {}
            logger.info(
                "Leader '%s': progress from '%s' – task=%s %.0f%% %s",
                self.agent_id,
                message.sender_id,
                payload.get("task_id", "?"),
                payload.get("progress", 0) * 100,
                payload.get("message", ""),
            )

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _select_agent(self, task: Task) -> Optional[Agent]:
        """Return the least-loaded capable agent, or ``None``."""
        capable = [
            a for a in self._subordinates.values() if a.can_handle(task)
        ]
        if not capable:
            return None
        return min(capable, key=lambda a: a.workload)

    def _assign_to_agent(self, task: Task, agent: Agent) -> None:
        """Dispatch *task* to *agent* and send an assignment message."""
        self.message_bus.dispatch(
            Message(
                sender_id=self.agent_id,
                recipient_id=agent.agent_id,
                message_type=MessageType.TASK_ASSIGNMENT,
                payload={"task_id": task.task_id,
                         "description": task.description},
            )
        )
        agent.receive_task(task)

    def _on_task_result(self, message: Message) -> None:
        payload = message.payload or {}
        task_id = payload.get("task_id")
        # Find the task in any subordinate's current-task dict.
        task = self._find_task(task_id)
        if task and task not in self._completed_tasks:
            self._completed_tasks.append(task)
            logger.info(
                "Leader '%s': task '%s' completed by '%s'",
                self.agent_id,
                task_id,
                message.sender_id,
            )

    def _on_task_failure(self, message: Message) -> None:
        payload = message.payload or {}
        task_id = payload.get("task_id")
        task = self._find_task(task_id)
        if task and task not in self._failed_tasks:
            self._failed_tasks.append(task)
            logger.warning(
                "Leader '%s': task '%s' failed – %s",
                self.agent_id,
                task_id,
                payload.get("error", "unknown error"),
            )

    def _find_task(self, task_id: Optional[str]) -> Optional[Task]:
        if task_id is None:
            return None
        for agent in self._subordinates.values():
            task = agent._current_tasks.get(task_id)
            if task:
                return task
        return None