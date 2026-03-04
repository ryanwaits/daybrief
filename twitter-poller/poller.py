"""Main polling loop for Twitter DM → nullclaw webhook bridge."""

import asyncio
import logging
import os
import signal
import sys

from dotenv import load_dotenv

from auth import get_client
from dm_fetcher import fetch_new_dms
from state import SeenStore
from webhook import post_all_dms

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)
log = logging.getLogger("twitter-poller")

# ── Configuration ────────────────────────────────────────────────────

TWITTER_USERNAME = os.environ.get("TWITTER_USERNAME", "")
TWITTER_EMAIL = os.environ.get("TWITTER_EMAIL", "")
TWITTER_PASSWORD = os.environ.get("TWITTER_PASSWORD", "")
NULLCLAW_WEBHOOK_URL = os.environ.get("NULLCLAW_WEBHOOK_URL", "http://localhost:3000/webhook")
NULLCLAW_WEBHOOK_TOKEN = os.environ.get("NULLCLAW_WEBHOOK_TOKEN", "")
POLL_INTERVAL_SECS = int(os.environ.get("POLL_INTERVAL_SECS", "600"))
DM_EXCLUDE_HANDLES = set(
    h.strip().lower()
    for h in os.environ.get("DM_EXCLUDE_HANDLES", "").split(",")
    if h.strip()
)

MAX_CONSECUTIVE_FAILURES = 3

# ── Graceful shutdown ────────────────────────────────────────────────

shutdown_event = asyncio.Event()


def _signal_handler(sig, _frame):
    log.info("Received signal %s, shutting down...", signal.Signals(sig).name)
    shutdown_event.set()


# ── Main loop ────────────────────────────────────────────────────────


async def main():
    if not TWITTER_USERNAME or not TWITTER_PASSWORD:
        log.error("TWITTER_USERNAME and TWITTER_PASSWORD are required")
        sys.exit(1)
    if not NULLCLAW_WEBHOOK_TOKEN:
        log.warning("NULLCLAW_WEBHOOK_TOKEN not set — webhook calls will be unauthenticated")

    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)

    store = SeenStore()
    consecutive_failures = 0
    poll_count = 0

    log.info(
        "Starting poller: interval=%ds, webhook=%s, excludes=%s",
        POLL_INTERVAL_SECS,
        NULLCLAW_WEBHOOK_URL,
        DM_EXCLUDE_HANDLES or "(none)",
    )

    while not shutdown_event.is_set():
        poll_count += 1
        log.info("Poll #%d starting", poll_count)

        try:
            client = await get_client(TWITTER_USERNAME, TWITTER_EMAIL, TWITTER_PASSWORD)
            dms = await fetch_new_dms(client, store, DM_EXCLUDE_HANDLES)

            if dms:
                ok, fail = post_all_dms(dms, NULLCLAW_WEBHOOK_URL, NULLCLAW_WEBHOOK_TOKEN)
                log.info("Poll #%d: %d DMs posted, %d failed", poll_count, ok, fail)
            else:
                log.info("Poll #%d: no new DMs", poll_count)

            consecutive_failures = 0

        except Exception as e:
            consecutive_failures += 1
            log.error(
                "Poll #%d failed (%d consecutive): %s",
                poll_count,
                consecutive_failures,
                e,
            )
            if consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
                log.critical("Too many consecutive failures, exiting")
                sys.exit(1)

        # Wait for next poll or shutdown
        try:
            await asyncio.wait_for(
                shutdown_event.wait(), timeout=POLL_INTERVAL_SECS
            )
        except asyncio.TimeoutError:
            pass  # Normal — poll interval elapsed

    store.close()
    log.info("Poller shut down cleanly")


if __name__ == "__main__":
    asyncio.run(main())
