# Audit: cft0808/edict

## Repository Overview

**三省六部 (Sansheng Liubu / Edict)** is a multi-agent AI orchestration framework inspired by the Tang Dynasty Chinese imperial bureaucracy model. It coordinates 12 specialized AI agents through a formalized three-tier review process (Planning → Review → Dispatch → Execution), featuring a real-time monitoring dashboard, event-sourced architecture, and full audit trails. The system uses a kanban-style task management approach with a state machine governing transitions, supporting both a legacy JSON file mode and a modern PostgreSQL + Redis event-sourced mode.

**Tech stack**: Python 3.9+ (FastAPI, SQLAlchemy 2.0, Pydantic, asyncpg, Redis Streams) | TypeScript (React 18, Vite, Zustand, Tailwind CSS) | Docker Compose | GitHub Actions CI.

**Maturity**: **Growing** — v2 architecture (Edict) is actively being developed alongside a legacy JSON-based mode. Good documentation, CI pipeline, and test scaffolding exist, but auth, rate limiting, and production hardening are incomplete.

---

## Code Quality Assessment

### Architecture and Organization
Well-organized with clear separation: `agents/` (SOUL definitions), `scripts/` (legacy orchestration CLI), `edict/backend/` (FastAPI v2), `edict/frontend/` (React dashboard). The dual-mode design (JSON legacy + Postgres/Redis) adds complexity but is managed through separate code paths. State machine enforcement is consistent across both modes. ~2,200 Python LOC + ~1,000 TypeScript LOC.

### Error Handling Patterns
- Backend uses FastAPI `HTTPException` with appropriate status codes
- Database sessions properly handle rollback on exception
- Workers implement backoff-and-retry on poll errors
- Frontend API calls use `.catch(() => [])` fallbacks — functional but silent
- File locking with `fcntl` (Unix) / `msvcrt` (Windows) for atomic JSON operations

### Test Coverage
6 test files covering: kanban task lifecycle, e2e workflows, file locking, server health, agent config sync, symlink sync. ~150 assertions total. **No tests for the Edict v2 backend** (FastAPI endpoints, event bus, workers, WebSocket). Frontend has zero test coverage.

### Documentation Quality
Strong — multilingual README (Chinese/English/Japanese), architecture design doc with sequence diagrams, getting-started guide, remote skills docs, CONTRIBUTING.md, ROADMAP.md, and per-agent SOUL.md definitions. Missing: API reference docs, deployment guide for production.

### Dependency Health
All dependencies are recent versions with minimum version pinning (`>=`). No known CVEs in current dependency set. External dependency on `openclaw` CLI is undocumented in terms of version requirements.

---

## Security Findings

### Critical

| # | Finding | Location |
|---|---------|----------|
| 1 | **Overly permissive CORS with credentials** — `allow_origins=["*"]` combined with `allow_credentials=True` allows any origin to make authenticated requests | `edict/backend/app/main.py:57-64` |
| 2 | **XSS via `dangerouslySetInnerHTML`** — Title and message rendered without sanitization | `edict/frontend/src/components/ConfirmDialog.tsx:18-19` |

### High

| # | Finding | Location |
|---|---------|----------|
| 3 | **No authentication on any endpoint** — All API endpoints including admin and WebSocket are publicly accessible | `edict/backend/app/main.py` (all routes) |
| 4 | **Insecure remote skill loading** — Downloads and executes skill code from URLs without cryptographic verification | `dashboard/server.py:250-302` |
| 5 | **Subprocess calls with user-controlled input** — Agent names from user input passed to subprocess commands | `edict/backend/app/workers/dispatch_worker.py:168`, `scripts/kanban_update.py:82` |

### Medium

