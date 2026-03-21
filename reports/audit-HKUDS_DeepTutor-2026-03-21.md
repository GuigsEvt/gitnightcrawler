Now I have enough data. Let me compile the report.

---

# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered personalized learning assistant built by HKUDS (Hong Kong University Data Science). It provides massive document knowledge Q&A with RAG, interactive learning visualization with Mermaid diagrams, knowledge reinforcement via question generation, and deep research/idea generation. Users upload textbooks and papers, then interact with a multi-agent system that uses RAG, web search, and code execution to deliver step-by-step solutions with citations.

**Tech stack:** Python 3.10+ (FastAPI, Pydantic, uvicorn), Next.js 16, React 19, TypeScript 5, TailwindCSS 3.4, WebSockets, LlamaIndex, RAGAnything, Docling, Mermaid, Docker + supervisord.

**Maturity:** Growing (v0.6.0 released Jan 2026, active development since Dec 2025, ~200 Python files, ~100 TS/TSX files, 7 releases in < 1 month).

---

## Code Quality Assessment

### Architecture and Organization
Well-structured modular Python backend with clean separation: `src/agents/` (multi-agent system with solve, chat, research, guide, question, ideagen), `src/api/routers/` (14 FastAPI routers), `src/services/` (LLM, config, RAG), `src/tools/` (code execution, web search), `src/knowledge/` (knowledge base management). Frontend follows Next.js App Router conventions with context providers, components, and type definitions. Configuration uses YAML + environment variables with Pydantic validation. **Score: 7/10**

### Error Handling Patterns
Mixed quality. Good: custom error utilities (`error_utils.py`), WebSocket disconnect handling, asyncio cancellation guards. Bad: raw `Exception` catches returning `str(e)` to clients (information leakage), silent fallbacks masking config errors (e.g., `"sk-no-key-required"` fallback). **Score: 5/10**

### Test Coverage
Minimal. Only 6 test files found in `tests/`: `test_json_utils.py`, `test_config_manager.py`, `test_prompt_manager.py`, `test_prompt_parity.py`, `test_pipeline_integration.py`, `test_rag_pipelines.py`. No tests for API routes, agents, WebSocket endpoints, or frontend. One Playwright e2e audit file exists but appears limited. **Score: 2/10**

### Documentation Quality
Good README with multi-language support (8 languages), clear setup instructions, Docker deployment guide. Config README exists. Inline docstrings present on most Python modules and key functions. Missing: API documentation (no OpenAPI descriptions on most endpoints), architecture decision records, contribution guide. **Score: 6/10**

### Dependency Health
Generally well-maintained. Pre-commit hooks configured with bandit and safety. No obviously vulnerable pinned versions. `numpy<2.0.0` constraint is intentional for compatibility. `safety<3.0.0` pin documented as avoiding a broken release. All major frameworks are recent versions. **Score: 7/10**

---

## Security Findings

### Critical

**1. CORS Wildcard with Credentials** `src/api/main.py:162-168`
```python
allow_origins=["*"], allow_credentials=True
```
Wildcard CORS + credentials allows any origin to make authenticated cross-origin requests. This is a textbook CSRF enabler. Per the Fetch spec, browsers should reject this combination, but implementation varies.

### High

**2. Mermaid XSS via `securityLevel: "loose"` + `dangerouslySetInnerHTML`** `web/components/Mermaid.tsx:16,90`
Mermaid's "loose" security level allows embedded HTML/scripts in diagrams. Combined with `dangerouslySetInnerHTML`, any user-supplied diagram content can execute arbitrary JavaScript. Since diagram content comes from LLM outputs and user inputs, this is exploitable.

**3. SSL Verification Bypass** `src/services/llm/providers/open_ai.py`
`DISABLE_SSL_VERIFY` env var creates an `httpx.AsyncClient(verify=False)`, enabling MITM attacks on LLM API traffic carrying API keys.

**4. Unauthenticated WebSocket Endpoints** `src/api/routers/solve.py:97-99`
WebSocket `/solve` endpoint accepts any connection without auth. Attackers can trigger expensive LLM operations at will.

### Medium

