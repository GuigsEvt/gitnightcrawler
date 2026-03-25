# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is a multi-agent AI tutoring system built on RAG (Retrieval-Augmented Generation) that provides specialized agents for problem solving, question generation, research, guided learning, co-writing, and idea generation. It supports multiple LLM backends (OpenAI, Anthropic Claude, DeepSeek, Ollama) and includes a full-stack application with a Python/FastAPI backend and React/Next.js 16 frontend. The system manages knowledge bases with embeddings and integrates web search, text-to-speech, and code execution capabilities.

**Tech Stack:** Python 3.10+ (FastAPI, LlamaIndex, LightRAG), TypeScript (React 19, Next.js 16, Tailwind CSS), Docker multi-stage builds, Playwright for E2E.

**Maturity:** Growing — ~81K LOC, active development with CI/CD, but limited test coverage and several security gaps indicate pre-production stage.

---

## Code Quality Assessment

### Architecture and Organization
Well-organized modular architecture with clear separation of concerns:
- `src/agents/` — domain-specific agents (solve, research, guide, co_writer, ideagen, question, chat)
- `src/api/` — FastAPI routers (13 route modules)
- `src/services/` — pluggable services (LLM, embedding, RAG, search, TTS, config)
- `src/tools/` — utility tools (code executor, web search, paper search, RAG)
- `web/` — Next.js frontend with i18n support (EN/ZH)

The agent architecture follows a well-documented dual-loop pattern (analysis loop + solve loop) with factory patterns for LLM/RAG providers. Configuration-driven agent parameters via `config/agents.yaml`.

### Error Handling Patterns
Mixed quality. Some modules have proper structured error handling, but API routers frequently use broad `except Exception as e` with `traceback.print_exc()` and leak error details to clients (e.g., `src/api/routers/research.py:77-79`). The LLM factory has well-documented retry mechanisms with exponential backoff.

### Test Coverage
**Poor.** 9 test files covering ~4% of source modules. CI workflow explicitly ignores `tests/agents/` and allows test failures (`|| echo "⚠️"`). Zero API endpoint tests, zero tool tests, zero frontend unit tests. Only RAG pipeline and core config/prompt managers have meaningful coverage.

### Documentation Quality
README is comprehensive with badges, quick start, and feature descriptions. `CONTRIBUTING.md` is well-structured with security and code quality requirements. Inline docstrings are selective — excellent in core services (`src/services/llm/factory.py`, `src/api/main.py`) but absent in most agent and tool implementations. No OpenAPI/Swagger endpoint reference despite using FastAPI.

### Dependency Health
80 packages in `requirements.txt` with loose version pinning (`>=` operators). Dependabot configured. `.secrets.baseline` for secret detection exists. Pre-commit hooks configured with Black, Ruff, Bandit, and detect-secrets.

---

## Security Findings

### Critical

**1. Overly Permissive CORS Configuration**
- **File:** `src/api/main.py:162-168`
- `allow_origins=["*"]` combined with `allow_credentials=True` violates CORS security standards, enabling CSRF attacks and credential leakage from any origin.

### High

**2. Unsafe Deserialization with pickle.load()**
- **File:** `src/services/rag/components/retrievers/dense.py:137-138`
- `pickle.load()` on embeddings files enables arbitrary code execution if files are tampered with. No integrity validation.

**3. Disabled SSL Verification Option**
- **File:** `src/services/llm/providers/open_ai.py:22-23`
- `DISABLE_SSL_VERIFY` environment variable allows disabling SSL cert verification, enabling MITM attacks.

**4. API Key Pollution in os.environ**
- **File:** `src/services/llm/config.py:47-53`, `src/services/llm/client.py:60-65`
- API keys copied into `os.environ` at runtime, visible to any process reading `/proc/[pid]/environ`.

### Medium

**5. Error Information Leakage**
- **Files:** Multiple API routers (`src/api/routers/research.py:77-79`, others)
- `traceback.print_exc()` and returning `str(e)` to clients exposes internal implementation details.

**6. Unvalidated User-Supplied File Paths**
- **File:** `src/api/routers/knowledge.py:86-89`
- `LinkFolderRequest.folder_path` is user-supplied without path traversal validation.

