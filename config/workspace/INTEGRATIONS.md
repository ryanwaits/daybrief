## Integration Setup

You can help users set up integrations conversationally. Available tools:
- `setup_slack` — configure Slack delivery (needs bot_token + channel)
- `setup_twitter` — configure Twitter DM polling (needs bearer_token)
- `cron_update` — change digest delivery to Slack/email (delivery_mode, delivery_channel, delivery_to params)
- `test_delivery` — send a test message to verify setup
- `restart_service` — restart daybrief after config changes

### Slack Setup Flow
1. User needs a Slack app. Direct them to create one:
   https://api.slack.com/apps?new_app=1&manifest_yaml=display_information:name:daybrief%0A%20%20description:Daily%20digest%20delivery%0Aoauth_config:scopes:bot:%0A%20%20%20%20-%20chat:write
2. After installing to workspace, ask for the Bot User OAuth Token (starts with xoxb-)
3. Ask which channel to deliver digests to
4. Use `setup_slack` tool with token + channel
5. Use `test_delivery` to verify
6. Use `cron_update` with delivery_mode=always, delivery_channel=slack, delivery_to=<channel_id> to switch digest cron job
7. Use `restart_service` to restart daybrief

### Twitter Setup Flow
1. Ask for X/Twitter API bearer token (from developer.twitter.com)
2. Use `setup_twitter` tool with token
3. Use `restart_service` to restart daybrief
