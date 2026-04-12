# Security Audit: Light-Heart-Labs/DreamServer

## Repository Overview

DreamServer is a fully local AI stack (LLM inference, chat, voice, agents, workflows, RAG, image generation, privacy tools) deployed on user hardware with a single command. It supports Linux (NVIDIA + AMD), Windows (WSL2), and macOS (Apple Silicon). The codebase is primarily Bash (~110+ shell scripts including a ~45K line CLI), Python (FastAPI dashboard-api with 12 routers), and React/Vite (dashboard UI). The project is well-organized with a modular installer (13 sequential phases + pure function libraries), 21 extension services with manifests, and layered Docker Compose configurations.

- **Tech stack**: Bash, Python (FastAPI/uvicorn), React/Vite/Tailwind, Docker Compose, Rust (DreamForge)
- **Maturity**: Growing (active development, comprehensive CI, 21 workflows, 60+ test files)
- **Categories detected**: ai | actions | crypto-primitives

---

## Critical & High Severity Findings

### Finding 1: Unverified GPG Key Import for NVIDIA Repository

- **Severity**: CRITICAL
- **Category**: supply-chain
- **Location**: `dream-server/installers/phases/05-docker.sh:358-365`
- **Description**: The NVIDIA container toolkit GPG key is downloaded from `nvidia.github.io` and piped directly to `gpg --dearmor` with `|| true`, suppressing any errors. No fingerprint verification is performed before adding it to the system keyring, which then trusts all packages signed by this key.
- **Impact**: If `nvidia.github.io` is compromised or MITM'd, an attacker could substitute a malicious GPG key and push compromised NVIDIA packages to all DreamServer installations. The `|| true` means failures are silently ignored.
- **Fix**: Pin the expected GPG key fingerprint and verify after download: `gpg --with-colons --import-options show-only < key.asc | grep "^fpr:" | grep -q "$EXPECTED_FINGERPRINT"`. Remove `|| true`.
- **Confidence**: high

### Finding 2: Remote Script Execution as Root Without Verification

- **Severity**: HIGH
- **Category**: supply-chain
- **Location**: `dream-server/installers/phases/05-docker.sh:74,99` and `dream-server/installers/phases/07-devtools.sh:30-31,94-95`
- **Description**: Three separate remote scripts are downloaded via `curl` and executed with elevated privileges without any checksum or signature verification: Docker (`get.docker.com`), NodeSource (`deb.nodesource.com/setup_22.x` with `sudo -E`), and OpenCode (`opencode.ai/install`).
- **Impact**: MITM or domain compromise would allow arbitrary code execution as root on all installing machines. The `sudo -E` flag on NodeSource preserves environment variables, which could be an additional attack vector.
- **Fix**: (1) Verify checksums or GPG signatures before execution. (2) Prefer distro package managers where possible. (3) Remove `sudo -E` flag unless strictly necessary. (4) At minimum, warn the user before executing third-party scripts.
- **Confidence**: high

### Finding 3: Prompt Injection via GitHub Issues (AI Workflow)

- **Severity**: HIGH
- **Category**: injection (prompt injection)
- **Location**: `.github/workflows/issue-to-pr.yml:93-96`, `.github/workflows/nightly-code-review.yml:116-121`
- **Description**: User-controlled input from GitHub issue titles and bodies is passed to Claude Code CLI. While truncation (`head -c 4000`) and a disclaimer about ignoring instructions are present, these are weak defenses against prompt injection. An attacker can craft an issue body that overrides the system prompt instructions.
- **Impact**: An attacker could manipulate the AI agent to make malicious code changes, exfiltrate secrets via crafted PR descriptions, or bypass the protected file guardrails through indirect prompt manipulation.
- **Fix**: (1) Sanitize issue content more aggressively (strip markdown code blocks, special characters). (2) Use structured input rather than passing raw issue body. (3) Add post-generation review step that validates changes against a security policy. (4) Consider disabling auto-PR creation for external contributors.
- **Confidence**: medium

### Finding 4: Inconsistent GitHub Actions Version Pinning

