#!/bin/bash
# gitnightcrawler cron/launchd wrapper - no .zshrc dependency
export HOME="/Users/tradeverse"
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.nvm/versions/node/v25.1.0/bin:/usr/bin:/bin:/usr/sbin:/sbin"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/logs"
exec bash "$ROOT/scripts/nightcrawl.sh" >> "$ROOT/logs/cron.log" 2>&1
