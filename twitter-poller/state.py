"""SQLite-based seen-message tracking for Twitter DM deduplication."""

import sqlite3
from pathlib import Path


class SeenStore:
    def __init__(self, db_path: str = "seen.db"):
        self.conn = sqlite3.connect(db_path)
        self.conn.execute(
            """CREATE TABLE IF NOT EXISTS seen_messages (
                conversation_id TEXT NOT NULL,
                message_id TEXT NOT NULL,
                timestamp TEXT,
                PRIMARY KEY (conversation_id, message_id)
            )"""
        )
        self.conn.commit()

    def is_seen(self, conversation_id: str, message_id: str) -> bool:
        row = self.conn.execute(
            "SELECT 1 FROM seen_messages WHERE conversation_id = ? AND message_id = ?",
            (conversation_id, message_id),
        ).fetchone()
        return row is not None

    def mark_seen(
        self, conversation_id: str, message_id: str, timestamp: str = ""
    ) -> None:
        self.conn.execute(
            "INSERT OR IGNORE INTO seen_messages (conversation_id, message_id, timestamp) VALUES (?, ?, ?)",
            (conversation_id, message_id, timestamp),
        )
        self.conn.commit()

    def get_last_seen_timestamp(self, conversation_id: str) -> str | None:
        row = self.conn.execute(
            "SELECT timestamp FROM seen_messages WHERE conversation_id = ? ORDER BY timestamp DESC LIMIT 1",
            (conversation_id,),
        ).fetchone()
        return row[0] if row else None

    def close(self):
        self.conn.close()
