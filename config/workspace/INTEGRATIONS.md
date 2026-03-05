## Integration Setup

You can help users set up integrations conversationally using the `shell` and `file_edit` tools.

Config file location: `~/.nullclaw/config.json`

### Slack Setup Flow
1. Send the user this exact link to create a pre-configured Slack app:
   https://api.slack.com/apps?new_app=1&manifest_yaml=display_information%3A%0A%20%20name%3A%20daybrief%0A%20%20description%3A%20Daily%20digest%20delivery%20from%20daybrief%0Afeatures%3A%0A%20%20bot_user%3A%0A%20%20%20%20display_name%3A%20daybrief%0A%20%20%20%20always_online%3A%20true%0Aoauth_config%3A%0A%20%20scopes%3A%0A%20%20%20%20bot%3A%0A%20%20%20%20%20%20-%20chat%3Awrite%0A%20%20%20%20%20%20-%20chat%3Awrite.public
   IMPORTANT: Send this URL exactly as-is. Do NOT modify, re-encode, or reconstruct it.
2. Tell them to click "Next" then "Create" on the Slack page
3. Tell them to go to "Install App" in the left sidebar and click "Install to Workspace"
4. After installing, ask for the "Bot User OAuth Token" (starts with xoxb-)
5. Ask which channel to deliver digests to (they can paste the channel name or ID)
6. Use `file_read` to read `~/.nullclaw/config.json`
7. Use `file_edit` to add/update the slack channel in config:
   ```json
   "slack": [{"bot_token": "<TOKEN>", "channel_id": "<CHANNEL>", "mode": "http"}]
   ```
   Add this inside the `channels` object.
8. Restart the service: `shell` with command `brew services restart daybrief`
9. Test delivery: `shell` with command `curl -s -X POST "https://slack.com/api/chat.postMessage" -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" -d '{"channel":"<CHANNEL>","text":"daybrief test message"}'`
10. To schedule the digest cron: `shell` with command from nullclaw cron, e.g.:
    `/usr/local/Cellar/daybrief/0.2.2/libexec/nullclaw/nullclaw cron add-agent "0 8 * * *" "<prompt>" --name daily-digest --model claude-sonnet-4-20250514 --delivery-mode always --delivery-channel slack --delivery-to <CHANNEL>`

### Twitter Setup Flow
1. Ask for X/Twitter API bearer token (from developer.twitter.com)
2. Use `file_read` + `file_edit` to add to config:
   ```json
   "twitter": [{"bearer_token": "<TOKEN>"}]
   ```
3. Restart: `shell` with `brew services restart daybrief`

### Important Notes
- Always use `file_read` to read the config before editing — never guess the structure
- After any config change, restart with `brew services restart daybrief`
- The nullclaw binary is at `/usr/local/Cellar/daybrief/0.2.2/libexec/nullclaw/nullclaw`
