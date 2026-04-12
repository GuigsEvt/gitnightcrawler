Now I have all the data needed. Here is the complete security audit report:

---

# Security Audit: moltis-org/moltis

## Repository Overview

Moltis is a Rust-based AI assistant platform (rewrite of openclaw) that provides a self-hosted, multi-channel chatbot with LLM provider integration, tool execution, MCP support, sandboxed code execution, and a web UI. It supports channels including Telegram, Discord, Slack, Matrix, WhatsApp, and MS Teams, with a web-based management interface and authentication system. The project includes 55+ Rust crates, a Preact-based web frontend, macOS/iOS native apps, and comprehensive CI/CD with Sigstore signing.

**Tech stack**: Rust (Tokio, Axum, SQLx/SQLite), JavaScript (Preact/HTM, Tailwind CSS), Swift (macOS/iOS), Docker/Apple Containers for sandboxing, WebAuthn/Passkeys, Argon2id, XChaCha20-Poly1305, VAPID push.

**Maturity**: Growing -- active development with 665+ merged PRs, comprehensive CI/CD, SLSA provenance, release signing, and well-structured workspace. Security is clearly a design priority.

**Categories detected**: ai | actions | crypto-primitives

---

## Critical & High Severity Findings

### FINDING-1: Shell Injection in Sandbox Package Check API

- **Severity**: HIGH
- **Category**: Injection (Command Injection)
- **Location**: `crates/web/src/api.rs:784-796`
- **Description**: The `api_check_packages_handler` interpolates user-controlled package names into a shell script using single-quote wrapping (`'{pkg}'`). A package name containing a single quote (e.g., `foo'; whoami; echo '`) breaks out of the single-quote context and executes arbitrary commands inside the container. Additionally, the `base` image parameter (L762-767) is entirely user-controlled with no validation, allowing an attacker to pull and run any Docker image.
- **Impact**: Arbitrary command execution inside the sandbox container. While container isolation limits blast radius, the container may have access to mounted volumes (workspace data). The unvalidated `base` image allows pulling attacker-controlled images.
- **Fix**: Validate package names against `^[a-zA-Z0-9._+\-]+$`. Validate `base` against an allowlist of known images or at least `^[a-z0-9._\-/]+:[a-z0-9._\-]+$`. Consider using `dpkg-query --show` with arguments passed via `--` to avoid shell interpolation entirely.
- **Confidence**: High

### FINDING-2: Dockerfile Injection in Image Build API

- **Severity**: HIGH
- **Category**: Injection (Command Injection)
- **Location**: `crates/web/src/api.rs:903-951`
- **Description**: The `api_build_image_handler` interpolates user-controlled `base` and `packages` values directly into a Dockerfile. The `name` is validated (alphanumeric/dash/underscore), but `base` has no validation -- newlines or Dockerfile directives could be injected. Package names are joined with spaces into a `RUN apt-get install -y` command without sanitization; shell metacharacters (`;`, `&&`, `|`, `$()`) would execute arbitrary commands during `docker build`.
- **Impact**: Arbitrary command execution during Docker build with network access. Build context includes a temp directory. An attacker could exfiltrate data, install backdoors in the resulting image, or abuse build-time network access.
- **Fix**: Validate `base` against `^[a-z0-9._\-/]+:[a-z0-9._\-]+$`. Validate each package name against `^[a-zA-Z0-9._+\-]+$`. Reject newlines in all inputs.
- **Confidence**: High

### FINDING-3: SAFE_BINS List Includes Command-Execution Primitives

- **Severity**: HIGH
- **Category**: Auth Bypass / Privilege Escalation
- **Location**: `crates/tools/src/approval.rs:78-136`
- **Description**: The `SAFE_BINS` allowlist includes `env`, `printenv`, `xargs`, `awk`, `sed`, and `tee` -- all of which bypass the tool approval flow. `env`/`printenv` can dump all environment variables including secrets. `xargs` can execute arbitrary commands (`echo 'cmd' | xargs`). `awk` has `system()`. `sed -i` can modify files. `tee` can write to arbitrary paths. These bypass approval even in `OnMiss` mode.
- **Impact**: An LLM manipulated via prompt injection could use these "safe" commands to exfiltrate secrets (`env`), execute arbitrary commands (`xargs`, `awk`), or modify files (`sed -i`, `tee`) without triggering the approval flow.
- **Fix**: Remove `env`, `printenv`, `xargs`, `awk`, `sed`, and `tee` from `SAFE_BINS`. These are not read-only utilities and should require approval. At minimum, add dangerous pattern detection for `env`, `printenv`, `xargs`, `awk system()`, `sed -i`, and `tee` to writable paths.
- **Confidence**: High