**5. Error Information Leakage** `src/api/routers/config.py:280-281`
Full exception messages returned to clients: `f"Connection failed: {str(e)}"`. Can expose internal paths, hostnames, API details.

**6. Silent API Key Fallback** `src/api/routers/config.py:268,306`
Missing API keys silently fall back to `"sk-no-key-required"` instead of raising errors. Masks configuration issues.

**7. No Rate Limiting**
No rate limiting middleware on any endpoint. File upload, code execution, and LLM endpoints are all vulnerable to abuse.

**8. Docker Runs as Root** `Dockerfile`
No `USER` directive in the production stage. Container processes run as root.

**9. Static File Serving Without Content-Type Restrictions** `src/api/main.py:187`
User-generated files served directly via `StaticFiles`. No content-type whitelist.

### Low

**10. No API Authentication**
The entire API is unauthenticated -- designed for local/personal use but risky if exposed.

**11. Rust Install from Internet During Build** `Dockerfile:71`
`curl | sh` pattern for Rust installation in Docker build. Supply chain risk if compromised.

---

## Contribution Opportunities

### Bugs

**1. CORS + Credentials Conflict**
- File: `src/api/main.py:162-168`
- Issue: `allow_origins=["*"]` with `allow_credentials=True` is invalid per spec. Browsers may ignore or behave unpredictably.
- Fix: Replace `"*"` with configurable origin list from env var (e.g., `CORS_ALLOWED_ORIGINS`).
- Effort: trivial
- PR-worthy: high

**2. Silent `sk-no-key-required` Fallback**
- File: `src/api/routers/config.py:268,306,403,444,534,565`
- Issue: Missing API keys don't produce errors, leading to confusing failures downstream.
- Fix: Return `{"success": False, "message": "API key is required"}` when key is empty.
- Effort: small
- PR-worthy: medium

### Security Fixes

**3. Mermaid XSS Vulnerability**
- File: `web/components/Mermaid.tsx:16,90`
- Issue: `securityLevel: "loose"` + `dangerouslySetInnerHTML` enables XSS.
- Fix: Change to `securityLevel: "strict"`, use ref-based rendering instead of innerHTML.
- Effort: small
- PR-worthy: high

**4. Error Message Leakage**
- File: `src/api/routers/config.py:280-281,320-321` (and similar in other routers)
- Issue: Raw exception messages returned to client.
- Fix: Log full error server-side, return generic "Connection test failed" to client.
- Effort: small
- PR-worthy: medium

**5. Add Rate Limiting**
- File: `src/api/main.py` (add middleware)
- Issue: No rate limiting on any endpoint.
- Fix: Add `slowapi` or custom rate limiting middleware, especially on `/solve`, `/knowledge`, and `/config` endpoints.
- Effort: medium
- PR-worthy: high

### Missing Tests

**6. API Route Tests**
- File: `tests/` (new files needed)
- Issue: Zero test coverage on all 14 API routers.
- Fix: Add pytest tests with `httpx.AsyncClient` for each router. Priority: `/solve`, `/knowledge`, `/config`.
- Effort: large
- PR-worthy: high

**7. Frontend Component Tests**
- File: `web/` (new test files)
- Issue: No unit tests for React components.
- Fix: Add Vitest/React Testing Library tests for critical components (Mermaid, MarkdownRenderer, Sidebar).
- Effort: large
- PR-worthy: medium

### Documentation Gaps

**8. API Endpoint Documentation**
- File: All routers in `src/api/routers/`
- Issue: FastAPI routes lack `description`, `response_model`, and `summary` parameters for OpenAPI docs.
- Fix: Add Pydantic response models and descriptions to each endpoint.
- Effort: medium
- PR-worthy: medium

**9. CONTRIBUTING.md Missing**
- File: root (new file)
- Issue: No contribution guide despite active community (Discord, WeChat, Feishu).
- Fix: Add CONTRIBUTING.md with setup instructions, coding standards, PR guidelines.
- Effort: small
- PR-worthy: medium

### Code Improvements

