Now I have enough data for a comprehensive report.

# Audit: anthropics/claude-plugins-official

## Repository Overview

This is Anthropic's official plugin marketplace and directory for **Claude Code**, providing a curated collection of 49+ plugins (34 internal, 17+ external) that extend Claude Code with MCP server integrations, slash commands, skills, agents, and hooks. It serves as both a plugin registry (via `marketplace.json` with 1400 lines referencing ~100+ plugins including remote URLs) and a monorepo hosting plugin source code. The repository acts as the distribution channel for the `/plugin install` and `/plugin > Discover` flows in Claude Code.

**Tech stack:** TypeScript/Bun (CI validation scripts), Python (hooks), Shell scripts (automation), JSON (configuration/registry). No frameworks -- this is a configuration-heavy repo with minimal runtime code.

**Maturity:** Growing. First commit 2025-11-20, active development through 2026-03-26. ~170+ commits, 10+ contributors, primarily Anthropic employees. Rapid plugin additions with evolving conventions.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 7/10**

Clean separation between internal (`/plugins`) and external (`/external_plugins`) plugins. Each plugin follows a standardized structure (`plugin.json`, optional `.mcp.json`, `commands/`, `skills/`, `agents/`, `hooks/`). The `marketplace.json` serves as a centralized registry with three source types: local path, `git-subdir`, and `url`.

Inconsistencies:
- Some plugins place `plugin.json` at root, others under `.claude-plugin/plugin.json` (e.g., `fakechat`, `playground`)
- External plugins range from config-only (github, firebase) to full TypeScript projects (imessage, discord, telegram)
- No shared library code -- each plugin is fully self-contained, leading to duplication in channel plugins

### Error Handling Patterns
**Score: 6/10**

- CI validation scripts have proper error handling with typed error messages and exit codes
- Python hooks (security-guidance) silently swallow errors (`pass` in except blocks) -- reasonable for hooks but makes debugging hard
- The `security_reminder_hook.py` writes debug logs to `/tmp/security-warnings-log.txt` -- good pattern
- No structured error handling framework across plugins

### Test Coverage
**Score: 1/10**

**Zero test files exist in the repository.** No unit tests, no integration tests, no test configuration. Validation is performed entirely through 3 GitHub Actions workflows:
1. `validate-marketplace.yml` -- JSON structure validation
2. `validate-frontmatter.yml` -- YAML frontmatter validation
3. `close-external-prs.yml` -- Access control

The validation scripts themselves (`validate-marketplace.ts`, `validate-frontmatter.ts`, `check-marketplace-sorted.ts`) have no tests.

### Documentation Quality
**Score: 7/10**

- Root README provides clear structure overview and installation instructions
- `example-plugin` serves as a reference implementation
- Most plugins have README files (39 across repo)
- `imessage` has detailed ACCESS.md for security/access control
- Missing: plugin development guide beyond example-plugin, security policy, contribution standards for external plugins

### Dependency Health
**Score: 7/10**

- External plugins with `package.json` use minimal dependencies: `@modelcontextprotocol/sdk@^1.0.0`, `zod`, framework-specific libs
- Lock files present for all npm-based plugins (bun.lock format)
- The iMessage `bun.lock` was recently regenerated to remove internal Anthropic artifactory URLs (commit `12e9c01`)
- No `node_modules` committed
- CI uses pinned action versions (`actions/checkout@v4`, `oven-sh/setup-bun@v2`)

---

## Security Findings

### Low: Hardcoded OAuth Client ID in Slack Plugin
- **File:** `external_plugins/slack/.mcp.json:6`
- **Finding:** OAuth `clientId: "1601185624273.8899143856786"` is hardcoded
- **Risk:** OAuth client IDs are typically considered public (part of the OAuth flow visible in redirect URLs). This is standard practice for public OAuth applications. The client secret is not exposed.
- **Rating:** **Low** (public OAuth client ID, no secret exposed)

### Info: Debug Log File Written to /tmp
- **File:** `plugins/security-guidance/hooks/security_reminder_hook.py:14`
- **Finding:** `DEBUG_LOG_FILE = "/tmp/security-warnings-log.txt"` -- writes debug output to world-readable location
- **Risk:** Information disclosure of file paths being edited. Minimal risk but could leak working directory info.
- **Rating:** **Info**

