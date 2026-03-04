#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ben-digest onboarding wizard ==="
echo ""

# ── Helpers ──────────────────────────────────────────────────────────
prompt_required() {
    local var_name="$1" prompt_text="$2" value=""
    while [[ -z "$value" ]]; do
        read -rp "$prompt_text: " value
    done
    eval "$var_name='$value'"
}

prompt_optional() {
    local var_name="$1" prompt_text="$2" default="$3" value=""
    read -rp "$prompt_text [$default]: " value
    eval "$var_name='${value:-$default}'"
}

prompt_secret() {
    local var_name="$1" prompt_text="$2" value=""
    while [[ -z "$value" ]]; do
        read -rsp "$prompt_text: " value
        echo ""
    done
    eval "$var_name='$value'"
}

# ── Anthropic ────────────────────────────────────────────────────────
echo "1/5  Anthropic API"
prompt_secret ANTHROPIC_API_KEY "Anthropic API key (sk-ant-...)"
echo "  Validating..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    "https://api.anthropic.com/v1/models" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
    echo "  API key valid"
else
    echo "  WARNING: API returned HTTP $HTTP_CODE (may still work)"
fi

# ── Twitter ──────────────────────────────────────────────────────────
echo ""
echo "2/5  Twitter credentials (for DM polling)"
prompt_required TWITTER_USERNAME "Twitter username"
prompt_required TWITTER_EMAIL "Twitter email"
prompt_secret TWITTER_PASSWORD "Twitter password"
prompt_optional DM_EXCLUDE_HANDLES "Exclude handles (comma-separated)" ""

# ── SMTP ─────────────────────────────────────────────────────────────
echo ""
echo "3/5  SMTP (for digest email delivery)"
prompt_optional SMTP_HOST "SMTP host" "smtp.gmail.com"
prompt_optional SMTP_PORT "SMTP port" "587"
prompt_required SMTP_USER "SMTP username/email"
prompt_secret SMTP_PASSWORD "SMTP password (app password for Gmail)"
prompt_required EMAIL_FROM "From email address"

# ── Digest ───────────────────────────────────────────────────────────
echo ""
echo "4/5  Digest settings"
prompt_required DIGEST_EMAIL "Digest recipient email"
prompt_optional DIGEST_TIME "Digest time (cron hour, 0-23)" "8"

# ── Full Disk Access ─────────────────────────────────────────────────
echo ""
echo "5/5  Full Disk Access (required for iMessage)"
echo ""
echo "  nullclaw needs Full Disk Access to read ~/Library/Messages/chat.db"
echo "  Opening System Settings → Privacy & Security → Full Disk Access..."
echo ""
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
echo "  Add the nullclaw binary to Full Disk Access:"
echo "  → $PROJECT_DIR/nullclaw/zig-out/bin/nullclaw"
echo ""
echo "  Waiting for Full Disk Access to be granted..."
CHAT_DB="$HOME/Library/Messages/chat.db"
while true; do
    if [[ -r "$CHAT_DB" ]]; then
        echo "  chat.db is readable — Full Disk Access granted"
        break
    fi
    sleep 2
done

# ── Generate configs ─────────────────────────────────────────────────
echo ""
echo "Generating configuration files..."

mkdir -p ~/.nullclaw

cat > ~/.nullclaw/config.json << CONF
{
  "models": {
    "default": "claude-sonnet-4-20250514",
    "providers": {
      "anthropic": {
        "api_key": "$ANTHROPIC_API_KEY",
        "default_model": "claude-sonnet-4-20250514"
      }
    }
  },
  "channels": {
    "imessage": {
      "enabled": true,
      "allow_from": ["*"],
      "poll_interval_secs": 3
    },
    "email": {
      "enabled": true,
      "smtp_host": "$SMTP_HOST",
      "smtp_port": $SMTP_PORT,
      "smtp_user": "$SMTP_USER",
      "smtp_password": "$SMTP_PASSWORD",
      "from_address": "$EMAIL_FROM",
      "allow_from": ["*"]
    }
  },
  "memory": {
    "backend": "sqlite",
    "auto_save": true
  },
  "gateway": {
    "port": 3000,
    "host": "127.0.0.1",
    "require_pairing": true
  }
}
CONF
echo "  wrote ~/.nullclaw/config.json"