**7. Shell=True in Subprocess**
- **File:** `scripts/install_all.py:509-515`
- `subprocess.run("npm install", shell=True)` — less critical since it's a setup script, not runtime.

**8. Docker Container Runs as Root**
- **File:** `Dockerfile`
- No `USER` directive; container runs as uid 0.

### Low

**9. Unpinned Dependency Versions**
- **File:** `requirements.txt`
- Most packages use `>=` without upper bounds, risking breaking changes or vulnerable versions.

**10. Missing Input Validation on API Endpoints**
- **Files:** Various routers in `src/api/routers/`
- Pydantic provides basic type validation but no field-level business logic validators.

---

## Contribution Opportunities

### Bugs

**1. CI Test Failures Silently Ignored**
- File: `.github/workflows/tests.yml:139`
- Issue: `|| echo "⚠️ Some tests failed or no tests found"` allows test failures without blocking merges
- Fix: Remove the fallback; let pytest exit code propagate
- Effort: trivial
- PR-worthy: high

**2. Agent Tests Excluded from CI**
- File: `.github/workflows/tests.yml:139`
- Issue: `--ignore=tests/agents/` removes the only agent-level tests from CI
- Fix: Remove the ignore flag; ensure agent tests pass
- Effort: small
- PR-worthy: high

### Security Fixes

**3. CORS Wildcard with Credentials**
- File: `src/api/main.py:162-168`
- Issue: `allow_origins=["*"]` with `allow_credentials=True`
- Fix: Load allowed origins from env var `CORS_ORIGINS`, default to frontend URL
- Effort: trivial
- PR-worthy: high

**4. Replace pickle.load with Safe Alternative**
- File: `src/services/rag/components/retrievers/dense.py:137-138`
- Issue: Arbitrary code execution via pickle deserialization
- Fix: Use `numpy.load(allow_pickle=False)` or JSON/msgpack serialization
- Effort: small
- PR-worthy: high

**5. Remove DISABLE_SSL_VERIFY Option**
- File: `src/services/llm/providers/open_ai.py:22-23`
- Issue: Allows disabling SSL in production
- Fix: Remove the env var check; always enforce SSL
- Effort: trivial
- PR-worthy: high

**6. Sanitize Error Responses**
- Files: `src/api/routers/research.py:77-79` and similar routers
- Issue: Stack traces and exception messages returned to clients
- Fix: Return generic error messages; log details server-side only
- Effort: small
- PR-worthy: medium

**7. Add Non-Root User to Docker**
- File: `Dockerfile`
- Issue: Container runs as root
- Fix: Add `RUN useradd -m -u 1000 appuser` and `USER appuser`
- Effort: small
- PR-worthy: medium

**8. Validate folder_path in Knowledge Router**
- File: `src/api/routers/knowledge.py:86-89`
- Issue: User-supplied path without traversal validation
- Fix: Add `Path.resolve()` + `is_relative_to()` check against allowed base dirs
- Effort: small
- PR-worthy: medium

### Missing Tests

**9. API Router Tests**
- Files: `src/api/routers/*.py` (10+ routers, 0 tests)
- Issue: No endpoint tests exist
- Fix: Add FastAPI TestClient tests for each router
- Effort: large
- PR-worthy: high

**10. Tool Unit Tests**
- Files: `src/tools/*.py` (11 tools, 0 unit tests)
- Issue: Code executor, web search, paper search untested
- Fix: Add unit tests with mocked dependencies
- Effort: medium
- PR-worthy: high

**11. LLM Provider Tests**
- Files: `src/services/llm/providers/*.py`
- Issue: No tests for provider factory or individual providers
- Fix: Add unit tests with mocked HTTP clients
- Effort: medium
- PR-worthy: medium

**12. Frontend Component Tests**
- Files: `web/components/*.tsx`, `web/app/**/*.tsx`
- Issue: Zero component tests (only 1 E2E audit file)
- Fix: Add Vitest/Jest tests for critical components
- Effort: large
- PR-worthy: medium

### Documentation Gaps

**13. Generate OpenAPI Endpoint Reference**
- File: `src/api/main.py`
- Issue: FastAPI has built-in OpenAPI generation but no endpoint docstrings
- Fix: Add docstrings to all router functions; link to `/docs` endpoint
- Effort: medium
- PR-worthy: medium

