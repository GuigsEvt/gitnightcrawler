Now I have all the data needed. Here's the complete security audit report:

---

# Security Audit: openclaw/openclaw

## Repository Overview

OpenClaw is a personal AI assistant gateway that connects to 20+ messaging channels (WhatsApp, Telegram, Discord, Slack, Signal, Matrix, etc.) and multiple AI model providers (Anthropic, OpenAI, Google, etc.). It provides a unified CLI, a gateway server with WebSocket/HTTP protocol, a plugin SDK for extensibility, and native apps for macOS/iOS/Android. The codebase is ~9.7M of TypeScript (ESM) with 94 bundled plugin extensions, backed by Node.js 22+, Vitest testing with 70% coverage thresholds, and pnpm workspace management.

**Tech stack**: TypeScript/ESM, Node.js, Bun, Express/Hono, Playwright, SQLite, Zod, Lit (UI), Swift/Kotlin (native apps)
**Maturity**: Mature -- extensive test infrastructure, CI/CD, plugin SDK versioning, security audit subsystem, secret detection baseline, CodeQL scanning, release gating
**Categories detected**: general (AI gateway, messaging, plugin system)

## Critical & High Severity Findings

No critical or high severity findings identified.

The codebase demonstrates strong defensive security engineering across all major surfaces: timing-safe secret comparison, shell injection prevention (shell mode always disabled), SSRF protection with DNS pinning, path traversal prevention with symlink resolution, TLS 1.3 enforcement, systematic prototype pollution guards, and heuristic prompt injection detection.

## Medium & Low Severity Findings

### MEDIUM-1: DNS Pinning Bypass in Trusted Proxy Mode

- **Severity**: MEDIUM
- **Category**: SSRF / Network
- **Location**: `src/infra/net/fetch-guard.ts:166-169`, `src/infra/net/ssrf.ts:327-354`
- **Description**: In `trusted_env_proxy` mode, when an HTTP proxy is configured via environment variables, the SSRF hostname validation runs against the resolved DNS of the target, but the actual HTTP request is dispatched through an `EnvHttpProxyAgent` that performs its own independent DNS resolution. This creates a TOCTOU window where an attacker controlling DNS could return a public IP during the validation phase, then a private/internal IP when the proxy resolves the hostname.
- **Impact**: An attacker with DNS control could potentially reach internal services (metadata endpoints, internal APIs) through the proxy, bypassing SSRF protections.
- **Fix**: Document explicitly that `trusted_env_proxy` mode trusts the proxy's DNS resolution. Consider passing pinned addresses to the proxy agent, or re-validating the resolved IP in the proxy's connect event.
- **Confidence**: Medium -- requires `trusted_env_proxy` mode AND attacker-controlled DNS AND a configured proxy, which is a narrow attack surface.

### MEDIUM-2: eval()/new Function() in Browser Extension

- **Severity**: MEDIUM
- **Category**: Code Execution
- **Location**: `extensions/browser/src/browser/pw-tools-core.interactions.ts:354-391`
- **Description**: The browser extension uses `eval()` and `new Function()` to execute JavaScript provided by the AI agent within a Playwright browser page context. While this runs in the browser sandbox (not the Node.js host), it enables arbitrary code execution within the browsing context.
- **Impact**: A prompt injection attack that manipulates the AI agent could cause execution of attacker-controlled JavaScript in the browser context, potentially exfiltrating page data or performing actions as the authenticated browser session.
- **Fix**: Restrict the scope of evaluable code, implement a content security policy within the Playwright context, or use Playwright's more constrained `locator.evaluate` with typed arguments instead of raw string evaluation.
- **Confidence**: Medium -- requires prompt injection to control the agent's browser tool calls.

### LOW-1: Unbounded Rate Limiter Map Growth

- **Severity**: LOW
- **Category**: Denial of Service
- **Location**: `src/gateway/auth-rate-limit.ts:102`
- **Description**: The rate limiter stores entries in an unbounded `Map<string, RateLimitEntry>`. While pruning runs every 60 seconds, locked entries persist for the full lockout window (default 5 minutes). An attacker sending requests from many unique IPs can grow the map during this window.
- **Impact**: Memory exhaustion on the gateway server under sustained high-cardinality IP attack.
- **Fix**: Add a hard cap on total map size (e.g., 100k entries). When exceeded, either reject unknown IPs or evict oldest unlocked entries.
- **Confidence**: Low -- requires significant volume from diverse IPs.

