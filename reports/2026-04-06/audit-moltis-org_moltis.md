Now I have all the data needed. Here's the comprehensive security audit report:

---

# Security Audit: moltis-org/moltis

## Repository Overview

Moltis is a secure, persistent personal AI agent server written in Rust -- a reimplementation of OpenClaw. It provides multi-channel messaging (Discord, Slack, Telegram, Matrix, WhatsApp, MS Teams), multi-provider LLM orchestration (OpenAI, Anthropic, local GGUF models), sandboxed tool execution (Docker/Apple containers), WebAuthn/passkey authentication, vault-based encryption-at-rest, and a web UI. The codebase spans 46 Rust crates, native macOS/iOS apps (Swift), and a Preact/HTM frontend with Playwright E2E tests.

**Tech stack:** Rust (async/tokio/axum), SQLite (sqlx), XChaCha20-Poly1305 + Argon2id (vault), WebAuthn (webauthn-rs), Preact/HTM + Tailwind CSS (frontend), Playwright (E2E), Docker/Podman (sandbox), wasmtime (WASM tools).

**Maturity:** Growing/mature -- 3,100+ tests, multi-platform CI, Sigstore+GPG release signing, comprehensive docs. Active development with conventional commits and date-based versioning.

**Categories detected:** general (AI agent server, authentication, cryptography, CI/CD)

---

## Critical & High Severity Findings

### Finding 1: SSRF Bypass via IPv4-Mapped IPv6 Addresses

- **Severity:** HIGH
- **Category:** SSRF / Network Security
- **Location:** `crates/tools/src/ssrf.rs:29-36`
- **Description:** The `is_private_ip` function checks IPv6 addresses for `::1` (loopback), `fc00::/7` (unique local), and `fe80::/10` (link-local). However, it does not handle IPv4-mapped IPv6 addresses like `::ffff:127.0.0.1` or `::ffff:10.0.0.1`. Rust's `Ipv6Addr::is_loopback()` only returns `true` for `::1`, not for `::ffff:127.0.0.1`. An attacker controlling a DNS record could point a hostname to `::ffff:127.0.0.1`, which would pass SSRF validation and resolve to the loopback interface.
- **Impact:** Server-side request forgery allowing access to internal services (localhost APIs, metadata endpoints, admin interfaces) via the LLM's web fetch tool.
- **Fix:** Before checking IPv6, extract any embedded IPv4 address and check it against IPv4 rules:
  ```rust
  IpAddr::V6(v6) => {
      if let Some(v4) = v6.to_ipv4_mapped() {
          return is_private_ip(&IpAddr::V4(v4));
      }
      // existing v6 checks...
  }
  ```
- **Confidence:** HIGH -- confirmed by reading `is_private_ip` logic and Rust std docs. No test for `::ffff:127.0.0.1` exists.

### Finding 2: DNS Rebinding in SSRF Protection (TOCTOU)

- **Severity:** HIGH
- **Category:** SSRF / Network Security
- **Location:** `crates/tools/src/ssrf.rs:60-75`
- **Description:** `ssrf_check` resolves DNS and validates IPs, but the subsequent HTTP request (via reqwest) performs its own independent DNS resolution. An attacker can configure DNS to return a public IP on first lookup (passing validation) and a private IP on the second lookup (reaching internal services). This is the classic DNS rebinding TOCTOU pattern.
- **Impact:** SSRF bypass allowing access to internal network services despite the IP validation layer.
- **Fix:** Pin resolved IPs and pass them to the HTTP client rather than re-resolving. Use reqwest's `resolve()` method to force the validated IP.
- **Confidence:** MEDIUM -- requires attacker-controlled DNS with short TTL; practical exploitability depends on DNS resolver caching behavior.

### Finding 3: Unpinned `cargo install` in Release Workflow

