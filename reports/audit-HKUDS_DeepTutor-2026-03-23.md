# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered personalized learning assistant built by HKU Data Science Lab. It provides multi-agent educational capabilities including problem solving (dual-loop analysis+solve architecture), topic research with literature review, interactive guided learning, question generation, idea generation, collaborative writing, and conversational AI -- all backed by Retrieval-Augmented Generation (RAG) over user-uploaded knowledge bases. The system processes PDFs and documents into knowledge graphs, then uses LLM agents to provide contextualized, citation-backed answers.

**Tech Stack:**
- Backend: Python 3.10+, FastAPI 0.100+, Pydantic 2.0+, LightRAG, LlamaIndex
- Frontend: React 19, Next.js 16, TypeScript 5, TailwindCSS 3.4
- LLM Providers: OpenAI, Anthropic, DeepSeek, Ollama, LM Studio
- Infrastructure: Docker, GitHub Actions CI/CD, Playwright E2E
- Lines: ~222 Python files, ~100 TS/TSX files

**Maturity: Growing** -- v0.5.0 backend / v0.2.0 frontend. Well-architected with enterprise patterns but thin test coverage and no authentication layer.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 8/10** -- Clean layered architecture with clear separation: `api/` (FastAPI routers) -> `agents/` (50+ agents inheriting BaseAgent) -> `services/` (LLM, RAG, embedding, search) -> `tools/` (code executor, web search) -> `utils/`. Uses Factory, Strategy, Template Method, Circuit Breaker, and Builder patterns. Lazy loading for heavy dependencies (LightRAG, LlamaIndex). Multi-layer config (env vars > YAML > Pydantic BaseSettings). 12 API routers with 40+ endpoints plus WebSocket streaming.

### Error Handling
**Score: 7/10** -- Custom exception hierarchy (`DeepTutorError` -> `ConfigurationError`, `ServiceError`, `LLMServiceError`, etc.). Provider error mapping in `src/services/llm/error_mapping.py`. Retry with exponential backoff (configurable). Circuit breaker for cascading failure prevention. Graceful degradation on non-critical failures. Configuration drift detection at startup.

### Test Coverage
**Score: 3/10** -- Tests exist but are minimal:
- `tests/core/test_config_manager.py`, `test_prompt_manager.py`, `test_prompt_parity.py`
- `tests/services/test_rag_pipelines.py`, `test_pipeline_integration.py`
- `tests/agents/solve/utils/test_json_utils.py`
- `web/tests/e2e/` (Playwright)
- CI runs pytest on Python 3.10/3.11/3.12 but only basic import checks + these few tests
- No coverage for: API routes, agent logic, LLM service, search providers, knowledge base operations, file upload validation

### Documentation
**Score: 7/10** -- README is comprehensive with multilingual support (9 languages). CONTRIBUTING.md is thorough. Config README exists. Google-style docstrings in ~67% of files. VitePress docs site with guides. Some critical paths have 80+ line docstrings. Missing: API documentation (no OpenAPI customization), architecture diagrams in repo.

### Dependency Health
**Score: 7/10** -- Modern versions throughout. Dependabot configured. Pre-commit hooks with Ruff, Prettier, detect-secrets, Bandit, MyPy. `safety` for vulnerability scanning. No suspicious packages. `requirements.txt` uses minimum version pins (`>=`) which is good for compatibility but could lead to breakage without a lockfile.

---

## Security Findings

### Critical
None found.

### High
| ID | Finding | Location | Details |
|----|---------|----------|---------|
| H1 | **No authentication/authorization** | `src/api/main.py` | No auth middleware, JWT, OAuth, or API key validation on any endpoint. Anyone with network access can upload files, execute code, and access all knowledge bases. |
| H2 | **Wildcard CORS** | `src/api/main.py:162-168` | `allow_origins=["*"]` with `allow_credentials=True`. Comment acknowledges production fix needed but this ships as default. |

### Medium
| ID | Finding | Location | Details |
|----|---------|----------|---------|
| M1 | **Code execution tool** | `src/tools/code_executor.py` | Executes arbitrary Python via subprocess. Has safeguards (AST import guard, path traversal protection, timeout) but no sandboxing (no seccomp, no containers). Combined with H1, any network user can execute code. |
| M2 | **Pickle deserialization** | `src/services/rag/components/retrievers/dense.py:138` | `pickle.load()` on embedding files. Files are system-generated but if an attacker can write to `/data/knowledge_bases/`, they get RCE. |
| M3 | **No rate limiting** | `src/api/main.py` | No rate limiting on any endpoint. Code execution, file upload, and LLM calls are all unbounded. |