### FINDING-4: Config Access Control Gap During Setup Window

- **Severity**: HIGH
- **Category**: Auth Bypass
- **Location**: `crates/httpd/src/tools_routes.rs:56-82`
- **Description**: `require_config_access()` has a logic path where non-localhost requests with a credential store that exists but has setup not complete fall through to `Ok(())` at L82. This means during the initial setup window (before a password is set), any remote user on the network can access config endpoints (`config_get`, `config_save`, `restart`). The code comments indicate reliance on auth middleware as the sole gate, but this defense-in-depth check has a gap.
- **Impact**: During the initial setup window, remote attackers could read the full TOML config (potentially containing provider keys), write config, or restart the process. The window exists from first launch until a password is set.
- **Fix**: Add an explicit denial path: when setup is not complete and the request is not local, return 403. Change the fall-through at L68 to return an error instead of falling through to `Ok(())`.
- **Confidence**: Medium (depends on whether auth middleware fully covers this path)

---

## Medium & Low Severity Findings

### FINDING-5: Session Tokens Stored Unhashed in SQLite

- **Severity**: MEDIUM
- **Category**: Crypto / Session Management
- **Location**: `crates/auth/src/credential_store.rs:499-504`
- **Description**: Session tokens are stored in plaintext in the `auth_sessions` table. API keys are correctly hashed with SHA-256 before storage, but sessions are not. An attacker with read access to the SQLite database file can immediately impersonate any active session.
- **Impact**: Database file compromise (backup leak, path traversal, container escape) exposes all active sessions. API keys are protected; sessions are not.
- **Fix**: Hash session tokens with SHA-256 before storage (same pattern as API keys). Look up sessions by hash, not raw token.
- **Confidence**: High

### FINDING-6: No Rate Limiting on Login Endpoint

- **Severity**: MEDIUM
- **Category**: Auth / Brute Force
- **Location**: `crates/httpd/src/auth_routes.rs:286-325`
- **Description**: The login handler has no rate limiting, lockout mechanism, or failed-attempt tracking. While Argon2 is naturally slow (~500ms), there is no explicit mechanism to prevent sustained brute-force attacks. The rate limiter bypass for authenticated users (request_throttle.rs:246-257) means a compromised API key grants unlimited request rates.
- **Impact**: Password brute-force attacks are throttled only by Argon2 cost. With a weak password, an attacker could succeed within days of continuous attempts.
- **Fix**: Add a per-IP rate limit on `/api/auth/login` (e.g., 5 attempts per minute with exponential backoff). Add account lockout after N failed attempts. Do not bypass rate limits for auth endpoints even for authenticated users.
- **Confidence**: High

### FINDING-7: VAPID Private Key Stored Unencrypted with Default Permissions

- **Severity**: MEDIUM
- **Category**: Crypto / Secret Storage
- **Location**: `crates/gateway/src/push.rs:25-31, 271-274`
- **Description**: The VAPID signing key (P-256 private key in PEM format) is stored in `push.json` as a plaintext string. The `Debug` derive on `VapidKeys` (L25) exposes the private key in debug output. The file is written with `tokio::fs::write` (default permissions, typically 0644). The key is not encrypted by the vault.
- **Impact**: Any process or user with read access to the data directory can extract the VAPID signing key and forge push notifications. Debug logging could leak the key.
- **Fix**: Encrypt via vault. Implement manual `Debug` with `[REDACTED]` for `private_key_pem`. Set file permissions to 0600 on write.
- **Confidence**: High

### FINDING-8: TLS CA Private Key Written Without Restrictive Permissions