- **Severity:** HIGH
- **Category:** Supply Chain
- **Location:** `.github/workflows/release.yml:301,395,1337`
- **Description:** Three `cargo install` commands in the release workflow install tools without version pinning: `cargo-deb`, `cargo-generate-rpm`, and `cargo-sbom`. These commands fetch and compile the latest version from crates.io at build time. A compromised crate version could inject malicious code into release artifacts.
- **Impact:** Supply chain compromise of all distributed release artifacts (deb, rpm packages, SBOM). An attacker publishing a malicious version of any of these crates would have code execution in the release CI environment with access to release signing credentials.
- **Fix:** Pin versions: `cargo install cargo-deb@2.11.0`, `cargo install cargo-generate-rpm@0.15.2`, `cargo install cargo-sbom@0.9.1` (or current versions).
- **Confidence:** HIGH -- confirmed by reading the workflow.

### Finding 4: X-Forwarded-For Leftmost IP Trusted for Rate Limiting

- **Severity:** HIGH
- **Category:** Rate Limiting Bypass
- **Location:** `crates/httpd/src/request_throttle.rs:294-301`
- **Description:** When `behind_proxy` is enabled, `extract_forwarded_ip` uses `split(',').find_map()` which takes the first parseable IP from the X-Forwarded-For header. If the upstream proxy appends rather than replaces the header, an attacker can prepend arbitrary IPs (e.g., `X-Forwarded-For: 1.2.3.4, real-ip`), effectively choosing their rate-limit bucket. This allows unlimited login attempts by rotating fake source IPs.
- **Impact:** Complete bypass of rate limiting on login and all other throttled endpoints, enabling brute-force attacks on passwords and API keys.
- **Fix:** Use the rightmost-minus-one IP (the IP added by the trusted proxy), or better, use a dedicated header set by the reverse proxy (e.g., `X-Real-IP` with proxy-controlled value). Document that the proxy must strip client-supplied XFF headers.
- **Confidence:** HIGH -- standard XFF spoofing attack. The code explicitly uses the first (leftmost) IP.

---

## Medium & Low Severity Findings

### Finding 5: Unverified Tailwind CSS Binary Download

- **Severity:** MEDIUM
- **Category:** Supply Chain
- **Location:** `scripts/download-tailwindcss-cli.sh`, `Dockerfile:36-38`
- **Description:** The Tailwind CSS binary is downloaded from GitHub using the `latest` tag with no checksum or signature verification. The script only validates magic bytes (ELF/Mach-O headers). This binary is executed during CI builds and its output is embedded in release artifacts.
- **Impact:** A compromised Tailwind release or MITM attack could inject malicious CSS/JS into the web UI served to all users.
- **Fix:** Pin to a specific version and verify SHA256 checksum after download.
- **Confidence:** HIGH

### Finding 6: Docker Base Images Not Pinned to Digest

- **Severity:** MEDIUM
- **Category:** Supply Chain
- **Location:** `Dockerfile:14,53`
- **Description:** `rust:bookworm` and `debian:bookworm-slim` are referenced by tag, not by SHA256 digest. Tag-based references can be mutated upstream.
- **Impact:** A compromised or mutated base image could affect all Docker-based deployments.
- **Fix:** Pin to specific image digests: `rust:bookworm@sha256:abc123...`
- **Confidence:** HIGH

### Finding 7: Passwordless Sudo + Docker Socket in Container

- **Severity:** MEDIUM
- **Category:** Container Security
- **Location:** `Dockerfile:97,111`
- **Description:** The container user has `NOPASSWD:ALL` sudo and the Docker socket is declared as a volume mount point. Combined with Docker group membership (L96), this provides full host Docker daemon access.
- **Impact:** Container escape to host system if the Docker socket is mounted.
- **Fix:** Remove passwordless sudo; use an entrypoint script for package installation. Do not declare Docker socket as a default volume.
- **Confidence:** HIGH

### Finding 8: Install Script Skips Checksum Verification on Failure

