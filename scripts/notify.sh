#!/bin/bash
# gitnightcrawler - Send morning summary via WhatsApp (CallMeBot)
# Usage: ./notify.sh <report_file>

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Load credentials
if [ ! -f "$ROOT/.env" ]; then
    echo "[notify] No .env file found. Skipping WhatsApp notification."
    exit 0
fi
source "$ROOT/.env"

if [ -z "${CALLMEBOT_PHONE:-}" ] || [ -z "${CALLMEBOT_APIKEY:-}" ]; then
    echo "[notify] CALLMEBOT_PHONE or CALLMEBOT_APIKEY not set. Skipping."
    exit 0
fi

REPORT_FILE="${1:-}"
DATE=$(date +%Y-%m-%d)

if [ -z "$REPORT_FILE" ]; then
    REPORT_FILE="$ROOT/reports/discovery-${DATE}.json"
fi

if [ ! -f "$REPORT_FILE" ]; then
    echo "[notify] Report not found: $REPORT_FILE"
    exit 1
fi

# Build summary message from discovery report
MESSAGE=$(python3 -c "
import json

r = json.loads(open('$REPORT_FILE').read())
lines = []
lines.append('*gitnightcrawler* - $DATE')
lines.append('')
lines.append('*Top Repos:*')
for i, repo in enumerate(r.get('top_repos', []), 1):
    m = repo['momentum']
    lines.append(f\"{i}. *{repo['full_name']}* ({repo['stars']:,} stars)\")
    lines.append(f\"   {repo['description'][:80]}\")
    lines.append(f\"   Score: {m['momentum_score']} | {repo['language']}\")
    lines.append('')

if r.get('marketing_repos'):
    lines.append('*Marketing Farm:*')
    for i, repo in enumerate(r.get('marketing_repos', []), 1):
        lines.append(f\"{i}. *{repo['full_name']}* ({repo['stars']:,} stars)\")
    lines.append('')

lines.append('Review: glow reports/morning-review-$DATE.md')
print('\n'.join(lines))
")

# URL-encode the message
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$MESSAGE'''))")

# Send via CallMeBot
RESPONSE=$(curl -s "https://api.callmebot.com/whatsapp.php?phone=${CALLMEBOT_PHONE}&text=${ENCODED}&apikey=${CALLMEBOT_APIKEY}")

echo "[notify] WhatsApp sent. Response: $RESPONSE"
