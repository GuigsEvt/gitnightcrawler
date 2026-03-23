Now I have everything I need. Here's the full audit report:

---

# Audit: nextlevelbuilder/goclaw

## Repository Overview

GoClaw is a **PostgreSQL-based multi-tenant AI agent gateway** — a Go port of OpenClaw that provides a WebSocket RPC + HTTP API for managing AI agents with LLM backends. It supports 20+ LLM providers (Anthropic, OpenAI, DashScope, etc.), 7 messaging channels (Telegram, Discord, Slack, Feishu, Zalo, WhatsApp), pgvector-powered semantic memory, knowledge graphs, a skill system with BM25 search, Docker-based code sandboxing, and a React 19 web dashboard. Ships as a single ~25MB static binary.

**Tech stack:** Go 1.26, PostgreSQL 18 + pgvector, React 19/Vite 6/TypeScript/Tailwind 4 (pnpm), Cobra CLI, gorilla/websocket, pgx/v5 (raw SQL, no ORM), golang-migrate, go-rod (browser automation), telego (Telegram). Optional build-tag features: OpenTelemetry, Redis, Tailscale.

**Maturity:** **Growing** — 632 Go files, 50 database migrations, 25 schema versions, active development (conventional commits, recent features like extractive memory fallback, knowledge graph semantic search). License: CC BY-NC 4.0.

## Code Quality Assessment

### Architecture and Organization
**Excellent.** Clean layered architecture with interface-based store abstractions (`store.SessionStore`, `store.AgentStore`, etc.) backed by PostgreSQL implementations in `store/pg/`. The agent loop follows a clear Think→Act→Observe cycle. Provider abstraction allows swapping LLM backends. 5-layer permission system (gateway → global policy → per-agent → per-channel → owner-only). Lane-based concurrency prevents resource exhaustion. Build tags cleanly gate optional features (OTel, Redis, Tailscale).

### Error Handling Patterns
**Good.** Uses `errors.Is()` consistently (33 occurrences across 21 files) with one exception in `store/pg/secure_cli.go:226` using direct comparison. Errors properly wrapped with `fmt.Errorf`. Some intentional `_ = json.Unmarshal()` for fallback logic. Missing circuit breaker pattern for failing LLM providers.

### Test Coverage
**Moderate.** 63 test files for 632 Go source files (~10%). Tools package well-covered (12+ test files). Store layer critically under-tested (1 test file for 50+ store files). No E2E tests for the web UI. No integration test suite for the agent loop.

### Documentation Quality
**Good.** Comprehensive README (17KB), detailed CLAUDE.md with architecture docs, API reference, WebSocket protocol spec, changelog. 30 readme files in `_readmes/`. Missing: inline code comments in complex files (loop.go at 57KB), Architecture Decision Records.

### Dependency Health
**Good.** Modern Go 1.26, up-to-date pgx/v5, gorilla/websocket (maintained), spf13/cobra (stable). No deprecated `ioutil` usage. No known vulnerable transitive dependencies detected.

## Security Findings

### Critical

None truly critical — the codebase has strong security foundations.

### High

None.

### Medium

| # | Finding | Location | Details |
|---|---------|----------|---------|
| M1 | **Encryption key set via os.Setenv()** | `cmd/onboard.go:87` | `os.Setenv("GOCLAW_ENCRYPTION_KEY", encryptionKey)` makes the key visible to child processes and `/proc` inspection. Should persist to `.env.local` only, not re-set in process env. |
| M2 | **MD5 used for Zalo protocol signing** | `internal/channels/zalo/personal/protocol/client.go:60,114` | MD5 is cryptographically broken. Used for IMEI generation and API signing. Likely a Zalo API requirement, but should be documented. |

### Low

| # | Finding | Location | Details |
|---|---------|----------|---------|
| L1 | **math/rand for retry jitter** | `internal/providers/retry.go:165`, `internal/channels/feishu/larkws.go:244` | Non-cryptographic RNG for timing jitter. Acceptable for backoff but inconsistent with `crypto/rand` used elsewhere. |
| L2 | **Inconsistent error comparison** | `internal/store/pg/secure_cli.go:226` | `err == sql.ErrNoRows` instead of `errors.Is(err, sql.ErrNoRows)`. |
| L3 | **Untracked goroutine for title generation** | `internal/gateway/methods/chat.go:229-230` | Fire-and-forget goroutine with `context.Background()` — no timeout, no cancellation propagation. |

### Info

| # | Finding | Location | Details |
|---|---------|----------|---------|
| I1 | **No explicit TLS version minimum** | Various HTTP clients | Defaults used. Consider `MinVersion: tls.VersionTLS12` for defense-in-depth. |
| I2 | **Strong SSRF protection** | `internal/tools/web_shared.go:117-160` | Private IP blocking, DNS pinning, domain allow/block lists — well implemented. |
| I3 | **Credential scrubbing** | `internal/tools/scrub.go` | Thread-safe regex scrubbing for API keys, secrets, connection strings. |
| I4 | **AES-256-GCM encryption** | `internal/crypto/aes.go` | Proper nonce generation via `crypto/rand.Read()`. |

## Contribution Opportunities

