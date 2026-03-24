The entire codebase was committed in one go. Now I have everything needed for the report.

# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered personalized learning assistant built by the HKUDS lab (University of Hong Kong). It provides multiple learning modules -- problem solving, research assistance, guided learning, question generation, co-writing with TTS, idea generation, and notebook management -- all backed by multi-provider LLM integration (OpenAI, Anthropic, DeepSeek, Ollama, etc.) and RAG-based knowledge bases using LlamaIndex/RagAnything. The system features a Python/FastAPI backend with WebSocket streaming and a Next.js 16 / React 19 frontend with i18n support (English/Chinese).

**Tech stack:** Python 3.10+, FastAPI, Next.js 16, React 19, TypeScript, Tailwind CSS, LlamaIndex, Docker (multi-arch), Playwright (E2E), pytest

**Maturity:** Early/Growing -- v0.5.0, AGPL-3.0 licensed, 56 commits (54 automated roster updates), single initial code drop, active GitHub community presence.

---

## Code Quality Assessment

### Architecture and Organization
Well-structured modular architecture with clear separation of concerns:
- `src/agents/` -- Domain-specific agent modules (solve, research, guide, question, co_writer, ideagen)
- `src/services/` -- Service layer (LLM, embedding, RAG, search, TTS)
- `src/api/routers/` -- 15 FastAPI routers with clear endpoint grouping
- `src/tools/` -- Tool implementations (RAG, web search, code execution, paper search)
- `src/config/` -- Centralized configuration with Pydantic schemas
- `src/core/errors.py` -- Custom exception hierarchy

The agent pattern is consistent: each module has a coordinator/manager, sub-agents, memory management, and utilities. The frontend follows Next.js App Router conventions with proper context/hooks separation.

**Strength:** Config drift detection on startup validates `agents.yaml` vs `main.yaml` consistency.
**Weakness:** Some code duplication across agent modules (session managers, JSON utils).

### Error Handling
- Custom exception hierarchy: `DeepTutorError` -> `ConfigurationError`, `ValidationError`, `ServiceError`, `LLMServiceError`
- LLM retry with exponential backoff (configurable via `src/config/settings.py`)
- **Issue:** Many routers expose raw exception strings via `HTTPException(status_code=500, detail=str(e))` -- information leakage risk.

### Test Coverage
- **6 actual test files** covering ~100 source files = ~6% structural coverage
- Tests exist for: prompt parity, prompt management, config management, JSON utils, RAG pipelines, pipeline integration
- **No tests for:** API routers, agents, tools (code_executor, web_search), services (LLM, embedding, TTS), WebSocket endpoints
- CI runs tests on Python 3.10/3.11/3.12 via GitHub Actions
- Playwright configured for E2E but no test files found in `web/`

### Documentation
- Comprehensive README (56KB) with multi-language support (EN, CN, JP, KR, DE, FR, RU, AR, ES, PT)
- `CONTRIBUTING.md` present
- Config directory has its own README
- VitePress documentation site in `docs/`
- Code-level documentation is sparse -- minimal docstrings and inline comments

### Dependency Health
- Generally recent versions (FastAPI >=0.100, React 19, Next.js 16.1.1)
- `safety<3.0.0` pinned to v2.x with comment explaining why
- `numpy<2.0.0` constraint may cause conflicts with newer packages
- Some dependencies unpinned: `raganything`, `docling`, `llama-index` -- risky for reproducibility
- Dependabot configured for automated updates

---

## Security Findings

### Critical

**1. CORS Wildcard with Credentials (Critical)**
- **File:** `src/api/main.py:162-168`
- `allow_origins=["*"]` combined with `allow_credentials=True` allows any origin to make authenticated cross-origin requests. This is a well-known dangerous misconfiguration.
- **Impact:** CSRF, credential theft, unauthorized API access from malicious sites.

**2. No Authentication on Any Endpoint (Critical)**
- **File:** All files in `src/api/routers/`
- Zero authentication middleware. All API endpoints and WebSocket connections are publicly accessible. No JWT, OAuth, API key, or session validation.
- **Impact:** Anyone with network access can use all features, access all sessions, and consume LLM API credits.

### High

**3. WebSocket Session Enumeration (High)**
- **File:** `src/api/routers/chat.py:104`, `src/api/routers/solve.py:152`
- Session IDs are accepted from client without ownership validation. Users can access any session by providing its ID.
- **Impact:** Data leakage across users in multi-user deployments.

