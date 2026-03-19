# Audit: cft0808/edict

## Repository Overview

Edict is a multi-agent AI orchestration platform modeled on the historical Chinese imperial bureaucratic system (三省六部 — Three Secretariats and Six Ministries). It implements a 12-agent architecture with a real-time kanban dashboard, event-driven task dispatch via Redis Streams, a PostgreSQL-backed state machine, and a React frontend. Agents are dispatched via OpenClaw CLI subprocess calls, with each agent having a unique "SOUL.md" personality profile defining its role and behavior.

**Tech stack:** Python 3.11 (FastAPI, SQLAlchemy async, Pydantic, asyncpg), TypeScript (React, Zustand, Vite, Tailwind CSS), PostgreSQL, Redis Streams, Docker, Nginx.

**Maturity:** Early/Growing — active development with frequent commits, but lacking authentication, comprehensive tests, and production hardening.

---

## Code Quality Assessment

**Architecture and organization:** Clean separation — `models/`, `services/`, `api/`, `workers/` in backend; component-based React frontend with a centralized Zustand store. Event-driven via Redis Streams with consumer groups. Well-thought-out state machine with explicit transition validation.

**Error handling:** Inconsistent. Some endpoints use `HTTPException`, others return raw tuples. Frontend silently catches all exceptions in store actions. Workers have basic try/catch but missing edge cases (stalled task handler is a TODO).

**Test coverage:** Poor. Only 4 test files exist, all targeting a legacy `kanban_update.py` script. Zero tests for the FastAPI backend, event bus, state machine, WebSocket, or any frontend component.

**Documentation:** README is comprehensive with screenshots. Agent SOUL.md files are detailed but contain hardcoded local paths. No API documentation (OpenAPI/Swagger not exposed). No deployment/runbook docs.

**Dependency health:** `requirements.txt` uses `>=` floor pins with no upper bounds — risky for reproducibility. Frontend `package.json` uses `^` ranges which is acceptable. No lock file for Python deps.

---

## Security Findings

### Critical

| # | Finding | Location |
|---|---------|----------|
| S1 | **Hardcoded default credentials** — `postgres_password: str = "edict_secret_change_me"` and `secret_key: str = "change-me-in-production"` with no enforcement to change them | `edict/backend/app/config.py:13,23` |

### High

| # | Finding | Location |
|---|---------|----------|
| S2 | **CORS wildcard with credentials** — `allow_origins=["*"]` combined with `allow_credentials=True` allows any origin to make authenticated requests, enabling CSRF | `edict/backend/app/main.py:58-64` |
| S3 | **Zero authentication/authorization** — All API endpoints (including admin, task transitions, WebSocket) are fully open. No auth middleware exists anywhere | All `edict/backend/app/api/*.py` |

### Medium

| # | Finding | Location |
|---|---------|----------|
| S4 | **Path traversal in agent endpoint** — `agent_id` parameter used directly in file path construction without validation; `../../etc/passwd` style attacks possible | `edict/backend/app/api/agents.py:46` |
| S5 | **Unvalidated subprocess arguments** — Agent name and message passed to `subprocess.run(["openclaw", "agent", "--agent", agent, "-m", message])` without whitelist validation | `edict/backend/app/workers/dispatch_worker.py:152-175` |
| S6 | **Database URL partial exposure** — Admin endpoint leaks host/database name via `settings.database_url.split("@")[-1]` | `edict/backend/app/api/admin.py:87` |
| S7 | **No rate limiting** — All endpoints accept unlimited requests; task creation and dispatch are unbounded | All API routes |

### Low

| # | Finding | Location |
|---|---------|----------|
| S8 | **Unpinned base Docker image** — `FROM python:3.11-slim` without digest pin; vulnerable to supply chain substitution | `Dockerfile:1`, `edict/Dockerfile:1` |
| S9 | **Redis connection without TLS** — No `ssl=True` or certificate validation on Redis connections | `edict/backend/app/services/event_bus.py:54-58` |
| S10 | **WebSocket accepts all connections** — No origin validation or token required for WS connections | `edict/backend/app/api/websocket.py:26` |

### Info

| # | Finding | Location |
|---|---------|----------|
| S11 | Hardcoded local paths in agent SOUL.md files (`/Users/bingsen/clawd/...`) | `agents/zhongshu/SOUL.md` |
| S12 | Demo data embedded in Docker image — not suitable for production | `Dockerfile`, `docker/demo_data/` |

---

## Contribution Opportunities

### Bugs

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `edict/backend/app/api/agents.py:43` | Returns `(dict, 404)` tuple instead of `HTTPException` — FastAPI ignores the status code | Use `raise HTTPException(status_code=404, ...)` | trivial | medium |
| `edict/backend/app/workers/orchestrator_worker.py:187` | Stalled task handler is a TODO comment, does nothing | Implement retry/escalation logic | medium | high |
| `edict/frontend/src/store.ts:338-349` | All API errors silently swallowed with empty `catch {}` | Add error state to store, surface in UI | small | medium |

### Security Fixes

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `edict/backend/app/config.py:13,23` | Hardcoded default secrets | Remove defaults, require env vars, add startup validation | small | high |
| `edict/backend/app/main.py:58-64` | CORS wildcard + credentials | Make origins configurable via env var, restrict methods/headers | trivial | high |
| `edict/backend/app/api/agents.py:46` | Path traversal via agent_id | Add agent ID whitelist validation | trivial | high |
| `edict/backend/app/workers/dispatch_worker.py:152` | Unvalidated subprocess args | Whitelist agent names, sanitize message | small | high |

