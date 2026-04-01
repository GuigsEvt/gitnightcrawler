I now have comprehensive data. Let me compile the final report.

# Security Audit: bitrouter/bitrouter

## Repository Overview

BitRouter is a modular, trait-based LLM routing system written in Rust. It serves as a lightweight local LLM aggregator/proxy connecting to upstream providers (OpenAI, Anthropic, Google) with config-driven routing, a Machine Payment Protocol (MPP) for paid API access via EVM/Solana wallets, JWT-based authentication using web3 wallet signatures, and a content guardrails engine. The architecture follows a strict layered dependency model across 9 workspace crates, with the binary crate assembling everything into a CLI product with serve/daemon management commands.

- **Tech stack**: Rust, Warp (HTTP), sea-orm (DB), tokio (async), Solana/EVM crypto libraries, serde/YAML config
- **Maturity**: Growing (v0.17.0, active development, conventional commits, CI/CD automation)
- **Categories detected**: ai | actions | crypto-primitives

---

## Critical & High Severity Findings

### Finding 1: OWS Passphrase Defaults to Empty String

- **Severity**: HIGH
- **Category**: crypto, auth
- **Location**: `bitrouter/src/runtime/server.rs:149`
- **Description**: The OWS wallet passphrase falls back to an empty string via `unwrap_or_default()` when `OWS_PASSPHRASE` is unset. This passphrase is used to decrypt the wallet's signing key for MPP close operations (financial transactions).
- **Impact**: An empty passphrase effectively disables wallet encryption. If the wallet file is accessible, an attacker could sign close/settlement transactions without knowing the passphrase. In production, this silently degrades security rather than failing safely.
- **Fix**: Replace `unwrap_or_default()` with an explicit check that returns an error if the environment variable is unset when wallet config is present:
  ```rust
  let credential = std::env::var("OWS_PASSPHRASE")
      .map_err(|_| "OWS_PASSPHRASE required when wallet is configured")?;
  ```
- **Confidence**: High

### Finding 2: No Request Body Size Limits on Any Endpoint

- **Severity**: HIGH
- **Category**: denial-of-service
- **Location**: All `warp::body::json` calls across `bitrouter-api/src/router/` (25+ endpoints)
- **Description**: No `warp::body::content_length_limit()` is configured on any JSON endpoint. Warp's default is permissive. Affected files include:
  - `openai/chat/filters.rs:37,60,85`
  - `anthropic/messages/filters.rs:36,59,80`
  - `google/generate_content/filters.rs:56,79,100`
  - `mcp/filters.rs:118,139,402`
  - `admin.rs:126`
- **Impact**: Denial of service via oversized request bodies exhausting memory. A single malicious client could send multi-GB payloads.
- **Fix**: Add `warp::body::content_length_limit(MAX_BODY_SIZE)` before each `warp::body::json()` call. Suggested limits: 10MB for chat/completion requests, 1MB for admin routes.
- **Confidence**: High

### Finding 3: API Keys Default to Empty Strings

- **Severity**: HIGH
- **Category**: auth, misconfiguration
- **Location**: `bitrouter/src/runtime/router.rs:30,48,65`
- **Description**: Provider API keys default to empty strings via `unwrap_or_default()` when not configured:
  ```rust
  let api_key = provider.api_key.clone().unwrap_or_default();
  ```
  This affects OpenAI, Anthropic, and Google provider adapters.
- **Impact**: Requests are forwarded to upstream providers with empty API keys. While upstream APIs reject these, it produces confusing 401 errors from upstream rather than a clear local configuration error. More critically, if a provider accepts empty/default keys in dev environments, requests could succeed unexpectedly.
- **Fix**: Validate API keys are non-empty at server startup and return a configuration error for providers with configured models but no API key.
- **Confidence**: High

### Finding 4: Claude Code Action Triggered by User-Controlled Input

- **Severity**: HIGH
- **Category**: actions, injection
- **Location**: `.github/workflows/claude.yml:15-19`
- **Description**: The Claude Code workflow triggers on `@claude` mentions in issue comments, PR review comments, issues, and PR reviews. The action executes Claude with the comment body as instructions. While `anthropics/claude-code-action` likely has its own sandboxing, this grants external commenters the ability to instruct an AI agent with `contents: read` and `id-token: write` permissions.
- **Impact**: External contributors or any GitHub user who can comment on issues could trigger arbitrary Claude Code execution against the repository. The `id-token: write` permission could be leveraged for OIDC token generation.
- **Fix**: Add an actor/association check:
  ```yaml
  if: |
    github.event.comment.author_association == 'MEMBER' ||
    github.event.comment.author_association == 'OWNER' ||
    github.event.comment.author_association == 'COLLABORATOR'
  ```
- **Confidence**: High

---

## Medium & Low Severity Findings

### Finding 5: ProviderConfig Derives Debug, Exposing API Keys in Logs

