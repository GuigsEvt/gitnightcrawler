Now I have a thorough understanding of the entire codebase. Here's the audit report:

---

# Audit: epiral/bb-browser

## Repository Overview

bb-browser ("BadBoy Browser") is a CLI + MCP server + Chrome extension system that lets AI agents control the user's real Chrome browser using their existing login state. Instead of headless browsers or scrapers, it leverages Chrome DevTools Protocol (CDP) and a browser extension to execute commands (navigate, click, eval, screenshot, network capture) in the user's authenticated session. It supports 103 commands across 36 platforms via community-built "site adapters" and integrates with Claude Code/Cursor via MCP. It also has a Pinix Hub bridge (`bb-browserd`) for OpenClaw integration.

**Tech stack:** TypeScript, Node.js (>=18), pnpm monorepo with Turborepo, Chrome Extension (Manifest V3), Chrome DevTools Protocol, MCP SDK (`@modelcontextprotocol/sdk`), gRPC/Connect (`@connectrpc/connect`), Protobuf, Zod, Vite (extension build), tsup (CLI/daemon build), ESLint.

**Maturity:** Early/Growing (v0.10.1, active development, limited tests, no stable API guarantee).

---

## Code Quality Assessment

### Architecture and Organization
Well-structured pnpm monorepo with clear separation:
- `packages/shared` -- protocol types, constants
- `packages/daemon` -- HTTP server + SSE bridge
- `packages/cli` -- CLI commands (30+ commands)
- `packages/extension` -- Chrome extension (MV3 background service worker)
- `packages/mcp` -- MCP server for Claude/Cursor integration
- `bin/bb-browserd.ts` -- Pinix Hub bridge (standalone Bun script)

Architecture is clean: CLI --> HTTP --> Daemon --> SSE --> Extension --> CDP --> Browser. Good separation of concerns. The command-handler.ts at ~1400 lines is the largest file and could benefit from splitting.

### Error Handling Patterns
- Consistent try/catch with `Error instanceof` checks throughout
- Request timeout management in `RequestManager` with proper cleanup
- SSE reconnection with backoff in extension client
- Some silenced errors (catch blocks that only reconnect without logging)
- Inconsistent patterns: some functions return error objects, others throw, others use `process.exit(1)`

### Test Coverage
**Critically low.** Only 2 test files exist:
- `packages/cli/src/openclaw-json.test.ts` (~10 tests for JSON parsing)
- `packages/cli/src/openclaw-bridge.test.ts` (~3 tests for argument building)

Estimated coverage: **~2-3%**. Zero tests for daemon, extension, MCP server, protocol, or any of the 30+ CLI commands.

### Documentation Quality
- Good README with bilingual support (EN/ZH)
- PRIVACY.md present
- AGENTS.md with AI agent guidance
- Skills documentation for OpenClaw
- Chinese inline comments throughout codebase (fine for the team, but limits contributor pool)
- No SECURITY.md, no CONTRIBUTING.md, no API docs

### Dependency Health
- 5 direct dependencies, all well-maintained and current
- `ws`, `ajv`, `@modelcontextprotocol/sdk`, `@connectrpc/connect`, `@bufbuild/protobuf`
- No abandoned or deprecated dependencies
- pnpm lockfile present, CI uses `--frozen-lockfile`

---

## Security Findings

### Critical

None found.

### High

**H1: Wildcard CORS on daemon HTTP server**
- File: `packages/daemon/src/http-server.ts:97` and `packages/daemon/src/sse-manager.ts:42`
- `Access-Control-Allow-Origin: *` allows any webpage to send commands to the daemon. A malicious site could execute `eval` commands in the user's authenticated browser session via `fetch('http://127.0.0.1:19824/command', ...)`.
- This is a **DNS rebinding** / **localhost CSRF** attack vector.

**H2: No authentication on daemon endpoints**
- File: `packages/daemon/src/http-server.ts:95-121`
- Any local process or website (via CORS) can POST to `/command`, `/shutdown`, or connect to `/sse` with zero authentication. Combined with H1, this is exploitable remotely.

**H3: Arbitrary JavaScript execution via eval**
- Files: `packages/cli/src/commands/eval.ts`, `packages/mcp/src/index.ts:378-389`, `bin/bb-browserd.ts:651-670`
- The `eval` command executes arbitrary JS in page context with full cookie/session access. By design, but no confirmation prompt, no allowlist, no `--dangerous` flag. Combined with H1+H2, a remote attacker could exfiltrate session tokens.

### Medium

**M1: No request body size limit**
- File: `packages/daemon/src/http-server.ts:245-261`
- `readBody()` concatenates all chunks without a size limit. An attacker could send a multi-GB body to OOM the daemon.

