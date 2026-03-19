#!/bin/bash
# gitnightcrawler cron/launchd wrapper - no .zshrc dependency
export HOME="/Users/tradeverse"
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.nvm/versions/node/v25.1.0/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK 2>/dev/null || echo /tmp/ssh-agent.sock)"
# Ensure ssh-agent has keys loaded for git push
ssh-add -l >/dev/null 2>&1 || ssh-add ~/.ssh/id_* 2>/dev/null || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/logs"
exec bash "$ROOT/scripts/nightcrawl.sh" >> "$ROOT/logs/cron.log" 2>&1
