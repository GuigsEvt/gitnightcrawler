Now I have enough information. Let me produce the report.

# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered educational platform that combines multiple AI agents (solver, chat, research, question generation, idea generation, collaborative writing, tutorial guide) with a RAG pipeline for learning assistance. It ingests documents into knowledge bases, provides multi-provider LLM support (10+ providers including OpenAI, Anthropic, Ollama, LM Studio), and streams responses via WebSocket. The backend is Python/FastAPI with 13 API routers; the frontend is a Next.js 16 / React 19 / TypeScript application with internationalization (EN/ZH).

**Tech stack:** Python 3.10+, FastAPI, Pydantic 2, Uvicorn, WebSockets, Next.js 16, React 19, TypeScript 5, TailwindCSS, llama-index, LightRAG, Docling, Docker + Docker Compose, Playwright (E2E), pytest, pre-commit (Ruff, Black, Bandit, detect-secrets).

**Maturity:** Growing -- v0.5.0 per pyproject.toml, actively developed, comprehensive feature set but limited test coverage.

---

## Code Quality Assessment

### Architecture and Organization
Strong modular architecture. Backend cleanly separated into `agents/`, `api/routers/`, `services/`, `tools/`, `knowledge/`, `core/`. Services use factory patterns (LLM provider, embedding adapters). Frontend uses Next.js App Router with context providers, custom hooks, and component directories. Configuration is YAML-based with environment variable overrides. Custom exception hierarchy in `src/core/errors.py` with provider-specific error mapping and retry logic. Score: **8/10**.

### Error Handling
Well-structured custom exception hierarchy (`DeepTutorError` -> `ConfigurationError`, `ServiceError`, `LLMServiceError`, etc.). LLM-specific exceptions with automatic retry and exponential backoff. WebSocket endpoints handle disconnects gracefully. REST endpoints use `HTTPException`. Structured logging throughout via `get_logger()`.

### Test Coverage
Only **9 test files** covering prompt management, config loading, JSON utilities, and RAG pipelines. No coverage reporting configured. No unit tests for agents, API routers, tools, or most services. E2E test file exists for frontend (`compliance-and-ux.audit.ts`). Score: **3/10**.

### Documentation Quality
Excellent -- 56KB README with badges, architecture overview, quick start. Bilingual docs (EN + ZH) covering setup, Docker, troubleshooting. `CONTRIBUTING.md` present. Config README. Inline docstrings on major functions. Score: **9/10**.

### Dependency Health
80 Python packages, all pinned with `>=` minimum versions. numpy pinned `<2.0.0` for compat. Pre-commit hooks include Bandit security linter and detect-secrets. Frontend uses current versions (Next.js 16, React 19). No obviously vulnerable packages. No `pip-audit` in CI yet.

---

## Security Findings

### Critical
None.

### High

**H1: CORS wildcard with credentials** -- `src/api/main.py:162-168`
`allow_origins=["*"]` combined with `allow_credentials=True` is a dangerous combination. While browsers block `Access-Control-Allow-Origin: *` with credentials, this configuration signals intent to be permissive and some proxy configurations may not enforce this correctly.

**H2: Mermaid XSS via `securityLevel: "loose"` + `dangerouslySetInnerHTML`** -- `web/components/Mermaid.tsx:16,90`
Mermaid is initialized with `securityLevel: "loose"` and SVG output is rendered via `dangerouslySetInnerHTML`. If LLM-generated or user-supplied Mermaid chart strings contain malicious payloads, this enables XSS. Should use `securityLevel: "strict"` or sanitize SVG output.

### Medium

**M1: Arbitrary code execution** -- `src/tools/code_executor.py:299-309`
Executes user/LLM-generated Python code via `subprocess.run`. Has mitigations (workspace sandboxing, import guards, timeouts) but the attack surface is significant. No process-level sandboxing (no containers, no seccomp).

