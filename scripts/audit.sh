#!/bin/bash
# gitnightcrawler - Audit a single repo using Claude Code with Trail of Bits skills
# Detects repo type and applies relevant security skills
# Usage: ./audit.sh <repo_full_name> <repo_url> [marketing]

set -euo pipefail

REPO_NAME="$1"
REPO_URL="$2"
CATEGORY="${3:-main}"
SAFE_NAME=$(echo "$REPO_NAME" | tr '/' '_')
DATE=$(date +%Y-%m-%d)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

REPOS_DIR="$ROOT/repos"
REPORTS_DIR="$ROOT/reports/$DATE"
LOGS_DIR="$ROOT/logs"

mkdir -p "$REPOS_DIR" "$REPORTS_DIR" "$LOGS_DIR"

REPO_DIR="$REPOS_DIR/$SAFE_NAME"
REPORT_FILE="$REPORTS_DIR/audit-${SAFE_NAME}.md"
LOG_FILE="$LOGS_DIR/audit-${SAFE_NAME}-${DATE}.log"

# Skip if report already exists for today
if [ -f "$REPORT_FILE" ] && [ -s "$REPORT_FILE" ]; then
    LINES=$(wc -l < "$REPORT_FILE")
    if [ "$LINES" -gt 20 ]; then
        echo "[audit] Report already exists for $REPO_NAME ($REPORT_FILE), skipping." | tee "$LOG_FILE"
        exit 0
    fi
fi

echo "[audit] Starting audit of $REPO_NAME ($CATEGORY)" | tee "$LOG_FILE"
echo "[audit] $(date)" | tee -a "$LOG_FILE"

# Clone or update - no depth limit for skills-based audit
if [ -d "$REPO_DIR" ]; then
    echo "[audit] Updating existing clone..." | tee -a "$LOG_FILE"
    cd "$REPO_DIR"
    git fetch --all 2>&1 | tee -a "$LOG_FILE" || true
    git reset --hard origin/$(git rev-parse --abbrev-ref HEAD) 2>&1 | tee -a "$LOG_FILE" || true
else
    echo "[audit] Cloning $REPO_URL..." | tee -a "$LOG_FILE"
    git clone "$REPO_URL" "$REPO_DIR" 2>&1 | tee -a "$LOG_FILE"
fi

cd "$REPO_DIR"

# Detect repo type
REPO_CATEGORIES=$(bash "$ROOT/scripts/detect-repo-type.sh" "$REPO_DIR" 2>/dev/null || echo "general")
echo "[audit] Detected categories: $REPO_CATEGORIES" | tee -a "$LOG_FILE"

# Build the blockchain-specific analysis guidance
BLOCKCHAIN_SKILLS=""
if echo "$REPO_CATEGORIES" | grep -q "ethereum"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (Ethereum/EVM):
- Analyze ERC20/ERC721 token implementations for conformity issues
- Check for reentrancy, flash loan attacks, oracle manipulation, front-running
- Review access controls, upgradeability patterns (proxy, UUPS, transparent)
- Check for unchecked return values on external calls
- Look for integer overflow/underflow in arithmetic operations"
elif echo "$REPO_CATEGORIES" | grep -q "solana"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (Solana):
- Check for arbitrary CPI (cross-program invocation) vulnerabilities
- Verify missing signer checks and PDA (Program Derived Address) validation
- Review account ownership verification and account confusion attacks
- Check for missing rent-exempt checks"
elif echo "$REPO_CATEGORIES" | grep -q "cairo"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (StarkNet/Cairo):
- Check for felt252 arithmetic overflow issues
- Review L1-L2 messaging for validation gaps
- Check for address conversion problems and signature replay"
elif echo "$REPO_CATEGORIES" | grep -q "algorand"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (Algorand):
- Check for rekeying attacks and unchecked transaction fees
- Review missing field validations and access control issues
- Verify group transaction atomicity"
elif echo "$REPO_CATEGORIES" | grep -q "cosmos"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (Cosmos):
- Check for non-determinism in state transitions (maps, floats, time)
- Review incorrect signers and ABCI panics
- Check for rounding errors and missing error handling"
elif echo "$REPO_CATEGORIES" | grep -q "substrate"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (Substrate/Polkadot):
- Check for arithmetic overflow and panic-induced DoS
- Review incorrect weights and bad origin checks
- Verify proper storage migration handling"
elif echo "$REPO_CATEGORIES" | grep -q "ton"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (TON):
- Check for integer-as-boolean misuse in FunC
- Review for fake Jetton contract attacks
- Verify forward TON amount includes gas costs"
elif echo "$REPO_CATEGORIES" | grep -q "blockchain"; then
    BLOCKCHAIN_SKILLS="Blockchain-specific (General):