cat > "$PROJECT_DIR/twitter-poller/.env" << ENV
TWITTER_USERNAME=$TWITTER_USERNAME
TWITTER_EMAIL=$TWITTER_EMAIL
TWITTER_PASSWORD=$TWITTER_PASSWORD
DM_EXCLUDE_HANDLES=$DM_EXCLUDE_HANDLES
NULLCLAW_WEBHOOK_URL=http://localhost:3000/webhook
NULLCLAW_WEBHOOK_TOKEN=
POLL_INTERVAL_SECS=600
ENV
echo "  wrote twitter-poller/.env"

# ── Install LaunchAgents ─────────────────────────────────────────────
echo ""
echo "Installing LaunchAgents..."

NULLCLAW_BIN="$PROJECT_DIR/nullclaw/zig-out/bin/nullclaw"
POLLER_VENV="$PROJECT_DIR/twitter-poller/.venv/bin/python3"
POLLER_SCRIPT="$PROJECT_DIR/twitter-poller/poller.py"

# Customize plists with actual paths
sed "s|/usr/local/bin/nullclaw|$NULLCLAW_BIN|g; s|/Users/ben|$HOME|g" \
    "$PROJECT_DIR/config/com.ben-digest.nullclaw.plist" \
    > ~/Library/LaunchAgents/com.ben-digest.nullclaw.plist

sed "s|/usr/local/bin/ben-digest-venv/bin/python3|$POLLER_VENV|g; s|/usr/local/lib/ben-digest/twitter-poller|$PROJECT_DIR/twitter-poller|g" \
    "$PROJECT_DIR/config/com.ben-digest.twitter-poller.plist" \
    > ~/Library/LaunchAgents/com.ben-digest.twitter-poller.plist

launchctl load ~/Library/LaunchAgents/com.ben-digest.nullclaw.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.ben-digest.twitter-poller.plist 2>/dev/null || true
echo "  LaunchAgents installed and loaded"

# ── Create digest cron job ───────────────────────────────────────────
echo ""
echo "Creating daily digest cron job..."
DIGEST_PROMPT='Use the message_history tool with hours_back=24 to get all iMessages from the last 24 hours. Then use memory_recall with query "twitter DM" to get recent Twitter DMs. Group messages by contact/sender. For each conversation: summarize the key points in 1-2 sentences. Then create sections: Key Conversations (sorted by importance), Action Items (anything requiring follow-up), and Interesting Signals (notable patterns or opportunities). If no messages found, say so. If more than 100 messages, focus on the top 20 most substantive conversations. Format as clean readable text.'

"$NULLCLAW_BIN" cron add \
    --expression "0 $DIGEST_TIME * * *" \
    --prompt "$DIGEST_PROMPT" \
    --name "daily-digest" \
    --delivery-mode always \
    --delivery-channel email \
    --delivery-to "$DIGEST_EMAIL" \
    2>/dev/null || echo "  (cron job creation via CLI — configure manually if this fails)"

echo ""
echo "=== Onboarding complete ==="
echo ""
echo "Services running:"
echo "  nullclaw gateway  → http://localhost:3000"
echo "  twitter-poller    → polling every ${POLL_INTERVAL_SECS}s"
echo "  daily digest      → ${DIGEST_TIME}:00 AM → $DIGEST_EMAIL"
echo ""
echo "Logs:"
echo "  /tmp/ben-digest-nullclaw.log"
echo "  /tmp/ben-digest-twitter-poller.log"
