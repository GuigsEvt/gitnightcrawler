# Audit: epiral/bb-browser

## Repository Overview

**bb-browser** (npm: `@anthropic-ai/browser-tool` / `@pinix/browser`) is a browser automation toolkit that lets AI agents (Claude Code, Cursor, etc.) control a real Chrome browser via CLI commands or an MCP server. It uses a three-tier architecture: CLI/MCP client -> localhost HTTP daemon -> Chrome MV3 extension -> Chrome DevTools Protocol (CDP). All communication is local-only with no external data transmission. The project provides 35+ commands (click, fill, eval, fetch, screenshot, network monitoring, etc.) enabling agents to browse the web with the user's real login state.

**Tech stack**: TypeScript 5.7+ (strict mode), Node.js 18+, pnpm monorepo (Turborepo), Chrome Manifest V3 extension, Vite, tsup, WebSocket (CDP), HTTP/SSE (daemon), gRPC (Pinix integration).

**Maturity**: Growing -- v0.10.1, active development, solid architecture but low test coverage.

---

## Code Quality Assessment

### Architecture and Organization
Well-structured pnpm monorepo with clear separation of concerns across 5 packages (`shared`, `cli`, `daemon`, `extension`, `mcp`). Data flows cleanly: CLI -> daemon (HTTP) -> extension (SSE) -> Chrome (CDP). Each package has its own build config and TypeScript setup. The extension properly separates background service worker, command handling, CDP service, and DOM service.

### Error Handling
Consistent patterns throughout: try-catch with typed error messages, 30s command timeouts with 408 responses, exponential backoff reconnection (capped at 60s), graceful degradation when daemon is unavailable (CLI falls back to direct CDP). Could benefit from more granular error categories and structured logging.

### Test Coverage
**Poor.** Only 2 test files found (`openclaw-json.test.ts`, `openclaw-bridge.test.ts`). No tests for the 35+ CLI commands, no integration tests for daemon-extension communication, no E2E tests. This is the biggest weakness.

### Documentation Quality
**Excellent.** Comprehensive README (40+ pages with examples), Chinese translation, PRIVACY.md with data handling specifics, AGENTS.md for agent integration, CHANGELOG.md, and embedded CLI guide (`bb-browser guide`).

### Dependency Health
Lean dependency tree. Key deps: `ws` (WebSocket), `@modelcontextprotocol/sdk`, `ajv` (validation), `@bufbuild/protobuf` (gRPC). Lockfile present. No security scanning in CI/CD. No `npm audit` step in publish workflow.

---

## Security Findings

### Critical
None found.

### High
None found.

### Medium

| # | Finding | Location |
|---|---------|----------|
| 1 | **PID and context files in world-readable `/tmp`** -- CDP session state (tab URLs, connection info) stored in `/tmp` readable by all users | `packages/daemon/src/index.ts:18`, `packages/cli/src/cdp-client.ts:89-92`, `bin/bb-browserd.ts:30` |
| 2 | **No rate limiting on daemon HTTP server** -- rapid requests could cause resource exhaustion on single-threaded Node.js | `packages/daemon/src/http-server.ts` |
| 3 | **CORS `Access-Control-Allow-Origin: *`** -- safe for localhost but risky if user binds to `0.0.0.0` | `packages/daemon/src/http-server.ts:97` |

### Low

| # | Finding | Location |
|---|---------|----------|
| 4 | **Naive glob-to-regex conversion** -- `route.urlPattern.replace(/\*/g, '.*')` doesn't escape `.` or other regex metacharacters, potential ReDoS with crafted patterns | `packages/extension/src/background/cdp-service.ts:1158-1170` |
| 5 | **No test step in publish CI** -- code ships without automated test verification | `.github/workflows/publish.yml` |
| 6 | **No heartbeat timeout in extension** -- if daemon disappears without closing SSE, extension doesn't detect it until next reconnect attempt | `packages/extension/src/background/sse-client.ts` |

### Info

| # | Finding |
|---|---------|
| 7 | `eval` command executes arbitrary JS in page context -- by design but should be documented as high-trust operation |
| 8 | Extension requires broad permissions (`debugger`, `<all_urls>`, `history`) -- necessary for functionality but worth documenting justification |
| 9 | No telemetry, no external data transmission -- excellent privacy posture verified across all source files |

---

## Contribution Opportunities

### Bugs

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `packages/extension/src/background/cdp-service.ts:1158-1170` | Glob-to-regex doesn't escape regex metacharacters; `example.com/*` matches `exampleXcom/anything` | Use `minimatch` or escape dots before converting | small | high |

