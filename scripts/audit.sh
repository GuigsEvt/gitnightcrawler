#!/bin/bash
# gitnightcrawler - Audit a single repo using Claude Code headless mode
# Generates a review MD file - does NOT push anything
# Usage: ./audit.sh <repo_full_name> <repo_url> [marketing]

set -euo pipefail

REPO_NAME="$1"
REPO_URL="$2"
CATEGORY="${3:-main}"
SAFE_NAME=$(echo "$REPO_NAME" | tr '/' '_')
DATE=$(date +%Y-%m-%d)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

REPOS_DIR="$ROOT/repos"
REPORTS_DIR="$ROOT/reports"
LOGS_DIR="$ROOT/logs"

mkdir -p "$REPOS_DIR" "$REPORTS_DIR" "$LOGS_DIR"

REPO_DIR="$REPOS_DIR/$SAFE_NAME"
REPORT_FILE="$REPORTS_DIR/audit-${SAFE_NAME}-${DATE}.md"
LOG_FILE="$LOGS_DIR/audit-${SAFE_NAME}-${DATE}.log"

echo "[audit] Starting audit of $REPO_NAME ($CATEGORY)" | tee "$LOG_FILE"
echo "[audit] $(date)" | tee -a "$LOG_FILE"

# Clone or update
if [ -d "$REPO_DIR" ]; then
    echo "[audit] Updating existing clone..." | tee -a "$LOG_FILE"
    cd "$REPO_DIR"
    git pull --ff-only 2>&1 | tee -a "$LOG_FILE" || true
else
    echo "[audit] Cloning $REPO_URL..." | tee -a "$LOG_FILE"
    git clone --depth 50 "$REPO_URL" "$REPO_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

cd "$REPO_DIR"

# Load prompt from file
if [ "$CATEGORY" = "marketing" ]; then
    PROMPT_FILE="$ROOT/scripts/prompts/audit-marketing.txt"
else
    PROMPT_FILE="$ROOT/scripts/prompts/audit-main.txt"
fi

# Replace placeholder with actual repo name
AUDIT_PROMPT=$(sed "s|REPO_NAME_PLACEHOLDER|${REPO_NAME}|g" "$PROMPT_FILE")

echo "[audit] Running Claude Code audit..." | tee -a "$LOG_FILE"

# Allow nested claude invocation (cron runs fine, but manual testing from claude session needs this)
unset CLAUDECODE 2>/dev/null || true

claude -p "$AUDIT_PROMPT" --output-format text 2>>"$LOG_FILE" > "$REPORT_FILE" || {
    echo "[audit] Claude Code failed for $REPO_NAME" | tee -a "$LOG_FILE"
    echo "# Audit Failed: $REPO_NAME" > "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Claude Code exited with error. Check logs: $LOG_FILE" >> "$REPORT_FILE"
}

echo "[audit] Report: $REPORT_FILE" | tee -a "$LOG_FILE"
echo "[audit] Done at $(date)" | tee -a "$LOG_FILE"
