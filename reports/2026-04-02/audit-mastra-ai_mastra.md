# Security Audit: mastra-ai/mastra

## Repository Overview

**Repository**: mastra-ai/mastra
**Description**: A modular TypeScript AI agent framework built as a pnpm monorepo, orchestrated with Turborepo. Provides agent creation, tool execution, memory management, workflows, MCP (Model Context Protocol) integration, RAG, evaluations, and a playground UI.
**Language**: TypeScript (primary), with shell scripts for CI
**License**: Apache-2.0 (core), Mastra Enterprise License (ee/ directories)
**Size**: ~1.2GB monorepo
**Key Areas**: `packages/` (core, server, mcp, cli, playground-ui, evals, rag, memory), `stores/` (23 database adapters), `auth/`, `workflows/`, `voice/`, `server-adapters/`, `workspaces/`, `.github/workflows/`
**Auth Architecture**: Multi-layer auth with SSO, credentials, RBAC, and per-route permission derivation
**Last Commit Analyzed**: HEAD of main branch

---

## Critical & High Severity Findings

### Finding 1: `eval()` Usage for Parsing Next.js Config

- **Severity**: HIGH
- **Category**: Code Injection
- **Location**: `packages/cli/src/commands/lint/rules/nextConfigRule.ts:15`
- **Description**: The `readNextConfig()` function reads a `next.config.js` file from disk and passes a regex-extracted string directly to `eval()`:
  ```typescript
  const configStr = configMatch[1].replace(/\n/g, '').replace(/\s+/g, ' ');
  return eval(`(${configStr})`);
  ```
  While this operates on the user's own project files (not remote input), `eval()` on file contents is inherently dangerous. A malicious next.config.js (e.g., from a cloned repo or supply chain attack on a template) would execute arbitrary code during `mastra lint`.
- **Impact**: Arbitrary code execution in the context of the CLI process. An attacker who controls a project's `next.config.js` can execute arbitrary code when a developer runs `mastra lint`.
- **Fix**: Replace `eval()` with a proper AST parser (e.g., Babel, jscodeshift, or acorn) as the TODO comment on line 30 already suggests. Alternatively, use `require()` or `import()` which at least execute in a module context.
- **Confidence**: high

### Finding 2: Shell Command Execution Tool with Bypassable Restrictions

- **Severity**: HIGH
- **Category**: Command Injection / Privilege Escalation
- **Location**: `packages/core/src/loop/network/run-command-tool.ts:169-276`
- **Description**: `createRunCommandTool()` provides agents with shell command execution. While it has security controls (blocked commands, allowlists, dangerous character rejection), several weaknesses exist:
  1. **Default configuration is permissive**: When `allowedCommands` is empty (the default), all non-blocked commands are allowed. When `allowedBasePaths` is empty (the default), any working directory is allowed.
  2. **`allowUnsafeCharacters` flag**: Setting this to `true` bypasses all metacharacter checks, enabling full shell injection (`; rm -rf /`).
  3. **Blocklist bypasses**: The blocklist checks only the base command name. An attacker-controlled agent could use absolute paths to blocked binaries (e.g., `/usr/bin/rm`) -- though path extraction handles this. More concerning: `env`, `xargs`, `awk`, `perl`, `python`, `ruby`, and `find -exec` are not blocked and can execute arbitrary commands.
  4. **PATH is not restricted**: The code comments out PATH restriction (line 256), leaving the full system PATH available.
- **Impact**: An AI agent with this tool configured with defaults could execute destructive or exfiltration commands. The `allowUnsafeCharacters` option is particularly dangerous as it completely disables injection protections.
- **Fix**: Make `allowedCommands` required (no default empty array). Remove or deprecate `allowUnsafeCharacters`. Add `env`, `xargs`, `python`, `perl`, `ruby`, `awk`, `find`, `tee`, `nohup`, `bash`, `sh`, `zsh`, `dash` to the blocklist. Enable PATH restriction by default.
- **Confidence**: high

### Finding 3: Dev Playground Auth Bypass via Header Injection

- **Severity**: HIGH
- **Category**: Authentication Bypass
- **Location**: `packages/server/src/server/auth/helpers.ts:64-79`
- **Description**: When `MASTRA_DEV=true` and no auth provider is configured, the `isDevPlaygroundRequest()` function grants unauthenticated access if the request contains the header `x-mastra-dev-playground: true`. This header can be trivially spoofed by any HTTP client. The condition at line 280 mitigates this somewhat by only applying the bypass when `!hasAuthProvider`, but the header-based bypass on line 77 still applies to protected paths when `MASTRA_DEV=true` and no auth provider is set.
- **Impact**: If a Mastra server is accidentally deployed with `MASTRA_DEV=true` and without auth configured, any client sending `x-mastra-dev-playground: true` can access all API endpoints without authentication.
- **Fix**: Remove the header-based bypass entirely. Dev mode should only be used locally and should rely on environment detection, not spoofable headers. Add a startup warning when `MASTRA_DEV=true` in non-local environments.
- **Confidence**: high

