#!/bin/bash
# gitnightcrawler - Send morning summary via WhatsApp (CallMeBot)
# Now includes critical/high severity security alerts
# Usage: ./notify.sh <discovery_report> <report_url>

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
REPORT_DIR="$ROOT/reports/$DATE"

if [ -z "$REPORT_FILE" ]; then
    REPORT_FILE="$REPORT_DIR/discovery.json"
    # Fallback to old location
    if [ ! -f "$REPORT_FILE" ]; then
        REPORT_FILE="$ROOT/reports/discovery-${DATE}.json"
    fi
fi

if [ -z "$REPORT_URL" ]; then
    REPORT_URL="https://github.com/GuigsEvt/gitnightcrawler/blob/main/reports/${DATE}/morning-review.md"
fi

if [ ! -f "$REPORT_FILE" ]; then
    echo "[notify] Report not found: $REPORT_FILE"
    exit 1
fi

# Build message and send entirely in Python
python3 << PYEOF
import json
import glob
import os
import urllib.parse
import urllib.request

r = json.loads(open("$REPORT_FILE").read())
report_dir = "$REPORT_DIR"

# Collect security findings
findings_files = glob.glob(os.path.join(report_dir, "findings-*.json"))
total_critical = 0
total_high = 0
alert_repos = []

for f in sorted(findings_files):
    try:
        data = json.load(open(f))
        c = data.get("critical", 0)
        h = data.get("high", 0)
        total_critical += c
        total_high += h
        if c > 0 or h > 0:
            alert_repos.append({
                "repo": data["repo"],
                "critical": c,
                "high": h,
                "risk": data.get("risk_level", "UNKNOWN"),
                "categories": data.get("categories", "general"),
                "findings": data.get("top_findings", [])
            })
    except Exception:
        pass

parts = ["gitnightcrawler $DATE"]

# Security alerts first (most important)
if total_critical > 0 or total_high > 0:
    parts.append(f"SECURITY ALERT: {total_critical} CRITICAL, {total_high} HIGH findings")
    for ar in alert_repos[:3]:
        alert_str = f"  {ar['repo']}: {ar['critical']}C/{ar['high']}H ({ar['categories']})"
        # Add top finding summary
        if ar.get("findings"):
            alert_str += f" - {ar['findings'][0].get('summary', '')[:60]}"
        parts.append(alert_str)

# Top repos summary
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
    parts.append("Mkt:")
    for i, repo in enumerate(mkt[:2], 1):
        parts.append(f"{i}. {repo['full_name']} ({repo['stars']} stars)")

parts.append(f"Report: $REPORT_URL")

msg = " -- ".join(parts)
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

# If there are critical findings, send a second urgent message
if total_critical > 0:
    urgent_parts = [f"URGENT - {total_critical} CRITICAL vulns found"]
    for ar in alert_repos:
        if ar["critical"] > 0:
            urgent_parts.append(f"{ar['repo']}: {ar['critical']} critical ({ar['risk']} risk)")
            for finding in ar.get("findings", [])[:2]:
                if finding.get("severity") == "CRITICAL":
                    urgent_parts.append(f"  -> {finding.get('summary', 'N/A')[:80]}")
    urgent_parts.append(f"Report: $REPORT_URL")
    urgent_msg = " -- ".join(urgent_parts)
    urgent_encoded = urllib.parse.quote_plus(urgent_msg)
    urgent_url = f"https://api.callmebot.com/whatsapp.php?phone=${CALLMEBOT_PHONE}&text={urgent_encoded}&apikey=${CALLMEBOT_APIKEY}"
    try:
        req = urllib.request.Request(urgent_url)
        resp = urllib.request.urlopen(req, timeout=30)
        body = resp.read().decode()
        if "queued" in body.lower():
            print("[notify] Urgent alert sent")
        else:
            print(f"[notify] Urgent response: {body[:200]}")
    except Exception as e:
        print(f"[notify] Urgent alert failed: {e}")
PYEOF
