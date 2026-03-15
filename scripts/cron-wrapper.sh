#!/bin/bash
# gitnightcrawler cron wrapper - loads env then runs nightcrawl
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.nvm/versions/node/v25.1.0/bin:$PATH"
source "$HOME/.zshrc" 2>/dev/null || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/scripts/nightcrawl.sh" >> "$ROOT/logs/cron.log" 2>&1