**4. Code Execution Without Mandatory Import Restrictions (High)**
- **File:** `src/tools/code_executor.py:252`
- `ImportGuard` only validates imports when `allowed_imports` is explicitly provided. If `None`, all imports are permitted including `os`, `subprocess`, `socket`.
- **Impact:** Arbitrary code execution if code_executor is exposed without import restrictions.

**5. ZipSlip Vulnerability (High)**
- **File:** `src/api/routers/knowledge.py:175-178` (or related extraction code)
- ZIP extraction uses `extractall()` without path traversal checks. TAR extraction has proper `safe_members()` filtering but ZIP does not.
- **Impact:** Malicious ZIP can write files outside the extraction directory.

### Medium

**6. No Rate Limiting (Medium)**
- No application-level rate limiting on any endpoint. WebSocket connections, file uploads, and LLM-consuming operations are all unlimited.
- **Impact:** DoS via resource exhaustion, LLM API cost amplification.

**7. Docker Container Runs as Root (Medium)**
- **File:** `Dockerfile`
- No `USER` directive -- container processes run as root.
- **Impact:** Container escape would grant root access to host.

**8. Incomplete Input Validation on WebSocket Messages (Medium)**
- **File:** `src/api/routers/chat.py:120-128`, `src/api/routers/solve.py:150-151`
- No message size limits, no type validation, no knowledge base name validation.
- **Impact:** Memory exhaustion, unexpected behavior.

### Low

**9. Internal Error Detail Exposure (Low)**
- Multiple routers return `str(e)` in HTTP 500 responses, leaking stack traces and internal paths.
- **Impact:** Information disclosure aiding further attacks.

**10. SSL Verification Bypass Option (Low)**
- **File:** `.env.example` -- `DISABLE_SSL_VERIFY` environment variable exists.
- **Impact:** If enabled, MITM attacks become possible on LLM API calls.

### Info

**11. Secret Detection Baseline Established (Info)**
- `.secrets.baseline` file with detect-secrets configured. Good practice.

**12. Pre-commit Hooks Configured (Info)**
- Ruff, Black, MyPy, Bandit configured. Security linting is active.

---

## Contribution Opportunities

### Bugs

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `src/api/routers/knowledge.py` ~L175 | ZipSlip: ZIP extraction lacks path traversal check (TAR has it) | Add `is_within_directory()` check for ZIP members before extraction | trivial | high |
| 2 | `src/tools/code_executor.py:252` | ImportGuard bypassed when `allowed_imports=None` | Default to safe whitelist (`math`, `json`, `re`, etc.) when None | small | high |

### Security Fixes

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `src/api/main.py:162-168` | CORS wildcard + credentials | Load allowed origins from env var, remove credentials with wildcard | trivial | high |
| 2 | `Dockerfile` | Running as root | Add `RUN useradd -m appuser` + `USER appuser` | trivial | high |
| 3 | Multiple routers | Raw exception strings in 500 responses | Catch, log internally, return generic message | small | medium |
| 4 | `src/api/main.py` | No rate limiting | Add `slowapi` middleware with sensible defaults | medium | high |

### Missing Tests

| # | File/Module | Issue | Fix | Effort | PR-worthy |
|---|-------------|-------|-----|--------|-----------|
| 1 | `src/api/routers/` | Zero router tests | Add pytest + httpx AsyncClient tests for all REST endpoints | large | high |
| 2 | `src/tools/code_executor.py` | No tests for sandboxing | Test ImportGuard, workspace isolation, timeout, path traversal | medium | high |
| 3 | `src/services/llm/` | No LLM service tests | Add unit tests with mocked providers | medium | medium |
| 4 | `web/` | No Playwright E2E tests | Add basic smoke tests for each page route | medium | medium |
| 5 | `src/utils/document_validator.py` | No validation tests | Test path traversal, filename sanitization, size limits | small | medium |

### Documentation Gaps

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `src/` | Minimal docstrings across Python modules | Add docstrings to public classes/methods in agents and services | medium | medium |
| 2 | `config/` | Agent configuration schema undocumented | Document all YAML config fields with types and defaults | small | medium |
| 3 | `src/api/` | No API documentation / OpenAPI descriptions | Add FastAPI route descriptions and response models | medium | high |

