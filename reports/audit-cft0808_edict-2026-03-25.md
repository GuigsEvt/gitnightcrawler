# Audit: cft0808/edict

## Repository Overview

**Edict** (三省六部 — "Three Secretariats and Six Ministries") is a multi-agent AI collaboration framework inspired by ancient Chinese imperial bureaucracy. It implements 12 specialized AI agents in a hierarchical governance structure with institutional checks and balances — a "Prince" (太子) triages incoming messages, planning/review/dispatch secretariats handle workflow, and six domain-specific ministries execute tasks. The system features a real-time dashboard, event-driven architecture via Redis Streams, and integrates with OpenClaw for agent execution.

**Tech stack:** Python 3.10+ (FastAPI, SQLAlchemy 2.0 async, asyncpg, Redis Streams, Pydantic v2), React 18 + TypeScript + Vite + Zustand + Tailwind CSS. Standalone dashboard server uses only Python stdlib. Docker multi-stage builds, Alembic migrations, GitHub Actions CI.

**Maturity:** Growing (Phase 1 complete, Phase 2 in progress). Core state machine and event bus are production-quality; auth, rate limiting, and observability are missing.

---

## Code Quality Assessment

### Architecture and Organization
Well-structured separation of concerns: models / services / API / workers in the backend, with a clear event-driven pattern (Redis Streams with consumer groups and ACK guarantees). The 9-state task machine with strict transition validation is the architectural highlight. Agent permissions are enforced via a subagent call matrix. Frontend uses Zustand for state with 5s polling.

**Issues:** Code duplication between `legacy.py` and `tasks.py` API endpoints; WebSocket handler logic is duplicated across two nearly identical endpoints; mutable global state (`_connections` set, `_bus` singleton) without synchronization primitives.

### Error Handling Patterns
Generally good — specific HTTP exceptions, structured logging per module, proper timeout/retry patterns in workers. **Issues:** Broad `except Exception` in WebSocket handlers; silent `JSONDecodeError`/`IOError` catch in `agents.py` returns empty config without logging; assertions used for connection validation in event bus.

### Test Coverage
5 test files covering kanban operations, file locking, server health, and config sync. CI runs on Python 3.10/3.11/3.12 with syntax checking. **Gaps:** No async endpoint tests (no pytest-asyncio), no service/event bus tests, no error path testing, no mocking of external dependencies, no coverage tracking.

### Documentation Quality
Excellent README in 3 languages (CN/EN/JA), detailed CONTRIBUTING.md, architecture docs, agent SOUL.md personality files for all 12 agents. Module-level docstrings in key backend files. **Gaps:** No API endpoint documentation, missing docstrings in config/admin/legacy modules.

### Dependency Health
Modern, well-maintained dependencies: FastAPI 0.115+, SQLAlchemy 2.0+, asyncpg, Redis 5.2+, Pydantic v2. Frontend uses React 18, Vite 6, TypeScript 5.6. All pinned with minimum versions. Dashboard server has zero external dependencies. No known CVEs detected in specified versions (should verify with `pip-audit`).

---

## Security Findings

### Critical

**[C1] Hardcoded Database Password in docker-compose.yml**
- File: `edict/docker-compose.yml:16-17`, `docker-compose.yml:13`
- `POSTGRES_PASSWORD: edict_dev_2024` and full connection string with credentials in version control
- Fix: Use `.env` file (gitignored) or Docker secrets

**[C2] Default Secrets in Source Code**
- File: `edict/backend/app/config.py:13,23`
- `postgres_password: str = "edict_secret_change_me"` and `secret_key: str = "change-me-in-production"` as Python defaults
- Fix: Remove defaults, require environment variables, fail at startup if unset

### High

**[H1] CORS Wildcard with Credentials**
- File: `edict/backend/app/main.py:58-64`
- `allow_origins=["*"]` combined with `allow_credentials=True` violates CORS security model, enabling CSRF
- Fix: Specify explicit allowed origins or remove `allow_credentials=True`

### Medium

**[M1] No Authentication Layer** — All API endpoints (including admin, WebSocket) are publicly accessible. Design decision for local use but undocumented.

