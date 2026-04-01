Now I have all the data needed. Here's the complete security audit report:

---

# Security Audit: nextlevelbuilder/goclaw

## Repository Overview

GoClaw is a PostgreSQL multi-tenant AI agent gateway providing WebSocket RPC and HTTP API for LLM-powered agents. It supports multiple LLM providers (Anthropic, OpenAI, DashScope, Claude CLI), Telegram/Discord/WhatsApp channels, Docker-sandboxed code execution, RBAC, AES-256-GCM encrypted secrets, and a React web dashboard. A desktop edition (Wails + SQLite) is also available.

- **Tech stack:** Go 1.26, PostgreSQL/pgvector, pgx/v5, gorilla/websocket, React 19, Vite 6, TypeScript, Tailwind CSS 4, Wails v2
- **Languages:** Go (backend), TypeScript (frontend)
- **Maturity:** Growing -- well-architected with comprehensive security layers, active development
- **Categories detected:** ai | actions | crypto-primitives

## Critical & High Severity Findings

### Finding 1: GitHub Actions -- No SHA Pinning on Third-Party Actions
- **Severity:** HIGH
- **Category:** supply-chain
- **Location:** `.github/workflows/claude.yml:35`, `.github/workflows/claude-code-review.yml:36`, `.github/workflows/release.yaml:27`, `.github/workflows/release-desktop.yaml:166`
- **Description:** All third-party actions use tag-based references (`@v1`, `@v2`, `@v4`) instead of SHA-pinned references. Tag-based references are mutable -- a compromised upstream action can replace a tag to inject malicious code.
- **Impact:** Supply chain attack via compromised action could exfiltrate `CLAUDE_CODE_OAUTH_TOKEN`, `DOCKERHUB_TOKEN`, `GITHUB_TOKEN`, and gain write access to releases/packages.
- **Fix:** Pin all actions to commit SHAs: `uses: anthropics/claude-code-action@<sha256>`. Use Dependabot or Renovate to update SHAs automatically.
- **Confidence:** High

### Finding 2: Claude Workflow Lacks Contributor Admission Control
- **Severity:** HIGH
- **Category:** injection, auth
- **Location:** `.github/workflows/claude.yml:4-19`
- **Description:** The Claude Code workflow triggers on `issue_comment`, `pull_request_review_comment`, and `issues` events with `@claude` mentions. There is no filter on contributor association -- any external user can trigger Claude with write permissions to PRs and issues.
- **Impact:** External attacker could craft a comment containing prompt injection to manipulate Claude into modifying PRs, closing issues, or leaking repository context.
- **Fix:** Add contributor filter: `if: github.event.comment.author_association != 'NONE'` or restrict to `OWNER`/`COLLABORATOR`/`MEMBER`.
- **Confidence:** High

### Finding 3: CORS Defaults to Allow-All Origins
- **Severity:** HIGH
- **Category:** auth, config
- **Location:** `internal/gateway/server.go:116-132`
- **Description:** `checkOrigin()` returns `true` for all origins when `AllowedOrigins` is empty (the default). This means any website can establish WebSocket connections to the gateway.
- **Impact:** Cross-site WebSocket hijacking -- a malicious website could interact with a user's GoClaw gateway if they're on the same network, potentially sending commands as the user.
- **Fix:** Require explicit origin configuration for production. Log a security warning on startup if `AllowedOrigins` is empty (already done via `security.cors_open` log in `cmd/gateway.go`), but consider failing startup or requiring an explicit `"*"` to opt-in to open CORS.
- **Confidence:** High

### Finding 4: Input Guard Defaults to Warn-Only (No Blocking)
- **Severity:** HIGH
- **Category:** injection, ai
- **Location:** `internal/agent/input_guard.go`
- **Description:** The prompt injection detection system defaults to `"warn"` action -- it logs detected injections but does not block them. Production deployments that don't explicitly set `injection_action: "block"` are vulnerable.
- **Impact:** Prompt injection attacks against LLM agents can manipulate agent behavior, exfiltrate context files, or abuse tool access (shell execution, file system, web fetch).
- **Fix:** Default to `"block"` for production. Add startup validation that warns loudly if injection_action is not "block".
- **Confidence:** Medium (depends on deployment config)

### Finding 5: Rate Limiting Disabled by Default
- **Severity:** HIGH
- **Category:** dos, config
- **Location:** `internal/gateway/ratelimit.go:27-40`, `internal/gateway/server.go:104`
- **Description:** Rate limiter is disabled when `RateLimitRPM <= 0` (the default). Deployments that don't configure this are exposed to unlimited API/WebSocket requests.
- **Impact:** Denial-of-service against the gateway; abuse of LLM API credits through rapid requests; resource exhaustion.
- **Fix:** Set a reasonable default RPM (e.g., 60) rather than 0. Require explicit opt-out via `rate_limit_rpm: -1`.
- **Confidence:** High

## Medium & Low Severity Findings

