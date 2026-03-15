#!/bin/bash
# gitnightcrawler - Audit a single repo using Claude Code headless mode
# Generates a review MD file — does NOT push anything
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

# Build the prompt based on category
if [ "$CATEGORY" = "marketing" ]; then
AUDIT_PROMPT="$(cat <<'PROMPT'
You are auditing this open-source repository to find EASY, high-visibility contribution opportunities.
Focus on quick wins that maintainers will appreciate and merge fast.

Produce a markdown report with these sections:

# Marketing Audit: {repo_name}

## Quick Overview
- What it does (1 paragraph)
- Tech stack
- Activity level (commits/week, responsiveness to PRs)

## Quick Win PRs (prioritize these)
For each, provide ready-to-implement details:

### 1. Documentation Improvements
- README gaps, typos, missing examples, broken links
- Missing or incomplete API docs
- Better installation/setup instructions

### 2. Code Quality
- Missing type hints / annotations
- Linting issues
- Dead code removal
- Import cleanup

### 3. Tests
- Missing test files
- Untested edge cases
- Test infrastructure improvements

### 4. CI/CD
- Missing GitHub Actions
- Badge additions
- Automated checks

### 5. DX Improvements
- Better error messages
- Config file templates
- Docker/containerization

## Draft PRs
For the TOP 3 easiest and most impactful items, provide:
- **PR Title**: concise, conventional commit style
- **Branch**: `fix/...` or `feat/...` or `docs/...`
- **Files to change**: exact paths
- **Changes**: exact diff description, what to add/modify/remove
- **Effort**: time estimate
- **Merge likelihood**: high/medium/low and why

## Notes
- Any red flags (inactive maintainer, PR backlog, etc.)
- Best time/approach to submit
PROMPT
)"
else
AUDIT_PROMPT="$(cat <<'PROMPT'
You are auditing this open-source repository. Perform a thorough analysis.
Produce a markdown report with these sections:

# Audit: {repo_name}

## Repository Overview
- What does this project do? One paragraph.
- Tech stack, languages, frameworks.
- Maturity: early/growing/mature.

## Code Quality Assessment
- Architecture and organization.
- Error handling patterns.
- Test coverage (existence, quality).
- Documentation quality.
- Dependency health.

## Security Findings
Rate each: Critical / High / Medium / Low / Info
- Injection flaws, hardcoded secrets, unsafe patterns
- Auth/authz issues
- Dependency vulnerabilities
- Supply chain risks

## Contribution Opportunities
Ranked by impact. For each provide:
- **File**: path and line numbers
- **Issue**: what's wrong
- **Fix**: how to fix it
- **Effort**: trivial / small / medium / large
- **PR-worthy**: high / medium / low

### Bugs
### Security Fixes
### Missing Tests
### Documentation Gaps
### Code Improvements
### Feature Ideas

## Draft PRs
For the TOP 3 most impactful items:
- **PR Title**: concise, conventional commit style
- **Branch**: `fix/...` or `feat/...`
- **Files**: exact paths to modify
- **Changes**: detailed description of what to change
- **Effort**: time estimate
- **Impact**: why this matters

## Scores (1-10)
| Category | Score |
|----------|-------|
| Code Quality | |
| Security | |
| Documentation | |
| Test Coverage | |
| Contribution Potential | |
PROMPT
)"
fi

# Replace {repo_name} placeholder
AUDIT_PROMPT="${AUDIT_PROMPT//\{repo_name\}/$REPO_NAME}"

echo "[audit] Running Claude Code audit..." | tee -a "$LOG_FILE"

claude -p "$AUDIT_PROMPT" --output-format text 2>>"$LOG_FILE" > "$REPORT_FILE" || {
    echo "[audit] Claude Code failed for $REPO_NAME" | tee -a "$LOG_FILE"
    echo "# Audit Failed: $REPO_NAME" > "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Claude Code exited with error. Check logs: $LOG_FILE" >> "$REPORT_FILE"
}

echo "[audit] Report: $REPORT_FILE" | tee -a "$LOG_FILE"
echo "[audit] Done at $(date)" | tee -a "$LOG_FILE"