### Finding 4: X-Forwarded-Host Trust Without Validation

- **Severity**: HIGH
- **Category**: Host Header Injection / Open Redirect
- **Location**: `packages/server/src/server/handlers/auth.ts:72-78`
- **Description**: The `getPublicOrigin()` function blindly trusts the `X-Forwarded-Host` header:
  ```typescript
  const forwardedHost = request.headers.get('x-forwarded-host')?.split(',')[0]?.trim();
  if (forwardedHost) {
    return `https://${forwardedHost}`;
  }
  ```
  No validation is performed on the header value. This is used to construct OAuth callback URLs (line 211) and redirect URLs throughout the auth flow. An attacker could inject a malicious `X-Forwarded-Host` header to redirect OAuth callbacks to an attacker-controlled domain.
- **Impact**: OAuth token theft via callback URL manipulation. The SSO callback URI (`oauthCallbackUri`) is built from the attacker-controlled origin, potentially leaking authorization codes to attacker servers.
- **Fix**: Validate `X-Forwarded-Host` against a configured list of allowed hosts, or require the origin to be explicitly configured rather than derived from headers. At minimum, validate the header value is a valid hostname.
- **Confidence**: high

### Finding 5: Workspace Filesystem Operations Without Path Traversal Protection

- **Severity**: HIGH
- **Category**: Path Traversal
- **Location**: `packages/server/src/server/handlers/workspace.ts:494,544,591,637,691,728`
- **Description**: Multiple workspace filesystem routes (`readFile`, `writeFile`, `list`, `delete`, `move`, `mkdir`) accept a user-provided `path` parameter that is only `decodeURIComponent()`'d before being passed to filesystem operations. No path traversal checks are performed -- paths like `../../etc/passwd` or `..%2F..%2Fetc%2Fpasswd` could escape the workspace root directory, depending on the filesystem implementation.
- **Impact**: Depending on the workspace filesystem backend, an attacker with API access could read or write arbitrary files outside the intended workspace directory.
- **Fix**: Normalize and validate that the resolved path stays within the workspace root. Use `path.resolve()` and verify the result starts with the workspace root prefix. Reject paths containing `..` segments.
- **Confidence**: medium (depends on filesystem implementation providing its own sandboxing)

### Finding 6: No Rate Limiting on Authentication Endpoints

- **Severity**: HIGH
- **Category**: Brute Force / Denial of Service
- **Location**: `packages/server/src/server/handlers/auth.ts:436-545`
- **Description**: The credentials sign-in (`POST /auth/credentials/sign-in`) and sign-up (`POST /auth/credentials/sign-up`) endpoints have no rate limiting, account lockout, or brute force protection. There is no CSRF protection either (no CSRF tokens are checked on any POST endpoints).
- **Impact**: Attackers can perform unlimited password brute force attempts against the sign-in endpoint. The sign-up endpoint could be abused for mass account creation (resource exhaustion).
- **Fix**: Implement rate limiting middleware (e.g., per-IP throttling) on auth endpoints. Add account lockout after N failed attempts. Consider adding CSRF protection for session-based auth flows.
- **Confidence**: high

---

## Medium & Low Severity Findings

### Finding 7: `MASTRA_PACKAGES_FILE` Path Injection

- **Severity**: MEDIUM
- **Category**: File Read via Environment Variable
- **Location**: `packages/server/src/server/handlers/system.ts:19-29`
- **Description**: The `GET /system/packages` endpoint reads a file path from the `MASTRA_PACKAGES_FILE` environment variable and returns its parsed JSON contents. If an attacker can control this environment variable (e.g., in a shared hosting environment), they could read arbitrary JSON files from the filesystem.
- **Impact**: Information disclosure of JSON-parseable files accessible to the process.
- **Fix**: Validate that the path points to an expected location or use a fixed config path relative to the project root.
- **Confidence**: low (requires env var control)

### Finding 8: Gateway Memory Client Hardcoded Default URL

- **Severity**: MEDIUM
- **Category**: Insecure Default Configuration
- **Location**: `packages/server/src/server/handlers/gateway-memory-client.ts:276`
- **Description**: The gateway client defaults to `https://gateway-api.mastra.ai` when `MASTRA_GATEWAY_URL` is not set. Memory data (threads, messages, observations) is sent to this external service. Users may not realize their agent memory data is being transmitted to a third-party service.
- **Impact**: Unintended data exfiltration to Mastra's cloud service. Sensitive conversation data could be sent externally without explicit user consent.
- **Fix**: Require explicit opt-in for gateway features. Log a clear warning when the gateway client is initialized. Consider requiring `MASTRA_GATEWAY_URL` to be explicitly set rather than defaulting to a remote service.
- **Confidence**: medium

