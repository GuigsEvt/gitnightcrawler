# Audit: nextlevelbuilder/goclaw

## Repository Overview

GoClaw is a PostgreSQL-backed, multi-tenant AI agent gateway that exposes both WebSocket RPC (v3 frame protocol) and HTTP REST APIs. It orchestrates LLM-powered agents through a think-act-observe loop, supports multiple messaging channels (Telegram, Slack, Discord, Feishu, Zalo, WhatsApp), and provides a React SPA dashboard. The system includes RBAC, AES-256-GCM encrypted API keys, Docker sandboxing, MCP bridge, pgvector memory, knowledge graphs, cron scheduling, and TTS integration across 6+ LLM providers.

**Tech stack:** Go 1.26, Cobra CLI, gorilla/websocket, pgx/v5, golang-migrate, go-rod | React 19, Vite 6, TypeScript 5.7, Tailwind CSS 4, Radix UI, Zustand | PostgreSQL 18 + pgvector, Redis

**Maturity:** Growing — 609 Go files, 22 migration pairs, 22 technical docs, 5 CI workflows, 9 Docker Compose stacks. Active development with recent commits. Architecture is well-structured but test coverage is sparse.

---

## Code Quality Assessment

### Architecture and Organization
Strong separation of concerns. The `internal/` tree follows Go best practices: interface-based stores (`store.SessionStore`, `store.AgentStore`) with `pg/` implementations, clean package boundaries, and context propagation via `store.WithAgentType(ctx)`. The `cmd/` layer uses Cobra properly. The `pkg/protocol/` wire types are cleanly isolated. The provider system is extensible with retry logic (`RetryDo()`). The agent loop (`RunRequest` → think→act→observe → `RunResult`) is well-modeled. Channel integrations follow a consistent dispatcher pattern.

**Weakness:** `cmd/gateway.go` is 35KB — the gateway startup is monolithic. The `internal/tools/` directory has 102 files which could benefit from sub-packaging.

### Error Handling
Generally good. SQL operations use parameterized queries with proper error returns. The `execMapUpdate()` helper validates column names via regex before interpolation. Security events are logged consistently via `slog.Warn("security.*")`. Crypto operations fail safely. The input guard uses detection-only mode with clear warnings.

### Test Coverage
**~20-25% estimated coverage.** 56 test files, 12,381 lines, 466+ test functions. Strong areas: tools (102 tests), channels (110 tests), HTTP API (34 tests), agent loop (59 tests). Critical gaps: `store/pg/` (54 files, 1 test file), `crypto/` (0 tests), `permissions/` (0 tests), `config/` (0 tests), `sessions/` (0 tests), `memory/` (0 tests). CI runs `go test -race ./...` but has no coverage reporting.

### Documentation Quality
Excellent. 22 numbered technical docs covering architecture, agent loop, providers, tools, gateway protocol, channels, data model, scheduling, security, tracing, teams, skills, and API. README is 948 lines. WebSocket protocol and API reference are separate docs. CLAUDE.md provides comprehensive project context. i18n supports en/vi/zh.

### Dependency Health
Clean. 23 direct Go dependencies, all recent. No replace directives. Frontend uses React 19, Vite 6, pnpm with SHA-pinned version. One concern: `gorilla/websocket` uses a pseudo-version (`v1.5.4-0.20250319...`) instead of a tagged release. License is CC BY-NC 4.0 (non-commercial).

---

## Security Findings

### Critical
None found.

### High

| # | Finding | Location |
|---|---------|----------|
| H1 | **XSS via dangerouslySetInnerHTML** — Highlighted code rendered as raw HTML in file viewers and trace dialogs. If attacker-controlled content reaches highlight.js, it could execute scripts. | `ui/web/src/components/shared/file-viewers.tsx:85`, `ui/web/src/pages/traces/trace-detail-dialog.tsx:435` |

### Medium

