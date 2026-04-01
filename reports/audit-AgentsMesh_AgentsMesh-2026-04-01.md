Now I have all the data needed. Let me compile the full audit report.

---

# Audit: AgentsMesh/AgentsMesh

## Repository Overview

AgentsMesh is a multi-tenant AI Code Agent collaboration platform that orchestrates multiple AI coding assistants (Claude Code, Codex CLI, Gemini CLI, Aider) in isolated execution environments. It provides a web dashboard for managing organizations, runners, pods (isolated PTY terminals), channels for multi-agent collaboration, and tickets for task management. The architecture consists of a Go backend (Gin + GORM + gRPC), a Next.js 16 frontend, an admin console, and a self-hosted Go runner daemon that executes AI agents in sandboxed PTY environments connected via mTLS.

**Tech Stack:**
- Backend: Go 1.25, Gin, GORM, gRPC with mTLS, PostgreSQL, Redis
- Frontend: Next.js 16, React 19, TypeScript, Tailwind CSS 4, Zustand, xterm.js
- Admin: Next.js 16, shadcn-style UI
- Runner: Go 1.25, creack/pty, gRPC advancedtls
- Infra: Docker, Traefik v3, MinIO, GitHub Actions CI/CD
- Auth: JWT (HMAC-SHA256), OAuth (GitHub/Google/GitLab/Gitee), SAML, LDAP

**Scale:** ~1770 Go files (829 test), ~730 TypeScript files, 69 commits, 7 contributors, 10 days of history (2026-03-20 to 2026-03-30).

**Maturity:** Early/Growing. Active development with rapid iteration, good architectural foundations, comprehensive test files but young commit history.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 8/10.** Clean DDD structure in backend (domain/service/infra layers). Well-separated concerns across 4 components. Proper multi-tenant isolation with `TenantContext`. Runner uses builder pattern for pod creation with plugin-based sandbox system. Frontend follows Next.js App Router conventions with Zustand stores per domain.

**Issues:** Several files exceed the project's own 200-line limit (service/extension: 781 lines, skill_importer: 737 lines, pod.ts: 453 lines, message_handler.go: 371 lines). These need splitting per SRP.

### Error Handling Patterns
**Score: 8/10.** Centralized `apierr` package with typed error codes mapped to HTTP statuses. Service layer uses sentinel errors with `errors.Is()` for specific handling. Runner has typed `PodError` with error codes. API responses are structured JSON. No panic-based error handling found.

### Test Coverage
**Score: 7/10.** 829 Go test files for 941 production Go files (~88% file coverage ratio). Frontend has 60+ test files with Vitest. Web-admin has 11 test files. Tests use in-memory SQLite for DB tests, proper mocking, and good edge case coverage. Missing: integration tests for full API flows, no E2E tests visible.

### Documentation Quality
**Score: 7/10.** Excellent CLAUDE.md with architecture diagrams, setup guides, and command reference. Good inline code comments on security-critical paths. 8-locale i18n support. Missing: SECURITY.md, CONTRIBUTING.md, API documentation.

### Dependency Health
**Score: 7/10.** All dependencies are well-known, maintained libraries (Gin, GORM, gRPC, JWT v5). No suspicious or abandoned packages. Go modules properly versioned. Frontend uses pnpm with lockfile. Concern: some CI actions use `version: latest` (supply chain risk).

---

## Security Findings

### Critical

**[C1] Redis deployed without authentication** -- All docker-compose files (dev, selfhost, on-premise) deploy Redis without `--requirepass`. In on-premise deployment where Redis port 6379 is exposed, any network-adjacent attacker can read/write session data and cache.
- Files: `deploy/selfhost/docker-compose.yml`, `deploy/onpremise/docker-compose.yml`
- Rating: **Critical** (on-premise), Medium (dev)

**[C2] PostgreSQL port exposed in on-premise without documented firewall rules**
- File: `deploy/onpremise/docker-compose.yml`
- Port 5432 exposed with only password auth, no SSL enforcement, no IP filtering documented.
- Rating: **Critical**

### High

**[H1] JWT tokens stored in localStorage** -- Both web and web-admin store JWT tokens in `localStorage` via Zustand persist. Any XSS vulnerability would expose all auth tokens.
- Files: `web/src/stores/auth.ts`, `web-admin/src/stores/auth.ts`
- Rating: **High**

**[H2] No Content-Security-Policy headers** -- Neither `next.config.ts` configures CSP headers. Combined with H1, this increases XSS impact.
- Files: `web/next.config.ts`, `web-admin/next.config.ts`
- Rating: **High**

**[H3] CI/CD supply chain: unversioned GitHub Actions** -- `golangci-lint-action@v9` with `version: latest`, `goreleaser/goreleaser-action@v7` with `version: latest`. A compromised action could inject malicious code into releases.
- File: `.github/workflows/ci.yml`, `.github/workflows/release.yml`
- Rating: **High**