- **Severity**: MEDIUM
- **Category**: Crypto / File Security
- **Location**: `crates/tls/src/lib.rs:191-194`
- **Description**: The self-generated CA private key is written to `ca-key.pem` via `std::fs::write` without explicit file permission setting. On Unix systems, the default umask (typically 022) results in 0644 permissions, making the CA key world-readable.
- **Impact**: Any local user can read the CA private key and forge TLS certificates trusted by the moltis instance.
- **Fix**: Set file permissions to 0600 using `std::os::unix::fs::PermissionsExt` after writing.
- **Confidence**: High

### FINDING-9: Memory Persistence Loop Enables Durable Prompt Injection

- **Severity**: MEDIUM
- **Category**: AI / Prompt Injection
- **Location**: `crates/agents/src/prompt.rs:502-523`, `crates/agents/src/memory_writer.rs`
- **Description**: The LLM writes to MEMORY.md via the memory_writer tool, and MEMORY.md content is injected into future system prompts. A successful one-time prompt injection (via tool output, MCP response, or fetched web page) can instruct the LLM to write persistent injection content to MEMORY.md, creating a durable backdoor across sessions.
- **Impact**: Single prompt injection success persists across all future interactions. The attacker's instructions become part of the system prompt permanently until MEMORY.md is manually cleaned.
- **Fix**: Add content validation on memory writes (reject content matching known injection patterns). Consider requiring user confirmation for memory writes. Add a "sanitize memory" admin action.
- **Confidence**: Medium

### FINDING-10: Skill Description Injection into System Prompt

- **Severity**: MEDIUM
- **Category**: AI / Prompt Injection
- **Location**: `crates/skills/src/prompt_gen.rs:30-33`, `crates/skills/src/safety.rs:37-43`
- **Description**: Skill descriptions are injected verbatim into the system prompt XML without escaping. The safety scanner (`scan_skill_body`) is warn-only with a minimal 9-pattern heuristic that is trivially bypassed (Unicode homoglyphs, indirect instructions). Third-party skills installed from untrusted sources can inject arbitrary instructions into the system prompt.
- **Impact**: A malicious skill package could manipulate LLM behavior -- exfiltrating data, executing unauthorized commands, or changing responses.
- **Fix**: XML-escape skill names and descriptions before prompt injection. Strengthen the safety scanner to block (not just warn) on detected injection patterns. Consider sandboxing third-party skill descriptions with a prefix disclaimer.
- **Confidence**: Medium

### FINDING-11: Setup Code Non-Constant-Time Comparison

- **Severity**: LOW
- **Category**: Crypto / Timing Side-Channel
- **Location**: `crates/httpd/src/auth_routes.rs:179-183, 852, 905`
- **Description**: The 6-digit setup code is compared using `!=` (standard string comparison) instead of constant-time comparison. While `safe_equal` exists and is used for legacy env-var auth, the setup code path uses direct comparison.
- **Impact**: Minimal in practice -- the code is 6 digits, ephemeral, and used over HTTP where network jitter dwarfs timing signals. The inconsistency with `safe_equal` used elsewhere is the main concern.
- **Fix**: Use `safe_equal` or `subtle::ConstantTimeEq` for setup code comparison for consistency.
- **Confidence**: Low

### FINDING-12: 30-Day Session Lifetime Without Rotation

- **Severity**: LOW
- **Category**: Session Management
- **Location**: `crates/auth/src/credential_store.rs:500`
- **Description**: Sessions have a fixed 30-day expiry with no sliding window, refresh mechanism, or rotation. A stolen session token is valid for up to 30 days. Password change does invalidate all sessions.
- **Impact**: Long window of exposure for stolen session tokens.
- **Fix**: Implement session rotation (issue new token periodically). Consider shorter session lifetime with refresh tokens. Add a "revoke all sessions" UI action.
- **Confidence**: High

### FINDING-13: TOCTOU in SSRF DNS Resolution