- **Severity**: HIGH
- **Category**: supply-chain
- **Location**: Multiple workflows: `lint-python.yml`, `lint-shell.yml`, `dashboard.yml`, `matrix-smoke.yml`, `test-linux.yml`, `validate-compose.yml`
- **Description**: While security-sensitive workflows (issue-to-pr, claude-review) properly pin actions to commit SHAs, many CI workflows use version tags (`@v4`, `@v5`) instead of SHA pinning. This creates a tag-mutability supply chain risk.
- **Impact**: A compromised upstream action could inject malicious code into CI runs. Tag-based references can be silently updated by the action maintainer or an attacker who compromises their account.
- **Fix**: Pin all third-party actions to full commit SHAs across all workflow files. Use Dependabot or Renovate to manage SHA updates.
- **Confidence**: high

---

## Medium & Low Severity Findings

### Medium Severity

#### M1: CORS Auto-Discovery Exposes API to LAN

- **Severity**: MEDIUM
- **Category**: auth / network exposure
- **Location**: `dream-server/extensions/services/dashboard-api/main.py:891-908`
- **Description**: The FastAPI app auto-discovers all local network interfaces (192.168.*, 10.*, 172.*) and adds them as CORS allowed origins. Any machine on the same subnet can make cross-origin requests to the dashboard API.
- **Impact**: On shared networks (offices, cafes, dorms), other machines could make authenticated requests if the API key is known or leaked.
- **Fix**: Default to localhost-only CORS. Require explicit `DASHBOARD_ALLOWED_ORIGINS` env var for LAN access. Document the exposure clearly.
- **Confidence**: high

#### M2: OpenClaw Dangerous Auth Flags

- **Severity**: MEDIUM
- **Category**: auth / insecure defaults
- **Location**: `dream-server/config/openclaw/inject-token.js:51-53,203-205`
- **Description**: OpenClaw configuration sets `allowInsecureAuth = true`, `dangerouslyDisableDeviceAuth = true`, and `dangerouslyAllowHostHeaderOriginFallback = true`. While labeled as dangerous, these are default-on in all installations.
- **Impact**: If OpenClaw port is exposed beyond localhost (e.g., via tunnel or firewall misconfiguration), authentication protections are disabled.
- **Fix**: Document these flags prominently. Consider making them configurable via env vars with secure defaults that only relax for localhost.
- **Confidence**: high

#### M3: Overly Broad Python Dependency Ranges

- **Severity**: MEDIUM
- **Category**: supply-chain
- **Location**: `dream-server/extensions/services/dashboard-api/requirements.txt`, `privacy-shield/requirements.txt`
- **Description**: `python-multipart>=0.0.9,<1.0.0` allows any 0.x version back to 2017. `aiohttp>=3.9.0,<4.0.0` includes versions with known CVE-2024-28285 (ReDoS). `fastapi>=0.100.0` in privacy-shield allows Oct 2023 versions.
- **Impact**: Resolvers could install old, vulnerable versions of critical dependencies.
- **Fix**: Bump `aiohttp>=3.9.5`, `python-multipart>=0.0.24`, `fastapi>=0.115.0`. Add `pip-audit` to CI.
- **Confidence**: high

#### M4: Missing Explicit Workflow Permissions

- **Severity**: MEDIUM
- **Category**: actions / permissions
- **Location**: `.github/workflows/autonomous-code-scanner.yml`, `.github/workflows/nightly-code-review.yml` (preflight/code-review jobs)
- **Description**: Several workflows lack explicit `permissions:` blocks at the workflow level, inheriting default write permissions for the GITHUB_TOKEN.
- **Impact**: If a workflow is compromised (e.g., via supply chain), the token has broader access than necessary.
- **Fix**: Add `permissions: contents: read` at the workflow level and escalate only in jobs that need write access.
- **Confidence**: high

#### M5: API Key Visible in Process Listing

- **Severity**: MEDIUM
- **Category**: secret exposure
- **Location**: `dream-server/dream-cli:735`
- **Description**: The dashboard API key is extracted from `.env` and passed directly as a `curl` header argument: `curl -sf -H "X-API-Key: ${api_key}"`. This is visible to all users via `ps aux`.
- **Impact**: On multi-user systems, any local user can see the API key in the process list.
- **Fix**: Pass the header via a file descriptor or environment variable: `curl -sf -H @- <<< "X-API-Key: ${api_key}"` or use `--config -`.
- **Confidence**: high

