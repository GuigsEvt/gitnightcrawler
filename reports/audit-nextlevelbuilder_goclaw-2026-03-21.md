# Audit: nextlevelbuilder/goclaw

## Repository Overview

GoClaw is a multi-tenant AI agent gateway built in Go that bridges 20+ LLM providers (Anthropic, OpenAI, DashScope, Gemini, etc.) with 7 messaging channels (Telegram, Discord, Slack, Zalo, Feishu, WhatsApp, WebSocket). It provides a PostgreSQL-backed platform for running AI agents with features including agent teams, knowledge graphs, BM25+pgvector hybrid skill search, cron scheduling, prompt caching, and a React web dashboard. Ships as a single ~25MB static binary with <1s startup.

**Tech stack:** Go 1.26 (Cobra CLI, gorilla/websocket, pgx/v5, go-rod), PostgreSQL 18 + pgvector, React 19, Vite 6, TypeScript, Tailwind CSS 4, Radix UI, Zustand.

**Maturity:** Growing/Mature. 629 Go source files, 48 migrations, 63 test files, comprehensive docs, Docker multi-stage builds, CI/CD pipelines, multi-language i18n (en/vi/zh). Production-grade security hardening. Active development with conventional commits.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 9/10.** Clean layered architecture: `cmd/` (CLI) -> `internal/gateway/` (WS+HTTP server) -> `internal/agent/` (think-act-observe loop) -> `internal/store/` (interface-based storage) -> `internal/store/pg/` (PostgreSQL impl). Context propagation is exceptionally well-designed with 20+ typed context values. Provider abstraction allows easy addition of new LLM backends. Interface-based store layer enables testability.

### Error Handling Patterns
**Score: 9/10.** Consistent `slog.Error`/`slog.Warn` logging across 562 calls. Proper error wrapping with `errors.Is()`/`errors.As()`. Security events uniformly logged as `slog.Warn("security.*")`. Only 6 intentional error ignores found, all in cleanup/fire-and-forget paths. Retry logic discriminates transient vs permanent failures.

### Test Coverage
**Score: 5/10.** 63 test files exist with high-quality unit tests for agent loop, providers, security patterns, and database helpers. However: store CRUD operations are untested, only 1/31 gateway methods has tests, ~85% of HTTP endpoints lack coverage, and integration/E2E tests are essentially absent.

### Documentation Quality
**Score: 8/10.** Comprehensive CLAUDE.md with architecture overview, patterns, and conventions. 25 docs subdirectories. WebSocket protocol documented. `.env.example` provided. README covers quick start. Inline code comments are sparse but code is generally readable.

### Dependency Health
**Score: 8/10.** Uses well-maintained dependencies (pgx/v5, gorilla/websocket, cobra, go-rod). Go standard library used for crypto. OpenTelemetry for observability. No obviously abandoned or vulnerable dependencies. Build-tag gating for optional features (OTel, Tailscale, Redis) keeps the binary lean.

---

## Security Findings

### Critical
None found.

### High
None found.

### Medium

| # | Finding | Location | Notes |
|---|---------|----------|-------|
| M1 | **Session in-memory cache unbounded growth** | `internal/store/pg/sessions.go:23` | No eviction policy; long-running instances with many sessions could exhaust memory |
| M2 | **No encryption key rotation procedure** | `internal/crypto/aes.go` | AES-256-GCM implementation is correct but no documented or implemented key rotation mechanism for `GOCLAW_ENCRYPTION_KEY` |

### Low

| # | Finding | Location | Notes |
|---|---------|----------|-------|
| L1 | **Silent error swallowing in cleanup paths** | `internal/channels/telegram/send.go:168,191,201,241` | Edit/delete message errors silently ignored; could mask persistent issues |
| L2 | **Fire-and-forget task updates** | `internal/tools/team_tasks/` (lines 45, 57) | Task status updates ignore errors; could cause state inconsistency |
| L3 | **No circuit breaker for failing providers** | `internal/providers/` | `RetryDo()` handles transient failures but no circuit breaker prevents hammering a consistently failing provider |

### Info

| # | Finding | Notes |
|---|---------|-------|
| I1 | **Input guard is detection-only by default** | Prompt injection detection logs/warns but doesn't block unless explicitly configured |
| I2 | **Web fetch 512KB content limit** | Reasonable but undocumented; could surprise users with large documents |
| I3 | **No golangci-lint configuration** | CI runs `go vet` but not a stricter linter |

---

## Contribution Opportunities

### Bugs

1. **File:** `internal/store/pg/sessions.go:23`
   **Issue:** In-memory session cache has no size limit or eviction policy
   **Fix:** Add LRU eviction or TTL-based expiry using `sync.Map` replacement or a bounded cache
   **Effort:** medium
   **PR-worthy:** high

### Security Fixes

2. **File:** `internal/crypto/aes.go`
   **Issue:** No key rotation support for encrypted provider API keys
   **Fix:** Add a `rotate-keys` CLI command that re-encrypts all secrets with new key, update docs
   **Effort:** medium
   **PR-worthy:** high