### Info: Session State Files in ~/.claude
- **File:** `plugins/security-guidance/hooks/security_reminder_hook.py:131`
- **Finding:** Creates per-session state files at `~/.claude/security_warnings_state_{session_id}.json` with 30-day cleanup
- **Risk:** State file accumulation (cleaned probabilistically at 10% per run). No file locking.
- **Rating:** **Info**

### Info: npx with -y Flag in External Plugins
- **Files:** `external_plugins/firebase/.mcp.json`, `external_plugins/context7/.mcp.json`
- **Finding:** `npx -y` auto-installs packages without confirmation (`firebase-tools@latest`, etc.)
- **Risk:** Standard pattern for MCP servers, but `@latest` tag means any published version gets auto-installed. Supply chain risk mitigated by package being from official publisher (Google).
- **Rating:** **Info**

### Info: Docker Execution in Terraform Plugin
- **File:** `external_plugins/terraform/.mcp.json`
- **Finding:** Runs `docker run -i --rm hashicorp/terraform-mcp-server:0.4.0` with `TFE_TOKEN` env var
- **Risk:** Pinned to specific version (0.4.0), official HashiCorp image. Low risk.
- **Rating:** **Info**

### Medium: No Secret Scanning or Pre-commit Hooks
- **Finding:** No `.pre-commit-config.yaml`, no secret scanning CI step
- **Risk:** The `bun.lock` incident (commit `12e9c01` removing artifactory URLs) shows internal URLs have leaked before. No automated prevention.
- **Rating:** **Medium**

### Low: Marketplace SHA Pinning Inconsistency
- **Finding:** External URL-based plugins in `marketplace.json` use SHA pinning, but there's no verification that the SHA matches the actual content at install time within this repo's CI.
- **Rating:** **Low**

---

## Contribution Opportunities

### Bugs

1. **File:** `plugins/security-guidance/hooks/security_reminder_hook.py:98`
   - **Issue:** `eval(` pattern match is too broad -- matches `evaluate(`, `evaluation(`, `medieval(`, etc.
   - **Fix:** Use word boundary check or more specific patterns: `re.search(r'\beval\s*\(', content)`
   - **Effort:** trivial
   - **PR-worthy:** medium

2. **File:** `plugins/security-guidance/hooks/security_reminder_hook.py:118-119`
   - **Issue:** `pickle` substring match triggers on comments/strings mentioning pickle (e.g., `# don't use pickle`), and on variable names like `pickle_jar`
   - **Fix:** Match import statements or function calls specifically: `import pickle`, `pickle.load`, `pickle.loads`
   - **Effort:** small
   - **PR-worthy:** medium

### Security Fixes

3. **File:** `plugins/security-guidance/hooks/security_reminder_hook.py:14`
   - **Issue:** Debug log written to world-readable `/tmp/security-warnings-log.txt`
   - **Fix:** Use `tempfile.mkstemp()` or write to `~/.claude/` with proper permissions
   - **Effort:** trivial
   - **PR-worthy:** low

4. **File:** Repository root
   - **Issue:** No secret scanning in CI
   - **Fix:** Add `trufflehog` or `gitleaks` GitHub Action to scan PRs
   - **Effort:** small
   - **PR-worthy:** high

### Missing Tests

5. **File:** `.github/scripts/validate-marketplace.ts`
   - **Issue:** Zero test coverage for validation scripts. Edge cases (empty plugins array, missing fields, malformed URLs) untested.
   - **Fix:** Add `bun test` with test cases for each validator
   - **Effort:** medium
   - **PR-worthy:** high

6. **File:** `plugins/security-guidance/hooks/security_reminder_hook.py`
   - **Issue:** No tests for pattern matching logic. False positives/negatives go undetected.
   - **Fix:** Add pytest test suite with fixture data covering each security pattern
   - **Effort:** medium
   - **PR-worthy:** high

### Documentation Gaps

7. **File:** `README.md`
   - **Issue:** No SECURITY.md or security policy. No guidance for external plugin authors on credential handling, MCP server security, or hook safety.
   - **Fix:** Create SECURITY.md with responsible disclosure info and plugin security guidelines
   - **Effort:** small
   - **PR-worthy:** high