### Missing Tests

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `edict/backend/app/api/tasks.py` | Zero tests for task CRUD and state transitions | Add pytest suite with DB fixtures | medium | high |
| `edict/backend/app/services/event_bus.py` | No tests for Redis Streams event bus | Add tests with mock/real Redis | medium | high |
| `edict/backend/app/models/task.py` | State machine transitions untested | Unit test all valid/invalid transitions | small | high |
| `edict/frontend/src/components/` | No frontend component tests | Add vitest + React Testing Library | large | medium |

### Documentation Gaps

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `edict/backend/app/main.py` | OpenAPI docs not exposed (no `docs_url`) | Enable `/api/docs` endpoint with descriptions | trivial | medium |
| (missing) | No deployment/operations guide | Write production deployment docs | medium | medium |
| `agents/*/SOUL.md` | Hardcoded local paths | Use environment variables/templates | small | low |

### Code Improvements

| File | Issue | Fix | Effort | PR-worthy |
|------|-------|-----|--------|-----------|
| `edict/backend/requirements.txt` | Unpinned dependencies (`>=` only) | Pin to exact versions, add `requirements-dev.txt` | trivial | medium |
| `edict/backend/app/api/websocket.py` | Duplicate WebSocket handler logic for `/ws` and `/ws/task/{id}` | Extract shared handler function | small | low |
| `edict/backend/app/workers/*.py` | Duplicated recovery/heartbeat patterns | Create base worker class | medium | medium |

### Feature Ideas

| Feature | Description | Effort | PR-worthy |
|---------|-------------|--------|-----------|
| API authentication middleware | Bearer token or API key auth with RBAC | medium | high |
| Prometheus metrics | Export task counts, latencies, worker health | medium | high |
| Task timeout/escalation | Auto-escalate stalled tasks after configurable timeout | medium | high |

---

## Draft PRs

### PR 1: Security hardening — credentials, CORS, path traversal

- **PR Title:** `fix: remove hardcoded secrets, restrict CORS, validate agent paths`
- **Branch:** `fix/security-hardening`
- **Files:**
  - `edict/backend/app/config.py` — Remove default values for `postgres_password` and `secret_key`, add startup validation that raises if defaults detected
  - `edict/backend/app/main.py` — Replace `allow_origins=["*"]` with configurable `ALLOWED_ORIGINS` env var, restrict methods/headers
  - `edict/backend/app/api/agents.py` — Add `VALID_AGENTS` whitelist, validate `agent_id` before path construction
  - `edict/backend/app/workers/dispatch_worker.py` — Validate agent name against whitelist before subprocess call
- **Changes:** 4 files, ~40 lines changed. Config raises `ValueError` on startup if secrets are defaults. CORS reads from `ALLOWED_ORIGINS` env (comma-separated, defaults to `http://localhost:3000`). Agent endpoint rejects IDs not in whitelist. Dispatch worker validates agent name.
- **Effort:** 1-2 hours
- **Impact:** Addresses 1 Critical + 2 High + 1 Medium security finding. Prevents credential reuse, CSRF, path traversal, and command injection.

### PR 2: Add backend test suite for task API and state machine

- **PR Title:** `test: add pytest suite for task API and state machine transitions`
- **Branch:** `feat/backend-tests`
- **Files:**
  - `tests/conftest.py` — Pytest fixtures for async DB session, test client, Redis mock
  - `tests/test_task_api.py` — CRUD tests for task endpoints, state transition validation (valid + invalid), error responses
  - `tests/test_state_machine.py` — Unit tests for `TaskState` enum and `VALID_TRANSITIONS` map
  - `edict/backend/requirements-dev.txt` — Add pytest, pytest-asyncio, httpx, fakeredis
- **Changes:** 4 new files, ~300 lines. Tests cover: task creation, retrieval, listing with filters, all valid state transitions, rejection of invalid transitions, error response format.
- **Effort:** 3-4 hours
- **Impact:** Goes from 0% to ~40% backend coverage. Catches regressions in the core task workflow. Enables CI gating.

### PR 3: Implement stalled task recovery and timeout handling

- **PR Title:** `feat: implement stalled task timeout and auto-recovery`
- **Branch:** `feat/task-timeout-recovery`
- **Files:**
  - `edict/backend/app/config.py` — Add `task_timeout_minutes` setting (default 60)
  - `edict/backend/app/workers/orchestrator_worker.py` — Implement `_on_task_stalled` to retry dispatch or escalate to supervisor agent
  - `edict/backend/app/models/task.py` — Add `stalled_at`, `retry_count` fields
  - `edict/migration/versions/002_add_stall_tracking.py` — Alembic migration for new columns
  - `tests/test_stall_recovery.py` — Tests for timeout detection and recovery
- **Changes:** 5 files, ~150 lines. Orchestrator checks task age against timeout, emits `task.stalled` event after threshold. Recovery attempts re-dispatch up to 3 times, then marks as `blocked` for human intervention.
- **Effort:** 4-6 hours
- **Impact:** Resolves the TODO in orchestrator_worker. Prevents tasks from silently hanging forever — a critical operational gap.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 3 |
| Documentation | 5 |
| Test Coverage | 2 |
| Contribution Potential | 9 |

The architecture is solid and well-designed, but the project needs significant security hardening, test coverage, and operational tooling before production use. High contribution potential — many impactful, well-scoped improvements available.