- Review smart contract patterns for common vulnerabilities
- Check token handling and DeFi integration patterns
- Review access controls and privilege escalation vectors"
else
    BLOCKCHAIN_SKILLS="(Not a blockchain project - skip blockchain-specific checks)"
fi

# Select prompt based on category and build via Python (handles multiline substitution)
if [ "$CATEGORY" = "marketing" ]; then
    PROMPT_FILE="$ROOT/scripts/prompts/audit-marketing.txt"
    AUDIT_PROMPT=$(python3 -c "
import sys
template = open('$PROMPT_FILE').read()
print(template.replace('REPO_NAME_PLACEHOLDER', '$REPO_NAME'))
")
else
    PROMPT_FILE="$ROOT/scripts/prompts/audit-skills.txt"
    AUDIT_PROMPT=$(python3 -c "
import sys
template = open('$PROMPT_FILE').read()
blockchain_skills = '''$BLOCKCHAIN_SKILLS'''
result = template.replace('REPO_NAME_PLACEHOLDER', '$REPO_NAME')
result = result.replace('REPO_CATEGORIES_PLACEHOLDER', '$REPO_CATEGORIES')
result = result.replace('SKILLS_BLOCKCHAIN_PLACEHOLDER', blockchain_skills)
print(result)
")
fi

echo "[audit] Running Claude Code skills-based audit..." | tee -a "$LOG_FILE"
echo "[audit] Categories: $REPO_CATEGORIES" | tee -a "$LOG_FILE"

# Allow nested claude invocation
unset CLAUDECODE 2>/dev/null || true

# Run audit with dangerously-skip-permissions for headless mode
# Use higher model for better analysis
claude -p "$AUDIT_PROMPT" \
    --dangerously-skip-permissions \
    --output-format text \
    2>>"$LOG_FILE" > "$REPORT_FILE" || {
    echo "[audit] Claude Code failed for $REPO_NAME" | tee -a "$LOG_FILE"
    echo "# Audit Failed: $REPO_NAME" > "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Claude Code exited with error. Check logs: $LOG_FILE" >> "$REPORT_FILE"
}

# Extract severity counts for the notification system
CRITICAL_COUNT=$(grep -ci "CRITICAL" "$REPORT_FILE" 2>/dev/null || echo "0")
HIGH_COUNT=$(grep -ci "HIGH" "$REPORT_FILE" 2>/dev/null || echo "0")

# Write a findings summary file for the notification script
FINDINGS_FILE="$REPORTS_DIR/findings-${SAFE_NAME}.json"
python3 -c "
import json, re

report = open('$REPORT_FILE').read()

# Count severity markers - handle both **Severity**: X and **Severity:** X formats
sev_pat = r'(?i)\*\*severity[:\*]*\*?\*?:?\s*'
critical = len(re.findall(sev_pat + r'critical', report))
high = len(re.findall(sev_pat + r'high', report))
medium = len(re.findall(sev_pat + r'medium', report))
low = len(re.findall(sev_pat + r'low', report))

# Fallback: count '- **Severity:** HIGH' style (colon inside bold)
if critical + high + medium + low == 0:
    critical = len(re.findall(r'(?i)severity.*?critical', report))
    high = len(re.findall(r'(?i)severity.*?high', report))
    medium = len(re.findall(r'(?i)severity.*?medium', report))
    low = len(re.findall(r'(?i)severity.*?low', report))

# Extract overall risk level
risk_match = re.search(r'(?i)overall risk level[\*\*:\s]*(CRITICAL|HIGH|MEDIUM|LOW)', report)
risk_level = risk_match.group(1).upper() if risk_match else 'UNKNOWN'

# Extract top findings (first 3 critical/high)
findings = []
for m in re.finditer(r'(?i)\*\*severity[:\*]*\*?\*?:?\s*(CRITICAL|HIGH).*?\n.*?\*\*(?:Description|Category|Location)[:\*]*\*?\*?:?\s*(.*?)(?:\n|$)', report):
    findings.append({'severity': m.group(1).upper(), 'summary': m.group(2).strip()[:100]})
    if len(findings) >= 3:
        break

json.dump({
    'repo': '$REPO_NAME',
    'categories': '$REPO_CATEGORIES',
    'critical': critical,
    'high': high,
    'medium': medium,
    'low': low,
    'risk_level': risk_level,
    'top_findings': findings
}, open('$FINDINGS_FILE', 'w'), indent=2)
"

echo "[audit] Report: $REPORT_FILE" | tee -a "$LOG_FILE"
echo "[audit] Findings: $FINDINGS_FILE" | tee -a "$LOG_FILE"
echo "[audit] Done at $(date)" | tee -a "$LOG_FILE"
