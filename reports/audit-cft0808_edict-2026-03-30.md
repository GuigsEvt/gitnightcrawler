# Audit: cft0808/edict

## Repository Overview

Edict is a multi-agent AI orchestration system themed around the Chinese imperial court bureaucracy. It uses OpenClaw agents (named after imperial ministries like "Crown Prince", "Ministry of Revenue", etc.) to process tasks through a kanban-style workflow. The system features a FastAPI backend with PostgreSQL and Redis, a React frontend dashboard, notification integrations (Slack, Discord, Telegram, Feishu, WeCom), and Docker-based deployment. Tasks flow through a dispatch pipeline where agents are assigned work based on their roles, with real-time WebSocket updates and an event bus built on Redis Streams.

**Tech stack**: Python 3.9+ (FastAPI, SQLAlchemy 2.0, Alembic, asyncpg, Redis), TypeScript (React 18, Vite 6, Tailwind CSS, Zustand), Docker Compose, PostgreSQL 16, Redis 7, Nginx, GitHub Actions CI.

**Maturity**: Growing. The project has solid architecture, multi-language docs, Docker support, and CI, but lacks authentication, has limited test coverage, and several security gaps that prevent production readiness.

---

## Code Quality Assessment

**Architecture and organization**: Well-structured. Clean separation between backend (`edict/backend/app/`) with proper layering (API routes, services, models, channels), frontend (`edict/frontend/src/`), and a legacy dashboard server. The event-driven architecture using Redis Streams is sound. The 12-agent system with distinct roles is creative and well-documented.

**Error handling patterns**: Inconsistent. Some endpoints use proper try/except with structured responses (`admin.py`), but error details leak to clients (exception strings returned in JSON). The event bus lacks error handling on JSON parsing. No global exception handler configured in FastAPI.

**Test coverage**: Weak. 6 test files totaling ~300 lines cover kanban operations, file locking, config sync, and symlink regression. Zero tests for API endpoints, WebSocket, authentication, input validation, event bus, or notification channels. No coverage tooling configured.

**Documentation quality**: Strong. README in 3 languages (Chinese, English, Japanese), architecture docs, getting-started guide, screenshots, demo video, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, and ROADMAP.md. Well above average for the project's size.

**Dependency health**: Good baseline. Dependabot configured for weekly updates across pip, npm, and GitHub Actions. However, Python dependencies use `>=` ranges without upper bounds, which risks breaking changes.

---

## Security Findings

### Critical

| # | Finding | Location |
|---|---------|----------|
| 1 | **No authentication/authorization on any endpoint** - All API routes (task CRUD, admin config, dispatch, health) are completely unauthenticated. Anyone with network access can create/modify/delete tasks, trigger agent dispatch, and read system configuration. | `edict/backend/app/api/*.py` |
| 2 | **Hardcoded default secrets** - `postgres_password="edict_secret_change_me"` and `secret_key="change-me-in-production"` as defaults. No validation that these are changed before startup. | `edict/backend/app/config.py:16,26` |
| 3 | **CORS wildcard with credentials** - `allow_origins=["*"]` combined with `allow_credentials=True` allows any origin to make authenticated requests. | `edict/backend/app/main.py:58-64` |

### High

| # | Finding | Location |
|---|---------|----------|
| 4 | **Path traversal in agents API** - `agent_id` parameter used directly in file path construction (`Path(...) / "agents" / agent_id / "SOUL.md"`) without validation. `../../etc/passwd` style attacks possible. | `edict/backend/app/api/agents.py:46,61` |
| 5 | **Unvalidated dispatch message** - Message content passed to subprocess without length/content validation. While using list-form subprocess (safe from shell injection), no bounds checking exists. | `edict/backend/app/workers/dispatch_worker.py:153-157` |

### Medium

| # | Finding | Location |
|---|---------|----------|
| 6 | **SSRF via webhook channels** - Webhook URL validation only checks HTTPS scheme, not hostname. Internal IPs (`https://169.254.169.254/...`) can be targeted. Same issue in Telegram channel using `urlopen()`. | `edict/backend/app/channels/webhook.py:17-18`, `telegram.py:35` |
| 7 | **Config info disclosure** - `/api/admin/config` endpoint exposes database host, port, and partial connection string. `/api/admin/health/deep` leaks infrastructure details. | `edict/backend/app/api/admin.py:79-90` |
| 8 | **Debug mode enabled in Docker Compose** - `DEBUG: "true"` hardcoded in production-like compose file. | `edict/docker-compose.yml:51` |
| 9 | **Dashboard path traversal (partial)** - `read_skill_content()` uses string prefix matching for path validation which can be bypassed via symlinks. | `dashboard/server.py:241-265` |
| 10 | **No rate limiting** - No rate limiting middleware on any endpoint. | `edict/backend/app/main.py` |

