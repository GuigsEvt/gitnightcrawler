#!/bin/bash
# gitnightcrawler - Setup nightly cron job
# Runs at 6 AM daily via crontab

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAPPER="$ROOT/scripts/cron-wrapper.sh"

chmod +x "$WRAPPER"

CRON_CMD="0 6 * * * /bin/bash $WRAPPER"
CRON_MARKER="# gitnightcrawler"

echo "[setup] Setting up nightly cron job..."
echo "[setup] Schedule: 6:00 AM daily"
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
echo "[setup] Review:     glow $ROOT/reports/\$(date +%Y-%m-%d)/morning-review.md"
