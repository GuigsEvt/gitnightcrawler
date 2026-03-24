# Audit: nextlevelbuilder/goclaw

## Repository Overview

GoClaw is a PostgreSQL-based multi-tenant AI agent gateway written in Go, providing WebSocket RPC and HTTP API for orchestrating LLM-powered agents across 7 messaging channels (Telegram, Discord, Slack, Feishu, Zalo, WhatsApp, Web). It features 20+ LLM provider integrations, 30+ built-in tools, Docker-sandboxed code execution, AES-256-GCM encrypted secret management, RBAC, and a React 19 SPA dashboard. Single binary deployment targeting containerized environments.

**Tech stack:** Go 1.26, Cobra CLI, gorilla/websocket, pgx/v5, PostgreSQL 18 + pgvector, React 19, Vite 6, TypeScript, Tailwind CSS 4, Radix UI, Zustand, pnpm

**Maturity:** Growing/Mature -- 28 database migrations, 647 Go files, 422 TypeScript files, 65 test files, comprehensive CI/CD, production-oriented security architecture. Active development with frequent commits.

---

## Code Quality Assessment

### Architecture and Organization
Excellent monorepo structure with clear separation: `cmd/` (CLI), `internal/` (31 packages), `pkg/` (wire protocol), `ui/web/` (SPA), `migrations/`. Interface-based store layer (`store.SessionStore`, `store.AgentStore`) with PostgreSQL implementations in `store/pg/`. Context-based multi-tenant isolation throughout. Provider pattern for LLM integrations. Build-tag gated optional features (OTel, Tailscale, Redis).

**Concern:** Gateway files are very large (`cmd/gateway.go` 40KB, `cmd/gateway_setup.go` 22KB, `cmd/gateway_consumer_handlers.go` 25KB). These would benefit from decomposition.

### Error Handling Patterns
Strong. 37 uses of `errors.Is()` across 23 files, zero instances of `err == sentinel`. Fail-closed patterns in tenant validation. Structured logging with `slog.Warn("security.*")` (91 occurrences across 37 files). Deferred resource cleanup (`defer rows.Close()`). No silent error swallowing in critical paths.

### Test Coverage
65 test files covering security-critical paths: shell deny patterns, input guard, tool policy, rate limiting, web fetch, auth, API key cache, OAuth, SQL helpers, scheduler. Integration tests in `tests/`. ~10% file-count ratio -- adequate for security paths but gaps in store implementations, channel drivers, and agent loop logic.

### Documentation Quality
Comprehensive `CLAUDE.md` with project structure, patterns, and conventions. `README.md` (17KB) with architecture diagrams, quick start, and feature comparisons. API reference at `api-reference.md`. 20+ localized READMEs. Full `docs/` directory (27 subdirs). `CHANGELOG.md` maintained.

**Issue:** README badge says "License: MIT" but actual license is CC BY-NC 4.0.

### Dependency Health
Go modules properly pinned in `go.sum` (150+ deps). Frontend locked via `pnpm-lock.yaml`. All dependencies are well-maintained libraries (pgx/v5, gorilla/websocket, go-rod, radix-ui). No obviously outdated or abandoned dependencies detected.

---

## Security Findings

### Critical
None found.

### High
None found.

### Medium

**M1: Input guard and skill guard are detection-only by default**
- Files: `internal/agent/input_guard.go`, `internal/skills/guard.go`
- The prompt injection detection system defaults to `warn` mode, not `block`. Skill content guard logs violations but allows execution. In adversarial environments, this allows prompt injection attacks to succeed.
- Mitigation: Configurable via `gateway.injection_action` -- operators can set to `block`.

**M2: Web fetch defaults to `allow_all` domain policy**
- File: `internal/tools/web_fetch.go`
- SSRF protection exists but defaults to allowing all domains. In multi-tenant deployments, this could allow agents to access internal services.
- Mitigation: Operators can configure allowlist mode.

### Low

**L1: License badge mismatch in README**
- File: `README.md`
- Badge says MIT, actual license is CC BY-NC 4.0. Could mislead users about commercial usage rights.

**L2: Browser pairing code is 8 characters**
- File: `internal/gateway/methods/pairing.go`
- Short approval codes. Low risk given the human-in-the-loop approval workflow.

**L3: Decrypt() silently falls back to plaintext**
- File: `internal/crypto/aes.go:66-68`
- If base64 decode fails, returns input as plaintext. Intentional for backward compatibility but could mask corruption.

### Info

**I1: Credential scrubbing is regex-based**
- File: `internal/tools/scrub.go`
- Covers 20+ patterns (OpenAI, Anthropic, AWS, GitHub, connection strings). Regex-based -- novel credential formats may slip through. Defense-in-depth with sandbox isolation mitigates this.

**I2: 91 security log points across 37 files**
- Good coverage with `slog.Warn("security.*")` prefix enabling centralized monitoring.

---

## Contribution Opportunities

### Bugs

**B1: README license badge incorrect**
- File: `README.md` (badge section near top)
- Issue: Shows MIT badge, actual license is CC BY-NC 4.0
- Fix: Update badge URL/text to match LICENSE file
- Effort: trivial
- PR-worthy: medium

### Security Fixes

**S1: Default web fetch policy should be restrictive**
- File: `internal/tools/web_fetch.go`
- Issue: Defaults to `allow_all` which permits SSRF in multi-tenant setups
- Fix: Change default to `allowlist` with documented safe defaults, or add internal network blocking (RFC 1918 ranges)
- Effort: small
- PR-worthy: high

