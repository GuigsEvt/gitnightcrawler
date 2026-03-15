#!/bin/bash
# gitnightcrawler - Setup nightly cron job
# Runs at 2 AM daily via crontab

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$ROOT/scripts/cron-wrapper.sh"

# Create a wrapper that loads the shell environment
cat > "$WRAPPER" << 'EOF'
#!/bin/bash
# gitnightcrawler cron wrapper - loads env then runs nightcrawl
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.nvm/versions/node/v25.1.0/bin:$PATH"
source "$HOME/.zshrc" 2>/dev/null || true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/scripts/nightcrawl.sh" >> "$ROOT/logs/cron.log" 2>&1
EOF
chmod +x "$WRAPPER"

CRON_CMD="0 2 * * * /bin/bash $WRAPPER"
CRON_MARKER="# gitnightcrawler"

echo "[setup] Setting up nightly cron job..."
echo "[setup] Schedule: 2:00 AM daily"
echo "[setup] Wrapper: $WRAPPER"

# Check if already installed
if crontab -l 2>/dev/null | grep -q "gitnightcrawler"; then
    echo "[setup] Cron job already exists. Updating..."
    crontab -l 2>/dev/null | grep -v "gitnightcrawler" | { cat; echo "$CRON_CMD $CRON_MARKER"; } | crontab -
else
    echo "[setup] Installing new cron job..."
    (crontab -l 2>/dev/null; echo "$CRON_CMD $CRON_MARKER") | crontab -
fi

echo ""
echo "[setup] Current crontab:"
crontab -l 2>/dev/null | grep "gitnightcrawler" || echo "  (none - error)"

echo ""
echo "[setup] Done."
echo "[setup] Manual run:  bash $ROOT/scripts/nightcrawl.sh"
echo "[setup] Discover only: bash $ROOT/scripts/nightcrawl.sh --discover-only"
echo "[setup] Review:     glow $ROOT/reports/morning-review-\$(date +%Y-%m-%d).md"