**14. Add Testing Guidelines to CONTRIBUTING.md**
- File: `CONTRIBUTING.md`
- Issue: No guidance on writing tests, running tests, or test requirements
- Fix: Add testing section with examples and coverage expectations
- Effort: small
- PR-worthy: medium

### Code Improvements

**15. Pin Dependency Versions**
- File: `requirements.txt`
- Issue: `>=` without upper bounds allows breaking changes
- Fix: Use `>=X.Y,<X+1.0` or exact pinning with lock file
- Effort: small
- PR-worthy: medium

**16. Centralize Error Handling in API**
- Files: `src/api/routers/*.py`
- Issue: Each router has duplicate try/except patterns
- Fix: Add FastAPI exception handlers in `src/api/main.py`
- Effort: medium
- PR-worthy: medium

### Feature Ideas

**17. Add Health Check Endpoint with Dependency Status**
- File: `src/api/routers/system.py`
- Issue: Current `/status` doesn't check LLM/embedding/RAG connectivity
- Fix: Add `/health` endpoint that validates all service dependencies
- Effort: medium
- PR-worthy: low

**18. Rate Limiting on API Endpoints**
- File: `src/api/main.py`
- Issue: No rate limiting; vulnerable to abuse
- Fix: Add `slowapi` or similar middleware
- Effort: small
- PR-worthy: low

---

## Draft PRs

### PR 1: Security Hardening — CORS, SSL, Pickle

- **PR Title:** `fix(security): harden CORS config, remove SSL bypass, replace unsafe pickle`
- **Branch:** `fix/security-hardening`
- **Files:**
  - `src/api/main.py` — Replace `allow_origins=["*"]` with env-configurable origins
  - `src/services/llm/providers/open_ai.py` — Remove `DISABLE_SSL_VERIFY` logic
  - `src/services/rag/components/retrievers/dense.py` — Replace `pickle.load()` with `numpy.load()` or JSON
  - `.env.example` — Add `CORS_ORIGINS` variable, remove `DISABLE_SSL_VERIFY`
- **Changes:** Configure CORS origins from `CORS_ORIGINS` env var (comma-separated list, no wildcard default). Remove the SSL verification bypass entirely. Replace pickle deserialization with numpy or JSON-based safe loading. Update .env.example accordingly.
- **Effort:** 1-2 hours
- **Impact:** Eliminates the 3 most critical security vulnerabilities. Prevents CSRF, MITM, and RCE attack vectors.

### PR 2: Fix CI Test Pipeline

- **PR Title:** `fix(ci): enable agent tests and fail on test errors`
- **Branch:** `fix/ci-test-pipeline`
- **Files:**
  - `.github/workflows/tests.yml` — Remove `--ignore=tests/agents/` and `|| echo` fallback
- **Changes:** Remove the `--ignore=tests/agents/` flag from the pytest command so all tests run in CI. Remove the `|| echo "⚠️"` fallback that swallows test failures. Ensure pytest exit code propagates to fail the workflow on test errors.
- **Effort:** 30 minutes (plus fixing any currently-broken tests)
- **Impact:** Prevents broken code from being merged silently. Makes the existing test suite actually enforceable.

### PR 3: API Error Handling and Docker Security

- **PR Title:** `fix(api): sanitize error responses and add non-root Docker user`
- **Branch:** `fix/error-handling-docker`
- **Files:**
  - `src/api/routers/research.py` — Replace `str(e)` responses with generic messages
  - `src/api/routers/solve.py` — Same
  - `src/api/routers/guide.py` — Same
  - `src/api/routers/knowledge.py` — Add path validation for `folder_path`
  - `Dockerfile` — Add non-root user
- **Changes:** Replace all `return {"error": str(e)}` patterns with generic "Internal server error" messages while preserving server-side logging. Add `Path.resolve()` + `is_relative_to()` validation on user-supplied folder paths. Add `RUN useradd -m -u 1000 appuser` and `USER appuser` to Dockerfile.
- **Effort:** 2-3 hours
- **Impact:** Prevents information leakage to attackers, mitigates path traversal, and reduces container compromise blast radius.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 4 |
| Documentation | 6 |
| Test Coverage | 2 |
| Contribution Potential | 9 |