- **Severity**: LOW
- **Category**: SSRF
- **Location**: `crates/tools/src/ssrf.rs:60-75`
- **Description**: DNS is resolved and IPs checked, but the subsequent HTTP connection may re-resolve the hostname. Short-TTL DNS rebinding could cause the actual connection to reach a private IP that was not present during the check.
- **Impact**: Theoretical SSRF bypass via DNS rebinding, requiring attacker-controlled DNS infrastructure.
- **Fix**: Pin the resolved IP address and pass it to the HTTP client directly, or use a custom DNS resolver that caches the checked result.
- **Confidence**: Low

### FINDING-14: Unpinned Binary Downloads in Release CI

- **Severity**: LOW
- **Category**: Supply Chain
- **Location**: `.github/workflows/release.yml:301, 395, 624, 1337`
- **Description**: `cargo install cargo-deb`, `cargo install cargo-generate-rpm`, `cargo install cargo-sbom` install the latest crate version at build time. `appimagetool` is downloaded from a `continuous` floating tag without checksum verification.
- **Impact**: A compromised crate or GitHub release could inject malicious code into release artifacts.
- **Fix**: Pin `cargo install` to specific versions (`--version X.Y.Z`). Pin `appimagetool` to a specific release tag and verify checksums.
- **Confidence**: Medium

### FINDING-15: No Dependabot/Renovate for Action SHA Updates

- **Severity**: LOW
- **Category**: Supply Chain
- **Location**: `.github/` (missing dependabot.yml)
- **Description**: All GitHub Actions are SHA-pinned (excellent), but there is no automated mechanism to update these pins when new versions are released. Security patches in actions require manual discovery and update.
- **Fix**: Add `.github/dependabot.yml` with `package-ecosystem: github-actions`.
- **Confidence**: High

---

## Supply Chain Analysis

**Strengths:**
- All 1,254 Cargo packages from standard crates.io registry
- Only 2 git dependencies (both from moltis-org fork, SHA-pinned)
- All workspace dependencies use explicit versions
- `Cargo.lock` committed and enforced with `cargo fetch --locked`
- All GitHub Actions SHA-pinned with version comments
- SLSA v1.0 Build Level 2 provenance
- GPG + Sigstore release signing
- Workspace lints deny `unsafe_code`, `.unwrap()`, `.expect()`
- Minimal JS dependencies (7 dev-only packages)

**Gaps:**
- No `cargo-audit` or `cargo-deny` in CI for automated CVE detection
- No Dependabot/Renovate configuration
- Multiple reqwest versions in tree (0.11, 0.12, 0.13) indicating some transitive dependency fragmentation
- Vendored JS bundles (preact, i18next, etc.) in `crates/web/src/assets/js/vendor/` -- manually managed, no automated update tracking
- mdBook/mdbook-admonish downloads in docs CI use pinned versions but no checksum verification

---

## Code Quality Assessment

**Architecture**: Excellent. 55-crate workspace with clear separation of concerns. Traits for behavior boundaries, async throughout, proper error handling with `anyhow`/`thiserror`.

**Error handling**: Strong. Workspace lints deny `.unwrap()`/`.expect()`. Uses `?` propagation consistently. `anyhow::Result` for application errors.

**Security awareness**: High. `secrecy::Secret<String>` for keys, SSRF protection, CSRF via SameSite cookies, XSS prevention with HTML escaping and CSP headers, WebSocket origin validation, sandbox hardening with `--cap-drop ALL`.

**Test coverage**: Good. Unit tests across crates, E2E tests with Playwright, integration tests for providers. CI runs `nextest` on all platforms.

**Documentation**: Comprehensive CLAUDE.md, docs/ mdBook, inline code comments, SECURITY.md with responsible disclosure. Channel integration checklist. Migration docs.

---

## Contribution Opportunities

1. **File**: `crates/tools/src/approval.rs:78-136`
   - **Issue**: SAFE_BINS includes `env`, `printenv`, `xargs`, `awk`, `sed`, `tee` which can be weaponized
   - **Fix**: Remove command-execution primitives from SAFE_BINS, add dangerous pattern detection
   - **Effort**: Small

2. **File**: `crates/web/src/api.rs:784-796, 903-951`
   - **Issue**: Shell/Dockerfile injection via unsanitized package names and base image
   - **Fix**: Add regex validation for package names and base images
   - **Effort**: Small