| # | Finding | Location |
|---|---------|----------|
| 6 | **Default secrets in .env.example** — `POSTGRES_PASSWORD=edict_secret_change_me`, `SECRET_KEY=change-me-in-production` with no runtime validation | `edict/.env.example:9,17` |
| 7 | **Dynamic module loading without integrity checks** — `importlib` loads Python files from disk without validation | `edict/scripts/kanban_update_edict.py:182-185` |
| 8 | **Path traversal risk** — String-based path comparison instead of proper canonicalization | `dashboard/server.py:197-199` |
| 9 | **Debug SQL logging** — `engine echo=settings.debug` can leak query data in logs | `edict/backend/app/db.py` |

### Low / Info

| # | Finding | Location |
|---|---------|----------|
| 10 | No rate limiting on any endpoint | All API routes |
| 11 | No CSP headers on frontend responses | `edict/backend/app/main.py` |
| 12 | Error messages expose implementation details to clients | Multiple API endpoints |
| 13 | Windows file locking may silently fail | `scripts/file_lock.py:35,43` |

---

## Contribution Opportunities

### Bugs

1. **File**: `edict/frontend/src/components/ConfirmDialog.tsx:18-19`
   **Issue**: `dangerouslySetInnerHTML` used for title/message rendering — XSS vector
   **Fix**: Replace with text content rendering or add DOMPurify sanitization
   **Effort**: trivial | **PR-worthy**: high

2. **File**: `edict/backend/app/main.py:57-64`
   **Issue**: CORS `allow_origins=["*"]` with `allow_credentials=True` is invalid per spec and insecure
   **Fix**: Use configurable origin list from env, or remove credentials flag
   **Effort**: trivial | **PR-worthy**: high

### Security Fixes

3. **File**: `edict/backend/app/main.py` + new middleware
   **Issue**: No authentication on any endpoint
   **Fix**: Add API key middleware or JWT auth using `SECRET_KEY`
   **Effort**: medium | **PR-worthy**: high

4. **File**: `edict/backend/app/workers/dispatch_worker.py:168`
   **Issue**: Agent names passed to subprocess without validation
   **Fix**: Validate agent names against a whitelist regex before subprocess execution
   **Effort**: small | **PR-worthy**: high

5. **File**: `edict/backend/app/config.py`
   **Issue**: No validation that default secrets have been changed
   **Fix**: Add startup check that rejects default `SECRET_KEY` and `POSTGRES_PASSWORD` values
   **Effort**: trivial | **PR-worthy**: medium

### Missing Tests

6. **File**: `tests/` (new files needed)
   **Issue**: Zero test coverage for Edict v2 backend (FastAPI endpoints, event bus, task service, workers)
   **Fix**: Add pytest-asyncio tests for API endpoints, event bus pub/sub, state transitions
   **Effort**: large | **PR-worthy**: high

7. **File**: `edict/frontend/` (new test setup needed)
   **Issue**: Zero frontend test coverage
   **Fix**: Add Vitest + React Testing Library; test key components (EdictBoard, TaskModal)
   **Effort**: large | **PR-worthy**: medium

### Documentation Gaps

8. **File**: `docs/` (new file)
   **Issue**: No API reference documentation for Edict v2 endpoints
   **Fix**: Add OpenAPI/Swagger auto-generation or manual API reference doc
   **Effort**: small | **PR-worthy**: medium

9. **File**: `docs/` (new file)
   **Issue**: No production deployment guide (TLS, secrets management, scaling)
   **Fix**: Write deployment guide covering Postgres/Redis setup, secret rotation, reverse proxy
   **Effort**: medium | **PR-worthy**: medium

### Code Improvements

10. **File**: `edict/frontend/src/api.ts`
    **Issue**: Silent error swallowing with `.catch(() => [])` — no user feedback on failures
    **Fix**: Add toast notifications for API errors using existing Toaster component
    **Effort**: small | **PR-worthy**: medium

11. **File**: `scripts/kanban_update.py` + `edict/scripts/kanban_update_edict.py`
    **Issue**: Dual-mode code duplication between JSON and Postgres versions
    **Fix**: Extract shared logic into common module; use strategy pattern for storage backend
    **Effort**: medium | **PR-worthy**: low