### Finding 9: Open Redirect Incomplete Validation

- **Severity**: MEDIUM
- **Category**: Open Redirect
- **Location**: `packages/server/src/server/handlers/auth.ts:219-240, 303-317`
- **Description**: The redirect validation allows any localhost URL (`localhost`, `127.0.0.1`, `[::1]`) on any port. While this is for dev convenience, an attacker could set up a service on localhost (or use DNS rebinding) to capture redirect tokens. The variable `isHttps` on line 227 is misleadingly named -- it matches both `http:` and `https:` protocols. Additionally, the callback handler re-validates the redirect from state, but the state itself could be tampered with between login and callback.
- **Impact**: Potential OAuth token/code leakage via redirect to attacker-controlled localhost service.
- **Fix**: In production, restrict redirects to same-origin only. Consider a configurable allowlist of redirect URIs rather than broad pattern matching.
- **Confidence**: medium

### Finding 10: Signed Dependency `node-forge` at Pinned Version

- **Severity**: MEDIUM
- **Category**: Supply Chain / Vulnerable Dependency
- **Location**: `package.json:128`
- **Description**: The root `package.json` pins `node-forge` at version `1.4.0` as a direct dependency. While 1.4.0 is not currently known to have critical vulnerabilities, `node-forge` has had a history of security issues (CVE-2022-24771, CVE-2022-24772, CVE-2022-24773). Pinning to a specific version prevents automatic security patches. The `docs/package.json` also includes `node-forge@^1.3.3` which could pull in versions with known vulnerabilities.
- **Impact**: Using an outdated cryptographic library could expose the project to known vulnerabilities.
- **Fix**: Update to latest `node-forge` or consider replacing with native Node.js crypto APIs. Use a range specifier (`^1.4.0`) instead of an exact pin to receive patch updates.
- **Confidence**: medium

### Finding 11: `pull_request_target` Workflow with PR Checkout

- **Severity**: MEDIUM
- **Category**: CI/CD Security
- **Location**: `.github/workflows/pr-triage.yml:4`
- **Description**: The `pr-triage.yml` workflow uses `pull_request_target` trigger. While it only performs org membership checks and adds comments (no code execution from the PR branch), the pattern is worth monitoring. The `dane-pr-commands.yml` workflow is better designed -- it uses `issue_comment` trigger, checks org membership, and explicitly checkouts trusted code from the default branch before running commands.
- **Impact**: Low in current implementation since no PR code is executed. However, future modifications could inadvertently introduce code execution from untrusted PR branches.
- **Fix**: Add a comment documenting why `pull_request_target` is safe here (no code execution from PR). Consider migrating to `pull_request` if secrets aren't needed.
- **Confidence**: low

### Finding 12: Secrets Exposed to workflow_run Workflows

- **Severity**: MEDIUM
- **Category**: CI/CD Secret Exposure
- **Location**: `.github/workflows/secrets.e2e.yml`, `.github/workflows/vitest-changed.yml`
- **Description**: Multiple workflows triggered by `workflow_run` expose numerous API keys (OpenAI, Anthropic, Google, Cohere, Pinecone, Cloudflare, etc.) as environment variables. While `workflow_run` is generally safe (runs on the default branch), the large number of secrets exposed increases the blast radius if any workflow step is compromised.
- **Impact**: If any test or build step is compromised, many third-party API keys could be exfiltrated.
- **Fix**: Apply principle of least privilege -- only pass secrets needed by each specific job. Consider using OIDC tokens or secret-scoped GitHub environments.
- **Confidence**: medium

### Finding 13: No CORS Configuration in Server

- **Severity**: LOW
- **Category**: Missing Security Header
- **Location**: `packages/server/src/` (throughout)
- **Description**: The server package has no CORS middleware or configuration. The proxy routes for skills.sh (lines 1178, 1234 in workspace.ts) explicitly mention avoiding CORS issues. Without CORS headers, the API could be called from any web origin.
- **Impact**: Cross-origin requests to the Mastra API are unrestricted. In browser-deployed scenarios, this could enable CSRF-like attacks.
- **Fix**: Add configurable CORS middleware. Default to restrictive same-origin policy.
- **Confidence**: medium

