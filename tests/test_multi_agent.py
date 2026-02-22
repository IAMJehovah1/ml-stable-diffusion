#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""Unit tests for the multi-agent task coordination system."""

import unittest
from typing import Any

from python_coreml_stable_diffusion.multi_agent import (
    Agent,
    AgentCapability,
    DataPreprocessingAgent,
    ImageGenerationAgent,
    LeaderAgent,
    Message,
    MessageBus,
    MessageType,
    ModelFineTuningAgent,
    MultiAgentCoordinator,
    QualityEvaluationAgent,
    Task,
    TaskStatus,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class _EchoAgent(Agent):
    """Trivial concrete agent that returns the task description as its result."""

    def execute_task(self, task: Task) -> Any:
        return f"done:{task.description}"


class _FailingAgent(Agent):
    """Agent that always raises an exception."""

    def execute_task(self, task: Task) -> Any:
        raise RuntimeError("intentional failure")


# ---------------------------------------------------------------------------
# Task tests
# ---------------------------------------------------------------------------

class TestTask(unittest.TestCase):

    def test_defaults(self):
        task = Task(description="do something")
        self.assertEqual(task.status, TaskStatus.PENDING)
        self.assertIsNone(task.assigned_to)
        self.assertIsNone(task.result)
        self.assertIsNone(task.error)
        self.assertFalse(task.is_done())

    def test_lifecycle(self):
        task = Task(description="lifecycle test")
        task.mark_in_progress("agent-1")
        self.assertEqual(task.status, TaskStatus.IN_PROGRESS)
        self.assertEqual(task.assigned_to, "agent-1")
        self.assertFalse(task.is_done())

        task.mark_completed(result=42)
        self.assertEqual(task.status, TaskStatus.COMPLETED)
        self.assertEqual(task.result, 42)
        self.assertTrue(task.is_done())

    def test_failure(self):
        task = Task(description="failing task")
        task.mark_failed("boom")
        self.assertEqual(task.status, TaskStatus.FAILED)
        self.assertEqual(task.error, "boom")
        self.assertTrue(task.is_done())

    def test_unique_ids(self):
        t1 = Task(description="a")
        t2 = Task(description="b")
        self.assertNotEqual(t1.task_id, t2.task_id)


# ---------------------------------------------------------------------------
# MessageBus tests
# ---------------------------------------------------------------------------

class TestMessageBus(unittest.TestCase):

    def test_unicast_delivery(self):
        received = []
        bus = MessageBus()
        bus.register("agent-A", received.append)

        msg = Message(
            sender_id="agent-B",
            recipient_id="agent-A",
            message_type=MessageType.STATUS_UPDATE,
        )
        bus.dispatch(msg)
        self.assertEqual(len(received), 1)
        self.assertIs(received[0], msg)

    def test_broadcast_delivery(self):
        received_a, received_b = [], []
        bus = MessageBus()
        bus.register("agent-A", received_a.append)
        bus.register("agent-B", received_b.append)

        msg = Message(
            sender_id="leader",
            recipient_id="broadcast",
            message_type=MessageType.STATUS_UPDATE,
        )
        bus.dispatch(msg)
        self.assertEqual(len(received_a), 1)
        self.assertEqual(len(received_b), 1)

    def test_unregistered_recipient_does_not_raise(self):
        bus = MessageBus()
        msg = Message(
            sender_id="x",
            recipient_id="nobody",
            message_type=MessageType.STATUS_UPDATE,
        )
        # Should not raise even though "nobody" is not registered.
        bus.dispatch(msg)

    def test_get_messages_for(self):
        bus = MessageBus()
        bus.register("A", lambda m: None)
        bus.register("B", lambda m: None)

        bus.dispatch(
            Message(sender_id="X", recipient_id="A",
                    message_type=MessageType.STATUS_UPDATE)
        )
        bus.dispatch(
            Message(sender_id="X", recipient_id="broadcast",
                    message_type=MessageType.STATUS_UPDATE)
        )
        msgs = bus.get_messages_for("A")
        self.assertEqual(len(msgs), 2)

    def test_unregister(self):
        received = []
        bus = MessageBus()
        bus.register("agent", received.append)
        bus.unregister("agent")
        bus.dispatch(
            Message(sender_id="x", recipient_id="agent",
                    message_type=MessageType.STATUS_UPDATE)
        )
        self.assertEqual(len(received), 0)


# ---------------------------------------------------------------------------
# Agent tests
# ---------------------------------------------------------------------------

class TestAgent(unittest.TestCase):

    def _make_agent(self, capabilities=None):
        bus = MessageBus()
        agent = _EchoAgent(
            agent_id="echo-1",
            capabilities=capabilities,
            message_bus=bus,
        )
        return agent, bus

    def test_default_capability(self):
        agent, _ = self._make_agent()
        self.assertIn(AgentCapability.GENERAL, agent.capabilities)

    def test_can_handle_general(self):
        agent, _ = self._make_agent()
        task = Task(description="anything",
                    required_capability=AgentCapability.GENERAL)
        self.assertTrue(agent.can_handle(task))

    def test_can_handle_matching_capability(self):
        agent, _ = self._make_agent(
            capabilities={AgentCapability.IMAGE_GENERATION})
        task = Task(description="generate",
                    required_capability=AgentCapability.IMAGE_GENERATION)
        self.assertTrue(agent.can_handle(task))

    def test_cannot_handle_wrong_capability(self):
        agent, _ = self._make_agent(
            capabilities={AgentCapability.IMAGE_GENERATION})
        task = Task(description="preprocess",
                    required_capability=AgentCapability.DATA_PREPROCESSING)
        self.assertFalse(agent.can_handle(task))

    def test_successful_execution(self):
        agent, _ = self._make_agent()
        task = Task(description="test task")
        agent.receive_task(task)
        self.assertEqual(task.status, TaskStatus.COMPLETED)
        self.assertEqual(task.result, "done:test task")
        self.assertEqual(task.assigned_to, "echo-1")

    def test_failed_execution(self):
        bus = MessageBus()
        agent = _FailingAgent(
            agent_id="fail-1",
            capabilities={AgentCapability.GENERAL},
            message_bus=bus,
        )
        task = Task(description="fail task")
        agent.receive_task(task)
        self.assertEqual(task.status, TaskStatus.FAILED)
        self.assertIn("intentional failure", task.error)

    def test_lessons_learned_on_success(self):
        agent, _ = self._make_agent()
        task = Task(description="learn task")
        agent.receive_task(task)
        self.assertEqual(len(agent.lessons_learned), 1)
        self.assertTrue(agent.lessons_learned[0]["success"])

    def test_lessons_learned_on_failure(self):
        bus = MessageBus()
        agent = _FailingAgent("fail-2", message_bus=bus)
        task = Task(description="bad task")
        agent.receive_task(task)
        self.assertEqual(len(agent.lessons_learned), 1)
        self.assertFalse(agent.lessons_learned[0]["success"])

    def test_workload_counter(self):
        bus = MessageBus()
        # Agent whose execute_task blocks – we can't truly test concurrency
        # here, but we verify workload=0 before and after.
        agent = _EchoAgent("w-1", message_bus=bus)
        task = Task(description="w task")
        self.assertEqual(agent.workload, 0)
        agent.receive_task(task)
        # Task completes synchronously; workload is back to 0 afterwards.
        self.assertEqual(agent.workload, 0)

    def test_capabilities_metadata(self):
        agent, _ = self._make_agent(
            capabilities={AgentCapability.IMAGE_GENERATION})
        meta = agent.get_capabilities_metadata()
        self.assertEqual(meta["agent_id"], "echo-1")
        self.assertIn("IMAGE_GENERATION", meta["capabilities"])
        self.assertIn("workload", meta)

    def test_progress_report_sent_to_leader(self):
        bus = MessageBus()
        received = []
        bus.register("leader-0", received.append)
        agent = _EchoAgent("echo-2", message_bus=bus, leader_id="leader-0")
        task = Task(description="prog task")
        agent.receive_task(task)
        # _EchoAgent does not call report_progress, but we can call it manually.
        agent.report_progress(task.task_id, 0.5, "halfway")
        progress_msgs = [
            m for m in received
            if m.message_type == MessageType.PROGRESS_REPORT
        ]
        self.assertEqual(len(progress_msgs), 1)
        self.assertEqual(progress_msgs[0].payload["progress"], 0.5)


# ---------------------------------------------------------------------------
# LeaderAgent tests
# ---------------------------------------------------------------------------

class TestLeaderAgent(unittest.TestCase):

    def _make_setup(self):
        bus = MessageBus()
        leader = LeaderAgent("leader-1", message_bus=bus)
        prep = DataPreprocessingAgent("prep-1", message_bus=bus)
        gen = ImageGenerationAgent("gen-1", message_bus=bus)
        eval_agent = QualityEvaluationAgent("eval-1", message_bus=bus)
        leader.register_agent(prep)
        leader.register_agent(gen)
        leader.register_agent(eval_agent)
        return leader, prep, gen, eval_agent

    def test_register_agent(self):
        leader, prep, gen, _ = self._make_setup()
        self.assertIn("prep-1", leader._subordinates)
        self.assertEqual(prep.leader_id, "leader-1")

    def test_decompose_task(self):
        leader, *_ = self._make_setup()
        tasks = leader.decompose_task(
            "full pipeline",
            [
                {"description": "preprocess",
                 "capability": AgentCapability.DATA_PREPROCESSING},
                {"description": "generate image",
                 "capability": AgentCapability.IMAGE_GENERATION},
            ],
        )
        self.assertEqual(len(tasks), 2)
        self.assertEqual(len(leader._task_queue), 2)

    def test_assign_tasks(self):
        leader, *_ = self._make_setup()
        leader.decompose_task(
            "pipeline",
            [
                {"description": "preprocess",
                 "capability": AgentCapability.DATA_PREPROCESSING},
                {"description": "generate",
                 "capability": AgentCapability.IMAGE_GENERATION},
                {"description": "evaluate",
                 "capability": AgentCapability.QUALITY_EVALUATION},
            ],
        )
        assigned = leader.assign_tasks()
        self.assertEqual(assigned, 3)
        # Queue should be empty after successful assignment.
        self.assertEqual(len(leader._task_queue), 0)

    def test_unassignable_task_stays_in_queue(self):
        bus = MessageBus()
        leader = LeaderAgent("l", message_bus=bus)
        leader.decompose_task(
            "fine-tune",
            [{"description": "fine-tune",
              "capability": AgentCapability.MODEL_FINETUNING}],
        )
        assigned = leader.assign_tasks()
        self.assertEqual(assigned, 0)
        self.assertEqual(len(leader._task_queue), 1)

    def test_compile_results(self):
        leader, *_ = self._make_setup()
        leader.decompose_task(
            "pipeline",
            [
                {"description": "preprocess",
                 "capability": AgentCapability.DATA_PREPROCESSING},
                {"description": "generate",
                 "capability": AgentCapability.IMAGE_GENERATION},
            ],
        )
        leader.assign_tasks()
        report = leader.compile_results()
        self.assertEqual(report["leader_id"], "leader-1")
        self.assertEqual(len(report["completed_tasks"]), 2)
        self.assertEqual(len(report["failed_tasks"]), 0)
        self.assertIsInstance(report["lessons_learned"], list)

    def test_monitor_progress(self):
        leader, *_ = self._make_setup()
        progress = leader.monitor_progress()
        self.assertEqual(progress["leader_id"], "leader-1")
        self.assertIn("task_status", progress)

    def test_resolve_conflict(self):
        leader, prep, gen, _ = self._make_setup()
        winner = leader.resolve_conflict(
            ["prep-1", "gen-1"], resource="gpu-0")
        self.assertIn(winner, ["prep-1", "gen-1"])

    def test_resolve_conflict_unknown_agents(self):
        bus = MessageBus()
        leader = LeaderAgent("l", message_bus=bus)
        winner = leader.resolve_conflict(["ghost"], resource="gpu")
        self.assertIsNone(winner)

    def test_failed_tasks_tracked(self):
        bus = MessageBus()
        leader = LeaderAgent("l", message_bus=bus)
        fail_agent = _FailingAgent("fail", message_bus=bus)
        leader.register_agent(fail_agent)
        leader.decompose_task(
            "will fail",
            [{"description": "fail", "capability": AgentCapability.GENERAL}],
        )
        leader.assign_tasks()
        report = leader.compile_results()
        self.assertEqual(len(report["failed_tasks"]), 1)
        self.assertEqual(len(report["completed_tasks"]), 0)


# ---------------------------------------------------------------------------
# MultiAgentCoordinator tests
# ---------------------------------------------------------------------------

class TestMultiAgentCoordinator(unittest.TestCase):

    def _make_coordinator(self):
        c = MultiAgentCoordinator("test-coord")
        c.add_leader("leader-A")
        c.add_agent(DataPreprocessingAgent("prep"), "leader-A")
        c.add_agent(ImageGenerationAgent("gen"), "leader-A")
        c.add_agent(QualityEvaluationAgent("eval"), "leader-A")
        return c

    def test_add_leader(self):
        c = MultiAgentCoordinator("c")
        leader = c.add_leader("l1")
        self.assertIsInstance(leader, LeaderAgent)
        self.assertIn("l1", c._leaders)

    def test_add_agent_unknown_leader(self):
        c = MultiAgentCoordinator("c")
        with self.assertRaises(ValueError):
            c.add_agent(_EchoAgent("e"), "nonexistent")

    def test_run_workflow(self):
        c = self._make_coordinator()
        tasks = c.run_workflow(
            "SD pipeline",
            [
                {"description": "preprocess",
                 "capability": AgentCapability.DATA_PREPROCESSING},
                {"description": "generate",
                 "capability": AgentCapability.IMAGE_GENERATION},
                {"description": "evaluate",
                 "capability": AgentCapability.QUALITY_EVALUATION},
            ],
        )
        self.assertEqual(len(tasks), 3)
        for task in tasks:
            self.assertEqual(task.status, TaskStatus.COMPLETED)

    def test_run_workflow_no_leaders_raises(self):
        c = MultiAgentCoordinator("empty")
        with self.assertRaises(RuntimeError):
            c.run_workflow("x", [])

    def test_get_status(self):
        c = self._make_coordinator()
        status = c.get_status()
        self.assertEqual(status["coordinator_id"], "test-coord")
        self.assertIn("leader-A", status["leaders"])

    def test_compile_all_results(self):
        c = self._make_coordinator()
        c.run_workflow(
            "SD pipeline",
            [
                {"description": "preprocess",
                 "capability": AgentCapability.DATA_PREPROCESSING},
                {"description": "generate",
                 "capability": AgentCapability.IMAGE_GENERATION},
            ],
        )
        report = c.compile_all_results()
        self.assertEqual(report["coordinator_id"], "test-coord")
        self.assertEqual(report["total_completed"], 2)
        self.assertEqual(report["total_failed"], 0)

    def test_hierarchical_leaders(self):
        c = MultiAgentCoordinator("hier")
        parent = c.add_leader("parent")
        child = c.add_leader("child", parent_leader_id="parent")
        self.assertIn("child", parent._subordinates)
        self.assertEqual(child.leader_id, "parent")

    def test_delegate_role(self):
        c = MultiAgentCoordinator("deleg")
        c.add_leader("main")
        c.add_agent(_EchoAgent("echo-x"), "main")
        new_leader = c.delegate_role(
            from_leader_id="main",
            agent_id="echo-x",
            new_leader_id="new-leader",
        )
        self.assertIsInstance(new_leader, LeaderAgent)
        self.assertIn("new-leader", c._leaders)
        # The original agent was removed from the parent's subordinates.
        self.assertNotIn("echo-x", c._leaders["main"]._subordinates)

    def test_delegate_role_unknown_leader(self):
        c = MultiAgentCoordinator("d")
        with self.assertRaises(ValueError):
            c.delegate_role("ghost", "x", "y")

    def test_delegate_role_unknown_agent(self):
        c = MultiAgentCoordinator("d")
        c.add_leader("l")
        with self.assertRaises(ValueError):
            c.delegate_role("l", "nobody", "new-l")

    def test_multiple_leaders_shared_bus(self):
        """All agents across leaders share the same message bus."""
        c = MultiAgentCoordinator("multi")
        c.add_leader("l1")
        c.add_leader("l2")
        c.add_agent(DataPreprocessingAgent("prep"), "l1")
        c.add_agent(ImageGenerationAgent("gen"), "l2")
        # Both leaders' agents are on the same bus.
        self.assertIs(
            c._leaders["l1"]._subordinates["prep"].message_bus,
            c.message_bus,
        )
        self.assertIs(
            c._leaders["l2"]._subordinates["gen"].message_bus,
            c.message_bus,
        )


# ---------------------------------------------------------------------------
# SD-specific agent tests
# ---------------------------------------------------------------------------

class TestStableDiffusionAgents(unittest.TestCase):

    def _run(self, agent, task):
        agent.receive_task(task)
        return task

    def test_data_preprocessing_agent(self):
        bus = MessageBus()
        agent = DataPreprocessingAgent("prep", message_bus=bus,
                                       leader_id=None)
        task = Task(
            description="preprocess",
            required_capability=AgentCapability.DATA_PREPROCESSING,
            metadata={"input_path": "/in", "output_path": "/out"},
        )
        self._run(agent, task)
        self.assertEqual(task.status, TaskStatus.COMPLETED)
        self.assertEqual(task.result["status"], "preprocessed")

    def test_model_finetuning_agent(self):
        bus = MessageBus()
        agent = ModelFineTuningAgent("ft", message_bus=bus)
        task = Task(
            description="fine-tune",
            required_capability=AgentCapability.MODEL_FINETUNING,
            metadata={"model_version": "sd-1.5", "epochs": 3},
        )
        self._run(agent, task)
        self.assertEqual(task.status, TaskStatus.COMPLETED)
        self.assertEqual(task.result["epochs_completed"], 3)

    def test_image_generation_agent(self):
        bus = MessageBus()
        agent = ImageGenerationAgent("gen", message_bus=bus)
        task = Task(
            description="generate",
            required_capability=AgentCapability.IMAGE_GENERATION,
            metadata={"prompt": "cat", "seed": 7, "output_path": "/out.png"},
        )
        self._run(agent, task)
        self.assertEqual(task.status, TaskStatus.COMPLETED)
        self.assertEqual(task.result["prompt"], "cat")
        self.assertEqual(task.result["seed"], 7)

    def test_quality_evaluation_agent(self):
        bus = MessageBus()
        agent = QualityEvaluationAgent("eval", message_bus=bus)
        task = Task(
            description="evaluate",
            required_capability=AgentCapability.QUALITY_EVALUATION,
            metadata={"image_path": "/img.png",
                      "reference_prompt": "cat"},
        )
        self._run(agent, task)
        self.assertEqual(task.status, TaskStatus.COMPLETED)
        self.assertEqual(task.result["status"], "evaluated")

    def test_wrong_capability_not_executed(self):
        bus = MessageBus()
        agent = DataPreprocessingAgent("prep", message_bus=bus)
        task = Task(
            description="generate",
            required_capability=AgentCapability.IMAGE_GENERATION,
        )
        # receive_task should silently skip – task stays PENDING.
        agent.receive_task(task)
        self.assertEqual(task.status, TaskStatus.PENDING)


if __name__ == "__main__":
    unittest.main()