**M2: Unauthenticated /shutdown endpoint**
- File: `packages/daemon/src/http-server.ts:231-240`
- Any local process can POST to `/shutdown` and kill the daemon with no auth.

**M3: Cookie exfiltration via getCookies command**
- File: `bin/bb-browserd.ts:680-694`
- The `getCookies` capability returns all cookies for the current page domain. Combined with H1+H2, this could be exploited for session hijacking.

**M4: Command injection risk in site_run MCP tool**
- File: `packages/mcp/src/index.ts:604-631`
- User-supplied `namedArgs` are passed directly as CLI arguments: `cliArgs.push(`--${key}`, value)`. While `execFile` is used (safe vs shell injection), keys are not validated and could inject unexpected flags.

### Low

**L1: localhost vs 127.0.0.1 inconsistency**
- File: `packages/shared/src/constants.ts:9` uses `"localhost"` for `DAEMON_HOST`, but `packages/daemon/src/http-server.ts:37` binds to `"127.0.0.1"`. On systems resolving localhost to `::1`, the CLI can't reach the daemon.

**L2: No rate limiting on daemon endpoints**
- File: `packages/daemon/src/http-server.ts`
- No request throttling. Local DoS possible.

**L3: Hardcoded CDP port written to predictable file**
- File: `bin/bb-browserd.ts:30` -- `~/.bb-browser/browser/cdp-port`
- Any local user can read the CDP port and connect to Chrome's debugging interface.

### Info

**I1: Protobuf descriptor embedded as base64 blob**
- File: `bin/bb-browserd.ts:392`
- 4KB+ base64 protobuf descriptor inlined. Not a security issue but makes code review difficult -- changes to the proto schema are opaque.

**I2: No SECURITY.md or vulnerability disclosure process**

---

## Contribution Opportunities

### Bugs

1. **File:** `packages/shared/src/constants.ts:9`
   - **Issue:** `DAEMON_HOST = "localhost"` causes IPv6 resolution failures on some systems
   - **Fix:** Change to `"127.0.0.1"` to match actual binding in daemon
   - **Effort:** trivial
   - **PR-worthy:** high

2. **File:** `packages/daemon/src/http-server.ts:245-261`
   - **Issue:** `readBody()` has no size limit -- unbounded memory allocation
   - **Fix:** Add `const MAX_BODY_SIZE = 10 * 1024 * 1024;` and reject if exceeded
   - **Effort:** trivial
   - **PR-worthy:** high

### Security Fixes

3. **File:** `packages/daemon/src/http-server.ts:97`, `packages/daemon/src/sse-manager.ts:42`
   - **Issue:** Wildcard CORS enables remote command execution
   - **Fix:** Replace `*` with origin validation allowing only `chrome-extension://` and `http://127.0.0.1:*`
   - **Effort:** small
   - **PR-worthy:** high

4. **File:** `packages/daemon/src/http-server.ts:95-121`
   - **Issue:** No authentication on daemon
   - **Fix:** Generate a random token at daemon start, write to `~/.bb-browser/daemon-token`, require `Authorization: Bearer <token>` header on all endpoints
   - **Effort:** medium
   - **PR-worthy:** high

5. **File:** `packages/daemon/src/http-server.ts:245-261`
   - **Issue:** No body size limit on POST endpoints
   - **Fix:** Reject bodies exceeding 10MB
   - **Effort:** trivial
   - **PR-worthy:** medium

### Missing Tests

6. **File:** `packages/daemon/src/` (all files)
   - **Issue:** Zero test coverage for daemon HTTP server, SSE manager, request manager
   - **Fix:** Add unit tests for HTTP routing, SSE connection lifecycle, request timeout/resolution
   - **Effort:** medium
   - **PR-worthy:** high

7. **File:** `packages/mcp/src/index.ts`
   - **Issue:** Zero test coverage for MCP server with 20+ tools
   - **Fix:** Add integration tests mocking daemon responses
   - **Effort:** medium
   - **PR-worthy:** high

8. **File:** `packages/shared/src/protocol.ts`
   - **Issue:** Protocol types have no runtime validation
   - **Fix:** Add Zod schemas for Request/Response and validate at daemon boundary
   - **Effort:** medium
   - **PR-worthy:** medium

### Documentation Gaps

9. **File:** (new) `SECURITY.md`
   - **Issue:** No security policy, threat model, or disclosure process
   - **Fix:** Document localhost-only trust model, eval risks, disclosure email
   - **Effort:** small
   - **PR-worthy:** high

