"""Fetch new Twitter DMs and deduplicate via SeenStore."""

import logging
from dataclasses import dataclass

from twikit import Client

from state import SeenStore

log = logging.getLogger(__name__)


@dataclass
class DM:
    sender_handle: str
    sender_name: str
    text: str
    timestamp: str
    conversation_id: str
    message_id: str


async def fetch_new_dms(
    client: Client, store: SeenStore, exclude_handles: set[str] | None = None
) -> list[DM]:
    """Fetch all unseen DMs across conversations."""
    exclude = exclude_handles or set()
    new_dms: list[DM] = []

    try:
        inbox = await client.get_dm_inbox()
        conversations = inbox.conversations if hasattr(inbox, "conversations") else []
    except Exception as e:
        log.error("Failed to fetch DM inbox: %s", e)
        return []

    for conv in conversations:
        try:
            conv_id = conv.id if hasattr(conv, "id") else str(conv)
            messages = conv.messages if hasattr(conv, "messages") else []

            for msg in messages:
                msg_id = str(msg.id) if hasattr(msg, "id") else ""
                if not msg_id:
                    continue
                if store.is_seen(conv_id, msg_id):
                    continue

                sender_handle = ""
                sender_name = ""
                if hasattr(msg, "sender"):
                    sender = msg.sender
                    sender_handle = getattr(sender, "screen_name", "")
                    sender_name = getattr(sender, "name", "")

                if sender_handle.lower() in exclude:
                    store.mark_seen(conv_id, msg_id)
                    continue

                text = getattr(msg, "text", "") or ""
                timestamp = getattr(msg, "time", "") or ""

                dm = DM(
                    sender_handle=sender_handle,
                    sender_name=sender_name,
                    text=text,
                    timestamp=str(timestamp),
                    conversation_id=conv_id,
                    message_id=msg_id,
                )
                new_dms.append(dm)
                store.mark_seen(conv_id, msg_id, str(timestamp))
        except Exception as e:
            log.warning("Error processing conversation: %s", e)
            continue

    log.info("Found %d new DMs", len(new_dms))
    return new_dms