- **Severity:** MEDIUM
- **Category:** Supply Chain
- **Location:** `install.sh:315`
- **Description:** When the `.sha256` checksum file cannot be downloaded, the installer proceeds with a warning rather than aborting. Package manager installs (deb, rpm, arch, snap) skip checksum verification entirely.
- **Impact:** Users may install tampered binaries if the checksum file is unavailable (CDN issues, targeted attack).
- **Fix:** Fail by default when checksums cannot be verified. Add `--no-verify` flag for explicit opt-out.
- **Confidence:** HIGH

### Finding 9: Process Orphaning on Timeout (Host Execution)

- **Severity:** MEDIUM
- **Category:** Resource Exhaustion / DoS
- **Location:** `crates/tools/src/exec.rs:157`
- **Description:** When `exec_command` times out, the `tokio::time::timeout` drops the future but does not explicitly kill the child process. The spawned `sh -c` process may continue running indefinitely on the host.
- **Impact:** Accumulation of orphaned processes consuming host resources. An LLM could be tricked into running long-lived commands that persist after timeout.
- **Fix:** Store the `Child` handle separately and call `child.kill()` on timeout before dropping.
- **Confidence:** MEDIUM -- depends on Tokio's `Child` drop behavior, which may kill the process on some platforms.

### Finding 10: Plaintext API Keys in `moltis.toml` `env` Field

- **Severity:** MEDIUM
- **Category:** Secrets Management
- **Location:** `crates/config/src/schema.rs:246`
- **Description:** The `MoltisConfig.env` HashMap stores environment variables (including API keys per the documentation at L243-244) as plaintext strings in `moltis.toml`. Unlike provider API keys which use `Secret<String>`, these values have no `Debug` redaction and are not covered by vault encryption-at-rest.
- **Impact:** API keys stored in the `env` map are visible in config file backups, debug logs, and any process that reads `moltis.toml`.
- **Fix:** Migrate `env` values to vault-encrypted storage (same pattern as `env_variables` in the credential store). At minimum, wrap in `Secret<String>`.
- **Confidence:** HIGH

### Finding 11: No Credential Store = No Auth + No Rate Limiting

- **Severity:** LOW
- **Category:** Insecure Default
- **Location:** `crates/httpd/src/auth_middleware.rs:116-118`, `crates/httpd/src/request_throttle.rs:247-249`
- **Description:** When `credential_store` is `None`, both the auth middleware and rate limiter pass all requests through without checks. This is intentional for backward compatibility but creates a completely unprotected state.
- **Impact:** Any deployment that fails to initialize the credential store runs without authentication or rate limiting.
- **Fix:** Log a prominent warning at startup when no credential store is configured. Consider requiring explicit `auth.disabled = true` to run without auth.
- **Confidence:** MEDIUM

### Finding 12: Fixed-Window Rate Limiting Allows Burst at Boundary

- **Severity:** LOW
- **Category:** Rate Limiting
- **Location:** `crates/httpd/src/request_throttle.rs:154-191`
- **Description:** The rate limiter uses fixed time windows. An attacker can make 5 login attempts at the end of one window and 5 at the start of the next, achieving 10 attempts in a short burst.
- **Impact:** Doubles effective brute-force rate at window boundaries (10 attempts per window transition vs 5 per window).
- **Fix:** Switch to sliding window or token bucket algorithm.
- **Confidence:** HIGH

### Finding 13: Backup Files Not Cleaned After Vault Migration

- **Severity:** LOW
- **Category:** Secrets Management
- **Location:** `crates/vault/src/migration.rs`
- **Description:** When migrating plaintext JSON files to vault-encrypted `.enc` files, the original is renamed to `.json.bak` but never deleted. These backup files contain plaintext secrets.
- **Impact:** Plaintext secrets persist on disk indefinitely in `.bak` files after encryption migration.
- **Fix:** After successful migration verification, securely delete `.bak` files (or prompt the user to do so).
- **Confidence:** HIGH

### Finding 14: `channel_storage_db_path` Exposed to Frontend

