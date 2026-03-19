# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered personalized learning assistant developed by HKUDS (Hong Kong University). It provides document-based Q&A with RAG (Retrieval Augmented Generation), interactive learning visualization, knowledge reinforcement, deep research, and idea generation through a multi-agent architecture. Users upload documents to knowledge bases and interact with specialized AI agents (chat, co-writer, guide, ideagen, question, research, solver) to learn from the material.

**Tech Stack:**
- **Backend:** Python 3.10+, FastAPI 0.100+, Uvicorn, Pydantic 2.0+
- **Frontend:** Next.js 16.1.1, React 19, TypeScript, TailwindCSS 3.4
- **LLM Integration:** OpenAI, Anthropic, DeepSeek, Groq, OpenRouter
- **RAG:** LlamaIndex, RagAnything, Docling
- **Infrastructure:** Docker (multi-stage), docker-compose
- **Testing:** Pytest (backend), Playwright (frontend E2E)
- **Linting/Security:** Ruff, Black, MyPy, Bandit, detect-secrets, ESLint, Prettier

**Maturity:** Growing (v0.6.0, active development, good CI/CD, bilingual docs, but limited test coverage and some production-readiness gaps)

---

## Code Quality Assessment

### Architecture and Organization
Excellent modular structure. Clear separation: `src/agents/` (7 agent modules with unified `BaseAgent`), `src/services/` (LLM, embedding, RAG, search, TTS), `src/api/` (FastAPI routers), `src/core/`, `src/tools/`. Factory pattern for LLM/RAG providers. Frontend follows standard Next.js conventions with proper context providers and i18n support. ~222 Python files, ~99 TypeScript files.

**Issues:** Path resolution (`Path(__file__).parent.parent...`) duplicated across agents. Configuration loading patterns inconsistent across modules. `research_pipeline.py` is 1,309 lines -- too large for a single file.

### Error Handling Patterns
Custom exception hierarchy (`DeepTutorError`, `ConfigurationError`, `ServiceError`, `LLMServiceError`). Pydantic-based output validation in solver agent. Tenacity retry decorators for parse errors.

**Issues:** 105 instances of bare `except Exception` across 47 files. Silent error suppression (`except Exception: pass`) in token tracking. Some API routers use `traceback.print_exc()` instead of structured logging. Exception details leaked in HTTP responses.

### Test Coverage
Test directory exists with: prompt parity tests, config manager tests, JSON utility tests, RAG pipeline integration tests. Frontend has Playwright E2E tests. CI runs pytest across Python 3.10-3.12.

**Issues:** Very sparse -- only ~7 test files for 222+ source files. No unit tests for any agent logic, API routers, LLM services, or knowledge base operations. Pre-commit config excludes `tests/`, `agents/`, and `rag/` from linting.

### Documentation Quality
Strong README with multilingual support (9 languages). VitePress documentation site with English and Chinese guides. CONTRIBUTING.md with clear guidelines. Config README. Good module-level docstrings in source code.

**Issues:** No API documentation (OpenAPI/Swagger auto-generated but not customized). Some complex orchestration methods lack step-by-step comments.

### Dependency Health
Dependencies pinned with minimum versions. Includes `bandit` and `safety` for security scanning. Modern, well-maintained packages. `numpy <2.0` constraint may become stale.

---

## Security Findings

### Critical

**1. SSL Certificate Verification Disabled Globally**
- **File:** `scripts/generate_roster.py:19-21`
- SSL verification completely disabled for GitHub API calls (`ssl.CERT_NONE`, `check_hostname = False`)
- Enables MITM attacks on contributor data fetching

**2. SSL Verification Bypass via Environment Variable**
- **File:** `src/services/llm/providers/open_ai.py:22-23`
- `DISABLE_SSL_VERIFY` env var creates `httpx.AsyncClient(verify=False)` for all OpenAI API calls
- Production deployments could unknowingly disable TLS

### High

**3. Wildcard CORS with Credentials**
- **File:** `src/api/main.py:162-168`
- `allow_origins=["*"]` combined with `allow_credentials=True` allows any website to make authenticated cross-origin requests
- Comment says "In production, replace" but no enforcement mechanism exists

**4. No Authentication on Any API Endpoint**
- **Files:** All routers in `src/api/routers/`
- Zero auth checks on knowledge base CRUD, question solving, research, settings modification
- Any network-accessible caller has full access