### Finding 14: Error Messages May Leak Internal Details

- **Severity**: LOW
- **Category**: Information Disclosure
- **Location**: `packages/server/src/server/handlers/auth.ts:364-365`
- **Description**: On OAuth callback failure, the error message is URL-encoded and included in the redirect: `error=${encodeURIComponent(error.message)}`. Internal error messages (stack traces, database errors) could be exposed to the user.
- **Impact**: Information disclosure of internal system details via error messages in redirect URLs.
- **Fix**: Map internal errors to generic user-facing messages. Log detailed errors server-side only.
- **Confidence**: medium

### Finding 15: Metadata Key Validation is Defense-Only

- **Severity**: LOW
- **Category**: Input Validation
- **Location**: `packages/core/src/storage/domains/memory/base.ts:322-348`
- **Description**: The `validateMetadataKeys()` method provides good protection against SQL injection and prototype pollution in metadata keys. However, it's a `protected` method that must be explicitly called by each storage adapter implementation. If a custom adapter forgets to call it, the protection is absent.
- **Impact**: Storage adapters that don't call `validateMetadataKeys()` could be vulnerable to injection via metadata keys.
- **Fix**: Make the validation mandatory by calling it in the base class before delegating to the implementation, or use a template method pattern.
- **Confidence**: low

---

## Supply Chain Analysis

### Dependency Management
- **Package Manager**: pnpm 10.29.3 with integrity hash verification in `packageManager` field
- **Lockfile**: `pnpm-lock.yaml` present and tracked in git
- **Overrides**: Several security-relevant overrides in `package.json`:
  - `cookie: >=1.1.1` (fixes prototype pollution)
  - `ssri: >=6.0.2` (ReDoS fix)
  - `body-parser@<=2.2.1: 2.2.2` (security patch)
  - `fast-xml-parser@<=5.3.8: 5.5.7` (security patch)
  - `js-yaml: ^3.14.2` (code execution fix)
- **Patched Dependencies**: `@changesets/get-dependents-graph` and `fetch-to-node@2.1.0`

### Notable Dependencies
- `node-forge@1.4.0` -- pinned, history of CVEs
- `better-auth@^1.4.18` -- overridden, auth library
- 23 storage adapters (pg, libsql, mongodb, dynamodb, etc.) each bring their own dependency trees
- `superjson` used for serialization -- generally safe

### CI/CD Security
- Renovate configured for automated dependency updates (`renovate.json`)
- Changesets used for version management
- `pnpm install --frozen-lockfile` used in CI (good)
- Pre-install script enforces pnpm usage (`npx only-allow pnpm`)

### Supply Chain Risks
- Large dependency surface (23+ storage adapters, multiple AI provider integrations)
- Multiple API keys handled (OpenAI, Anthropic, Google, Cohere, Pinecone, etc.)
- Templates ship `.env.example` files -- good practice
- `.gitignore` properly excludes `.env` files

---

## Code Quality Assessment

### Strengths
1. **Well-structured auth system**: Multi-layer auth with SSO, credentials, RBAC, and per-route permissions. Good separation of concerns.
2. **Schema validation**: Zod schemas used throughout for input/output validation on API routes.
3. **Prototype pollution protection**: Explicit checks for `__proto__`, `prototype`, `constructor` in metadata keys.
4. **CI security practices**: `dane-pr-commands.yml` properly separates trusted/untrusted code. Org membership checks before executing commands.
5. **Command sanitization**: The PR bot sanitizes unknown commands before displaying them (line 80 of dane-pr-commands.yml).
6. **Input sanitization**: `sanitizeBody()` function removes disallowed keys from request bodies.
7. **Parameterized queries**: The pg store uses parameterized queries via `pg.Pool.query(sql, values)`.
8. **Comprehensive test coverage**: Auth helpers, memory handlers, and workspace handlers have extensive tests.

### Weaknesses
1. **No rate limiting anywhere in the server**
2. **No CSRF protection**
3. **No CORS configuration**
4. **`eval()` usage in CLI**
5. **Permissive defaults on shell command tool**
6. **Missing path traversal validation on filesystem operations**

---

## Contribution Opportunities

1. **Add rate limiting middleware**: The server has zero rate limiting. Contributing a configurable rate limiter (especially for auth endpoints) would be a high-value security improvement.

