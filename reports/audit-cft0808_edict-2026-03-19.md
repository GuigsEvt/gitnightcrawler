Now I have enough information to produce the full audit report.

# Audit: cft0808/edict

## Repository Overview

Edict ("三省六部") is a multi-AI-agent orchestration platform modeled after China's historical Three Departments and Six Ministries government system. It provides a real-time Kanban dashboard for managing AI agent workflows with built-in review/approval gates (the "Menxia Province" review step), task dispatch, agent health monitoring, and WebSocket-based live updates. The system routes tasks through a pipeline: user input -> Taizi (triage) -> Zhongshu (planning) -> Menxia (review/veto) -> Shangshu (dispatch) -> Six Ministries (execution) -> completion report.

- **Tech stack**: Python 3.9+ (FastAPI, SQLAlchemy async, Alembic, Redis), React 18 + TypeScript (Vite, Zustand, TailwindCSS), PostgreSQL, Redis, Docker, nginx
- **Languages**: Python (~40%), TypeScript/TSX (~55%), Shell/YAML (~5%)
- **Maturity**: **Early/Growing** -- active development with frequent commits, incomplete migration from a legacy JSON-file-based backend to PostgreSQL, test coverage focused on legacy scripts

## Code Quality Assessment

### Architecture and organization
The project has a clear separation: `edict/backend/` (FastAPI app with models/api/services/workers), `edict/frontend/` (React SPA), `agents/` (SOUL.md persona files per agent), `edict/scripts/` (legacy kanban script), `edict/migration/` (Alembic). The backend follows a reasonable layered pattern: API routes -> services -> models -> DB. The event-driven architecture via Redis pub/sub with WebSocket push is well-structured. However, the codebase still carries legacy JSON-file-based code (`scripts/kanban_update.py`, `tests/`) alongside the new PostgreSQL-backed FastAPI backend, creating confusion about which is canonical.

### Error handling patterns
Mixed quality. Backend workers use broad `except Exception` with logging but no backoff or retry limits. Frontend silently swallows errors in many `.catch(() => [])` patterns. The `agents.py` route returns `(dict, 404)` tuples instead of `HTTPException`, which FastAPI ignores (always returns 200).

### Test coverage
**Weak.** Four test files exist but they all test the **legacy** `scripts/kanban_update.py` and `scripts/file_lock.py` -- not the actual FastAPI backend. Zero tests for:
- API routes (tasks, agents, events, admin, websocket)
- Database models and services
- Workers (dispatch, orchestrator)
- Frontend components

### Documentation quality
**Good for a Chinese-language project.** Comprehensive README with comparison tables, architecture diagrams, demo video. Architecture docs exist (`docs/task-dispatch-architecture.md`). Each agent has a `SOUL.md` persona file. ROADMAP.md and CONTRIBUTING.md present. English README available.

### Dependency health
Dependencies are pinned with minimum versions (`>=`) in requirements.txt, which is standard but allows breaking changes. All deps are well-maintained mainstream packages (FastAPI, SQLAlchemy, Redis, httpx). Frontend uses React 18 with Vite -- current and well-maintained. No known vulnerable versions at time of review.

## Security Findings

### Critical

| # | Finding | Location |
|---|---------|----------|
| 1 | **Hardcoded database password** `edict_secret_change_me` as default | `edict/backend/app/config.py:9` |
| 2 | **Hardcoded JWT secret** `change-me-in-production` as default | `edict/backend/app/config.py:23` |
| 3 | **CORS wildcard with credentials** -- `allow_origins=["*"]` + `allow_credentials=True` violates CORS spec | `edict/backend/app/main.py:58-64` |

### High

| # | Finding | Location |
|---|---------|----------|
| 4 | **Path traversal** in agent_id used directly in file path construction | `edict/backend/app/api/agents.py:45-49` |
| 5 | **XSS via dangerouslySetInnerHTML** without sanitization | `edict/frontend/src/components/ConfirmDialog.tsx:18-19` |
| 6 | **Hardcoded DB password** in docker-compose.yml committed to repo | `edict/docker-compose.yml:14-15,50` |
| 7 | **No authentication** on any endpoint including admin | All API routes |

### Medium

| # | Finding | Location |
|---|---------|----------|
| 8 | File system path disclosure in admin API response | `edict/backend/app/api/admin.py:69-76` |
| 9 | Redis URL with potential credentials logged | `edict/backend/app/services/event_bus.py:59` |
| 10 | No rate limiting on any endpoint | All API routes |
| 11 | No CSP/security headers in nginx | `edict/frontend/nginx.conf` |
| 12 | Missing input sanitization on user-provided text fields | All task creation endpoints |
| 13 | `npm install` instead of `npm ci` in Dockerfile | `edict/frontend/Dockerfile:4` |

### Low

| # | Finding | Location |
|---|---------|----------|
| 14 | Hardcoded `localhost` in dispatch worker env | `edict/backend/app/workers/dispatch_worker.py:162` |
| 15 | Incorrect error response format (tuple instead of HTTPException) | `edict/backend/app/api/agents.py:43` |
| 16 | No upper bound on pagination offset | `edict/backend/app/api/tasks.py:88-89` |