**S2: Add logging on crypto fallback to plaintext**
- File: `internal/crypto/aes.go:66-68`
- Issue: Silent fallback to plaintext on decode failure
- Fix: Add `slog.Warn("security.decrypt_fallback")` when returning plaintext
- Effort: trivial
- PR-worthy: medium

### Missing Tests

**T1: Store layer integration tests**
- File: `internal/store/pg/*.go` (59 implementations, few tests)
- Issue: Most PostgreSQL store implementations lack dedicated tests
- Fix: Add integration tests for critical stores (agents, sessions, users, config_secrets)
- Effort: large
- PR-worthy: high

**T2: Channel driver tests**
- File: `internal/channels/` (23 files, no test files found)
- Issue: No tests for Telegram, Discord, Slack, Feishu, Zalo, WhatsApp drivers
- Fix: Add unit tests with mocked API clients
- Effort: large
- PR-worthy: medium

**T3: Agent loop tests**
- File: `internal/agent/` (35 files, limited test coverage)
- Issue: Core agent loop (think-act-observe) lacks comprehensive tests
- Fix: Add tests for RunRequest flow, tool call handling, context summarization
- Effort: medium
- PR-worthy: high

### Documentation Gaps

**D1: Security hardening guide**
- Issue: No dedicated guide for production security configuration (injection_action=block, web_fetch allowlist, sandbox mode, deny group tuning)
- Fix: Add `docs/security-hardening.md`
- Effort: medium
- PR-worthy: medium

### Code Improvements

**C1: Decompose large gateway files**
- Files: `cmd/gateway.go` (40KB), `cmd/gateway_setup.go` (22KB), `cmd/gateway_consumer_handlers.go` (25KB)
- Issue: Files exceed reasonable size, making navigation and review difficult
- Fix: Extract logical sections into separate files (e.g., `gateway_lifecycle.go`, `gateway_events.go`)
- Effort: medium
- PR-worthy: medium

**C2: Add RFC 1918 blocking to web fetch**
- File: `internal/tools/web_fetch.go`
- Issue: No built-in blocking of internal/private IP ranges
- Fix: Add IP resolution check before fetch to reject 10.x, 172.16-31.x, 192.168.x, 127.x, ::1
- Effort: small
- PR-worthy: high

### Feature Ideas

**F1: Structured audit log export**
- Issue: Security events only in slog output, no structured export for SIEM integration
- Fix: Add optional JSON export of `security.*` events to a file or webhook
- Effort: medium
- PR-worthy: medium

**F2: Dependency vulnerability scanning in CI**
- File: `.github/workflows/ci.yaml`
- Issue: No `govulncheck` or `npm audit` in CI pipeline
- Fix: Add `govulncheck ./...` and `pnpm audit` steps
- Effort: small
- PR-worthy: high

---

## Draft PRs

### PR 1: fix(security): block private IP ranges in web fetch to prevent SSRF

- **Branch:** `fix/ssrf-private-ip-blocking`
- **Files:** `internal/tools/web_fetch.go`, `internal/tools/web_fetch_test.go`
- **Changes:** Add IP resolution step before HTTP fetch. After DNS resolution, check if the resolved IP falls in RFC 1918 (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16), loopback (127.0.0.0/8, ::1), or link-local ranges. Reject with clear error message. Add configuration option to disable for local development. Add tests for all blocked ranges and allowed public IPs.
- **Effort:** 2-3 hours
- **Impact:** Prevents agents from accessing internal services in multi-tenant deployments. Critical for cloud-hosted instances where internal metadata endpoints (169.254.169.254) could leak credentials.

### PR 2: ci: add govulncheck and pnpm audit to CI pipeline

- **Branch:** `feat/dependency-vulnerability-scanning`
- **Files:** `.github/workflows/ci.yaml`
- **Changes:** Add two new CI steps: (1) `go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...` after Go build step, (2) `pnpm audit --audit-level=high` after web build step. Both steps should fail the pipeline on findings. Add a scheduled weekly run for continuous monitoring.
- **Effort:** 1 hour
- **Impact:** Catches known CVEs in Go and npm dependencies before merge. Industry standard practice for supply chain security.

### PR 3: test: add integration tests for core store implementations

- **Branch:** `test/store-integration-tests`
- **Files:** `internal/store/pg/agents_test.go`, `internal/store/pg/sessions_test.go`, `internal/store/pg/users_test.go`, `internal/store/pg/config_secrets_test.go`, `tests/integration/store_test.go`
- **Changes:** Add integration tests using a test PostgreSQL instance for the 4 most critical store implementations: AgentStore (CRUD, tenant isolation, context files), SessionStore (create, list, delete, user scoping), UserStore (create, lookup, preferences), ConfigSecretsStore (encrypt/decrypt round-trip, key rotation). Use `testing.Short()` skip for CI without DB. Verify multi-tenant isolation (queries from tenant A cannot see tenant B data).
- **Effort:** 1-2 days
- **Impact:** Store layer is the foundation -- 59 implementations with minimal test coverage. These tests catch SQL regressions, tenant isolation leaks, and migration breakage before production.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 8 |
| Documentation | 7 |
| Test Coverage | 5 |
| Contribution Potential | 8 |

**Summary:** GoClaw is a well-engineered, security-conscious project with production-grade patterns (AES-256-GCM encryption, parameterized SQL, 15-group shell deny system, RBAC, constant-time auth). Main gaps are test coverage (especially store layer and channel drivers) and some configuration defaults that favor convenience over security (web fetch allow_all, injection guard warn-only). The large gateway files need decomposition. Strong contribution potential given the clear architecture and meaningful gaps to fill.