### Finding 6: Install Scripts Lack Checksum Verification
- **Severity:** MEDIUM
- **Category:** supply-chain
- **Location:** `scripts/install.sh`, `scripts/install-lite.sh`, `scripts/install-lite.ps1`
- **Description:** Install scripts download release binaries from GitHub but do not verify SHA256 checksums (which are generated in the release workflow at `.github/workflows/release.yaml:102-107`).
- **Impact:** MITM or compromised GitHub release could deliver malicious binaries.
- **Fix:** Add checksum download and verification step in install scripts before executing the binary.
- **Confidence:** High

### Finding 7: Docker Python/npm Dependencies Not Pinned
- **Severity:** MEDIUM
- **Category:** supply-chain
- **Location:** `Dockerfile:76-84`
- **Description:** `pip3 install` and `npm install -g` in the Dockerfile install latest package versions without lockfile pinning. Packages like `pypdf`, `pandas`, `openpyxl` are installed with `--break-system-packages`.
- **Impact:** Malicious package update or typosquatting could inject code into Docker images.
- **Fix:** Pin all Python dependencies in a `requirements.txt` with hashes. Use `npm ci` with lockfile for Node packages.
- **Confidence:** High

### Finding 8: Gorilla WebSocket Pre-Release Dependency
- **Severity:** MEDIUM
- **Category:** supply-chain
- **Location:** `go.mod:14` -- `github.com/gorilla/websocket v1.5.4-0.20250319132907-e064f32e3674`
- **Description:** Using a pre-release commit hash of gorilla/websocket rather than a stable tagged release.
- **Impact:** Untested code paths; no guarantee of security patches from the gorilla maintainers.
- **Fix:** Upgrade to stable v1.5.4 when released, or pin to the latest stable tag.
- **Confidence:** Medium

### Finding 9: `table` Parameter in SQL Helpers Not Validated
- **Severity:** MEDIUM
- **Category:** injection
- **Location:** `internal/store/pg/helpers.go:192`, `internal/store/pg/agents.go:558,610`
- **Description:** `execMapUpdate()` validates column names against `validColumnName` regex but does not validate the `table` parameter, which is interpolated directly into SQL. Currently safe because `table` is always a hardcoded string literal from Go code, but no defensive check prevents future misuse.
- **Impact:** If a code path ever passes user-controlled data as `table`, SQL injection would be possible.
- **Fix:** Add `validColumnName.MatchString(table)` check, or use a table allowlist.
- **Confidence:** Low (currently safe, defense-in-depth improvement)

### Finding 10: Encryption Backward Compatibility Allows Plaintext Fallback
- **Severity:** MEDIUM
- **Category:** crypto
- **Location:** `internal/crypto/aes.go:57-59,68`
- **Description:** `Decrypt()` returns unencrypted values as-is for backward compatibility. If `Encrypt()` is called with an empty key (line 20-22), plaintext is returned unchanged. This means credentials stored before encryption was enabled remain readable.
- **Impact:** During key rotation or migration, plaintext secrets may persist in the database longer than expected.
- **Fix:** Add a migration command that encrypts all plaintext values in the database. Log warnings when plaintext fallback is triggered.
- **Confidence:** Medium

### Finding 11: `math/rand` Used for Retry Jitter
- **Severity:** LOW
- **Category:** crypto
- **Location:** `internal/providers/retry.go:9`, `internal/channels/feishu/larkws.go:9`
- **Description:** `math/rand` (not `crypto/rand`) used for retry jitter timing. This is acceptable for jitter but worth noting.
- **Impact:** None -- jitter does not require cryptographic randomness.
- **Fix:** No fix needed. Could use `math/rand/v2` for consistency (already used in `internal/cron/retry.go`).
- **Confidence:** High (non-issue, informational)

### Finding 12: Docker Base Images Not Digest-Pinned
- **Severity:** LOW
- **Category:** supply-chain
- **Location:** `Dockerfile:4,13,58`
- **Description:** Base images `node:22-alpine`, `golang:1.26-bookworm`, `alpine:3.22` use tag references without SHA256 digest pinning.
- **Impact:** Rebuilds may pull different base images. A compromised Docker Hub tag could inject malicious base layer.
- **Fix:** Pin to digest: `FROM alpine:3.22@sha256:<digest>`.
- **Confidence:** Medium

### Finding 13: Desktop App Binary Not Code-Signed
- **Severity:** LOW
- **Category:** supply-chain
- **Location:** `.github/workflows/release-desktop.yaml:77-79`
- **Description:** macOS `.app` bundle is not code-signed (TODO comment in workflow). Triggers Gatekeeper warnings.
- **Impact:** Users must bypass macOS security to run the app. No integrity guarantee on downloaded binary.
- **Fix:** Obtain Apple Developer certificate and enable code signing in the release workflow.
- **Confidence:** High

## Supply Chain Analysis

**Dependency Health:**
- Go dependencies are generally well-maintained (pgx, cobra, telego, rod)
- gorilla/websocket uses a pre-release version (medium risk)
- Python/npm dependencies in Dockerfile are not pinned (medium risk)
- No `go.sum` audit failures detected