3. **File**: `crates/auth/src/credential_store.rs:499-504`
   - **Issue**: Session tokens stored unhashed
   - **Fix**: SHA-256 hash tokens before storage, lookup by hash
   - **Effort**: Medium

4. **File**: `crates/gateway/src/push.rs:25-31`
   - **Issue**: VAPID private key in plaintext with `Debug` derive exposing it
   - **Fix**: Encrypt via vault, manual Debug impl, 0600 file permissions
   - **Effort**: Medium

5. **File**: `.github/dependabot.yml` (new file)
   - **Issue**: No automated dependency update mechanism
   - **Fix**: Add Dependabot config for GitHub Actions and Cargo ecosystems
   - **Effort**: Trivial

---

## Draft PRs

### PR 1: `fix(web): sanitize sandbox API inputs against shell injection`

- **Branch**: `fix/sandbox-input-sanitization`
- **Files to modify**: `crates/web/src/api.rs`
- **Changes**:
  - Add `validate_package_name()` function that rejects names not matching `^[a-zA-Z0-9._+\-]+$`
  - Add `validate_base_image()` function that rejects names not matching `^[a-z0-9._\-/]+:[a-z0-9._\-]+$`
  - Apply validation in `api_check_packages_handler` (L784) and `api_build_image_handler` (L903) before interpolation
  - Add unit tests for injection payloads (single quotes, semicolons, newlines, `$()`)
- **Impact**: Closes two HIGH severity shell injection vectors. These endpoints are authenticated but reachable by any authenticated user, making them the highest-impact fixable findings.

### PR 2: `fix(tools): remove command-execution primitives from SAFE_BINS`

- **Branch**: `fix/safe-bins-audit`
- **Files to modify**: `crates/tools/src/approval.rs`
- **Changes**:
  - Remove `env`, `printenv`, `xargs`, `awk`, `sed`, `tee` from `SAFE_BINS`
  - Add dangerous pattern entries for `env` (full dump), `printenv` (secret exfiltration), `xargs` (arbitrary execution)
  - Update tests to verify these commands now require approval
- **Impact**: Hardens the LLM tool execution approval flow against prompt injection attacks that use "safe" commands for data exfiltration or arbitrary code execution.

### PR 3: `fix(auth): hash session tokens before storage`

- **Branch**: `fix/hash-session-tokens`
- **Files to modify**: `crates/auth/src/credential_store.rs`
- **Changes**:
  - In `create_session()`, store `sha256_hex(&token)` instead of raw token
  - In `validate_session()`, hash the incoming token before SQL lookup
  - In `delete_session()`, hash the token before SQL delete
  - Add migration to invalidate existing plaintext sessions (force re-login)
  - Add tests verifying the raw token is never stored
- **Impact**: Aligns session token storage with the already-correct API key storage pattern. Eliminates session hijacking from database file compromise.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 9 |
| Security | 7 |
| Documentation | 9 |
| Test Coverage | 7 |
| Contribution Potential | 8 |

---

## Summary

- **Total findings by severity**: Critical: 0, High: 4, Medium: 6, Low: 5, Info: 0
- **Overall risk level**: **MEDIUM** -- The project demonstrates strong security awareness with defense-in-depth patterns, but specific gaps in input validation (sandbox APIs), tool approval (SAFE_BINS), and secret storage (sessions, VAPID keys) create exploitable paths for authenticated attackers or prompt injection chains.

**Top 3 recommendations:**

1. **Sanitize sandbox API inputs** (FINDING-1, FINDING-2) -- Shell and Dockerfile injection via package names and base images are the most directly exploitable findings. Small fix, high impact.

2. **Audit and tighten SAFE_BINS** (FINDING-3) -- The tool approval bypass list includes utilities that can execute arbitrary commands or exfiltrate secrets, undermining the entire approval flow against prompt injection attacks.

3. **Hash session tokens** (FINDING-5) -- Aligning session storage with the existing API key pattern (SHA-256 hash before storage) is a straightforward defense-in-depth improvement that protects against database compromise scenarios.