| # | Finding | Location |
|---|---------|----------|
| M1 | **Dev-mode admin bypass** — Empty `GOCLAW_GATEWAY_TOKEN` grants admin to all requests. No startup warning in production. | `internal/http/auth.go:145-148` |
| M2 | **CORS wildcard allowed** — `AllowedOrigins` config accepts `"*"`, defeating CORS protection. OpenAPI endpoint hardcodes `Access-Control-Allow-Origin: *`. | `internal/gateway/server.go:119-138`, `internal/http/openapi.go:30` |
| M3 | **Sandbox setup command injection** — `cfg.SetupCommand` passed to `sh -lc` without validation. Safe only if config is trusted. | `internal/sandbox/docker.go:122-129` |
| M4 | **Crypto module untested** — AES-256-GCM encryption and API key hashing have zero test coverage. Implementation looks correct but unverified. | `internal/crypto/aes.go`, `internal/crypto/apikey.go` |

### Low

| # | Finding | Location |
|---|---------|----------|
| L1 | **No bounds validation on query params** — `limit`/`offset` silently default to 0 on parse failure, no max bounds. | `internal/http/knowledge_graph_handlers.go:19-20` |
| L2 | **Sandbox race condition** — Mutex only protects `lastUsed`; concurrent `Exec` calls on same sandbox are unprotected. | `internal/sandbox/docker.go:144-146` |

### Info

| # | Finding | Location |
|---|---------|----------|
| I1 | SQL helper `execMapUpdate` properly validates column names via `^[a-zA-Z_][a-zA-Z0-9_]*$` regex. | `internal/store/pg/helpers.go:167-192` |
| I2 | Shell deny patterns, credentialed exec with operator detection, and web content homoglyph sanitization are all well-implemented. | `internal/tools/shell.go`, `internal/tools/credentialed_exec.go`, `internal/tools/web_shared.go` |
| I3 | Prompt injection detection in web tool results with security warnings. | `internal/agent/loop_utils.go:27-41` |

---

## Contribution Opportunities

### Bugs

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `internal/sandbox/docker.go:144-146` | Race condition — concurrent Exec calls share sandbox state unprotected | Extend mutex to cover full Exec operation or use per-sandbox semaphore | small | medium |
| `internal/http/knowledge_graph_handlers.go:19-20` | Negative/overflow limit/offset silently become 0 | Add explicit bounds validation, cap max limit | trivial | low |

### Security Fixes

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `ui/web/src/components/shared/file-viewers.tsx:85` | XSS via dangerouslySetInnerHTML with highlight.js output | Wrap with DOMPurify or use a React-based highlighter | small | high |
| `ui/web/src/pages/traces/trace-detail-dialog.tsx:435` | Same XSS pattern in trace viewer | Same DOMPurify fix | small | high |
| `internal/http/auth.go:145-148` | No production warning when gateway token is empty | Add `slog.Warn` at startup if token empty and env != dev | trivial | medium |
| `internal/sandbox/docker.go:122-129` | SetupCommand passed to `sh -lc` without validation | Validate against allowlist or document trust boundary | small | medium |

### Missing Tests

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `internal/crypto/` | Zero test coverage on security-critical encryption | Add tests for encrypt/decrypt, key derivation, error paths | small | high |
| `internal/permissions/policy.go` | Zero test coverage on RBAC | Add tests for all role evaluations and edge cases | small | high |
| `internal/store/pg/` (54 files) | Only `helpers_test.go` exists — entire data layer untested | Add unit tests with mock DB or integration tests | large | high |
| `internal/config/` (6 files) | Zero tests for JSON5 parsing, env overlay, hot reload | Add unit tests for config loading and validation | medium | medium |
| `internal/sessions/` | Zero tests for session lifecycle | Add tests for key generation and manager operations | small | medium |
| `internal/providers/anthropic*.go` | Primary LLM provider untested | Add request/response parsing tests, error handling | medium | medium |