- **Severity:** LOW
- **Category:** Information Disclosure
- **Location:** `crates/web/src/templates.rs:446-449`
- **Description:** The full filesystem path to `moltis.db` is included in the `gon` data injected into the web UI, revealing the server's home directory structure.
- **Impact:** Information disclosure of server filesystem layout to authenticated users.
- **Fix:** Remove the full path from gon data; use a relative or opaque identifier instead.
- **Confidence:** HIGH

---

## Supply Chain Analysis

**Strengths:**
- All GitHub Actions SHA-pinned across 6 workflows (no tag-only references)
- `persist-credentials: false` default on all checkouts
- Top-level `permissions: {}` with per-job escalation
- Sigstore keyless signing + GPG (YubiKey) signing + SLSA build provenance
- `zizmor` security scanner runs as prerequisite on every workflow
- Workspace lints deny `unsafe_code`, `unwrap_used`, `expect_used`

**Concerns:**
- 3 unpinned `cargo install` in release workflow (Finding 3)
- Tailwind CSS binary not checksum-verified (Finding 5)
- Docker base images not digest-pinned (Finding 6)
- `appimagetool` downloaded from `continuous` tag (not a versioned release) in release.yml L624
- Patched `sqlx` fork (`moltis-org/sqlx`) requires ongoing maintenance to stay current with upstream security patches
- `sled` 0.34.7 dependency is effectively unmaintained (last release 2021)
- `update-deploy-tags` job commits directly to `main` via GitHub API, bypassing merge queue/branch protection

**Dependency health:** The project has ~140 direct workspace dependencies. Core cryptographic crates (`argon2`, `chacha20poly1305`, `p256`, `rustls`, `ring`) are well-maintained and at current stable versions. The `whatsapp-rust 0.2` and `llama-cpp-2 0.1` crates are early-version with smaller communities.

---

## Code Quality Assessment

**Architecture:** Excellent modular design with 46 focused crates. Clear separation of concerns: auth, config, channels, tools, vault, memory. Trait-based abstractions for providers and sandboxes. Feature flags for optional functionality.

**Error handling:** Consistent use of `anyhow::Result` for application errors and `thiserror` for library errors. Workspace-wide deny on `unwrap()`/`expect()` enforced by clippy lints. Errors propagated with `?` throughout.

**Test coverage:** 3,100+ tests including unit, integration, and Playwright E2E tests. Security-relevant test cases for SSRF, auth bypass, cookie attributes, locality detection, and OTP. Notable gap: no test for IPv4-mapped IPv6 in SSRF (`::ffff:127.0.0.1`).

**Documentation:** Comprehensive mdBook docs (57 pages), detailed CLAUDE.md with development conventions, channel integration checklist, security architecture docs. Strong inline documentation of security decisions.

**Code quality highlights:**
- `secrecy::Secret<String>` consistently used for all API keys and tokens in config
- `Zeroizing<[u8; 32]>` for vault DEK in memory
- AEAD with per-field AAD for domain separation
- Session tokens: 256-bit CSPRNG, SHA-256 stored
- Device tokens: SHA-256 hashed, raw returned only once
- CSP with nonce-based script-src on all HTML responses
- `HttpOnly; SameSite=Strict` cookies

---

## Contribution Opportunities

1. **File:** `crates/tools/src/ssrf.rs:29-36` -- Add IPv4-mapped IPv6 handling to `is_private_ip`. **Effort:** trivial
2. **File:** `.github/workflows/release.yml:301,395,1337` -- Pin `cargo install` versions. **Effort:** trivial
3. **File:** `crates/httpd/src/request_throttle.rs:294-301` -- Fix XFF IP extraction to use rightmost IP. **Effort:** small
4. **File:** `scripts/download-tailwindcss-cli.sh` -- Add SHA256 checksum verification. **Effort:** small
5. **File:** `crates/tools/src/exec.rs:157` -- Add explicit `child.kill()` on timeout. **Effort:** small