**10. Non-Root Docker User**
- File: `Dockerfile:84-100`
- Issue: Production container runs as root.
- Fix: Add `RUN useradd -m deeptutor` and `USER deeptutor` before ENTRYPOINT.
- Effort: trivial
- PR-worthy: medium

**11. Configurable CORS Origins**
- File: `src/api/main.py:161-168`
- Issue: Hardcoded wildcard CORS.
- Fix: Read `CORS_ALLOWED_ORIGINS` from env, split by comma, default to `["http://localhost:3782"]`.
- Effort: trivial
- PR-worthy: high

### Feature Ideas

**12. WebSocket Authentication**
- File: `src/api/routers/solve.py`, `knowledge.py`, `guide.py`
- Issue: WebSocket endpoints are completely open.
- Fix: Add token-based auth via query param or first message validation.
- Effort: medium
- PR-worthy: high

**13. Request/Response Audit Logging**
- File: `src/api/main.py` (new middleware)
- Issue: No audit trail for sensitive operations (config changes, file uploads).
- Fix: Add middleware that logs request method, path, user-agent, and response status.
- Effort: small
- PR-worthy: low

---

## Draft PRs

### PR 1: Fix CORS Misconfiguration and Mermaid XSS

- **PR Title:** `fix: harden CORS policy and fix Mermaid XSS vulnerability`
- **Branch:** `fix/cors-and-mermaid-xss`
- **Files:**
  - `src/api/main.py` (lines 161-168)
  - `web/components/Mermaid.tsx` (lines 13-31, 86-93)
- **Changes:**
  - Replace `allow_origins=["*"]` with `os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:3782").split(",")`
  - Change Mermaid `securityLevel` from `"loose"` to `"strict"`
  - Replace `dangerouslySetInnerHTML` with ref-based rendering: use `useRef` + `useEffect` to set `containerRef.current.innerHTML = svg` after DOMPurify sanitization
- **Effort:** ~1 hour
- **Impact:** Closes the two most exploitable vulnerabilities in the codebase. CORS fix prevents cross-origin credential theft; Mermaid fix prevents stored XSS via crafted diagrams.

### PR 2: Add Rate Limiting and Error Sanitization

- **PR Title:** `fix: add rate limiting middleware and sanitize error responses`
- **Branch:** `fix/rate-limiting-and-error-sanitization`
- **Files:**
  - `src/api/main.py` (add middleware)
  - `src/api/routers/config.py` (all `except Exception` blocks)
  - `src/api/routers/knowledge.py` (error handlers)
  - `requirements.txt` (add `slowapi`)
- **Changes:**
  - Add `slowapi` rate limiter: 10 req/min on `/config/*/test`, 5 req/min on `/solve`, 3 req/min on knowledge upload
  - Replace all `f"Connection failed: {str(e)}"` patterns with generic messages while logging full error server-side
  - Remove `"sk-no-key-required"` fallback; return explicit error when API key is missing
- **Effort:** ~2 hours
- **Impact:** Prevents DoS via expensive LLM/upload operations. Stops internal error details from leaking to clients.

### PR 3: Add API Route Test Suite

- **PR Title:** `test: add pytest suite for core API routers`
- **Branch:** `feat/api-route-tests`
- **Files:**
  - `tests/api/__init__.py` (new)
  - `tests/api/test_config_router.py` (new)
  - `tests/api/test_solve_router.py` (new)
  - `tests/api/test_knowledge_router.py` (new)
  - `tests/api/conftest.py` (new -- shared fixtures)
- **Changes:**
  - Create test fixtures with `httpx.AsyncClient` and `ASGITransport` for FastAPI test client
  - Test config CRUD operations, validation errors, connection test edge cases
  - Test solve session lifecycle (create, list, get, delete)
  - Test knowledge base creation and file upload validation
  - Mock LLM calls with `unittest.mock.AsyncMock`
- **Effort:** ~4-6 hours
- **Impact:** Currently at ~0% API test coverage. This establishes a test foundation for the most critical backend functionality, catching regressions in config management, solve orchestration, and knowledge base operations.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 3 |
| Documentation | 6 |
| Test Coverage | 2 |
| Contribution Potential | 9 |
