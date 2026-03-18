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
REPORT_URL="${2:-}"
DATE=$(date +%Y-%m-%d)

if [ -z "$REPORT_FILE" ]; then
    REPORT_FILE="$ROOT/reports/discovery-${DATE}.json"
fi

if [ -z "$REPORT_URL" ]; then
    REPORT_URL="https://github.com/GuigsEvt/gitnightcrawler/blob/main/reports/morning-review-${DATE}.md"
fi

if [ ! -f "$REPORT_FILE" ]; then
    echo "[notify] Report not found: $REPORT_FILE"
    exit 1
fi

# Build message and send entirely in Python
# CallMeBot rejects %0A newlines, so use flat format with -- separators
python3 << PYEOF
import json
import urllib.parse
import urllib.request

r = json.loads(open("$REPORT_FILE").read())
parts = ["gitnightcrawler $DATE"]

for i, repo in enumerate(r.get("top_repos", [])[:3], 1):
    m = repo["momentum"]
    stars = repo["stars"]
    if stars >= 1000:
        stars_str = f"{stars/1000:.1f}k"
    else:
        stars_str = str(stars)
    parts.append(f"{i}. {repo['full_name']} {stars_str} stars {repo['language']} score:{m['momentum_score']}")

mkt = r.get("marketing_repos", [])
if mkt:
    parts.append("-- Mkt:")
    for i, repo in enumerate(mkt[:2], 1):
        parts.append(f"{i}. {repo['full_name']} ({repo['stars']} stars)")

parts.append("-- Report: $REPORT_URL")

msg = " -- ".join(parts[:4]) + " " + " ".join(parts[4:])
# Use quote_plus: spaces become +, no newlines
encoded = urllib.parse.quote_plus(msg)

url = f"https://api.callmebot.com/whatsapp.php?phone=${CALLMEBOT_PHONE}&text={encoded}&apikey=${CALLMEBOT_APIKEY}"

try:
    req = urllib.request.Request(url)
    resp = urllib.request.urlopen(req, timeout=30)
    body = resp.read().decode()
    if "queued" in body.lower():
        print("[notify] WhatsApp sent successfully")
    else:
        print(f"[notify] Response: {body[:200]}")
except Exception as e:
    print(f"[notify] WhatsApp failed: {e}")
PYEOF
