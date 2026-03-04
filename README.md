# daybrief

Daily iMessage + Twitter DM digest agent. Get a summary email every morning.

## Install

```bash
brew tap ryanwaits/daybrief
brew install daybrief
daybrief setup
brew services start daybrief
```

## What it does

```
Ben's Mac (always-on)
├── nullclaw (gateway)   ← iMessage reader + email delivery + webhook receiver + cron
├── twitter-poller (Py)  ← polls Twitter DMs every 10min → POST to nullclaw webhook
└── Tailscale            ← remote maintenance (optional)
```

1. iMessage → nullclaw reads `chat.db` directly (SQLite poll every 3s)
2. Twitter DMs → twikit polls every 10min → `POST /webhook` → nullclaw stores to memory
3. Daily 8am cron → agent calls `message_history` + `memory_recall` → Claude summarizes → email

## Commands

```bash
daybrief setup                 # one-time configuration wizard
daybrief status                # service health ✓/✗
daybrief doctor                # diagnose issues
daybrief logs [nullclaw|twitter] # tail logs
daybrief config                # edit config in $EDITOR
daybrief config show           # print config (secrets redacted)
daybrief test-digest           # trigger digest now
daybrief exclude tiffany       # exclude contact (resolves via Contacts.app)
daybrief exclude @spambot      # exclude Twitter handle
daybrief exclude +15551234567  # exclude phone number
daybrief include tiffany       # remove from exclusions
daybrief exclude --list        # show all excluded
daybrief reauth-twitter        # clear cookies, restart poller
daybrief remote enable <key>   # enable Tailscale SSH access
daybrief remote disable        # revoke remote access
daybrief uninstall             # stop services, remove plists
```

## Prerequisites

- macOS (iMessage access)
- Anthropic API key
- Email account (Gmail/iCloud/Outlook) with app password
- Twitter credentials

## Privacy Controls

Exclude contacts from your digest:

```bash
daybrief exclude tiffany       # resolves name → phone via Contacts.app
daybrief exclude @spambot      # Twitter handle
daybrief exclude +15551234567  # phone number
daybrief include tiffany       # re-include
daybrief exclude --list        # view all exclusions
```

## Remote Access

For remote management via Tailscale:

```bash
# Ben runs:
daybrief remote enable tskey-auth-abc123

# Ryan can then:
ssh ben@bens-mac
daybrief status / doctor / config / test-digest
brew upgrade daybrief
```

## Troubleshooting

```bash
daybrief doctor    # checks FDA, binary, config, API, SMTP, venv, port
daybrief status    # gateway, poller, cron, endpoint status
daybrief logs      # tail all logs
```

## Dev Setup

For development without Homebrew:

```bash
./scripts/setup.sh    # build nullclaw, create venv
./scripts/onboard.sh  # interactive configuration
```

## Fork Changes (nullclaw)

1. **attributedBody decoder** — `src/channels/imessage_attributed.zig`
2. **SQL WHERE clause** — includes `attributedBody`-only messages, excludes tapbacks
3. **message_history tool** — `src/tools/message_history.zig`, queries chat.db by time range
4. **cron CLI flags** — `--name`, `--delivery-mode`, `--delivery-channel`, `--delivery-to`