### Low Severity

#### L1: OpenAPI Documentation Unauthenticated

- **Severity**: LOW
- **Category**: information disclosure
- **Location**: FastAPI default `/docs`, `/redoc`, `/openapi.json` endpoints
- **Description**: API schema is publicly accessible without authentication, revealing all endpoint signatures and data models.
- **Fix**: Set `docs_url=None, redoc_url=None` in production or gate behind auth.
- **Confidence**: high

#### L2: Missing Lock Files for Node Projects

- **Severity**: LOW
- **Category**: supply-chain
- **Location**: `resources/products/token-spy/dashboard/`, `installer/`, `dream-server/extensions/services/dreamforge/rust/frontend/`
- **Description**: Three Node.js projects lack `package-lock.json` files, meaning builds are not reproducible and transitive dependencies are not locked.
- **Fix**: Run `npm install` and commit the lock files.
- **Confidence**: high

#### L3: Non-Atomic File Writes for State Files

- **Severity**: LOW
- **Category**: reliability
- **Location**: `dashboard-api/helpers.py:78`, `dashboard-api/routers/extensions.py:103`
- **Description**: Token counter and progress files are written directly without atomic write patterns (write-then-rename), creating a race condition window where a crash could corrupt the file.
- **Fix**: Write to a temporary file in the same directory, then `os.rename()` to the target path.
- **Confidence**: medium

#### L4: Privacy Shield Regex-Only PII Detection