3. **File:** `internal/channels/telegram/send.go:168,191,201,241`
   **Issue:** Cleanup errors silently swallowed with `_ =`
   **Fix:** Add `slog.Debug()` logging for these operations
   **Effort:** trivial
   **PR-worthy:** medium

### Missing Tests

4. **File:** `internal/store/pg/*.go` (31 files)
   **Issue:** Core store CRUD operations (agents, sessions, teams, users) have no tests
   **Fix:** Add table-driven tests with test database or mock interfaces
   **Effort:** large
   **PR-worthy:** high

5. **File:** `internal/gateway/methods/` (31 files, only 1 tested)
   **Issue:** 95% of WebSocket RPC handlers lack test coverage
   **Fix:** Add unit tests for critical methods: chat, sessions, delegation, teams
   **Effort:** large
   **PR-worthy:** high

6. **File:** `internal/http/` (54 handler files, 5 tested)
   **Issue:** Core REST API endpoints (chat completions, agents, skills) untested
   **Fix:** Add handler tests with httptest
   **Effort:** large
   **PR-worthy:** high

### Documentation Gaps

7. **File:** (new) `docs/security/key-rotation.md`
   **Issue:** No documentation for encryption key rotation or secret management lifecycle
   **Fix:** Document rotation procedure, backup strategy, and recovery
   **Effort:** small
   **PR-worthy:** medium

8. **File:** `internal/tools/shell_deny_groups.go`
   **Issue:** 14 deny groups with 200+ patterns but no documentation on how to customize or extend
   **Fix:** Add doc comments explaining each group and customization guidance
   **Effort:** small
   **PR-worthy:** low

### Code Improvements

9. **File:** `internal/agent/input_guard.go`
   **Issue:** Detection-only default means prompt injection attempts are only logged
   **Fix:** Consider changing default action to `warn` or documenting the security tradeoff prominently
   **Effort:** trivial
   **PR-worthy:** medium

10. **File:** project-wide
    **Issue:** No `.golangci.yml` configuration
    **Fix:** Add golangci-lint config with reasonable defaults (errcheck, govet, staticcheck, gosec)
    **Effort:** small
    **PR-worthy:** medium

### Feature Ideas

11. **Provider circuit breaker:** Add circuit breaker pattern to provider retry logic to prevent cascading failures when a provider is down
    **Effort:** medium
    **PR-worthy:** high

12. **Health dashboard:** Expose `/health/detailed` endpoint showing provider status, cache sizes, active sessions
    **Effort:** medium
    **PR-worthy:** medium

---

## Draft PRs

### PR 1: Bounded Session Cache

- **PR Title:** `fix(store): add LRU eviction to in-memory session cache`
- **Branch:** `fix/session-cache-eviction`
- **Files:** `internal/store/pg/sessions.go`, `internal/store/pg/sessions_test.go` (new)
- **Changes:** Replace unbounded `sync.Map` session cache with a bounded LRU cache (e.g., `hashicorp/golang-lru` or hand-rolled with `container/list`). Add configurable max size via config. Add cache hit/miss metrics logging. Write tests for eviction behavior.
- **Effort:** 2-4 hours
- **Impact:** Prevents memory exhaustion in long-running production deployments with many sessions. Currently a silent resource leak.

### PR 2: Encryption Key Rotation CLI

- **PR Title:** `feat(crypto): add key rotation command for encrypted secrets`
- **Branch:** `feat/key-rotation`
- **Files:** `internal/crypto/aes.go`, `internal/crypto/rotate.go` (new), `cmd/rotate_keys.go` (new), `internal/store/pg/config_secrets.go`
- **Changes:** Add `goclaw rotate-keys --old-key=... --new-key=...` command that: reads all encrypted secrets from DB, decrypts with old key, re-encrypts with new key, updates in a transaction. Add dry-run mode. Log rotation summary.
- **Effort:** 4-6 hours
- **Impact:** Enables security best practice of periodic key rotation. Currently impossible without manual DB surgery.

### PR 3: Store Layer Integration Tests

- **PR Title:** `test(store): add integration tests for core store operations`
- **Branch:** `test/store-integration`
- **Files:** `tests/integration/store_test.go` (new), `tests/integration/testutil.go` (new)
- **Changes:** Add integration tests for agent, session, team, and user store operations using a test PostgreSQL instance. Cover CRUD operations, edge cases (duplicate keys, not found), and concurrent access. Use `testing.Short()` skip for CI without DB.
- **Effort:** 1-2 days
- **Impact:** Covers the most critical untested layer. Store bugs can corrupt data across all tenants. Currently relying entirely on manual testing.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 9 |
| Documentation | 7 |
| Test Coverage | 5 |
| Contribution Potential | 8 |

**Summary:** GoClaw is a well-architected, security-hardened production system with excellent defense-in-depth. The main gap is test coverage -- the security and agent loop code is thoroughly tested, but store operations, gateway methods, and HTTP handlers are largely untested. The three draft PRs above address the highest-impact issues: a potential memory leak, missing key rotation, and the largest testing gap.