**[H4] No binary signing verification for self-update** -- Runner's self-update via `go-selfupdate` downloads from GitHub Releases without GPG signature verification. MITM or compromised release could replace runner binary.
- File: `runner/internal/updater/updater.go`
- Rating: **High**

### Medium

**[M1] MinIO uses floating `latest` tag** -- `pgsty/minio:latest` in compose files. Unknown image version at deploy time.
- Files: `deploy/selfhost/docker-compose.yml`, `deploy/dev/docker-compose.yml`
- Rating: **Medium**

**[M2] Docker image tags not pinned to digest** -- CI Dockerfiles use `golang:1.25-alpine` and `node:20-alpine` without `@sha256:` digest pinning.
- Files: `ci/backend.Dockerfile`, `ci/web.Dockerfile`
- Rating: **Medium**

**[M3] golang-migrate downloaded without checksum verification**
- File: `ci/backend.Dockerfile` (line ~36)
- Rating: **Medium**

**[M4] Image remotePatterns allows all hostnames** -- Next.js image optimization accepts any remote host.
- Files: `web/next.config.ts`, `web-admin/next.config.ts`
- Rating: **Medium**

**[M5] Default JWT_SECRET with weak enforcement** -- `change-me-in-production` only logs a warning, doesn't block startup in non-debug modes.
- File: `backend/internal/config/config.go`
- Rating: **Medium**

### Low

**[L1] No image scanning in CI pipeline** -- No Trivy, Grype, or Snyk integration.
- Rating: **Low**

**[L2] Preparation scripts from backend executed on runner without validation** -- Runner trusts backend-provided scripts via mTLS. If backend is compromised, arbitrary code execution on runners.
- Rating: **Low** (mTLS mitigates significantly)

### Info

**[I1]** 200-line file limit violated in 10+ files across backend, runner, and web.
**[I2]** Dev credentials hardcoded (acceptable for dev environment).
**[I3]** No SECURITY.md or vulnerability disclosure policy.

---

## Contribution Opportunities

### Bugs

1. **File:** `deploy/onpremise/docker-compose.yml`
   - **Issue:** PostgreSQL and Redis ports exposed without network restrictions or auth
   - **Fix:** Remove port exposure or add `requirepass` for Redis and `sslmode=require` for PostgreSQL
   - **Effort:** trivial
   - **PR-worthy:** high

### Security Fixes

2. **File:** `web/next.config.ts:1-50`, `web-admin/next.config.ts:1-50`
   - **Issue:** No CSP headers configured
   - **Fix:** Add `headers()` export with `Content-Security-Policy`, `X-Frame-Options`, `X-Content-Type-Options`
   - **Effort:** small
   - **PR-worthy:** high

3. **File:** `.github/workflows/ci.yml`, `.github/workflows/release.yml`
   - **Issue:** GitHub Actions use `version: latest` for critical tools
   - **Fix:** Pin to specific versions with SHA digests
   - **Effort:** trivial
   - **PR-worthy:** high

4. **File:** `deploy/selfhost/docker-compose.yml`, `deploy/dev/docker-compose.yml`
   - **Issue:** Redis has no authentication
   - **Fix:** Add `--requirepass ${REDIS_PASSWORD}` and generate password in setup scripts
   - **Effort:** small
   - **PR-worthy:** high

5. **File:** `web/src/stores/auth.ts`, `web-admin/src/stores/auth.ts`
   - **Issue:** JWT tokens in localStorage vulnerable to XSS
   - **Fix:** Move to httpOnly secure cookies with backend `Set-Cookie` support
   - **Effort:** large (requires backend changes)
   - **PR-worthy:** medium

### Missing Tests

6. **File:** `backend/internal/api/rest/v1/`
   - **Issue:** No E2E API integration tests (handler → service → DB round-trip)
   - **Fix:** Add integration test suite using test database
   - **Effort:** large
   - **PR-worthy:** medium

7. **File:** `web/src/components/`
   - **Issue:** Terminal components (xterm integration) lack test coverage
   - **Fix:** Add tests for TerminalGrid, terminal connection hooks
   - **Effort:** medium
   - **PR-worthy:** medium

### Documentation Gaps

8. **File:** (new) `SECURITY.md`
   - **Issue:** No security policy or vulnerability disclosure process
   - **Fix:** Create SECURITY.md with reporting instructions and supported versions
   - **Effort:** trivial
   - **PR-worthy:** high

9. **File:** (new) `CONTRIBUTING.md`
   - **Issue:** No contribution guidelines for external contributors
   - **Fix:** Document dev setup, PR process, coding standards
   - **Effort:** small
   - **PR-worthy:** medium

### Code Improvements

10. **File:** `backend/internal/service/extension/service.go` (781 lines)
    - **Issue:** Exceeds 200-line limit by 4x, violates SRP
    - **Fix:** Split into extension_crud.go, extension_lifecycle.go, extension_validation.go
    - **Effort:** medium
    - **PR-worthy:** medium