- **Severity**: MEDIUM
- **Category**: information-disclosure
- **Location**: `bitrouter-config/src/config.rs:238`
- **Description**: `ProviderConfig` derives `Debug` and `Serialize`, with `api_key: Option<String>` as a plain field. Any `tracing::debug!` or error formatting that includes a provider config will leak API keys.
- **Impact**: API key exposure in logs, error messages, or debug output.
- **Fix**: Implement a custom `Debug` that redacts `api_key`, or wrap it in a `Secret<String>` newtype.
- **Confidence**: Medium

### Finding 6: No Rate Limiting on Any Endpoint

- **Severity**: MEDIUM
- **Category**: denial-of-service, auth
- **Location**: `bitrouter/src/runtime/server.rs` (entire route tree)
- **Description**: No rate limiting middleware found. All endpoints (including auth, admin, and chat completions) accept unlimited requests.
- **Impact**: Brute force attacks on JWT auth, resource exhaustion, upstream provider quota depletion by a single client.
- **Fix**: Add per-IP and per-account rate limiting via a Warp filter or middleware layer.
- **Confidence**: High

### Finding 7: Query Parameter Parsing Without URL Decoding

- **Severity**: MEDIUM
- **Category**: logic, input-validation
- **Location**: `bitrouter-api/src/router/tools.rs:65-77`
- **Description**: Custom query parsing splits on `&` and `=` without URL-decoding values. Parameters with percent-encoded characters (e.g., `id=%20foo`) will not match expected values.
- **Impact**: Filter bypass if tool IDs or provider names contain special characters. Low severity in practice since tool IDs are typically alphanumeric.
- **Fix**: Use `percent_encoding::percent_decode_str()` on key and value after splitting.
- **Confidence**: Medium

### Finding 8: `.expect()` in Production MPP Code Path

- **Severity**: MEDIUM
- **Category**: denial-of-service, code-quality
- **Location**: `bitrouter-api/src/mpp/solana_voucher.rs:72`
- **Description**: `serde_json::to_string(...).expect("voucher JSON serialization cannot fail")` in the voucher serialization path. While the comment argues infallibility, this is a production code path handling payment vouchers.
- **Impact**: If serialization fails for any reason (e.g., a custom serializer bug), the server panics and crashes.
- **Fix**: Replace with `.map_err()` returning a proper error type.
- **Confidence**: Medium

### Finding 9: No CORS Configuration

- **Severity**: LOW
- **Category**: misconfiguration
- **Location**: `bitrouter/src/runtime/server.rs` (server setup)
- **Description**: No CORS middleware or headers configured. If the API is accessed from browser-based clients, CORS issues will arise. More importantly, absence of CORS headers means no explicit restriction on cross-origin requests.
- **Impact**: Low for API-only use. If browser clients are added, could enable cross-site request forgery against authenticated endpoints.
- **Fix**: Add explicit CORS middleware with restrictive defaults, or document that browser clients are not supported.
- **Confidence**: Low

### Finding 10: JWTs Without `exp` Claim Are Accepted Indefinitely

- **Severity**: LOW
- **Category**: auth
- **Location**: `bitrouter-core/src/auth/token.rs:122-133`
- **Description**: `check_expiration()` returns `Ok(())` when `exp` is `None`, meaning tokens without an expiration are valid forever.
- **Impact**: A compromised token without `exp` cannot be revoked by expiration. The operator must rotate wallet keys to invalidate all tokens.
- **Fix**: Consider requiring `exp` on all tokens, or enforcing a maximum token lifetime (e.g., 24h) when `exp` is absent.
- **Confidence**: Medium

### Finding 11: Actions Not Pinned to SHA

- **Severity**: LOW
- **Category**: supply-chain, actions
- **Location**: All files in `.github/workflows/`
- **Description**: All GitHub Actions use semantic version tags (`@v1`, `@v4`, `@stable`) rather than SHA-256 pins. This includes security-sensitive actions like `anthropics/claude-code-action@v1` and `actions/checkout@v4`.
- **Impact**: A compromised tag could inject malicious code into CI/CD pipelines.
- **Fix**: Pin all actions to specific commit SHAs with a version comment.
- **Confidence**: High

### Finding 12: `serde-saphyr` at Version `0.0`

- **Severity**: LOW
- **Category**: supply-chain
- **Location**: Workspace `Cargo.toml` (dependency declaration)
- **Description**: `serde-saphyr = "0.0"` is a pre-release crate with zero stability guarantees, used for YAML parsing across multiple crates.
- **Impact**: Breaking changes or security issues in the crate could affect config loading without warning.
- **Fix**: Pin to a specific patch version or evaluate migration to a more stable YAML library.
- **Confidence**: Medium

---

## Supply Chain Analysis

**Positive**: Cargo.lock is committed, ensuring reproducible builds. No `build.rs` files exist (no custom build-time code execution). No Dockerfiles.

**Concerns**:
- **Loose version constraints**: Most dependencies use major-only pins (`"1"`, `"0.3"`) rather than patch-level (`"1.40.0"`). While semver should protect against breaking changes, it doesn't protect against newly introduced bugs.
- **`serde-saphyr = "0.0"`**: Pre-release YAML library with no stability guarantees.
- **OWS ecosystem** (`ows-core`, `ows-lib`, `ows-signer` at `"1.1"`): Niche dependencies. Should verify they are actively maintained and audited.
- **`mpp-br = "0.8.1"`**: Machine Payment Protocol library -- verify provenance and maintenance status.
- **No `cargo audit`** in CI: Dependency vulnerability scanning is not automated.