10. **File:** (new) `CONTRIBUTING.md`
    - **Issue:** No contributor guide
    - **Fix:** Add setup instructions, PR guidelines, code style notes
    - **Effort:** small
    - **PR-worthy:** medium

### Code Improvements

11. **File:** `packages/extension/src/background/command-handler.ts` (~1400 lines)
    - **Issue:** Monolithic file handling all commands
    - **Fix:** Split into per-command or per-domain handler files
    - **Effort:** medium
    - **PR-worthy:** medium

12. **File:** `bin/bb-browserd.ts` (1248 lines)
    - **Issue:** Single file containing CDP client, Pinix bridge, protobuf, CLI parser, all command handlers
    - **Fix:** Split into modules (cdp-client, pinix-bridge, commands, etc.)
    - **Effort:** medium
    - **PR-worthy:** medium

13. **File:** `packages/mcp/src/index.ts:132-157`
    - **Issue:** `tryParseJson` uses O(n^2) brute-force line scanning to find valid JSON in stdout
    - **Fix:** Try full parse first, then scan from end (most common case is trailing JSON)
    - **Effort:** small
    - **PR-worthy:** low

### Feature Ideas

14. Unix domain socket support for daemon (eliminates CORS/network attack surface entirely)
15. Audit logging -- record all commands executed with timestamps
16. `--confirm` flag for eval command requiring user confirmation

---

## Draft PRs

### PR 1: Restrict CORS and add token auth to daemon

- **PR Title:** `fix: restrict CORS policy and add token authentication to daemon`
- **Branch:** `fix/daemon-auth-cors`
- **Files:**
  - `packages/daemon/src/http-server.ts` -- CORS origin validation, token check middleware
  - `packages/daemon/src/index.ts` -- generate token on start, write to `~/.bb-browser/daemon-token`
  - `packages/shared/src/constants.ts` -- add `DAEMON_TOKEN_PATH` constant
  - `packages/cli/src/client.ts` -- read token from file, add Authorization header
  - `packages/mcp/src/index.ts` -- read token from file, add Authorization header
  - `packages/extension/src/background/sse-client.ts` -- read token, pass in SSE URL
- **Changes:** Replace `Access-Control-Allow-Origin: *` with allowlist (`chrome-extension://`, `http://127.0.0.1`). Generate random 32-byte token at daemon startup, persist to `~/.bb-browser/daemon-token`. Require `Authorization: Bearer <token>` on `/command`, `/result`, `/shutdown`. The `/status` and `/sse` endpoints check token as well. CLI and MCP read token from the file. Extension reads from chrome.storage or queries daemon.
- **Effort:** 2-3 hours
- **Impact:** Closes the most critical security gap -- prevents remote websites and unauthorized local processes from controlling the user's browser.

### PR 2: Add request body size limit and input validation

- **PR Title:** `fix: add body size limit and validate daemon request payloads`
- **Branch:** `fix/daemon-input-validation`
- **Files:**
  - `packages/daemon/src/http-server.ts` -- max body size in `readBody()`, validate JSON against schema
  - `packages/shared/src/constants.ts` -- add `MAX_REQUEST_BODY_SIZE`
  - `packages/shared/src/protocol.ts` -- add Zod schema for Request type
- **Changes:** Add 10MB body limit in `readBody()` with 413 response on overflow. Add Zod schema validation for incoming Request objects in `handleCommand()`. Reject malformed or unknown action types early.
- **Effort:** 1-2 hours
- **Impact:** Prevents OOM attacks and ensures only valid commands reach the extension.

### PR 3: Add daemon and MCP server test suite

- **PR Title:** `test: add unit tests for daemon HTTP server and MCP tools`
- **Branch:** `feat/daemon-mcp-tests`
- **Files:**
  - `packages/daemon/src/http-server.test.ts` -- new
  - `packages/daemon/src/request-manager.test.ts` -- new
  - `packages/daemon/src/sse-manager.test.ts` -- new
  - `packages/mcp/src/index.test.ts` -- new
  - `packages/daemon/package.json` -- add test script/deps
  - `packages/mcp/package.json` -- add test script/deps
- **Changes:** Add vitest as test runner. Test HTTP routing (404, CORS, valid/invalid POST), SSE connection lifecycle (connect, heartbeat, disconnect), request manager (add, resolve, timeout, clear), MCP tool handlers with mocked daemon responses. Target 80%+ coverage for daemon, 60%+ for MCP.
- **Effort:** 4-6 hours
- **Impact:** Establishes testing foundation, catches regressions, makes future contributions safer.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 3 |
| Documentation | 5 |
| Test Coverage | 1 |
| Contribution Potential | 9 |
