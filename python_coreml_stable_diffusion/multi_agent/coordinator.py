#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Top-level coordinator for multi-leader agent systems."""

import logging
from typing import Any, Dict, List, Optional

from .agent import Agent
from .communication import MessageBus
from .leader import LeaderAgent
from .task import AgentCapability, Task

logger = logging.getLogger(__name__)


class MultiAgentCoordinator:
    """Manages a fleet of :class:`~leader.LeaderAgent` instances.

    The coordinator is the entry-point for large projects where a single
    leader is insufficient.  It:

    * maintains a shared :class:`~communication.MessageBus` so every agent in
      the system can communicate,
    * routes agents to leaders based on capability requirements,
    * supports **role delegation** – a leader can promote a capable subordinate
      into a new leader role.

    Args:
        coordinator_id: Human-readable name for this coordinator instance.

    Example::

        coordinator = MultiAgentCoordinator("sd-coordinator")
        leader = coordinator.add_leader("main-leader")
        coordinator.add_agent(DataPreprocessingAgent("prep-1"), leader.agent_id)
        coordinator.add_agent(ImageGenerationAgent("gen-1"), leader.agent_id)
        tasks = coordinator.run_workflow("Generate image", subtask_specs)
        report = coordinator.compile_all_results()
    """

    def __init__(self, coordinator_id: str = "coordinator") -> None:
        self.coordinator_id = coordinator_id
        self.message_bus = MessageBus()
        self._leaders: Dict[str, LeaderAgent] = {}

    # ------------------------------------------------------------------
    # Leader management
    # ------------------------------------------------------------------

    def add_leader(
        self,
        leader_id: str,
        parent_leader_id: Optional[str] = None,
    ) -> LeaderAgent:
        """Create a new :class:`~leader.LeaderAgent` and register it.

        Args:
            leader_id: Unique identifier for the new leader.
            parent_leader_id: If set, the new leader becomes a subordinate of
                this existing leader (hierarchical delegation).

        Returns:
            The newly created :class:`~leader.LeaderAgent`.
        """
        leader = LeaderAgent(
            agent_id=leader_id,
            message_bus=self.message_bus,
            leader_id=parent_leader_id,
        )
        self._leaders[leader_id] = leader

        if parent_leader_id and parent_leader_id in self._leaders:
            parent = self._leaders[parent_leader_id]
            parent.register_agent(leader)

        logger.info(
            "Coordinator '%s': added leader '%s'%s",
            self.coordinator_id,
            leader_id,
            f" under '{parent_leader_id}'" if parent_leader_id else "",
        )
        return leader

    def remove_leader(self, leader_id: str) -> None:
        """Remove the leader with *leader_id* from the coordinator."""
        self._leaders.pop(leader_id, None)

    # ------------------------------------------------------------------
    # Agent management
    # ------------------------------------------------------------------

    def add_agent(self, agent: Agent, leader_id: str) -> None:
        """Register *agent* with the leader identified by *leader_id*.

        The agent's :attr:`~agent.Agent.message_bus` is replaced with the
        coordinator's shared bus so all participants can communicate.

        Args:
            agent: The agent to register.
            leader_id: ID of the leader that should oversee this agent.

        Raises:
            ValueError: If *leader_id* is not known to this coordinator.
        """
        if leader_id not in self._leaders:
            raise ValueError(
                f"Unknown leader '{leader_id}'. "
                "Create it first with add_leader()."
            )
        agent.message_bus = self.message_bus
        self._leaders[leader_id].register_agent(agent)
        logger.info(
            "Coordinator '%s': registered agent '%s' under leader '%s'",
            self.coordinator_id,
            agent.agent_id,
            leader_id,
        )

    # ------------------------------------------------------------------
    # Role delegation
    # ------------------------------------------------------------------

    def delegate_role(
        self,
        from_leader_id: str,
        agent_id: str,
        new_leader_id: str,
    ) -> LeaderAgent:
        """Promote a subordinate agent into a new :class:`~leader.LeaderAgent`.

        The original agent is removed from its current leader's pool and a
        new :class:`~leader.LeaderAgent` with *new_leader_id* is created as a
        subordinate of *from_leader_id*.

        Args:
            from_leader_id: The delegating leader's ID.
            agent_id: ID of the subordinate being promoted.
            new_leader_id: ID to assign to the new leader.

        Returns:
            The newly created leader.

        Raises:
            ValueError: If *from_leader_id* is unknown or *agent_id* is not
                one of its subordinates.
        """
        if from_leader_id not in self._leaders:
            raise ValueError(f"Unknown leader '{from_leader_id}'.")

        source_leader = self._leaders[from_leader_id]
        if agent_id not in source_leader._subordinates:
            raise ValueError(
                f"Agent '{agent_id}' is not a subordinate of '{from_leader_id}'."
            )

        source_leader.unregister_agent(agent_id)
        new_leader = self.add_leader(
            new_leader_id, parent_leader_id=from_leader_id
        )
        logger.info(
            "Coordinator '%s': delegated role from '%s'→'%s' (promoted '%s')",
            self.coordinator_id,
            from_leader_id,
            new_leader_id,
            agent_id,
        )
        return new_leader

    # ------------------------------------------------------------------
    # Workflow execution
    # ------------------------------------------------------------------

    def run_workflow(
        self,
        description: str,
        subtask_specs: List[Dict[str, Any]],
        leader_id: Optional[str] = None,
    ) -> List[Task]:
        """Decompose and execute a workflow on *leader_id* (default: first leader).

        Args:
            description: High-level description of the goal.
            subtask_specs: List of sub-task specification dicts (see
                :meth:`~leader.LeaderAgent.decompose_task`).
            leader_id: Which leader should orchestrate; uses the first
                registered leader if omitted.

        Returns:
            The list of :class:`~task.Task` objects created.

        Raises:
            RuntimeError: If no leaders are registered.
        """
        if not self._leaders:
            raise RuntimeError(
                "No leaders registered. Call add_leader() first."
            )

        chosen_leader_id = leader_id or next(iter(self._leaders))
        leader = self._leaders[chosen_leader_id]

        tasks = leader.decompose_task(description, subtask_specs)
        leader.assign_tasks()
        return tasks

    # ------------------------------------------------------------------
    # Reporting
    # ------------------------------------------------------------------

    def get_status(self) -> Dict[str, Any]:
        """Return a status summary for each registered leader."""
        return {
            "coordinator_id": self.coordinator_id,
            "leaders": {
                lid: leader.monitor_progress()
                for lid, leader in self._leaders.items()
            },
        }

    def compile_all_results(self) -> Dict[str, Any]:
        """Compile results from every registered leader into one report."""
        per_leader = {
            lid: leader.compile_results()
            for lid, leader in self._leaders.items()
        }
        total_completed = sum(
            len(r["completed_tasks"]) for r in per_leader.values()
        )
        total_failed = sum(
            len(r["failed_tasks"]) for r in per_leader.values()
        )
        return {
            "coordinator_id": self.coordinator_id,
            "total_completed": total_completed,
            "total_failed": total_failed,
            "per_leader_results": per_leader,
        }