**5. API Key Partially Logged**
- **File:** `src/agents/co_writer/narrator_agent.py:131`
- Logs first 8 and last 4 characters of API keys -- enough to narrow down key identity

### Medium

**6. Pickle Deserialization of Embeddings**
- **File:** `src/services/rag/components/retrievers/dense.py:138`
- `pickle.load()` used for embedding cache -- safe only if files are from trusted source
- No integrity verification on pickle files

**7. Jinja2 Without Autoescape**
- **File:** `src/services/search/consolidation.py:187`
- `Environment(autoescape=autoescape)` with bandit suppression `# nosec B701`
- Risk if user-supplied content reaches template rendering

### Low

**8. Exception Details in HTTP Responses**
- **Files:** Multiple API routers
- `str(e)` returned directly in error responses, leaking internal paths/state

**9. Hardcoded Dummy API Keys**
- **Files:** `src/api/routers/system.py:108`, `src/api/routers/config.py:268,306`
- `"sk-no-key-required"` used as fallback -- not a real credential but poor practice

---

## Contribution Opportunities

### Bugs

1. **File:** `src/agents/solve/utils/json_utils.py` + `src/agents/research/utils/json_utils.py`
   - **Issue:** Duplicate JSON extraction utilities with subtle behavioral differences (solve version handles triple-quoted strings, research version doesn't)
   - **Fix:** Consolidate into `src/utils/json_parser.py` with combined features
   - **Effort:** small
   - **PR-worthy:** high

2. **File:** `src/agents/research/research_pipeline.py` (1,309 lines)
   - **Issue:** God-class handling orchestration, agent coordination, and memory management
   - **Fix:** Extract loop coordination, memory management, and agent dispatch into separate classes
   - **Effort:** large
   - **PR-worthy:** medium

### Security Fixes

3. **File:** `src/api/main.py:162-168`
   - **Issue:** Wildcard CORS with credentials enabled
   - **Fix:** Read allowed origins from config/env, default to frontend URL only. Remove `allow_credentials=True` when using wildcard.
   - **Effort:** trivial
   - **PR-worthy:** high

4. **File:** `scripts/generate_roster.py:19-21`
   - **Issue:** SSL verification disabled
   - **Fix:** Remove SSL bypass, use default certificate verification
   - **Effort:** trivial
   - **PR-worthy:** high

5. **File:** `src/services/llm/providers/open_ai.py:22-23`
   - **Issue:** `DISABLE_SSL_VERIFY` env var bypasses TLS
   - **Fix:** Remove the feature entirely, or gate behind `DEBUG` mode with prominent warnings
   - **Effort:** trivial
   - **PR-worthy:** high

6. **File:** All routers in `src/api/routers/`
   - **Issue:** No authentication on any endpoint
   - **Fix:** Add API key middleware or JWT-based auth with configurable toggle
   - **Effort:** medium
   - **PR-worthy:** high

### Missing Tests

7. **File:** `src/agents/` (all agent modules)
   - **Issue:** Zero unit tests for agent logic (BaseAgent, MainSolver, research agents, etc.)
   - **Fix:** Add unit tests with mocked LLM responses for each agent's `process()` method
   - **Effort:** large
   - **PR-worthy:** high

8. **File:** `src/api/routers/` (all routers)
   - **Issue:** No API endpoint tests
   - **Fix:** Add FastAPI TestClient tests for each router
   - **Effort:** medium
   - **PR-worthy:** high

9. **File:** `src/services/llm/` (LLM factory and providers)
   - **Issue:** No tests for LLM provider selection, configuration, or error handling
   - **Fix:** Add unit tests with mocked API clients
   - **Effort:** medium
   - **PR-worthy:** medium

### Documentation Gaps

10. **File:** `src/api/` (API layer)
    - **Issue:** No API documentation beyond auto-generated OpenAPI schema
    - **Fix:** Add docstrings to all router functions with request/response examples
    - **Effort:** medium
    - **PR-worthy:** medium

11. **File:** Root level
    - **Issue:** No SECURITY.md or security policy
    - **Fix:** Add SECURITY.md with vulnerability reporting process
    - **Effort:** trivial
    - **PR-worthy:** medium

### Code Improvements

12. **File:** 47 files with bare `except Exception`
    - **Issue:** 105 instances of overly broad exception handling, some silent
    - **Fix:** Replace with specific exception types, add proper logging
    - **Effort:** medium
    - **PR-worthy:** medium

13. **File:** Multiple agent files
    - **Issue:** `print()` statements mixed with logger calls
    - **Fix:** Replace all `print()` with appropriate `logger.info/debug/warning` calls
    - **Effort:** small
    - **PR-worthy:** medium

14. **File:** Multiple agent `__init__` files
    - **Issue:** Path resolution `Path(__file__).parent.parent.parent.parent` duplicated everywhere
    - **Fix:** Centralize in `src/core/paths.py` with a `get_project_root()` function
    - **Effort:** small
    - **PR-worthy:** medium

### Feature Ideas

15. **API Authentication Middleware**
    - Add configurable auth (API key header or JWT) as FastAPI middleware
    - **Effort:** medium
    - **PR-worthy:** high

16. **Rate Limiting**
    - Add rate limiting to API endpoints to prevent abuse of LLM-backed endpoints
    - **Effort:** small
    - **PR-worthy:** medium

---

## Draft PRs

### PR 1: Fix Critical CORS and SSL Security Issues

- **PR Title:** `fix: restrict CORS origins and remove SSL verification bypasses`
- **Branch:** `fix/cors-ssl-security`
- **Files:**
  - `src/api/main.py` (CORS configuration)
  - `scripts/generate_roster.py` (SSL bypass removal)
  - `src/services/llm/providers/open_ai.py` (DISABLE_SSL_VERIFY removal)
  - `src/agents/co_writer/narrator_agent.py` (API key logging)
- **Changes:**
  - Replace `allow_origins=["*"]` with env-configurable `CORS_ORIGINS` defaulting to `["http://localhost:3782"]`
  - Remove `allow_credentials=True` or restrict to specific origins
  - Remove SSL verification bypass in `generate_roster.py` (delete lines 19-21, use default SSL context)
  - Remove `DISABLE_SSL_VERIFY` env var support in `open_ai.py`
  - Replace API key partial logging with fully masked `"sk-***"` format
- **Effort:** 1-2 hours
- **Impact:** Closes 4 security findings (2 critical, 1 high, 1 medium). Essential for any network-exposed deployment.

### PR 2: Consolidate Duplicate JSON Utilities

- **PR Title:** `refactor: consolidate duplicate json_utils into shared module`
- **Branch:** `refactor/shared-json-utils`
- **Files:**
  - `src/utils/json_parser.py` (enhanced shared implementation)
  - `src/agents/solve/utils/json_utils.py` (replace with import)
  - `src/agents/research/utils/json_utils.py` (replace with import)
  - All files importing from either json_utils
- **Changes:**
  - Merge both implementations into `src/utils/json_parser.py`, keeping the triple-quoted string handling from solve and ensuring both modules' edge cases are covered
  - Update all imports to use `from src.utils.json_parser import extract_json_from_text`
  - Add unit tests for the consolidated module
- **Effort:** 2-3 hours
- **Impact:** Eliminates code duplication, prevents behavioral divergence bugs, establishes pattern for future shared utilities.

### PR 3: Add API Router Test Suite

- **PR Title:** `test: add FastAPI router test suite with TestClient`
- **Branch:** `test/api-router-tests`
- **Files:**
  - `tests/api/__init__.py` (new)
  - `tests/api/test_system_router.py` (new)
  - `tests/api/test_knowledge_router.py` (new)
  - `tests/api/test_config_router.py` (new)
  - `tests/conftest.py` (add FastAPI test fixtures)
- **Changes:**
  - Create test fixtures for FastAPI TestClient with mocked service dependencies
  - Test all system endpoints (health, version, status)
  - Test knowledge base CRUD operations with mocked storage
  - Test config endpoints with validation edge cases
  - Test error response formats
- **Effort:** 4-6 hours
- **Impact:** Covers the most exposed attack surface (API layer) with regression tests. Currently zero API tests exist for ~15+ endpoints.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 4 |
| Documentation | 7 |
| Test Coverage | 2 |
| Contribution Potential | 9 |

**Summary:** DeepTutor is a well-architected, feature-rich project with excellent modular design and documentation. Its main weaknesses are critically low test coverage (~7 test files for 222+ source files), several high-severity security gaps (no auth, wildcard CORS, SSL bypasses), and code duplication in utility modules. The project's growing maturity and active development make it highly amenable to impactful contributions, especially around security hardening and test infrastructure.