8. **File:** `README.md`
   - **Issue:** No CONTRIBUTING.md with plugin development standards, linting requirements, or review criteria
   - **Fix:** Create CONTRIBUTING.md referencing example-plugin and documenting plugin.json schema
   - **Effort:** small
   - **PR-worthy:** medium

### Code Improvements

9. **File:** `.claude-plugin/marketplace.json:30`
   - **Issue:** Internal plugin homepage URLs reference `claude-plugins-public` but repo is named `claude-plugins-official`
   - **Fix:** Update all homepage URLs to match actual repo name
   - **Effort:** trivial
   - **PR-worthy:** medium

10. **File:** `plugins/security-guidance/hooks/security_reminder_hook.py:227-228`
    - **Issue:** Probabilistic cleanup (10% chance) means state files could accumulate for months
    - **Fix:** Use a deterministic approach: check once per day based on last-cleanup timestamp
    - **Effort:** small
    - **PR-worthy:** low

### Feature Ideas

11. **File:** `.github/workflows/`
    - **Issue:** No automated link checking for homepage URLs in marketplace.json
    - **Fix:** Add CI job that validates homepage URLs return 200
    - **Effort:** small
    - **PR-worthy:** medium

12. **File:** `.github/workflows/`
    - **Issue:** No SHA verification for URL-sourced plugins
    - **Fix:** Add CI step that clones URL sources and verifies SHA matches
    - **Effort:** medium
    - **PR-worthy:** high

---

## Draft PRs

### PR 1: Add Secret Scanning to CI Pipeline
- **PR Title:** `chore: add gitleaks secret scanning to CI`
- **Branch:** `fix/add-secret-scanning`
- **Files:** `.github/workflows/scan-secrets.yml` (new)
- **Changes:** Add a GitHub Actions workflow triggered on PRs that runs `gitleaks` to detect hardcoded secrets, API keys, and internal URLs. Prevents repeat of the artifactory URL leak incident. Configure with `.gitleaks.toml` allowing known-safe patterns (OAuth client IDs).
- **Effort:** 1-2 hours
- **Impact:** Prevents credential leaks before they're merged. Directly addresses the historical artifactory URL leak.

### PR 2: Add Test Suite for CI Validation Scripts
- **PR Title:** `test: add unit tests for marketplace and frontmatter validators`
- **Branch:** `feat/validation-tests`
- **Files:** `.github/scripts/__tests__/validate-marketplace.test.ts`, `.github/scripts/__tests__/validate-frontmatter.test.ts`, `.github/scripts/__tests__/check-marketplace-sorted.test.ts`
- **Changes:** Add bun test suite covering: valid input, missing required fields, duplicate plugin names, unsorted entries, malformed YAML frontmatter, edge cases (empty arrays, special characters). Add `bun test` step to CI workflows.
- **Effort:** 3-4 hours
- **Impact:** Ensures CI validation catches regressions. Currently any refactor of validation scripts has zero safety net.

### PR 3: Fix False Positive Pattern Matching in Security Hook
- **PR Title:** `fix: reduce false positives in security reminder hook patterns`
- **Branch:** `fix/security-hook-patterns`
- **Files:** `plugins/security-guidance/hooks/security_reminder_hook.py`
- **Changes:** Replace substring-based matching with regex patterns using word boundaries for `eval(`, `pickle`, `os.system`. Change `"eval("` to `r'\beval\s*\('`, change `"pickle"` to match only `import pickle` or `pickle.load/loads/dump/dumps`. Add comment documenting each pattern's intent. Move debug log from `/tmp` to `~/.claude/` directory.
- **Effort:** 1-2 hours
- **Impact:** Reduces developer friction from false security warnings, improving plugin adoption and trust in the security guidance system.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 7 |
| Documentation | 6 |
| Test Coverage | 1 |
| Contribution Potential | 8 |

**Summary:** A well-organized plugin marketplace with clean architecture but significant gaps in testing (zero tests) and contributor documentation. Security posture is reasonable -- credentials use env var templates, OAuth client IDs are appropriately public, and the security-guidance hook is a good defensive pattern. The biggest opportunities are adding a test suite for the validation infrastructure and implementing secret scanning to prevent future leaks.