**[M2] Debug Mode in Docker Compose** — `edict/docker-compose.yml:49` sets `DEBUG: "true"`, exposing stack traces and SQL queries with credentials.

**[M3] No Rate Limiting** — No request throttling on any endpoint; DoS-susceptible.

**[M4] Unauthenticated WebSocket** — `edict/backend/app/api/websocket.py:27` accepts any connection, broadcasts all events.

**[M5] Admin Config Endpoint Exposure** — `edict/backend/app/api/admin.py:84-90` partially redacts credentials but endpoint is unauthenticated.

**[M6] Race Condition in WebSocket Broadcast** — `websocket.py:142-150` iterates `_connections` set while it can be mutated by concurrent coroutines.

### Low / Info

**[L1]** HTTP localhost references (dev-only, acceptable). 
**[L2]** SSRF protections properly implemented in `scripts/utils.py:validate_url()`. 
**[L3]** Path traversal protections in place in `dashboard/server.py` with `.resolve()` and root checking. 
**[L4]** No pickle/unsafe YAML deserialization found. 
**[L5]** Subprocess calls use list-based invocation (no shell injection).

---

## Contribution Opportunities

### Bugs

**B1. Race condition in WebSocket broadcast**
- File: `edict/backend/app/api/websocket.py:142-150`
- Issue: `_connections` set mutated during iteration by concurrent coroutines
- Fix: Snapshot with `list(_connections)` before iterating, or use `asyncio.Lock`
- Effort: trivial
- PR-worthy: high

**B2. Event bus singleton double-instantiation**
- File: `edict/backend/app/services/event_bus.py:200-205`
- Issue: `get_event_bus()` can create multiple instances under high concurrency
- Fix: Add `asyncio.Lock` guard
- Effort: trivial
- PR-worthy: medium

**B3. Silent config load failure**
- File: `edict/backend/app/api/agents.py:69-70`
- Issue: `JSONDecodeError`/`IOError` silently returns empty config, masking real errors
- Fix: Add `log.warning()` before returning fallback
- Effort: trivial
- PR-worthy: low

### Security Fixes

**S1. Remove hardcoded credentials from docker-compose**
- File: `edict/docker-compose.yml:16-17`, `docker-compose.yml:13`
- Issue: Plaintext DB password in version control
- Fix: Reference `.env` file, add `.env` to `.gitignore`, document setup
- Effort: small
- PR-worthy: high

**S2. Fix CORS wildcard + credentials**
- File: `edict/backend/app/main.py:58-64`
- Issue: `allow_origins=["*"]` with `allow_credentials=True`
- Fix: Make origins configurable via environment variable, default to localhost
- Effort: small
- PR-worthy: high

**S3. Remove default secrets from config.py**
- File: `edict/backend/app/config.py:13,23`
- Issue: Default passwords/secrets in source code
- Fix: Remove defaults, add startup validation that requires env vars
- Effort: small
- PR-worthy: high

### Missing Tests

**T1. Async API endpoint tests**
- File: `tests/` (new files needed)
- Issue: No tests for FastAPI endpoints, service layer, or event bus
- Fix: Add pytest-asyncio, httpx test client, test all endpoints
- Effort: medium
- PR-worthy: high

**T2. State transition edge case tests**
- File: `tests/` (new file)
- Issue: No tests validating illegal state transitions are rejected
- Fix: Parametrized tests for all valid/invalid transitions
- Effort: small
- PR-worthy: medium

**T3. Error path tests**
- File: `tests/` (new file)
- Issue: No tests for missing tasks, invalid IDs, malformed payloads
- Fix: Add negative test cases
- Effort: small
- PR-worthy: medium

### Documentation Gaps

**D1. Security model documentation**
- File: `docs/` (new file)
- Issue: No documentation explaining that the system assumes trusted network
- Fix: Add security model document, deployment recommendations
- Effort: small
- PR-worthy: medium

**D2. API endpoint documentation**
- File: `edict/backend/app/api/*.py`
- Issue: No OpenAPI descriptions on endpoints
- Fix: Add `summary`/`description` to FastAPI route decorators
- Effort: small
- PR-worthy: medium

### Code Improvements