### LOW-2: RSA 2048-bit Key for Self-Signed TLS Certificate

- **Severity**: LOW
- **Category**: Cryptography
- **Location**: `src/infra/tls/gateway.ts:55`
- **Description**: Auto-generated self-signed certificates use RSA 2048-bit keys. While still considered secure, current best practices recommend 3072+ bits for RSA or ECDSA P-256.
- **Impact**: Reduced cryptographic margin for long-lived certificates (10-year expiry).
- **Fix**: Change to `ec -pkeyopt ec_paramgen_curve:P-256` or `rsa:4096`.
- **Confidence**: High -- this is a factual configuration observation.

### LOW-3: shell: true in Windows Spawn Fallback

- **Severity**: LOW
- **Category**: Command Injection
- **Location**: `src/plugin-sdk/windows-spawn.ts:273`, `src/tui/tui-local-shell.ts:112`
- **Description**: Two production code paths use `shell: true` -- one as a last-resort Windows fallback when no direct executable can be resolved, another for the interactive local TUI shell feature.
- **Impact**: If attacker-controlled data reaches these code paths, command injection is possible.
- **Fix**: Both are guarded (Windows fallback requires `allowShellFallback` parameter; TUI shell requires operator approval). Ensure these guards cannot be bypassed.
- **Confidence**: Low -- both paths have explicit guards.

### LOW-4: dangerouslyForceUnsafeInstall Bypass Flag

- **Severity**: LOW
- **Category**: Security Bypass
- **Location**: `src/plugins/install-security-scan.ts:6,43,89`
- **Description**: Plugin installation security scanning can be completely bypassed with the `dangerouslyForceUnsafeInstall` flag. If any code path sets this programmatically, all security scanning is skipped.
- **Fix**: Audit all call sites. Consider requiring an interactive confirmation when this flag is used, or logging a security warning.
- **Confidence**: Low -- the flag name is intentionally scary and likely only exposed via CLI flags.

## Supply Chain Analysis

### Dependency Health

**Positive practices**:
- Committed pnpm lockfile (v9.0 format) ensures reproducible builds
- Deprecated `request` package aliased to maintained `@cypress/request` fork
- Native dependencies explicitly allowlisted in `pnpm.onlyBuiltDependencies`
- `minimumReleaseAge: 2880` (48 hours) prevents installation of just-published packages
- `detect-secrets` baseline with 8+ specialized detectors configured
- Pre-commit hooks run `npm audit` and private key detection

**Areas of concern**:

| Package | Version | Concern |
|---------|---------|---------|
| `@buape/carbon` | `0.0.0-beta-20260327000044` | Pre-release Discord library in production |
| `matrix-js-sdk` | `41.3.0-rc.0` | Release candidate, not stable |
| `@lydell/node-pty` | `1.2.0-beta.3` | Beta PTY library |
| `sqlite-vec` | `0.1.9` | Early-stage vector DB (excluded from release-age check) |

**No known CVEs** detected in the pinned dependency versions. The aliasing of `request` to `@cypress/request` and pinning of `path-to-regexp`, `qs`, `tough-cookie`, `minimatch`, and `tar` to specific versions indicates proactive vulnerability management.

## Code Quality Assessment

**Architecture**: Excellent separation of concerns -- CLI, gateway, plugins, channels, config, and security are cleanly modularized. The plugin SDK provides a stable, versioned contract for 94 bundled extensions and third-party plugins.

**Error handling**: Uses Result-style outcomes and closed error-code unions for recoverable decisions. Custom exception types with scope tracking in the secrets subsystem. Process-level unhandled rejection handlers in entry points.

**Test coverage**: 70% line/branch/function/statement thresholds enforced via Vitest + V8 coverage. Multiple specialized test configs (unit, gateway, channels, extensions, contracts, e2e, live, performance). Colocated `*.test.ts` files throughout.

**Documentation**: Extensive -- Mintlify-hosted docs with i18n, plugin SDK guides, channel docs, gateway protocol docs. Internal security documentation covers credential semantics, SecretRef contracts, and audit policies.

**Security subsystem**: Built-in `openclaw doctor` audit framework checks 8+ security dimensions (auth strength, device auth, provider presence, group policy, synced paths, sandbox config, exec approvals). ReDoS protection in `safe-regex.ts`. Skill scanner for plugin safety.

## Contribution Opportunities