### Low
| ID | Finding | Location | Details |
|----|---------|----------|---------|
| L1 | **SSL verification bypass** | `src/services/llm/providers/open_ai.py:22-28` | `DISABLE_SSL_VERIFY` env var disables TLS verification. Defaults to false, documented, but no runtime warning logged. |
| L2 | **Static file serving of user data** | `src/api/main.py:187` | `/api/outputs/` serves user-generated content. No auth check on static files. |
| L3 | **No CSRF protection** | `src/api/main.py` | No CSRF tokens. Low risk for API-only backend but relevant if cookies/sessions added. |

### Info
| ID | Finding | Location | Details |
|----|---------|----------|---------|
| I1 | No lockfile for Python deps | `requirements.txt` | Uses `>=` pins without `requirements.lock`. Builds may be non-reproducible. |
| I2 | `.env.example` contains pattern hints | `.env.example` | `sk-xxx`, `pplx-xxx` patterns -- not secrets but could confuse automated scanners. |

---

## Contribution Opportunities

### Bugs

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `src/api/main.py:162-168` | CORS `allow_origins=["*"]` with `allow_credentials=True` is invalid per spec (browsers ignore credentials with wildcard origin) | Read `ALLOWED_ORIGINS` from env var, default to `["http://localhost:3000"]` | trivial | high |
| 2 | `src/services/llm/providers/open_ai.py:22-28` | SSL bypass logs no warning | Add `logger.warning("SSL verification disabled")` when env var is set | trivial | low |

### Security Fixes

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `src/api/main.py` | No authentication layer | Add optional API key middleware (`X-API-Key` header) with env var `API_KEY`. When set, all endpoints require the key. | medium | high |
| 2 | `src/api/main.py` | No rate limiting | Add `slowapi` or custom middleware: 10 req/min on `/api/v1/solve`, 5/min on code execution, 20/min on uploads | small | high |
| 3 | `src/services/rag/components/retrievers/dense.py:138` | Pickle deserialization | Replace `pickle.load()` with `numpy.load()` for embedding arrays, or add `RestrictedUnpickler` | small | medium |
| 4 | `src/tools/code_executor.py` | No resource limits on code execution | Add `resource.setrlimit()` for memory (256MB) and CPU time (30s) on Unix | small | medium |

### Missing Tests

| # | File/Module | Issue | Fix | Effort | PR-worthy |
|---|-------------|-------|-----|--------|-----------|
| 1 | `src/api/routers/knowledge.py` | No tests for file upload validation, size limits, filename sanitization | Add pytest tests with `TestClient` for upload endpoint edge cases | medium | high |
| 2 | `src/utils/document_validator.py` | No tests for MIME validation, extension checking, filename sanitization | Unit tests for `sanitize_filename()`, `validate_file_type()` | small | high |
| 3 | `src/services/llm/` | No tests for LLM factory, provider routing, retry logic | Mock-based tests for factory routing and error mapping | medium | medium |
| 4 | `src/agents/base_agent.py` | No tests for BaseAgent initialization, config loading | Test two-phase init, parameter loading from agents.yaml | small | medium |
| 5 | `src/tools/code_executor.py` | No tests for import guard, path traversal protection | Test blocked imports, path escape attempts, timeout enforcement | medium | high |

### Documentation Gaps

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `src/api/main.py` | No OpenAPI customization (title, description, version) | Add FastAPI metadata, tag descriptions for Swagger UI | trivial | medium |
| 2 | Root | No SECURITY.md | Add security policy with responsible disclosure process | trivial | medium |
| 3 | Root | No deployment guide for production | Document CORS restriction, auth setup, rate limiting, SSL | small | high |

### Code Improvements

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `requirements.txt` | No lockfile, `>=` pins risk breakage | Add `pip-compile` generated `requirements.lock` or switch to `uv.lock` | small | medium |
| 2 | `src/services/rag/components/retrievers/dense.py` | Type hint coverage ~67% | Add type hints to remaining modules, especially agent implementations | medium | low |
| 3 | `src/api/main.py:187` | Static file serving with no access control | Serve user outputs through an authenticated endpoint instead of `StaticFiles` | medium | medium |

