"""Twitter authentication via twikit (cookie-based, no API key)."""

import logging
from pathlib import Path

from twikit import Client

log = logging.getLogger(__name__)

COOKIES_PATH = Path("cookies.json")


async def get_client(
    username: str, email: str, password: str
) -> Client:
    """Return an authenticated twikit Client.

    On first run: logs in with credentials and saves cookies.
    On subsequent runs: loads cookies from disk.
    On auth failure: attempts one re-login before raising.
    """
    client = Client("en-US")

    if COOKIES_PATH.exists():
        try:
            client.load_cookies(str(COOKIES_PATH))
            log.info("Loaded cookies from %s", COOKIES_PATH)
            return client
        except Exception:
            log.warning("Cookie load failed, will re-login")

    try:
        await client.login(
            auth_info_1=username,
            auth_info_2=email,
            password=password,
        )
        client.save_cookies(str(COOKIES_PATH))
        log.info("Logged in and saved cookies")
        return client
    except Exception as e:
        log.error("Login failed: %s", e)
        raise