### Feature Ideas

12. **Issue**: No rate limiting — vulnerable to DoS
    **Fix**: Add `slowapi` middleware with configurable limits per endpoint
    **Effort**: small | **PR-worthy**: medium

13. **Issue**: No health check endpoint aggregating all dependencies (DB, Redis, OpenClaw)
    **Fix**: Extend `/api/admin/health` to check all upstream dependencies with timeouts
    **Effort**: small | **PR-worthy**: medium

---

## Draft PRs

### PR 1: Fix Critical CORS and XSS Vulnerabilities

- **PR Title**: `fix: patch CORS misconfiguration and XSS in ConfirmDialog`
- **Branch**: `fix/cors-and-xss`
- **Files**:
  - `edict/backend/app/main.py` — Replace `allow_origins=["*"]` with env-configurable `ALLOWED_ORIGINS` list; set `allow_credentials=False` when using wildcard
  - `edict/backend/app/config.py` — Add `ALLOWED_ORIGINS: list[str]` setting
  - `edict/frontend/src/components/ConfirmDialog.tsx` — Replace `dangerouslySetInnerHTML` with safe text rendering
- **Changes**: Add `ALLOWED_ORIGINS` env var (default `["http://localhost:5173"]`), wire it into CORS middleware. Remove `dangerouslySetInnerHTML` usage, render title/message as text content.
- **Effort**: 1-2 hours
- **Impact**: Closes the two critical security vulnerabilities. Prevents cross-origin attacks and XSS injection through dialog components.

### PR 2: Add API Key Authentication Middleware

- **PR Title**: `feat: add API key authentication middleware for all endpoints`
- **Branch**: `feat/api-key-auth`
- **Files**:
  - `edict/backend/app/middleware/auth.py` (new) — API key validation middleware
  - `edict/backend/app/main.py` — Register auth middleware
  - `edict/backend/app/config.py` — Add `API_KEY` and `AUTH_ENABLED` settings
  - `edict/.env.example` — Document new env vars
- **Changes**: Create middleware that validates `X-API-Key` header against configured secret. Skip auth for health check endpoint. Add `AUTH_ENABLED=false` default for backward compatibility. Update frontend `api.ts` to include API key header.
- **Effort**: 3-4 hours
- **Impact**: Addresses the high-severity no-auth finding. Required before any non-localhost deployment.

### PR 3: Add Edict v2 Backend Test Suite

- **PR Title**: `test: add pytest-asyncio test suite for Edict v2 backend`
- **Branch**: `feat/edict-backend-tests`
- **Files**:
  - `edict/backend/tests/conftest.py` (new) — Async test fixtures, SQLite in-memory DB
  - `edict/backend/tests/test_tasks_api.py` (new) — Task CRUD and state transition tests
  - `edict/backend/tests/test_event_bus.py` (new) — Event publish/subscribe tests
  - `edict/backend/tests/test_task_service.py` (new) — Business logic unit tests
  - `edict/backend/requirements-dev.txt` (new) — pytest-asyncio, httpx (for TestClient)
  - `.github/workflows/ci.yml` — Add Edict backend test job
- **Changes**: Create async test infrastructure using `pytest-asyncio` and FastAPI `TestClient`. Cover: task creation, all 15 state transitions (valid + invalid), event emission, task service transaction handling. Use SQLite async for tests to avoid Postgres dependency in CI.
- **Effort**: 1-2 days
- **Impact**: The v2 backend has zero test coverage. This establishes the test foundation and catches regressions as the project matures.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 3 |
| Documentation | 7 |
| Test Coverage | 3 |
| Contribution Potential | 9 |

**Summary**: Well-architected project with a creative domain metaphor and solid documentation. The main gaps are in security hardening (no auth, CORS misconfiguration, XSS) and test coverage (v2 backend entirely untested). High contribution potential — the security fixes are impactful and approachable, and the test gap is a clear opportunity for meaningful contribution.