**M2: Pickle deserialization** -- `src/services/rag/components/retrievers/dense.py:138`
`pickle.load()` on embeddings files. If an attacker can write to the knowledge base directory, this enables arbitrary code execution. Mitigated by file being internally generated, but still a risk if the data directory is shared.

**M3: Static file mount exposes entire user data directory** -- `src/api/main.py:187`
`/api/outputs` serves the entire `data/user/` directory without access controls. Could expose logs, session data, or other artifacts.

**M4: No authentication on any endpoint** -- all routers
No auth middleware, no API keys, no session tokens. Any network-accessible deployment is fully open. Design appears intentional for local use but dangerous if exposed.

**M5: File upload without size limits** -- `src/api/routers/knowledge.py`
File uploads for knowledge bases use `UploadFile` without explicit max size configuration. `DocumentValidator` exists but size enforcement unclear at the FastAPI layer.

### Low

**L1: `sys.path.insert(0, ...)` in module scope** -- `src/api/routers/knowledge.py:38`
Modifies `sys.path` at import time. Can cause import shadowing. Minor.

**L2: `DISABLE_SSL_VERIFY` option** -- `.env.example:115`
Allows disabling SSL verification. Documented as "not recommended for production" but the flag exists.

**L3: Debug logging in production config** -- `config/main.yaml`
Default `logging.level: DEBUG` could leak sensitive information in production logs.

### Info

- Pre-commit hooks include Bandit and detect-secrets -- good security hygiene.
- `.secrets.baseline` file maintained for secret scanning.
- Bandit skips B603 (subprocess) -- intentional and documented in pyproject.toml.
- `ast.literal_eval` used instead of `eval()` -- correct pattern.

---

## Contribution Opportunities

### Bugs

1. **File:** `web/components/Mermaid.tsx:16`
   **Issue:** `securityLevel: "loose"` combined with `dangerouslySetInnerHTML` enables XSS from LLM-generated mermaid content.
   **Fix:** Change to `securityLevel: "strict"` or `"sandbox"`. Alternatively, sanitize SVG with DOMPurify before setting innerHTML.
   **Effort:** trivial
   **PR-worthy:** high

2. **File:** `src/api/routers/knowledge.py:38`
   **Issue:** `sys.path.insert(0, ...)` in module scope can cause import shadowing.
   **Fix:** Remove -- the project uses `src.` module paths which should already be on the path via pyproject.toml.
   **Effort:** trivial
   **PR-worthy:** low

### Security Fixes

3. **File:** `src/api/main.py:162-168`
   **Issue:** CORS wildcard `allow_origins=["*"]` with `allow_credentials=True`.
   **Fix:** Read allowed origins from environment variable, default to `["http://localhost:3782"]`.
   **Effort:** small
   **PR-worthy:** high

4. **File:** `src/api/main.py:187`
   **Issue:** Entire `data/user/` directory served as static files without access control.
   **Fix:** Serve only specific subdirectories (e.g., `data/user/solve/*/artifacts/`) or add a route that validates artifact access.
   **Effort:** small
   **PR-worthy:** high

5. **File:** `src/services/rag/components/retrievers/dense.py:138`
   **Issue:** `pickle.load()` on embeddings files -- unsafe deserialization.
   **Fix:** Use `numpy.load()` with `.npy` format for embeddings, or use `safetensors`/`json` serialization.
   **Effort:** medium
   **PR-worthy:** medium

### Missing Tests

6. **File:** `src/api/routers/` (all routers)
   **Issue:** Zero unit/integration tests for any API router.
   **Fix:** Add pytest fixtures with `httpx.AsyncClient` / `TestClient` for each router.
   **Effort:** large
   **PR-worthy:** high

7. **File:** `src/tools/code_executor.py`
   **Issue:** No tests for code executor sandbox, import guards, or timeout enforcement.
   **Fix:** Add tests verifying sandboxing, blocked imports, timeout behavior.
   **Effort:** medium
   **PR-worthy:** high