**I1. Consolidate legacy and main task APIs**
- File: `edict/backend/app/api/legacy.py`, `edict/backend/app/api/tasks.py`
- Issue: Duplicated state transition/progress logic across two routers
- Fix: Create shared service methods, make legacy router a thin adapter
- Effort: medium
- PR-worthy: medium

**I2. Extract WebSocket connection management**
- File: `edict/backend/app/api/websocket.py`
- Issue: Two nearly identical WebSocket handlers with duplicated setup
- Fix: Extract shared logic into helper class/function
- Effort: small
- PR-worthy: medium

**I3. Add linting and type checking to CI**
- File: `.github/workflows/ci.yml`
- Issue: No ruff/mypy in CI pipeline
- Fix: Add ruff lint + mypy type check steps
- Effort: small
- PR-worthy: high

### Feature Ideas

**F1. Optional API key authentication middleware** — Environment-configurable API key validation for network deployments. Effort: small.

**F2. Frontend WebSocket with reconnect** — Replace 5s polling with persistent WebSocket + exponential backoff reconnect. Effort: medium.

**F3. Prometheus metrics endpoint** — Export task counts, state distributions, agent latencies for observability. Effort: medium.

---

## Draft PRs

### PR 1: Security hardening — credentials and CORS

- **PR Title:** `fix(security): remove hardcoded credentials and fix CORS configuration`
- **Branch:** `fix/security-credentials-cors`
- **Files:**
  - `edict/docker-compose.yml` — Replace inline passwords with `${POSTGRES_PASSWORD}` env ref
  - `docker-compose.yml` — Same treatment
  - `edict/backend/app/config.py` — Remove default values for `postgres_password` and `secret_key`, add startup validation
  - `edict/backend/app/main.py` — Make CORS origins configurable via `settings.cors_origins`, default to `["http://localhost:3000", "http://127.0.0.1:7891"]`
  - `edict/.env.example` — Add CORS_ORIGINS example
- **Changes:** Extract all secrets to `.env` files, fail fast on missing required secrets, make CORS origins a comma-separated env var, update docker-compose to reference env vars. Add `.env` to `.gitignore` if not already present.
- **Effort:** ~1 hour
- **Impact:** Eliminates the two critical and one high security findings. Prevents credential leakage and CSRF attacks.

### PR 2: Fix WebSocket race condition and add asyncio safety

- **PR Title:** `fix(websocket): resolve race condition in broadcast and singleton initialization`
- **Branch:** `fix/websocket-race-condition`
- **Files:**
  - `edict/backend/app/api/websocket.py` — Replace `_connections` set with `asyncio.Lock`-protected access, snapshot before iteration in `broadcast()`
  - `edict/backend/app/services/event_bus.py` — Add `asyncio.Lock` to `get_event_bus()` singleton
- **Changes:** Add `_lock = asyncio.Lock()` guard around `_connections` add/remove/iterate operations. In `broadcast()`, snapshot with `conns = list(_connections)` under lock. In `get_event_bus()`, use lock to prevent double-init.
- **Effort:** ~30 minutes
- **Impact:** Eliminates potential crashes and data races under concurrent WebSocket connections. Production stability improvement.

### PR 3: Add ruff linting and pytest-asyncio to CI

- **PR Title:** `ci: add ruff linting, mypy type checking, and async test infrastructure`
- **Branch:** `feat/ci-quality-gates`
- **Files:**
  - `.github/workflows/ci.yml` — Add ruff lint step, mypy check step
  - `pyproject.toml` (new) — Configure ruff rules, mypy settings
  - `edict/backend/requirements-dev.txt` (new) — Add ruff, mypy, pytest-asyncio, httpx
  - `tests/test_api_tasks.py` (new) — Basic async endpoint tests using httpx AsyncClient
- **Changes:** Add quality gate steps to CI before tests. Configure ruff with reasonable defaults (pyflakes, pycodestyle, isort). Add mypy in non-strict mode initially. Create one test file demonstrating async endpoint testing pattern.
- **Effort:** ~2 hours
- **Impact:** Catches bugs and style issues automatically on every PR. Establishes testing patterns for async code that other contributors can follow.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 4 |
| Documentation | 7 |
| Test Coverage | 4 |
| Contribution Potential | 9 |