11. **File:** `web/src/stores/pod.ts` (453 lines)
    - **Issue:** Exceeds 200-line limit, mixes CRUD, filtering, and mapping logic
    - **Fix:** Extract pod-filters.ts, pod-mappers.ts, pod-actions.ts
    - **Effort:** small
    - **PR-worthy:** medium

12. **File:** `runner/internal/runner/message_handler.go` (371 lines)
    - **Issue:** Handles pod, relay, upgrade, and ops messages in one file
    - **Fix:** Split by message type into handler_pod.go, handler_relay.go, handler_upgrade.go
    - **Effort:** small
    - **PR-worthy:** medium

### Feature Ideas

13. **Rate limiting on auth endpoints** -- No visible rate limiting on `/api/v1/auth/login` beyond generic middleware. Add per-IP rate limiting to prevent brute force.
    - **Effort:** small
    - **PR-worthy:** high

14. **Runner disk quota enforcement** -- Sandbox has no disk space limits. Malicious or runaway agents can fill disk.
    - **Effort:** medium
    - **PR-worthy:** medium

---

## Draft PRs

### PR 1: Security headers and Redis authentication

- **PR Title:** `fix(security): add CSP headers and Redis authentication`
- **Branch:** `fix/security-headers-redis-auth`
- **Files:**
  - `web/next.config.ts` -- Add `headers()` with CSP, X-Frame-Options, X-Content-Type-Options
  - `web-admin/next.config.ts` -- Same headers
  - `deploy/selfhost/docker-compose.yml` -- Add `--requirepass` to Redis, add `REDIS_PASSWORD` env
  - `deploy/onpremise/docker-compose.yml` -- Same Redis auth, remove direct DB port exposure
  - `deploy/selfhost/selfhost.sh` -- Generate `REDIS_PASSWORD` alongside other secrets
  - `deploy/dev/dev.sh` -- Add Redis password to dev environment
- **Changes:** Add Content-Security-Policy header restricting script sources to self, add X-Frame-Options DENY, add X-Content-Type-Options nosniff. Configure Redis with `--requirepass` in all compose files and update backend config to include Redis password.
- **Effort:** 2-3 hours
- **Impact:** Closes 2 critical and 1 high security finding. Prevents XSS escalation and unauthorized Redis access.

### PR 2: Pin CI/CD action versions and add image scanning

- **PR Title:** `fix(ci): pin GitHub Actions versions and add image scanning`
- **Branch:** `fix/ci-supply-chain-hardening`
- **Files:**
  - `.github/workflows/ci.yml` -- Pin golangci-lint to specific version, pin all action SHAs, add Trivy scan step
  - `.github/workflows/release.yml` -- Pin goreleaser version, pin action SHAs, add SLSA provenance
  - `ci/backend.Dockerfile` -- Add checksum verification for golang-migrate download
  - `ci/web.Dockerfile` -- Pin node image to digest
- **Changes:** Replace `version: latest` with explicit version pins. Add SHA digest pinning for all third-party actions. Add Trivy container scan job to CI pipeline. Verify golang-migrate binary checksum after download.
- **Effort:** 2-4 hours
- **Impact:** Eliminates supply chain attack vectors in CI/CD pipeline. Adds vulnerability scanning before image push.

### PR 3: Split oversized files to comply with 200-line limit

- **PR Title:** `refactor: split oversized service files per SRP`
- **Branch:** `refactor/split-oversized-files`
- **Files:**
  - `backend/internal/service/extension/service.go` (781 lines) -- Split into service_crud.go, service_lifecycle.go, service_import.go
  - `backend/internal/service/extension/skill_importer.go` (737 lines) -- Extract skill_parser.go, skill_validator.go
  - `backend/internal/api/rest/v1/extension.go` (712 lines) -- Split into extension_handler.go, extension_skill_handler.go
  - `web/src/stores/pod.ts` (453 lines) -- Extract pod-filters.ts, pod-mappers.ts
  - `runner/internal/runner/message_handler.go` (371 lines) -- Split by message type
- **Changes:** Extract logical units from oversized files into focused, SRP-compliant modules. No behavior changes. Update imports and ensure all tests pass.
- **Effort:** 4-6 hours
- **Impact:** Improves maintainability and auditability. Brings codebase in line with its own 200-line architectural constraint.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 6 |
| Documentation | 7 |
| Test Coverage | 7 |
| Contribution Potential | 9 |

**Summary:** AgentsMesh has strong architectural foundations with clean separation of concerns, solid auth patterns (bcrypt, mTLS, parameterized queries), and good test coverage ratios. The main gaps are infrastructure security (Redis auth, CSP headers, supply chain pinning) and file size discipline. The codebase is well-positioned for contributions -- the issues are clearly scoped, the development environment is excellent (`dev.sh` one-click setup), and the project has high potential given its ambition to orchestrate multiple AI coding agents.