---

## Code Quality Assessment

**Architecture**: Excellent layered architecture with strict bottom-up dependency rules. Trait-based design enables clean separation of concerns. Feature gating for optional capabilities (MPP, MCP) is well-implemented.

**Error handling**: Generally strong. Production code avoids `unwrap()`/`expect()` except in the MPP voucher path. Test code appropriately uses `unwrap()`. Error types are well-structured with `thiserror`.

**Test coverage**: Good unit test coverage for JWT signing/verification, config loading, admin routes, and agent skills. Integration tests exist for key API paths. Missing: security-specific tests (malformed inputs, oversized payloads, auth bypass attempts).

**Documentation**: Excellent inline documentation with module-level doc comments explaining design decisions. JWT auth flow is well-documented with security-critical ordering notes.

---

## Contribution Opportunities

1. **File**: `bitrouter-api/src/router/openai/chat/filters.rs:37` (and all filter files)
   - **Issue**: No `content_length_limit` on JSON body parsing
   - **Fix**: Add `warp::body::content_length_limit(10 * 1024 * 1024)` before each `body::json()`
   - **Effort**: Small

2. **File**: `bitrouter/src/runtime/server.rs:149`
   - **Issue**: `OWS_PASSPHRASE` silently defaults to empty string
   - **Fix**: Return error when wallet is configured but passphrase is missing
   - **Effort**: Trivial

3. **File**: `.github/workflows/claude.yml:15-19`
   - **Issue**: No author association check on Claude Code trigger
   - **Fix**: Add `author_association` filter to the `if` condition
   - **Effort**: Trivial

4. **File**: `bitrouter-config/src/config.rs:238`
   - **Issue**: `ProviderConfig` Debug derives expose API keys
   - **Fix**: Custom `Debug` impl that redacts `api_key`
   - **Effort**: Small

5. **File**: `bitrouter-core/src/auth/token.rs:122-133`
   - **Issue**: Tokens without `exp` accepted indefinitely
   - **Fix**: Enforce maximum lifetime when `exp` is absent
   - **Effort**: Small

---

## Draft PRs

### PR 1: Request Body Size Limits

- **PR Title**: `fix(api): add content length limits to all JSON endpoints`
- **Branch**: `fix/body-size-limits`
- **Files to modify**:
  - `bitrouter-api/src/router/openai/chat/filters.rs`
  - `bitrouter-api/src/router/anthropic/messages/filters.rs`
  - `bitrouter-api/src/router/google/generate_content/filters.rs`
  - `bitrouter-api/src/router/openai/responses/filters.rs`
  - `bitrouter-api/src/router/mcp/filters.rs`
  - `bitrouter-api/src/router/admin.rs`
- **Changes**: Add `warp::body::content_length_limit(10 * 1024 * 1024)` (10MB) before each `warp::body::json()` call on chat/completion endpoints. Use 1MB limit for admin endpoints and MCP filter update endpoints.
- **Impact**: Prevents denial-of-service via oversized request bodies. Zero breaking changes for legitimate clients.

### PR 2: Require OWS Passphrase When Wallet Configured

- **PR Title**: `fix(runtime): require OWS_PASSPHRASE when wallet is configured`
- **Branch**: `fix/require-ows-passphrase`
- **Files to modify**:
  - `bitrouter/src/runtime/server.rs`
- **Changes**: Replace `std::env::var("OWS_PASSPHRASE").unwrap_or_default()` with a proper error path that returns `Err` when the variable is unset and wallet config is present. Log a clear error message indicating the required environment variable.
- **Impact**: Prevents silent degradation to empty passphrase, ensuring wallet encryption is actually enforced in production.

### PR 3: Restrict Claude Code Workflow to Repo Members

- **PR Title**: `fix(ci): restrict Claude Code trigger to repo members`
- **Branch**: `fix/claude-action-auth`
- **Files to modify**:
  - `.github/workflows/claude.yml`
- **Changes**: Add `author_association` checks to the `if` condition so only MEMBER, OWNER, and COLLABORATOR comments trigger the workflow. This prevents external contributors from executing arbitrary Claude Code instructions against the repository.
- **Impact**: Closes a privilege escalation vector where any GitHub user could trigger AI-powered code execution via issue/PR comments.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 6 |
| Documentation | 8 |
| Test Coverage | 6 |
| Contribution Potential | 7 |

---

## Summary

- **Total findings by severity**: Critical: 0, High: 4, Medium: 4, Low: 4, Info: 0
- **Overall risk level**: **MEDIUM**

**Top 3 recommendations**:
1. **Add request body size limits** to all JSON endpoints -- trivial fix that prevents DoS.
2. **Require `OWS_PASSPHRASE`** when wallet config is present -- prevent silent security degradation for financial signing operations.
3. **Restrict Claude Code GitHub Action** to repository members only -- close external trigger vector.