8. **File:** `pyproject.toml`
   **Issue:** No coverage reporting configured.
   **Fix:** Add `pytest-cov` to requirements, add `--cov=src --cov-report=html` to pytest addopts.
   **Effort:** trivial
   **PR-worthy:** medium

### Documentation Gaps

9. **File:** `src/api/` (all routers)
   **Issue:** No OpenAPI descriptions on endpoints (FastAPI generates docs but they lack descriptions).
   **Fix:** Add `summary=` and `description=` parameters to route decorators.
   **Effort:** medium
   **PR-worthy:** medium

### Code Improvements

10. **File:** `src/api/main.py:162-168`
    **Issue:** CORS config is hardcoded -- should be configurable.
    **Fix:** Read from `CORS_ORIGINS` environment variable with safe defaults.
    **Effort:** trivial
    **PR-worthy:** high

11. **File:** `config/main.yaml` -- `logging.level: DEBUG`
    **Issue:** Default debug logging in production.
    **Fix:** Default to `INFO`, allow override via `LOG_LEVEL` env var.
    **Effort:** trivial
    **PR-worthy:** low

### Feature Ideas

12. **Optional API key authentication middleware**
    **Issue:** All endpoints are unauthenticated.
    **Fix:** Add optional `API_KEY` env var with FastAPI dependency that validates `Authorization: Bearer <key>` header when set.
    **Effort:** small
    **PR-worthy:** high

13. **CI/CD pipeline with GitHub Actions**
    **Issue:** No CI/CD configuration.
    **Fix:** Add `.github/workflows/ci.yml` with lint, type-check, test, and security scan steps.
    **Effort:** medium
    **PR-worthy:** high

---

## Draft PRs

### PR 1: Mermaid XSS fix
- **PR Title:** `fix: set mermaid securityLevel to strict to prevent XSS`
- **Branch:** `fix/mermaid-security-level`
- **Files:** `web/components/Mermaid.tsx`
- **Changes:** Change `securityLevel: "loose"` to `securityLevel: "strict"` on line 16. Optionally add DOMPurify sanitization before `dangerouslySetInnerHTML` on line 90. This prevents LLM-generated mermaid diagrams from injecting scripts into the page.
- **Effort:** 15 minutes
- **Impact:** Closes an XSS vector where untrusted mermaid chart content (from LLM responses or user input) could execute arbitrary JavaScript in the browser.

### PR 2: CORS hardening + configurable origins
- **PR Title:** `fix: make CORS origins configurable, restrict default`
- **Branch:** `fix/cors-origins`
- **Files:** `src/api/main.py`, `.env.example`
- **Changes:** Replace `allow_origins=["*"]` with `allow_origins=os.environ.get("CORS_ORIGINS", "http://localhost:3782").split(",")`. Add `CORS_ORIGINS` to `.env.example` with documentation. This prevents unauthorized cross-origin requests in production deployments.
- **Effort:** 20 minutes
- **Impact:** Eliminates the most visible security misconfiguration. Essential for any internet-facing deployment.

### PR 3: Restrict static file mount scope
- **PR Title:** `fix: limit static file serving to artifact directories only`
- **Branch:** `fix/restrict-static-mount`
- **Files:** `src/api/main.py`
- **Changes:** Instead of mounting `data/user/` wholesale, mount specific subdirectories (`data/user/solve`, `data/user/question`) or implement a route handler that validates the requested path is within allowed artifact patterns (e.g., `solve_*/artifacts/*`). This prevents accidental exposure of log files, session data, or other sensitive content in the user data directory.
- **Effort:** 30 minutes
- **Impact:** Prevents information disclosure from the data directory, which may contain logs, session history, and generated content.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 5 |
| Documentation | 9 |
| Test Coverage | 3 |
| Contribution Potential | 9 |