### Low

| # | Finding | Location |
|---|---------|----------|
| 11 | **Error details leaked to clients** - Exception strings returned in API responses expose schema/infrastructure info. | `edict/backend/app/api/admin.py:27-36` |
| 12 | **Container images not pinned** - Using `python:3.12-slim`, `node:20-alpine` without digests. | `edict/Dockerfile`, `edict/frontend/Dockerfile` |
| 13 | **Backend container runs as root** - No `USER` directive in backend Dockerfile. | `edict/Dockerfile` |
| 14 | **Dependencies not upper-bounded** - `>=` without `<` allows major version jumps. | `edict/backend/requirements.txt` |

### Info

| # | Finding | Location |
|---|---------|----------|
| 15 | **No CSRF protection** - JSON API mitigates most CSRF, but state-changing POST endpoints should validate Origin header. | `edict/backend/app/main.py` |
| 16 | **No security event audit logging** - Admin operations, task transitions, and dispatch events not logged for security auditing. | `edict/backend/app/` |

---

## Contribution Opportunities

### Bugs

1. **File**: `edict/backend/app/services/event_bus.py:143-146`
   - **Issue**: `json.loads()` on Redis stream payload has no try/except. Malformed JSON crashes the consumer loop.
   - **Fix**: Wrap in try/except, log malformed payloads, continue processing.
   - **Effort**: Trivial
   - **PR-worthy**: Medium

2. **File**: `dashboard/server.py:241-265`
   - **Issue**: Path validation uses string prefix matching (`str(path).startswith(str(root))`) which can be tricked by paths like `/allowed_root_extra/malicious`.
   - **Fix**: Use `pathlib.Path.is_relative_to()` (Python 3.9+).
   - **Effort**: Trivial
   - **PR-worthy**: High

### Security Fixes

3. **File**: `edict/backend/app/api/agents.py:46,61`
   - **Issue**: Path traversal via unvalidated `agent_id`.
   - **Fix**: Validate `agent_id` against regex `^[a-z_]+$` or whitelist from config.
   - **Effort**: Small
   - **PR-worthy**: High

4. **File**: `edict/backend/app/main.py:58-64`
   - **Issue**: CORS wildcard + credentials.
   - **Fix**: Make `allow_origins` configurable via env var `CORS_ORIGINS`, default to frontend URL.
   - **Effort**: Small
   - **PR-worthy**: High

5. **File**: `edict/backend/app/config.py:16,26`
   - **Issue**: Insecure defaults accepted silently.
   - **Fix**: Add `@validator` that raises on default values when `DEBUG=False`.
   - **Effort**: Small
   - **PR-worthy**: High

6. **File**: `edict/backend/app/channels/webhook.py:17-18`, `telegram.py:35`
   - **Issue**: SSRF via webhook URLs.
   - **Fix**: Add hostname validation rejecting private/reserved IP ranges (RFC 1918, link-local, loopback).
   - **Effort**: Medium
   - **PR-worthy**: High

### Missing Tests

7. **File**: `tests/` (new files needed)
   - **Issue**: No API endpoint tests. Zero coverage on FastAPI routes, WebSocket, event bus, notification channels.
   - **Fix**: Add `test_api_tasks.py`, `test_api_admin.py`, `test_event_bus.py` using `httpx.AsyncClient` with FastAPI TestClient.
   - **Effort**: Large
   - **PR-worthy**: High

8. **File**: `tests/` (new file)
   - **Issue**: No input validation tests (path traversal, XSS in task titles, oversized payloads).
   - **Fix**: Add `test_input_validation.py` with fuzzing-style inputs.
   - **Effort**: Medium
   - **PR-worthy**: Medium

### Documentation Gaps

9. **File**: `docs/` (new file: `docs/security-hardening.md`)
   - **Issue**: No production deployment security guide. Users may deploy with default secrets and debug mode.
   - **Fix**: Document required env vars, secret rotation, firewall rules, CORS config.
   - **Effort**: Small
   - **PR-worthy**: Medium

10. **File**: `edict/backend/requirements.txt`
    - **Issue**: No `requirements-dev.txt` for test dependencies (pytest, httpx, etc.).
    - **Fix**: Create dev requirements file, document in CONTRIBUTING.md.
    - **Effort**: Trivial
    - **PR-worthy**: Low

### Code Improvements

11. **File**: `edict/backend/app/api/admin.py:27-36`
    - **Issue**: Raw exception strings returned to clients leak internal details.
    - **Fix**: Log full exception server-side, return generic "service unavailable" to client.
    - **Effort**: Trivial
    - **PR-worthy**: Medium