---

## Draft PRs

### PR 1: SSRF IPv4-Mapped IPv6 Bypass Fix

- **PR Title:** `fix(tools): block IPv4-mapped IPv6 addresses in SSRF filter`
- **Branch name:** `fix/ssrf-ipv4-mapped-ipv6`
- **Files to modify:** `crates/tools/src/ssrf.rs`
- **Changes:** In `is_private_ip`, add IPv4-mapped IPv6 extraction before the existing IPv6 checks. Add test cases for `::ffff:127.0.0.1`, `::ffff:10.0.0.1`, `::ffff:169.254.1.1`, `::ffff:8.8.8.8`.
  ```rust
  IpAddr::V6(v6) => {
      if let Some(v4) = v6.to_ipv4_mapped() {
          return is_private_ip(&IpAddr::V4(v4));
      }
      v6.is_loopback() || v6.is_unspecified()
          || (v6.segments()[0] & 0xFE00) == 0xFC00
          || (v6.segments()[0] & 0xFFC0) == 0xFE80
  }
  ```
- **Impact:** Closes an SSRF bypass that could allow LLM-initiated requests to reach internal services via IPv4-mapped IPv6 addresses.

### PR 2: Pin `cargo install` Versions in Release Workflow

- **PR Title:** `fix(ci): pin cargo-deb, cargo-generate-rpm, cargo-sbom versions in release`
- **Branch name:** `fix/pin-release-cargo-install`
- **Files to modify:** `.github/workflows/release.yml`
- **Changes:** Add version specifiers to all three `cargo install` commands. Determine current versions from Cargo.lock or crates.io, pin with `@version` syntax.
- **Impact:** Eliminates supply chain risk from unpinned build tools in the release pipeline. Prevents a compromised crate version from injecting malicious code into release artifacts.

### PR 3: Fix X-Forwarded-For Rate Limit Bypass

- **PR Title:** `fix(httpd): use rightmost XFF IP for rate limiting`
- **Branch name:** `fix/xff-rate-limit-bypass`
- **Files to modify:** `crates/httpd/src/request_throttle.rs`
- **Changes:** Change `extract_forwarded_ip` to use the rightmost (last) parseable IP from X-Forwarded-For instead of the leftmost. Add documentation that the reverse proxy must be configured to append (not replace) XFF. Add tests for spoofed XFF headers.
  ```rust
  fn extract_forwarded_ip(headers: &HeaderMap) -> Option<IpAddr> {
      let xff = headers.get("x-forwarded-for").and_then(|v| v.to_str().ok());
      if let Some(xff) = xff {
          // Use rightmost IP (added by the trusted proxy)
          if let Some(ip) = xff.rsplit(',').find_map(|c| parse_ip(c.trim())) {
              return Some(ip);
          }
      }
      // ... rest unchanged
  }
  ```
- **Impact:** Prevents attackers from bypassing rate limiting by injecting arbitrary IPs into X-Forwarded-For headers, protecting login brute-force defenses.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 9 |
| Security | 7 |
| Documentation | 9 |
| Test Coverage | 8 |
| Contribution Potential | 7 |

---

## Summary

- **Total findings by severity:** Critical: 0, High: 4, Medium: 5, Low: 4, Info: 0
- **Overall risk level:** **MEDIUM** -- The codebase demonstrates strong security engineering (vault encryption, AEAD, WebAuthn, sandbox hardening, deny-unsafe lints, Sigstore signing) with specific gaps in network-layer protections and supply chain hardening.

**Top 3 recommendations:**
1. **Fix SSRF IPv4-mapped IPv6 bypass** -- trivial fix, blocks a real attack vector on the web fetch tool
2. **Pin all `cargo install` versions in release workflow** -- trivial fix, eliminates supply chain risk in the release pipeline
3. **Fix X-Forwarded-For IP extraction** -- small fix, restores rate limiting effectiveness for proxied deployments