**CI/CD Pipeline:**
- GitHub Actions use tag-based references throughout (high risk)
- Docker Hub and GHCR credentials properly stored in GitHub Secrets
- Release workflow generates checksums but install scripts don't verify them
- No SBOM generation for Docker images

**No known CVEs** found in current Go dependency versions.

## Code Quality Assessment

**Architecture:** Excellent. Clean separation of concerns with interface-based store layer, 5-layer RBAC, defense-in-depth security patterns. Multi-tenant isolation enforced at the database query level.

**Error Handling:** Strong. Consistent use of `errors.Is()`, proper error propagation, informative error messages without leaking internals. Security events logged with `security.*` prefix.

**Test Coverage:** Good for security-critical paths (crypto roundtrip, symlink escape, shell deny patterns). Integration tests with race detector. Could benefit from more fuzzing of input validation.

**Documentation:** The CLAUDE.md is exceptionally detailed. Inline code comments are minimal but code is self-documenting. Missing: SECURITY.md, threat model documentation, production hardening guide.

## Contribution Opportunities

1. **File:** `.github/workflows/*.yml` (all workflow files)
   - **Issue:** All third-party actions use mutable tag references
   - **Fix:** Pin to SHA digests, add Dependabot for action updates
   - **Effort:** Small

2. **File:** `internal/gateway/server.go:116-132`
   - **Issue:** CORS defaults to allow-all; rate limiting defaults to disabled
   - **Fix:** Add production-safe defaults with explicit opt-out
   - **Effort:** Small

3. **File:** `scripts/install.sh`, `scripts/install-lite.sh`
   - **Issue:** No checksum verification of downloaded binaries
   - **Fix:** Download and verify SHA256 checksums from release assets
   - **Effort:** Small

4. **File:** `Dockerfile:76-91`
   - **Issue:** Unpinned Python/npm dependencies
   - **Fix:** Create `requirements.txt` with pinned versions and hashes
   - **Effort:** Small

5. **File:** `internal/store/pg/helpers.go:192`
   - **Issue:** `table` parameter not validated in SQL helper
   - **Fix:** Add table name validation or allowlist
   - **Effort:** Trivial

## Draft PRs

### PR 1: Pin GitHub Actions to SHA digests
- **PR Title:** `fix(ci): pin all third-party actions to commit SHAs`
- **Branch:** `fix/pin-action-shas`
- **Files:** `.github/workflows/ci.yaml`, `.github/workflows/claude.yml`, `.github/workflows/claude-code-review.yml`, `.github/workflows/docker-publish.yaml`, `.github/workflows/release.yaml`, `.github/workflows/release-desktop.yaml`
- **Changes:** Replace all `@v1`/`@v2`/`@v4` references with `@<sha256>` digests. Add Dependabot config for GitHub Actions updates.
- **Impact:** Eliminates supply chain attack vector through compromised action tags. Prevents silent code injection via mutable Git tags.

### PR 2: Add contributor filter to Claude workflow
- **PR Title:** `fix(ci): restrict Claude Code action to trusted contributors`
- **Branch:** `fix/claude-action-admission`
- **Files:** `.github/workflows/claude.yml`
- **Changes:** Add `github.event.comment.author_association` filter to only allow `OWNER`, `COLLABORATOR`, and `MEMBER` to trigger Claude. Prevents external users from invoking Claude with write permissions.
- **Impact:** Prevents prompt injection attacks from external contributors that could manipulate PRs/issues via Claude.

### PR 3: Harden production defaults (CORS, rate limiting, input guard)
- **PR Title:** `fix(security): enforce secure defaults for CORS, rate limiting, and input guard`
- **Branch:** `fix/secure-defaults`
- **Files:** `internal/gateway/server.go`, `internal/gateway/ratelimit.go`, `internal/agent/input_guard.go`, `internal/config/config.go`
- **Changes:** (1) Require explicit `"*"` in `AllowedOrigins` to allow all origins, otherwise reject cross-origin requests. (2) Set default `RateLimitRPM` to 60. (3) Default `injection_action` to `"block"`. (4) Add startup warnings for insecure configurations.
- **Impact:** Ensures new deployments are secure by default. Prevents CSRF/CSWSH, DoS, and prompt injection out of the box.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 9 |
| Security | 7 |
| Documentation | 7 |
| Test Coverage | 6 |
| Contribution Potential | 8 |

## Summary

- **Total findings by severity:** Critical: 0, High: 5, Medium: 5, Low: 3, Info: 0
- **Overall risk level:** **MEDIUM** -- The codebase has excellent security architecture (AES-256-GCM, RBAC, sandboxing, SSRF protection, shell deny patterns), but several security features default to permissive/disabled configurations, and CI/CD supply chain hardening is missing.

**Top 3 recommendations:**
1. **Pin all GitHub Actions to SHA digests** and add contributor admission control to the Claude workflow -- highest impact supply chain fix
2. **Harden production defaults** -- CORS should not default to allow-all, rate limiting should not default to disabled, input guard should default to block
3. **Add checksum verification to install scripts** and pin Docker/pip/npm dependencies -- closes the remaining supply chain gaps