2. **Replace `eval()` with AST parser in nextConfigRule**: The code already has a TODO comment for this (`// TODO: Move to babel`). This is a well-scoped, clearly needed change.

3. **Add path traversal protection to workspace filesystem**: The workspace filesystem handlers need path normalization and sandboxing validation. This is a clear gap.

4. **Strengthen `createRunCommandTool` defaults**: Making `allowedCommands` required and expanding the blocklist would significantly reduce the attack surface.

5. **Add CORS middleware**: The server lacks CORS support entirely. Adding configurable CORS would benefit all users deploying Mastra-based APIs.

---

## Draft PRs (top 3)

### PR 1: Replace `eval()` with safe config parser in CLI lint rule

**Files**: `packages/cli/src/commands/lint/rules/nextConfigRule.ts`
**Change**: Replace `eval(`(${configStr})`)` with a safe JSON-like parser or AST-based approach using `acorn` or `@babel/parser` to extract the config object without executing arbitrary code.
**Impact**: Eliminates code injection vector in the CLI tool.

### PR 2: Add path traversal protection to workspace filesystem handlers

**Files**: `packages/server/src/server/handlers/workspace.ts`
**Change**: Add a `validateWorkspacePath()` helper that normalizes the decoded path with `path.resolve()` and verifies it stays within the workspace root. Call this before every `readFile`, `writeFile`, `list`, `delete`, `move`, and `mkdir` operation.
**Impact**: Prevents directory traversal attacks on workspace filesystem endpoints.

### PR 3: Harden `createRunCommandTool` security defaults

**Files**: `packages/core/src/loop/network/run-command-tool.ts`
**Change**: Add `bash`, `sh`, `zsh`, `python`, `python3`, `perl`, `ruby`, `env`, `xargs`, `awk`, `find`, `nohup`, `tee` to the blocked commands list. Deprecate `allowUnsafeCharacters`. Enable PATH restriction by default. Add a runtime warning when `allowedCommands` is empty.
**Impact**: Significantly reduces the attack surface of the shell command tool available to AI agents.

---

## Scores (1-10)

| Category | Score | Notes |
|----------|-------|-------|
| **Overall Security Posture** | 6 | Good auth architecture but several gaps in input validation and missing security middleware |
| **Authentication & Authorization** | 7 | Multi-layer auth with RBAC, but no rate limiting, no CSRF, header-based dev bypass |
| **Input Validation** | 6 | Zod schemas on API routes, metadata key validation, but `eval()` in CLI and no path traversal checks |
| **Dependency Management** | 7 | pnpm with lockfile, security overrides for known CVEs, Renovate for updates, but large attack surface |
| **CI/CD Security** | 7 | Good trusted/untrusted code separation in dane workflow, but broad secret exposure in test workflows |
| **Code Quality** | 8 | Well-structured, good TypeScript, comprehensive tests, clear patterns |
| **Cryptographic Practices** | 6 | Uses `crypto.randomUUID()` for state, but pinned `node-forge`, no security headers |
| **Error Handling** | 6 | Generic errors on auth failure (good), but internal errors leaked in OAuth redirects |
| **Documentation** | 8 | Excellent CLAUDE.md/AGENTS.md, detailed auth flow documentation, clear code comments |
| **Supply Chain Security** | 6 | Lockfile present, overrides for CVEs, but huge dependency surface with 23 store adapters |

---

## Summary

**Overall risk level: MEDIUM-HIGH**

The mastra-ai/mastra repository demonstrates solid software engineering practices with a well-designed auth architecture, comprehensive schema validation, and good CI/CD security patterns. However, several security gaps exist that could be exploited in production deployments:

**Finding Counts**:
- Critical: 0
- High: 6 (eval() usage, permissive shell command tool, dev auth bypass, X-Forwarded-Host injection, path traversal, no rate limiting)
- Medium: 6 (env path injection, gateway default URL, open redirect, node-forge pinning, pull_request_target, secret exposure)
- Low: 3 (no CORS, error info disclosure, optional metadata validation)
- **Total: 15 findings**

The most impactful issues are the lack of path traversal protection on workspace filesystem operations, the `eval()` usage in the CLI, the permissive defaults on the shell command execution tool, and the absence of rate limiting on authentication endpoints. The X-Forwarded-Host trust issue in the OAuth flow is particularly concerning as it could enable token theft in reverse-proxy deployments.

The codebase shows security awareness (prototype pollution checks, command blocklists, input sanitization) but has gaps in defense-in-depth, especially around filesystem operations, rate limiting, and secure-by-default configurations.