### Security Fixes

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `packages/daemon/src/index.ts:18`, `packages/cli/src/cdp-client.ts:89-92` | PID and context files in world-readable `/tmp` | Move to `~/.bb-browser/` with mode 0700 | small | high |
| `packages/daemon/src/http-server.ts` | No rate limiting on HTTP endpoints | Add simple request counter with sliding window | small | medium |
| `packages/daemon/src/http-server.ts:97` | Wildcard CORS when `--host 0.0.0.0` | Restrict origin when not localhost | trivial | medium |

### Missing Tests

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `packages/cli/src/commands/*.ts` | Zero test coverage for 35+ CLI commands | Add unit tests for command argument parsing and script generation | large | high |
| `packages/daemon/src/` | No integration tests for daemon-extension communication | Add tests with mock SSE client | medium | high |
| `packages/mcp/src/` | No tests for MCP server tool registration | Add tests verifying tool schemas and routing | medium | medium |

### Documentation Gaps

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| (missing) | No CONTRIBUTING.md | Add contributor guide with setup instructions, test requirements | small | medium |
| (missing) | No SECURITY.md | Add security model documentation, responsible disclosure process | small | high |
| (missing) | No architecture diagram/doc | Add architecture.md with data flow and threat model | medium | medium |

### Code Improvements

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `.github/workflows/publish.yml` | No test or audit step before publish | Add `pnpm test` and `pnpm audit` steps | trivial | high |
| `packages/extension/src/background/sse-client.ts` | No heartbeat timeout detection | Add timer that triggers reconnect if no heartbeat within 2x interval | trivial | medium |
| `packages/daemon/src/http-server.ts` | Raw `http.createServer` with manual routing | Consider using a lightweight router for maintainability | medium | low |

### Feature Ideas

| Description | Effort | PR-worthy |
|-------------|--------|-----------|
| Add `--dry-run` flag to `eval` command showing script without executing | trivial | medium |
| Add Dependabot config for automated dependency security updates | trivial | high |
| Add structured JSON logging option for daemon (audit trail) | small | medium |
| Dynamic permission requests in extension (request `history` only when needed) | medium | medium |

---

## Draft PRs

### PR 1: fix: move temp files from /tmp to ~/.bb-browser for security

- **Branch**: `fix/secure-temp-files`
- **Files**: `packages/daemon/src/index.ts`, `packages/cli/src/cdp-client.ts`, `bin/bb-browserd.ts`, `packages/shared/src/constants.ts`
- **Changes**: 
  - Add `BB_HOME` constant (`~/.bb-browser`) to shared constants
  - Add `ensureHomeDir()` helper that creates `~/.bb-browser` with mode 0700
  - Change PID file path from `/tmp/bb-browser.pid` to `~/.bb-browser/daemon.pid`
  - Change CDP context file from `/tmp/bb-browser-cdp-context-*.json` to `~/.bb-browser/cdp-context-*.json`
  - Change bb-browserd PID from `/tmp/bb-browserd.pid` to `~/.bb-browser/browserd.pid`
  - Update cleanup/shutdown to use new paths
- **Effort**: 1-2 hours
- **Impact**: Prevents information disclosure of CDP session state and tab URLs to other users on shared systems

### PR 2: fix: escape regex metacharacters in URL pattern matching

- **Branch**: `fix/url-pattern-matching`
- **Files**: `packages/extension/src/background/cdp-service.ts`
- **Changes**:
  - Replace naive `.replace(/\*/g, '.*')` with proper escaping: escape all regex metacharacters first, then convert `*` to `.*`
  - Or add `minimatch` dependency and use it for glob matching
  - Add unit tests for pattern matching edge cases (dots in domains, query params, etc.)
- **Effort**: 30 minutes
- **Impact**: Prevents unintended URL matches in network route mocking that could cause subtle debugging issues

### PR 3: ci: add test and security audit steps to publish workflow

- **Branch**: `feat/ci-security-checks`
- **Files**: `.github/workflows/publish.yml`, `.github/dependabot.yml`
- **Changes**:
  - Add `pnpm test` step after build in publish workflow
  - Add `pnpm audit --audit-level=high` step before publish
  - Add Dependabot configuration for npm ecosystem with weekly schedule
  - Add `SECURITY.md` with responsible disclosure process
- **Effort**: 30 minutes
- **Impact**: Prevents publishing untested or vulnerable code, enables automated dependency updates

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 8 |
| Test Coverage | 2 |
| Contribution Potential | 9 |

**Summary**: Well-architected, privacy-first browser automation tool with excellent documentation and a strong security posture for its threat model. The critical gap is test coverage (only 2 test files for 35+ commands). The security findings are all medium/low severity -- no hardcoded secrets, no data exfiltration, no auth bypass. High contribution potential due to the clear codebase and numerous straightforward improvement opportunities.