### Feature Ideas

| # | Idea | Impact | Effort |
|---|------|--------|--------|
| 1 | Optional API key authentication via middleware | Enables safe network deployment | medium |
| 2 | Per-user knowledge base isolation | Multi-tenancy support | large |
| 3 | OpenTelemetry integration | Observability for production | medium |
| 4 | WebSocket authentication | Secure real-time streaming | small |

---

## Draft PRs

### PR 1: Add optional API key authentication and fix CORS

- **PR Title:** `feat: add optional API key auth and restrict CORS origins`
- **Branch:** `feat/api-key-auth`
- **Files:**
  - `src/api/main.py` -- Add auth middleware, fix CORS
  - `src/api/middleware/__init__.py` (new) -- API key validation middleware
  - `.env.example` -- Add `API_KEY` and `ALLOWED_ORIGINS` vars
  - `tests/api/test_auth_middleware.py` (new) -- Tests
- **Changes:**
  - Create `APIKeyMiddleware` that checks `X-API-Key` header against `API_KEY` env var. When `API_KEY` is unset, auth is disabled (backward compatible). Return 401 on mismatch.
  - Replace `allow_origins=["*"]` with `os.getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(",")`.
  - Add tests for auth enabled/disabled/invalid scenarios.
- **Effort:** 2-3 hours
- **Impact:** Fixes the two highest-severity findings (H1, H2). Enables safe deployment beyond localhost without breaking existing local usage.

### PR 2: Add rate limiting to critical endpoints

- **PR Title:** `feat: add rate limiting for code execution and file uploads`
- **Branch:** `feat/rate-limiting`
- **Files:**
  - `src/api/main.py` -- Add slowapi limiter
  - `src/api/routers/knowledge.py` -- Rate limit upload endpoints
  - `src/api/routers/solve.py` -- Rate limit solve/code execution
  - `requirements.txt` -- Add `slowapi`
- **Changes:**
  - Install `slowapi`. Configure global limiter with in-memory backend.
  - Add `@limiter.limit("5/minute")` to code execution endpoint.
  - Add `@limiter.limit("10/minute")` to file upload endpoint.
  - Add `@limiter.limit("30/minute")` to solve/research endpoints.
  - Return 429 with `Retry-After` header on limit exceeded.
- **Effort:** 1-2 hours
- **Impact:** Prevents resource exhaustion and abuse of expensive operations (LLM calls, code execution, file processing).

### PR 3: Add tests for file upload validation and code executor security

- **PR Title:** `test: add security-critical tests for upload validation and code executor`
- **Branch:** `test/security-critical-coverage`
- **Files:**
  - `tests/utils/test_document_validator.py` (new)
  - `tests/tools/test_code_executor.py` (new)
  - `tests/api/test_knowledge_upload.py` (new)
- **Changes:**
  - `test_document_validator.py`: Test `sanitize_filename()` with path traversal (`../../etc/passwd`), null bytes, unicode, overlong names. Test `validate_file_type()` with spoofed extensions, double extensions, empty files.
  - `test_code_executor.py`: Test `ImportGuard.validate()` blocks `os`, `subprocess`, `shutil`. Test `_ensure_within_allowed_roots()` blocks path traversal. Test timeout enforcement kills long-running code.
  - `test_knowledge_upload.py`: Integration tests with `TestClient` for oversized files (>100MB), invalid MIME types, concurrent uploads.
- **Effort:** 3-4 hours
- **Impact:** Validates the security controls that protect against file-based attacks and code execution escapes. Critical for confidence in the security posture.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 4 |
| Documentation | 7 |
| Test Coverage | 3 |
| Contribution Potential | 9 |

**Summary:** DeepTutor is a well-architected, pattern-driven educational AI platform with clean separation of concerns, comprehensive logging, and thoughtful configuration management. The main gaps are **security** (no auth, no rate limiting, permissive CORS) and **test coverage** (minimal tests for a 300+ file codebase). These are high-impact contribution opportunities -- the architecture is solid enough that adding auth, rate limiting, and tests would be straightforward and dramatically improve production-readiness.