1. **File**: `src/gateway/auth-rate-limit.ts:102`
   - **Issue**: Unbounded Map growth under high-cardinality IP attack
   - **Fix**: Add hard cap on total entries with LRU eviction
   - **Effort**: trivial

2. **File**: `src/infra/tls/gateway.ts:55`
   - **Issue**: RSA 2048-bit key; modern best practice is ECDSA P-256 or RSA 3072+
   - **Fix**: Change key generation to ECDSA P-256
   - **Effort**: trivial

3. **File**: `src/infra/net/fetch-guard.ts:166-169`
   - **Issue**: DNS pinning bypassed in trusted_env_proxy mode
   - **Fix**: Document limitation or pass pinned addresses to proxy agent
   - **Effort**: small

4. **File**: `extensions/browser/src/browser/pw-tools-core.interactions.ts:354-391`
   - **Issue**: eval()/new Function() in browser context could be tightened
   - **Fix**: Use Playwright's typed evaluate APIs, add CSP headers
   - **Effort**: medium

5. **File**: `src/plugins/install-security-scan.ts`
   - **Issue**: dangerouslyForceUnsafeInstall could be audited at call sites
   - **Fix**: Add interactive confirmation or audit logging when flag is used
   - **Effort**: small

## Draft PRs

### PR 1: Rate Limiter Memory Bounds

- **PR Title**: `fix(gateway): cap auth rate-limiter map size to prevent memory exhaustion`
- **Branch name**: `fix/rate-limiter-map-cap`
- **Files to modify**: `src/gateway/auth-rate-limit.ts`
- **Changes**: Add a `MAX_ENTRIES` constant (e.g., 100,000). In the `check()` method, before adding a new entry, check map size against the cap. If exceeded, run an immediate prune, then if still over cap, reject the request or evict the oldest unlocked entry. Add a test case verifying the cap behavior.
- **Impact**: Prevents memory exhaustion under sustained brute-force from diverse IPs. Trivial change with no behavioral impact under normal operation.

### PR 2: Upgrade TLS Key to ECDSA P-256

- **PR Title**: `fix(infra): use ECDSA P-256 for auto-generated TLS certificates`
- **Branch name**: `fix/tls-ecdsa-p256`
- **Files to modify**: `src/infra/tls/gateway.ts`
- **Changes**: Replace `rsa:2048` with `ec -pkeyopt ec_paramgen_curve:P-256` in the OpenSSL command. Update the certificate subject if needed. Add/update test to verify the new key type.
- **Impact**: Modern key algorithm with better performance and equivalent security at smaller key size. Self-signed certs will regenerate on next startup (breaking change for pinned cert setups -- document in changelog).

### PR 3: Document DNS Pinning Limitation in Proxy Mode

- **PR Title**: `docs(security): document DNS pinning bypass in trusted_env_proxy mode`
- **Branch name**: `docs/ssrf-proxy-dns-limitation`
- **Files to modify**: `src/infra/net/fetch-guard.ts` (code comment), `docs/gateway/secrets.md` or relevant security doc
- **Changes**: Add inline comment explaining that `trusted_env_proxy` delegates DNS resolution to the proxy and does not pin addresses. Add a security considerations section to the gateway docs explaining when this mode is appropriate and the trust assumptions involved.
- **Impact**: Helps operators make informed decisions about proxy configuration. No code change required.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 9 |
| Security | 8 |
| Documentation | 9 |
| Test Coverage | 8 |
| Contribution Potential | 6 |

## Summary

- **Total findings by severity**: Critical: 0, High: 0, Medium: 2, Low: 4, Info: 5
- **Overall risk level**: LOW

**Top 3 recommendations**:

1. **Cap the rate limiter map size** (`src/gateway/auth-rate-limit.ts`) -- trivial fix that prevents a memory exhaustion DoS vector under high-cardinality brute-force attacks.

2. **Upgrade auto-generated TLS certificates to ECDSA P-256** (`src/infra/tls/gateway.ts`) -- modernizes cryptographic defaults with better performance and future-proofing.

3. **Tighten browser extension eval() usage** (`extensions/browser/src/browser/pw-tools-core.interactions.ts`) -- the current Playwright sandbox provides isolation, but switching to typed evaluate APIs would reduce the attack surface from prompt injection scenarios.

This is a well-engineered codebase with mature security practices. The existing defense-in-depth (SSRF protection, timing-safe comparisons, shell injection prevention, prototype pollution guards, prompt injection detection, secret detection baseline, CodeQL scanning) significantly exceeds the security posture of most open-source projects of comparable scope.
