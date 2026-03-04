"""POST Twitter DMs to nullclaw webhook endpoint."""

import logging
import time

import requests

from dm_fetcher import DM

log = logging.getLogger(__name__)

MAX_RETRIES = 3
BACKOFF_BASE = 2  # seconds


def post_dm(dm: DM, webhook_url: str, token: str) -> bool:
    """POST a single DM to the nullclaw webhook with retry.

    Format: {"message": "[Twitter DM from @handle (Name)] text"}
    """
    payload = {
        "message": f"[Twitter DM from @{dm.sender_handle} ({dm.sender_name})] {dm.text}"
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }

    for attempt in range(MAX_RETRIES):
        try:
            resp = requests.post(webhook_url, json=payload, headers=headers, timeout=10)
            if resp.status_code < 300:
                log.debug("Posted DM %s (attempt %d)", dm.message_id, attempt + 1)
                return True
            log.warning(
                "Webhook returned %d for DM %s", resp.status_code, dm.message_id
            )
        except requests.RequestException as e:
            log.warning("Webhook request failed (attempt %d): %s", attempt + 1, e)

        if attempt < MAX_RETRIES - 1:
            delay = BACKOFF_BASE ** (attempt + 1)
            time.sleep(delay)

    log.error("Failed to post DM %s after %d retries", dm.message_id, MAX_RETRIES)
    return False


def post_all_dms(dms: list[DM], webhook_url: str, token: str) -> tuple[int, int]:
    """Post all DMs and return (success_count, failure_count)."""
    ok = 0
    fail = 0
    for dm in dms:
        if post_dm(dm, webhook_url, token):
            ok += 1
        else:
            fail += 1
    return ok, fail