### Bugs

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| B1 | `internal/store/pg/secure_cli.go:226` | `err == sql.ErrNoRows` bypasses error wrapping | Change to `errors.Is(err, sql.ErrNoRows)` | trivial | medium |
| B2 | `internal/gateway/methods/chat.go:229-230` | Title generation goroutine uses `context.Background()` with no timeout | Use `context.WithTimeout(context.Background(), 30*time.Second)` | trivial | medium |

### Security Fixes

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| S1 | `cmd/onboard.go:87` | Encryption key in process env via `os.Setenv` | Write to `.env.local` file instead; remove `os.Setenv` call | small | high |
| S2 | `internal/channels/zalo/personal/protocol/client.go` | MD5 for signing without documentation | Add comments explaining Zalo API requirement; consider SHA-256 if API allows | trivial | low |

### Missing Tests

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| T1 | `internal/store/pg/` | Only 1 test file for 50+ store files | Add integration tests for critical stores (sessions, agents, memory) | large | high |
| T2 | `internal/agent/loop.go` | No unit tests for core agent loop | Add tests for think/act/observe cycle, context injection, auto-summarization | large | high |
| T3 | `internal/providers/` | Provider integration tests missing | Add mock-based tests for retry logic, stream handling, error propagation | medium | high |
| T4 | `ui/web/` | No E2E tests | Add Playwright tests for critical flows (chat, agent config, memory) | large | medium |

### Documentation Gaps

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| D1 | `internal/agent/loop.go` | 57KB file with minimal inline comments | Add godoc for exported functions, section comments for phases | medium | medium |
| D2 | `docs/` | No Architecture Decision Records | Add ADRs for key decisions (raw SQL vs ORM, event bus, delegation) | medium | medium |
| D3 | `internal/channels/zalo/` | Zalo protocol crypto undocumented | Document MD5/encryption requirements from Zalo API | small | low |

### Code Improvements

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| C1 | `internal/providers/` | No circuit breaker for failing LLM endpoints | Add circuit breaker pattern (half-open/open/closed) to `RetryDo()` | medium | high |
| C2 | `internal/agent/loop.go` | `sync.Map` for session summarization locks | Replace with sharded mutex map for better performance at scale | small | medium |
| C3 | Various HTTP clients | No explicit TLS minimum version | Set `MinVersion: tls.VersionTLS12` on custom TLS configs | trivial | low |

### Feature Ideas

| # | Area | Idea | Effort | PR-worthy |
|---|------|------|--------|-----------|
| F1 | Providers | Circuit breaker with fallback provider chain | medium | high |
| F2 | Observability | Enable OTel by default, add Grafana dashboard templates | medium | high |
| F3 | KG | DFS/BFS traversal primitives for knowledge graph queries | medium | medium |
| F4 | Skills | Skill versioning docs + rollback mechanism | medium | medium |

## Draft PRs

### PR 1: Add integration tests for PostgreSQL store layer

- **PR Title:** `test(store): add integration tests for critical pg store operations`
- **Branch:** `test/store-integration`
- **Files:** `internal/store/pg/sessions_test.go`, `internal/store/pg/agents_test.go`, `internal/store/pg/memory_test.go`, `internal/store/pg/teams_test.go`, `tests/integration/store_test.go`
- **Changes:** Create integration tests using a test PostgreSQL instance for the 4 most critical store implementations: sessions (CRUD, message append, token tracking), agents (create, update context files, list by team), memory (index, search, embedding), teams (delegation, task CRUD). Use `testing.Short()` to skip in CI without a DB. Add Docker Compose overlay for test DB.
- **Effort:** 2-3 days
- **Impact:** Store layer is the foundation — bugs here cascade everywhere. Currently has 1 test file for 50+ implementations. This is the single highest-impact testing investment.

### PR 2: Add circuit breaker to LLM provider retry logic

- **PR Title:** `feat(providers): add circuit breaker pattern to RetryDo`
- **Branch:** `feat/provider-circuit-breaker`
- **Files:** `internal/providers/retry.go`, `internal/providers/circuit_breaker.go`, `internal/providers/retry_test.go`
- **Changes:** Implement a per-provider circuit breaker with three states (closed/open/half-open). Track failure counts with configurable thresholds (e.g., 5 failures in 60s trips open, 30s cooldown before half-open). Integrate into existing `RetryDo()` function. Add metrics emission for state transitions. When a provider is open, immediately return error instead of wasting time on requests that will fail.
- **Effort:** 1 day
- **Impact:** Prevents cascade failures when an LLM provider goes down. Currently, failing requests retry blindly, wasting time and potentially blocking the lane-based scheduler.

### PR 3: Fix encryption key handling in onboard flow

- **PR Title:** `fix(onboard): stop setting encryption key via os.Setenv`
- **Branch:** `fix/encryption-key-handling`
- **Files:** `cmd/onboard.go`
- **Changes:** Remove `os.Setenv("GOCLAW_ENCRYPTION_KEY", encryptionKey)` at line 87. Instead, ensure the key is written to `.env.local` (which the onboard flow already does) and loaded from there at startup. If the key is needed during the same onboard session (for migrations), pass it explicitly through config rather than environment. This prevents the key from being visible in `/proc/self/environ` or inherited by child processes.
- **Effort:** 1-2 hours
- **Impact:** Reduces attack surface for encryption key exposure. Low effort, meaningful security improvement.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 8 |
| Documentation | 7 |
| Test Coverage | 4 |
| Contribution Potential | 8 |