- **Severity**: LOW
- **Category**: logic / coverage gap
- **Location**: `dream-server/extensions/services/privacy-shield/`
- **Description**: Presidio (Microsoft's PII detection library) integration is commented out. The service relies on basic regex matching which will miss sophisticated PII patterns.
- **Fix**: Re-enable Presidio integration or document the coverage limitations clearly.
- **Confidence**: medium

#### L5: Unvalidated Port Number from Environment

- **Severity**: LOW
- **Category**: input validation
- **Location**: `dashboard-api/agent_monitor.py:55`
- **Description**: `CLUSTER_PROXY_PORT` is read from the environment without range validation and used in a URL construction.
- **Fix**: Validate port is an integer in range [1, 65535].
- **Confidence**: high

---

## Supply Chain Analysis

**Dependency Health:**
- APE service has excellent pinning (exact versions). Dashboard-api uses reasonable ranges. Privacy-shield and voice-agent have overly broad ranges.
- `aiohttp>=3.9.0` includes versions with CVE-2024-28285 (ReDoS) -- should bump minimum to 3.9.5.
- No `pip-audit` or `npm audit` in CI pipelines.

**Lock File Status:**
- Dashboard frontend: `package-lock.json` present
- Token Spy dashboard, Installer, DreamForge frontend: Missing lock files

**Pre-commit Security:**
- gitleaks v8.21.2 for secret scanning
- Private key detection hook
- Large file detection (500KB)

**Suspicious/Unmaintained Dependencies:** None detected. All direct dependencies are well-known, actively maintained packages.

**Rust Dependencies (DreamForge):** 9 crates in workspace; not deeply analyzed as DreamForge appears to be in early development.

---

## Code Quality Assessment

**Architecture and Organization:**
Excellent modular architecture. Installer uses a clean separation between pure function libraries (`installers/lib/`) and imperative phase scripts (`installers/phases/`). Extension system is well-designed with manifest-driven service discovery. Dashboard-api follows FastAPI best practices with router-based decomposition and dependency injection for auth.

**Error Handling:**
Strong. All shell scripts use `set -euo pipefail`. Python code follows "let it crash" philosophy per CLAUDE.md. FastAPI routers raise `HTTPException` rather than returning error values. Comprehensive trap handlers in the installer.

**Test Coverage:**
Good breadth: 62+ shell test scripts, 20 Python test files, 12 BATS files, 5 smoke tests, security-specific test suite (`test-secret-security.sh`). CI runs linting, type checking, multi-distro smoke tests, and compose validation.

**Documentation:**
Extensive. 43 docs files, comprehensive CLAUDE.md, ARCHITECTURE.md, CONTRIBUTING.md, SECURITY.md. Extension manifests serve as self-documenting configuration.

---

## Contribution Opportunities

| # | File | Issue | Fix | Effort |
|---|------|-------|-----|--------|
| 1 | `dream-server/installers/phases/05-docker.sh:358-365` | NVIDIA GPG key imported without fingerprint verification | Pin expected fingerprint, verify after download | small |
| 2 | Multiple workflow files | Inconsistent action SHA pinning | Pin all third-party actions to commit SHAs | small |
| 3 | `dashboard-api/requirements.txt`, `privacy-shield/requirements.txt` | Overly broad version ranges, aiohttp CVE | Bump minimums, add pip-audit to CI | trivial |
| 4 | `dashboard-api/main.py:891-908` | CORS auto-discovers LAN IPs by default | Default to localhost-only, require explicit opt-in | small |
| 5 | `config/openclaw/inject-token.js:51-53` | Dangerous auth flags always enabled | Make configurable via env vars with secure defaults | medium |

---

## Draft PRs

### PR 1: fix(security): verify NVIDIA GPG key fingerprint before import

- **Branch**: `fix/nvidia-gpg-key-verification`
- **Files to modify**: `dream-server/installers/phases/05-docker.sh`
- **Changes**: Add a `NVIDIA_GPG_FINGERPRINT` constant. After downloading the GPG key, verify the fingerprint matches before importing to the system keyring. Remove `|| true` to fail fast on errors. Add a similar verification step for the repository list URL.
- **Impact**: Prevents supply chain attacks via compromised NVIDIA package signing keys. Affects every Linux NVIDIA installation.

### PR 2: fix(ci): pin all GitHub Actions to commit SHAs

- **Branch**: `fix/pin-actions-shas`
- **Files to modify**: `lint-python.yml`, `lint-shell.yml`, `dashboard.yml`, `matrix-smoke.yml`, `test-linux.yml`, `validate-compose.yml`, `validate-env.yml`, `validate-catalog.yml`, `type-check-python.yml`, `lint-powershell.yml`
- **Changes**: Replace all `@v4`/`@v5` tag references with full commit SHA pinning (e.g., `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5`). Add a comment with the version tag for readability. Consider adding Dependabot config for automated SHA updates.
- **Impact**: Eliminates tag-mutability supply chain risk across all CI workflows. Aligns with security best practices already followed in the AI-powered workflows.

### PR 3: fix(deps): bump minimum dependency versions, add pip-audit

- **Branch**: `fix/dependency-versions`
- **Files to modify**: `dream-server/extensions/services/dashboard-api/requirements.txt`, `dream-server/extensions/services/privacy-shield/requirements.txt`, `.github/workflows/lint-python.yml`
- **Changes**: Bump `aiohttp>=3.9.5` (fixes CVE-2024-28285), `python-multipart>=0.0.24`, `fastapi>=0.115.0` in privacy-shield. Add a `pip-audit` step to the Python lint workflow. Add `npm audit` to the dashboard workflow.
- **Impact**: Closes known CVE exposure window and adds ongoing vulnerability scanning to CI.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 6 |
| Documentation | 8 |
| Test Coverage | 7 |
| Contribution Potential | 8 |

---

## Summary

- **Total findings by severity**: Critical: 1, High: 3, Medium: 5, Low: 5, Info: 0
- **Overall risk level**: **MEDIUM** -- The application has strong foundational security (timing-safe auth, localhost binding, extension sandboxing, safe subprocess handling, no eval/pickle/shell=True) but has supply chain gaps in the installer and CI.

**Top 3 recommendations:**
1. **Verify all remote scripts and GPG keys before execution** -- The installer downloads and runs 4 remote scripts as root without any signature or checksum verification. Pin expected fingerprints/checksums.
2. **Pin all GitHub Actions to commit SHAs and add dependency vulnerability scanning** -- Unify the inconsistent approach across workflows and add `pip-audit`/`npm audit` to CI.
3. **Restrict CORS and OpenClaw auth defaults** -- Default to localhost-only CORS origins and make OpenClaw's dangerous auth flags configurable rather than always-on.
