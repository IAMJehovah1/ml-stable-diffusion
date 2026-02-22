#
# For licensing see accompanying LICENSE.md file.
# Copyright (C) 2022 Apple Inc. All Rights Reserved.
#

"""In-process message bus for agent communication."""

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum, auto
from typing import Any, Callable, Dict, List, Optional

logger = logging.getLogger(__name__)


class MessageType(Enum):
    """Supported message types between agents."""
    TASK_ASSIGNMENT = auto()
    PROGRESS_REPORT = auto()
    TASK_RESULT = auto()
    TASK_FAILURE = auto()
    STATUS_UPDATE = auto()
    CONFLICT_ALERT = auto()
    LESSON_LEARNED = auto()


@dataclass
class Message:
    """A single message exchanged between agents.

    Attributes:
        sender_id: ID of the sending agent.
        recipient_id: ID of the intended recipient, or ``"broadcast"`` for all.
        message_type: Category of the message.
        payload: Arbitrary data carried by the message.
        timestamp: UTC time of creation.
        message_id: Unique identifier for the message.
    """
    sender_id: str
    recipient_id: str
    message_type: MessageType
    payload: Any = None
    timestamp: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc))
    message_id: str = field(
        default_factory=lambda: str(
            __import__("uuid").uuid4()))


class MessageBus:
    """Lightweight publish/subscribe message bus.

    Agents register a handler callable keyed by their ``agent_id``.  When a
    message is dispatched the bus delivers it to the matching handler (or to
    every registered handler for broadcast messages).

    Example::

        bus = MessageBus()
        bus.register("leader", lambda msg: print(msg))
        bus.dispatch(Message(sender_id="agent1", recipient_id="leader",
                             message_type=MessageType.PROGRESS_REPORT,
                             payload={"progress": 0.5}))
    """

    def __init__(self) -> None:
        self._handlers: Dict[str, Callable[[Message], None]] = {}
        self._message_log: List[Message] = []

    def register(self, agent_id: str,
                 handler: Callable[[Message], None]) -> None:
        """Register *handler* to receive messages addressed to *agent_id*."""
        self._handlers[agent_id] = handler
        logger.debug("MessageBus: registered handler for '%s'", agent_id)

    def unregister(self, agent_id: str) -> None:
        """Remove the handler registered for *agent_id*, if any."""
        self._handlers.pop(agent_id, None)

    def dispatch(self, message: Message) -> None:
        """Deliver *message* to the intended recipient(s).

        Broadcast messages (``recipient_id == "broadcast"``) are delivered to
        every registered handler.  The message is always appended to the
        internal log regardless of whether a handler was found.
        """
        self._message_log.append(message)

        if message.recipient_id == "broadcast":
            for handler in self._handlers.values():
                self._safe_call(handler, message)
        else:
            handler = self._handlers.get(message.recipient_id)
            if handler:
                self._safe_call(handler, message)
            else:
                logger.warning(
                    "MessageBus: no handler for recipient '%s'",
                    message.recipient_id,
                )

    def get_messages_for(self, agent_id: str) -> List[Message]:
        """Return all logged messages addressed to *agent_id* or broadcast."""
        return [
            m for m in self._message_log
            if m.recipient_id in (agent_id, "broadcast")
        ]

    def get_all_messages(self) -> List[Message]:
        """Return the full message log (read-only copy)."""
        return list(self._message_log)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _safe_call(handler: Callable[[Message], None],
                   message: Message) -> None:
        try:
            handler(message)
        except Exception:
            logger.exception(
                "MessageBus: handler raised an exception for message %s",
                message.message_id,
            )