12. **File**: `edict/Dockerfile`
    - **Issue**: Runs as root, no health check.
    - **Fix**: Add `RUN useradd -r edict && USER edict`, add `HEALTHCHECK` directive.
    - **Effort**: Trivial
    - **PR-worthy**: Medium

13. **File**: `install.sh:5`
    - **Issue**: Missing `set -u` for unset variable detection.
    - **Fix**: Add `set -u` after `set -e`.
    - **Effort**: Trivial
    - **PR-worthy**: Low

### Feature Ideas

14. **API key authentication** - Add `X-API-Key` header middleware as minimum viable auth. Store keys in env/config.
    - **Effort**: Medium
    - **PR-worthy**: High

15. **Request rate limiting** - Add `slowapi` middleware with configurable limits per endpoint.
    - **Effort**: Small
    - **PR-worthy**: Medium

16. **Security event audit log** - Log admin operations, task transitions, failed requests to a dedicated `audit_events` table.
    - **Effort**: Medium
    - **PR-worthy**: Medium

---

## Draft PRs

### PR 1: Path Traversal Fix + Input Validation

- **PR Title**: `fix: prevent path traversal in agents API and validate input parameters`
- **Branch**: `fix/path-traversal-agents-api`
- **Files**:
  - `edict/backend/app/api/agents.py` - Add agent_id regex validation
  - `edict/backend/app/api/tasks.py` - Add Pydantic validators for query params
  - `edict/backend/app/api/websocket.py` - Validate task_id format
  - `dashboard/server.py` - Replace `startswith()` with `is_relative_to()`
- **Changes**: Add `VALID_AGENT_ID = re.compile(r'^[a-z_]{1,32}$')` guard at the top of agents.py. Return 400 for invalid agent_id before any file path construction. In websocket.py, validate task_id as UUID format. In dashboard server.py, replace string prefix path check with `pathlib.Path.is_relative_to()`. Add corresponding test cases.
- **Effort**: 2-3 hours
- **Impact**: Closes the most exploitable vulnerability in the codebase. Path traversal could allow reading arbitrary server files.

### PR 2: CORS Hardening + Secret Validation

- **PR Title**: `fix: restrict CORS origins and enforce secret key configuration`
- **Branch**: `fix/cors-and-secrets-hardening`
- **Files**:
  - `edict/backend/app/main.py` - Configurable CORS origins
  - `edict/backend/app/config.py` - Add startup validators for secrets
  - `edict/docker-compose.yml` - Set `DEBUG=false`, add `CORS_ORIGINS`
  - `.env.example` - Document `CORS_ORIGINS` variable
- **Changes**: Add `cors_origins: list[str] = ["http://localhost:5173"]` to Settings. Replace hardcoded `["*"]` with `settings.cors_origins`. Add `@model_validator` that raises `ValueError` if `secret_key` or `postgres_password` contain "change" when `debug=False`. Set `DEBUG=false` in docker-compose.yml. Update .env.example with comments.
- **Effort**: 1-2 hours
- **Impact**: Prevents two critical security misconfigurations that would be present in any naive deployment. Zero breaking changes for development.

### PR 3: SSRF Protection for Notification Channels

- **PR Title**: `fix: add SSRF protection to webhook and notification channels`
- **Branch**: `fix/ssrf-notification-channels`
- **Files**:
  - `edict/backend/app/channels/base.py` - Add `validate_webhook_url()` utility
  - `edict/backend/app/channels/webhook.py` - Use shared URL validator
  - `edict/backend/app/channels/telegram.py` - Use shared URL validator
  - `edict/backend/app/channels/discord.py` - Use shared URL validator
  - `edict/backend/app/channels/slack.py` - Use shared URL validator
  - `edict/backend/app/channels/feishu.py` - Use shared URL validator
  - `tests/test_ssrf_validation.py` - Test private IP rejection
- **Changes**: Create `validate_webhook_url(url: str) -> bool` in base.py that resolves the hostname and rejects private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8, 169.254.0.0/16, ::1, fc00::/7). Apply validation in all channel `send()` methods before making HTTP requests. Add tests covering all private ranges and valid public URLs.
- **Effort**: 3-4 hours
- **Impact**: Prevents server-side request forgery across all 6 notification channels. Critical for any deployment that accepts user-configured webhook URLs.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 3 |
| Documentation | 8 |
| Test Coverage | 3 |
| Contribution Potential | 9 |

**Summary**: Edict has strong documentation, creative architecture, and clean project organization. The main gaps are security (no auth, path traversal, SSRF, permissive CORS) and test coverage (near zero for the backend API). These gaps represent high-impact contribution opportunities - the project would benefit enormously from even basic auth middleware and API endpoint tests.
