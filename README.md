# daybrief

Daily iMessage + Twitter DM digest agent. Get a summary email every morning.

## Install

```bash
brew install ryanwaits/daybrief/daybrief
daybrief setup
brew services start daybrief
```

That's it. First digest arrives tomorrow at 8am.

## What you need

- macOS (for iMessage access)
- Anthropic API key ([get one here](https://console.anthropic.com/settings/keys))
- Email account (Gmail, iCloud, or Outlook) with an app password
- Twitter credentials (username, email, password)

## Setup walkthrough

`daybrief setup` walks you through 4 steps:

**Step 1 — Anthropic API key.** Paste your key, it validates inline.

**Step 2 — Email.** Pick your provider (Gmail/iCloud/Outlook). It pre-fills SMTP settings, opens your browser to create an app password, and sends a test email to confirm.

**Step 3 — Twitter.** Enter your username, email, and password for DM polling.

**Step 4 — Full Disk Access.** Opens System Settings automatically. Add the nullclaw binary, and setup waits until access is granted.

Done. Config is written, services start, digest is scheduled for 8am.

## Daily usage

Zero effort. You get an email every morning with:

- **Key Conversations** — most important threads from iMessage + Twitter DMs
- **Action Items** — anything that needs follow-up
- **Signals** — notable patterns or opportunities

### Trigger a digest now

```bash
daybrief test-digest
```

### Check health

```bash
daybrief status     # ✓/✗ for gateway, poller, cron, endpoint
daybrief doctor     # deeper checks: FDA, binary, config, API, SMTP, venv, port
```

### View logs

```bash
daybrief logs              # tail all logs
daybrief logs nullclaw     # gateway logs only
daybrief logs twitter      # poller logs only
```

### Edit config

```bash
daybrief config            # opens in $EDITOR
daybrief config show       # print config with secrets redacted
```

## Excluding contacts

Don't want certain people in your digest? Exclude by name, phone number, or Twitter handle.

```bash
daybrief exclude tiffany         # resolves name → phone via Contacts.app
daybrief exclude +15551234567    # phone number directly
daybrief exclude @spambot        # Twitter handle

daybrief exclude --list          # see all exclusions
daybrief include tiffany         # re-include someone
```

Name lookups query your macOS Contacts database. If multiple matches are found, you'll be prompted to choose.

## Twitter re-auth

Twitter cookies expire. If DM polling stops:

```bash
daybrief reauth-twitter    # clears cookies, restarts poller
```

## Remote access

Enable SSH access via Tailscale so someone else can manage your setup:

```bash
# You run (with an auth key from admin.tailscale.com):
daybrief remote enable tskey-auth-abc123

# They can then:
ssh you@your-mac
daybrief status / doctor / config / test-digest
brew upgrade daybrief

# Revoke anytime:
daybrief remote disable
```

## Updating

```bash
brew upgrade daybrief
```

## Uninstalling

**Stop services and remove plists** (keeps your config):

```bash
daybrief uninstall
```

**Full removal** (removes everything including credentials):

```bash
daybrief uninstall
brew uninstall daybrief
rm -rf ~/.nullclaw ~/.local/share/daybrief
```

`brew uninstall` removes the binaries and venv. The `rm` cleans up your API keys, SMTP credentials, Twitter cookies, and exclusion list. Homebrew never touches files in `~/` on its own.

## All commands

| Command | What it does |
|---------|-------------|
| `daybrief setup` | One-time configuration wizard |
| `daybrief status` | Service health (✓/✗) |
| `daybrief doctor` | Diagnose issues with actionable fixes |
| `daybrief logs [nullclaw\|twitter]` | Tail service logs |
| `daybrief config` | Edit config in $EDITOR |
| `daybrief config show` | Print config (secrets redacted) |
| `daybrief test-digest` | Trigger digest immediately |
| `daybrief exclude <contact>` | Exclude from digest |
| `daybrief include <contact>` | Remove from exclusions |
| `daybrief exclude --list` | Show all exclusions |
| `daybrief reauth-twitter` | Clear cookies, restart poller |
| `daybrief remote enable <key>` | Enable Tailscale SSH |
| `daybrief remote disable` | Disable remote access |
| `daybrief remote status` | Show Tailscale status |
| `daybrief uninstall` | Stop services, remove plists |
| `daybrief version` | Print version info |
| `daybrief help` | Show usage |

## How it works

```
Your Mac (always-on)
├── nullclaw gateway    ← reads iMessage, sends email, receives webhooks, runs cron
├── twitter-poller      ← polls Twitter DMs every 10min → posts to nullclaw webhook
└── Tailscale           ← optional remote SSH access
```

1. **iMessage** — nullclaw reads `~/Library/Messages/chat.db` directly (polls every 3s)
2. **Twitter DMs** — Python poller uses twikit (cookie-based), posts new DMs to nullclaw webhook, stored in memory
3. **Daily digest** — 8am cron job triggers a Claude agent that reads 24h of messages, summarizes, and emails you

## File locations

| What | Where |
|------|-------|
| CLI | `/opt/homebrew/bin/daybrief` |
| nullclaw binary | `/opt/homebrew/opt/daybrief/libexec/nullclaw/nullclaw` |
| Python venv | `/opt/homebrew/opt/daybrief/libexec/venv/` |
| Config | `~/.nullclaw/config.json` |
| Twitter env | `~/.local/share/daybrief/twitter-poller.env` |
| Twitter cookies | `~/.local/share/daybrief/cookies.json` |
| Exclusions | `~/.local/share/daybrief/exclusions.json` |
| Logs | `/opt/homebrew/var/log/daybrief/` |

## Dev setup

For development without Homebrew:

```bash
git clone https://github.com/ryanwaits/daybrief.git
cd daybrief
./scripts/setup.sh       # builds nullclaw, creates Python venv
./scripts/onboard.sh     # interactive configuration wizard
```