### Code Improvements

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `src/agents/solve/session_manager.py` + `src/agents/chat/session_manager.py` | Duplicated session management logic | Extract shared `BaseSessionManager` class | small | medium |
| 2 | `src/agents/solve/utils/json_utils.py` + `src/agents/research/utils/json_utils.py` | Duplicated JSON utility code | Consolidate into `src/utils/json_utils.py` | small | medium |
| 3 | WebSocket routers | Repeated WebSocket accept/error patterns | Extract shared WebSocket handler middleware | medium | low |

### Feature Ideas

| # | Description | Effort | PR-worthy |
|---|-------------|--------|-----------|
| 1 | Add optional API key authentication middleware (toggle via env var) | medium | high |
| 2 | Add WebSocket connection authentication via token query parameter | small | high |
| 3 | Add structured logging with correlation IDs for request tracing | medium | medium |
| 4 | Add health check endpoint returning dependency status (LLM, embedding, KB) | small | medium |

---

## Draft PRs

### PR 1: Fix CORS misconfiguration and add non-root Docker user

**PR Title:** `fix: harden CORS config and run Docker container as non-root`
**Branch:** `fix/cors-and-docker-security`
**Files:**
- `src/api/main.py` (lines 162-168)
- `Dockerfile` (add USER directive before final CMD)

**Changes:**
1. In `src/api/main.py`: Replace `allow_origins=["*"]` with `os.getenv("CORS_ORIGINS", "http://localhost:3782").split(",")`. When credentials are enabled, wildcard must not be used. Add `CORS_ORIGINS` to `.env.example`.
2. In `Dockerfile`: Before `EXPOSE` line, add:
   ```dockerfile
   RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
   USER appuser
   ```
3. Update `.env.example` with `CORS_ORIGINS=http://localhost:3782` documentation.

**Effort:** ~30 minutes
**Impact:** Eliminates the two most easily exploitable deployment security issues. Critical for anyone deploying beyond localhost.

---

### PR 2: Fix ZipSlip vulnerability and enforce code executor import restrictions

**PR Title:** `fix: prevent ZipSlip path traversal and enforce code execution import whitelist`
**Branch:** `fix/zipslip-and-code-executor-safety`
**Files:**
- `src/api/routers/knowledge.py` (ZIP extraction function)
- `src/utils/document_validator.py` (add ZIP-safe extraction utility)
- `src/tools/code_executor.py` (line ~252, ImportGuard class)

**Changes:**
1. Add `safe_zip_extract()` function to `document_validator.py` that validates each ZIP member path with `is_within_directory()` before extraction, mirroring the existing TAR safety logic.
2. Replace `zip_file.extractall(extract_dir)` with the safe version.
3. In `code_executor.py`, change `ImportGuard` to use a default safe whitelist (`["math", "json", "re", "datetime", "collections", "itertools", "functools", "typing", "string", "decimal", "fractions", "statistics", "random"]`) when `allowed_imports` is `None`.
4. Add tests for both fixes in `tests/`.

**Effort:** ~1-2 hours
**Impact:** Closes two high-severity vulnerabilities -- arbitrary file write via ZIP and potential code execution bypass.

---

### PR 3: Add API router test suite

**PR Title:** `test: add comprehensive API router test suite`
**Branch:** `feat/api-router-tests`
**Files:**
- `tests/api/__init__.py` (new)
- `tests/api/test_knowledge.py` (new)
- `tests/api/test_system.py` (new)
- `tests/api/test_config.py` (new)
- `tests/api/test_dashboard.py` (new)
- `tests/conftest.py` (shared fixtures)

**Changes:**
1. Create `tests/conftest.py` with FastAPI `TestClient` fixture, mock LLM config, and temp knowledge base directory.
2. Add tests for all REST endpoints (non-WebSocket): system status, config CRUD, knowledge base CRUD (create, list, delete, upload), dashboard data, settings.
3. Test error cases: invalid KB names, missing files, oversized uploads.
4. Add `httpx` and `pytest-asyncio` to test dependencies if not present.

**Effort:** ~4-6 hours
**Impact:** Brings test coverage from ~6% to ~25%+ for the API layer, catches regressions in the most user-facing code, and establishes patterns for future test contributions.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 3 |
| Documentation | 6 |
| Test Coverage | 2 |
| Contribution Potential | 9 |

**Summary:** DeepTutor has solid architecture and clean modular design for an early-stage academic project. The main weaknesses are security (no auth, CORS misconfiguration, no rate limiting) and extremely low test coverage (6 test files for ~100+ source files). The contribution surface is large and accessible -- security hardening and test additions would have outsized impact.