## Contribution Opportunities

### Bugs

1. **File**: `edict/backend/app/api/agents.py:43`
   **Issue**: Returns `(dict, 404)` tuple -- FastAPI ignores the status code, always returns 200
   **Fix**: Use `raise HTTPException(status_code=404, detail=...)`
   **Effort**: trivial | **PR-worthy**: high

2. **File**: `edict/backend/app/api/tasks.py:8`
   **Issue**: Unused import `Field` from pydantic
   **Fix**: Remove unused import
   **Effort**: trivial | **PR-worthy**: low

### Security Fixes

3. **File**: `edict/backend/app/api/agents.py:45-49`
   **Issue**: Path traversal via unsanitized `agent_id` in file path
   **Fix**: Validate `agent_id` against `[a-zA-Z0-9_-]+` regex, verify resolved path is within agents dir
   **Effort**: small | **PR-worthy**: high

4. **File**: `edict/backend/app/main.py:58-64`
   **Issue**: Wildcard CORS with credentials
   **Fix**: Read allowed origins from env var, remove wildcard in production
   **Effort**: small | **PR-worthy**: high

5. **File**: `edict/frontend/src/components/ConfirmDialog.tsx:18-19`
   **Issue**: XSS via `dangerouslySetInnerHTML`
   **Fix**: Replace with plain text rendering or add DOMPurify sanitization
   **Effort**: small | **PR-worthy**: high

### Missing Tests

6. **File**: `tests/` (new files needed)
   **Issue**: Zero test coverage for the FastAPI backend -- no API route tests, no service tests, no model tests
   **Fix**: Add pytest + httpx `TestClient` tests for all API routes
   **Effort**: large | **PR-worthy**: high

7. **File**: `edict/frontend/` (new files needed)
   **Issue**: Zero frontend test coverage
   **Fix**: Add Vitest + React Testing Library tests for key components
   **Effort**: large | **PR-worthy**: medium

### Documentation Gaps

8. **File**: `edict/backend/` (no API docs)
   **Issue**: No OpenAPI documentation beyond auto-generated FastAPI /docs
   **Fix**: Add docstrings and response models to all API routes
   **Effort**: medium | **PR-worthy**: medium

### Code Improvements

9. **File**: `edict/backend/app/workers/orchestrator_worker.py:71-72`
   **Issue**: Broad `except Exception` with no backoff or retry limit
   **Fix**: Add exponential backoff and max retry count
   **Effort**: small | **PR-worthy**: medium

10. **File**: `edict/backend/app/config.py:9-23`
    **Issue**: Dangerous defaults for secrets that may reach production
    **Fix**: Raise error if `SECRET_KEY` or `POSTGRES_PASSWORD` are still default values when not in debug mode
    **Effort**: small | **PR-worthy**: high

### Feature Ideas

11. **Authentication middleware** -- add JWT-based auth to protect admin and mutation endpoints
    **Effort**: medium | **PR-worthy**: high

12. **Rate limiting** -- add `slowapi` middleware to prevent API abuse
    **Effort**: small | **PR-worthy**: medium

## Draft PRs

### PR 1
- **PR Title**: `fix: add path traversal protection and proper HTTP error responses in agents API`
- **Branch**: `fix/agents-api-security`
- **Files**: `edict/backend/app/api/agents.py`
- **Changes**:
  - Add regex validation for `agent_id` parameter (`^[a-zA-Z0-9_-]+$`)
  - Use `Path.resolve().is_relative_to()` to verify path stays within agents directory
  - Replace `return (dict, 404)` with `raise HTTPException(status_code=404)`
- **Effort**: 30 minutes
- **Impact**: Closes a high-severity path traversal vulnerability and fixes incorrect HTTP status codes

### PR 2
- **PR Title**: `fix: harden CORS config and require non-default secrets in production`
- **Branch**: `fix/security-hardening`
- **Files**: `edict/backend/app/main.py`, `edict/backend/app/config.py`
- **Changes**:
  - Read `CORS_ORIGINS` from env var, default to `["http://localhost:5173"]` in dev
  - Add startup validation that rejects default `SECRET_KEY` and `POSTGRES_PASSWORD` when `DEBUG=false`
  - Remove `allow_credentials=True` when using wildcard origins
- **Effort**: 1 hour
- **Impact**: Prevents credential-stuffing CORS attacks and eliminates risk of deploying with placeholder secrets

### PR 3
- **PR Title**: `fix: remove XSS vector in ConfirmDialog and add CSP headers`
- **Branch**: `fix/xss-csp-hardening`
- **Files**: `edict/frontend/src/components/ConfirmDialog.tsx`, `edict/frontend/nginx.conf`
- **Changes**:
  - Replace `dangerouslySetInnerHTML` with plain text rendering in ConfirmDialog
  - Add `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options` headers to nginx.conf
- **Effort**: 45 minutes
- **Impact**: Eliminates confirmed XSS vulnerability and adds defense-in-depth via security headers

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 3 |
| Documentation | 7 |
| Test Coverage | 2 |
| Contribution Potential | 9 |
