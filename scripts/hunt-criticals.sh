#!/bin/bash
# Hunt for repos with CRITICAL findings
# Audits repos one by one, skipping already-audited ones
# Creates a critical-<repo>.md if critical findings are found
# Usage: ./hunt-criticals.sh [max_repos] [discovery_file]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(date +%Y-%m-%d)
MAX_REPOS="${1:-10}"
DISCOVERY="${2:-$ROOT/reports/$DATE/discovery.json}"
TRACKER="$ROOT/reports/audited-repos.md"
REPORT_DIR="$ROOT/reports/$DATE"

mkdir -p "$REPORT_DIR"

if [ ! -f "$DISCOVERY" ]; then
    # Fallback to compat path
    DISCOVERY="$ROOT/reports/discovery-${DATE}.json"
fi

if [ ! -f "$DISCOVERY" ]; then
    echo "[hunt] No discovery file found. Run nightcrawl.sh --discover-only first."
    exit 1
fi

# Get all repos from discovery (main + marketing)
REPO_LIST=$(python3 -c "
import json
r = json.loads(open('$DISCOVERY').read())
for repo in r.get('top_repos', []):
    print(f\"{repo['full_name']}|{repo['url']}\")
for repo in r.get('marketing_repos', []):
    print(f\"{repo['full_name']}|{repo['url']}\")
")

AUDITED=0
FOUND_CRITICAL=0

echo "============================================"
echo "  Critical Hunt - $DATE"
echo "  Max repos: $MAX_REPOS"
echo "============================================"

while IFS='|' read -r name url; do
    # Skip if already audited
    if grep -qF "$name" "$TRACKER" 2>/dev/null; then
        echo "[skip] $name (already audited)"
        continue
    fi

    AUDITED=$((AUDITED + 1))
    echo ""
    echo "[$AUDITED/$MAX_REPOS] Auditing: $name"
    echo "  URL: $url"

    # Run audit
    bash "$ROOT/scripts/audit.sh" "$name" "$url" "main" || {
        echo "[warn] Audit failed for $name"
        continue
    }

    SAFE_NAME=$(echo "$name" | tr '/' '_')
    FINDINGS="$REPORT_DIR/findings-${SAFE_NAME}.json"
    REPORT="$REPORT_DIR/audit-${SAFE_NAME}.md"

    if [ ! -f "$FINDINGS" ]; then
        echo "[warn] No findings file for $name"
        continue
    fi

    # Read findings
    CRITICAL=$(python3 -c "import json; print(json.load(open('$FINDINGS')).get('critical', 0))")
    HIGH=$(python3 -c "import json; print(json.load(open('$FINDINGS')).get('high', 0))")
    MEDIUM=$(python3 -c "import json; print(json.load(open('$FINDINGS')).get('medium', 0))")
    LOW=$(python3 -c "import json; print(json.load(open('$FINDINGS')).get('low', 0))")
    RISK=$(python3 -c "import json; print(json.load(open('$FINDINGS')).get('risk_level', 'UNKNOWN'))")
    CATS=$(python3 -c "import json; print(json.load(open('$FINDINGS')).get('categories', 'general'))")

    echo "  Results: Critical=$CRITICAL High=$HIGH Medium=$MEDIUM Low=$LOW Risk=$RISK"

    # Update tracker
    echo "| $name | $DATE | $CATS | $CRITICAL | $HIGH | $MEDIUM | $LOW | $RISK |" >> "$TRACKER"

    # If critical found, create critical report
    if [ "$CRITICAL" -gt 0 ]; then
        CRITICAL_FILE="$REPORT_DIR/CRITICAL-${SAFE_NAME}.md"
        cat > "$CRITICAL_FILE" << CEOF
# CRITICAL FINDINGS: $name

> Date: $DATE
> Categories: $CATS
> Findings: $CRITICAL critical, $HIGH high, $MEDIUM medium, $LOW low

---

CEOF
        # Extract critical findings from the audit report
        python3 -c "
import re
report = open('$REPORT').read()
# Find sections mentioning CRITICAL
lines = report.split('\n')
in_critical = False
for i, line in enumerate(lines):
    if 'CRITICAL' in line.upper() and ('severity' in line.lower() or 'finding' in line.lower() or '###' in line):
        in_critical = True
    if in_critical:
        print(line)
        # Stop after blank line following content
        if line.strip() == '' and i > 0 and lines[i-1].strip() == '':
            in_critical = False
" >> "$CRITICAL_FILE"

        echo ""
        echo "  *** CRITICAL FOUND in $name ***"
        echo "  Critical report: $CRITICAL_FILE"
        FOUND_CRITICAL=$((FOUND_CRITICAL + 1))
    fi

    if [ "$AUDITED" -ge "$MAX_REPOS" ]; then
        echo ""
        echo "[hunt] Reached max repos ($MAX_REPOS). Stopping."
        break
    fi
done <<< "$REPO_LIST"

echo ""
echo "============================================"
echo "  Hunt Complete"
echo "  Audited: $AUDITED repos"
echo "  Criticals found: $FOUND_CRITICAL"
echo "============================================"