### Documentation Gaps

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `docs/09-security.md` | No mention of CORS wildcard risks or dev-mode auth bypass | Document security configuration best practices | trivial | low |
| CI pipeline | No test coverage reporting | Add `go test -coverprofile` and upload to Codecov/similar | small | medium |
| `ui/web/package.json` | No `engines` field or `.nvmrc` for Node version | Add Node version constraint | trivial | low |

### Code Improvements

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `cmd/gateway.go` (35KB) | Monolithic gateway startup file | Already partially split into `gateway_*.go` files — continue extraction | medium | medium |
| `gorilla/websocket` pseudo-version in `go.mod` | Using unreleased commit hash | Pin to stable `v1.5.4` tag when available | trivial | low |
| `internal/tools/` (102 files) | Flat directory with many files | Group into sub-packages (filesystem/, web/, exec/, memory/) | large | medium |

### Feature Ideas

| Idea | Description | Effort | PR-worthy |
|------|-------------|--------|-----------|
| Coverage gating in CI | Fail CI if coverage drops below threshold | small | high |
| DOMPurify integration | Add sanitization layer for all dangerouslySetInnerHTML usage | small | high |
| Store test harness | Dockerized PostgreSQL test container for store/pg integration tests | medium | high |

---

## Draft PRs

### PR 1: fix(security): sanitize HTML output to prevent XSS in file viewers and trace dialog

- **Branch:** `fix/xss-dangerouslysetinnerhtml`
- **Files:**
  - `ui/web/package.json` — add `dompurify` + `@types/dompurify`
  - `ui/web/src/components/shared/file-viewers.tsx:85` — wrap `highlighted` with `DOMPurify.sanitize()`
  - `ui/web/src/pages/traces/trace-detail-dialog.tsx:435` — wrap `highlightedHtml` with `DOMPurify.sanitize()`
- **Changes:** Install DOMPurify, create a shared `sanitizeHtml()` helper, replace all raw `dangerouslySetInnerHTML` usages with sanitized versions. This closes the XSS vector where attacker-controlled content could reach highlight.js rendering.
- **Effort:** 1-2 hours
- **Impact:** Eliminates the highest-severity frontend vulnerability. Any content flowing through traces or file viewers (which may contain external/untrusted data) will be sanitized before DOM insertion.

### PR 2: test(crypto): add comprehensive tests for AES-256-GCM encryption and API key hashing

- **Branch:** `test/crypto-coverage`
- **Files:**
  - `internal/crypto/aes_test.go` (new) — test Encrypt/Decrypt round-trip, wrong key, corrupted ciphertext, empty input, backward-compat plaintext fallback
  - `internal/crypto/apikey_test.go` (new) — test key generation format (`goclaw_<32hex>`), hash consistency, display prefix truncation
- **Changes:** Add ~200 lines of table-driven tests covering all crypto operations, error paths, and edge cases. Verify AES-256-GCM nonce uniqueness and authenticated decryption failure on tampered ciphertext.
- **Effort:** 2-3 hours
- **Impact:** The crypto module protects all API keys and provider credentials stored in the database. Testing it ensures encryption correctness and prevents silent regressions that could expose secrets.

### PR 3: fix(auth): warn on empty gateway token in non-dev environments

- **Branch:** `fix/auth-empty-token-warning`
- **Files:**
  - `internal/http/auth.go:145-148` — add `slog.Warn("security.no_gateway_token", ...)` log
  - `cmd/gateway.go` or `cmd/gateway_setup.go` — emit startup warning if `GOCLAW_GATEWAY_TOKEN` is empty
- **Changes:** Add a prominent startup log warning when no gateway token is configured, making it clear that all requests will receive admin privileges. Optionally add a `--allow-anonymous` flag to make this an explicit opt-in rather than a silent default.
- **Effort:** 30 minutes
- **Impact:** Prevents accidental production deployments without authentication. A single misconfigured deployment could expose full admin API access to the internet.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 9 |
| Test Coverage | 4 |
| Contribution Potential | 8 |
