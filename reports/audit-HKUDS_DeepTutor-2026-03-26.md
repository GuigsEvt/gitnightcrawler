I have enough data. Let me compile the full audit report.

---

# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered personalized learning assistant built by HKUDS (Hong Kong University of Data Science). It provides multi-agent tutoring capabilities including research assistance, problem solving, guided learning, idea generation, co-writing, and question answering -- all powered by RAG (Retrieval-Augmented Generation) over user-uploaded knowledge bases (PDFs, documents, folders). The system supports multiple LLM providers (OpenAI, Anthropic, DeepSeek, Groq, Ollama, vLLM, LM Studio) and features full internationalization (English/Chinese).

**Tech Stack:**
- **Backend:** Python 3.10+, FastAPI 0.100+, Uvicorn, WebSockets
- **Frontend:** TypeScript, React 19, Next.js 16, TailwindCSS 3.4
- **RAG:** LlamaIndex, raganything, LightRAG, Docling
- **LLM:** OpenAI, Anthropic, Azure OpenAI, DeepSeek, Groq, Ollama, vLLM
- **Infrastructure:** Docker (multi-stage), Supervisor, GitHub Actions CI/CD
- **Docs:** VitePress

**Maturity:** Growing -- v0.5.0, ~58 commits visible in shallow clone, active automated updates (roster images), well-structured but test coverage is thin. The project has comprehensive documentation, CI/CD, and Docker support, indicating it's past early stage but not yet mature.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 7/10** -- Well-organized with clear separation of concerns. The `src/` directory has clean layers: `agents/` (8 specialized agents), `api/` (FastAPI routers), `services/` (LLM, config, RAG, embedding, TTS), `tools/`, `knowledge/`, `utils/`. The frontend follows Next.js app router conventions with `components/`, `context/`, `hooks/`, `i18n/`, `types/`. Agent prompts are externalized as YAML files with i18n support (EN/ZH).

**Concerns:** Config loading has 3+ implementations scattered across modules. Logger setup is repetitive. Error response formats vary across routers.

### Error Handling Patterns
**Score: 5/10** -- Mixed quality. The `src/services/llm/error_mapping.py` provides excellent structured error classification (LLMAuthenticationError, LLMRateLimitError, ProviderContextWindowError). However, there are 358 bare `except Exception` blocks and 14 `except: pass` silent failures across the codebase. API routers use inconsistent error response formats.

### Test Coverage
**Score: 3/10** -- 9 Python test files for 222 source files (~4% file ratio, estimated <15% line coverage). Existing tests are well-written (config, prompt management, RAG pipelines), but entire subsystems are untested: all 8 agents, all API routers, all frontend components. The single E2E Playwright test (`compliance-and-ux.audit.ts`) covers only accessibility basics (4 tests). No coverage reporting configured.

### Documentation Quality
**Score: 7/10** -- Good README (1,565 lines) with architecture overview, quick start, FAQ. VitePress docs site with English/Chinese guides. `CONTRIBUTING.md` covers pre-commit setup and conventional commits. `config/README.md` documents YAML configuration. However, no API documentation (OpenAPI/Swagger is auto-generated but no custom docs), no architecture decision records.

### Dependency Health
**Score: 6/10** -- 80 Python dependencies with minimum version pins (e.g., `openai>=1.30.0`) but no upper bounds or lockfile. Dependabot is configured. `safety` pinned to `<3.0.0` with note that "3.0.0 is broken." No `pip-audit` in CI (disabled due to Windows Unicode issues). Frontend uses `package-lock.json` which is better. `--legacy-peer-deps` in Docker build suggests dependency conflicts.

---

## Security Findings

### HIGH: CORS Wildcard with Credentials
- **File:** `src/api/main.py:162-168`
- **Issue:** `allow_origins=["*"]` combined with `allow_credentials=True` allows any origin to make authenticated cross-origin requests
- **Impact:** CSRF, credential theft, data exfiltration in production deployments
- **Fix:** Use environment variable for allowed origins, default to specific domain

### HIGH: XSS via Mermaid with Loose Security
- **File:** `web/components/Mermaid.tsx:16,20,90`
- **Issue:** `securityLevel: "loose"` + `htmlLabels: true` + `dangerouslySetInnerHTML={{ __html: svg }}` allows HTML/JS injection via diagram labels
- **Impact:** Stored XSS if diagram content comes from untrusted sources (e.g., AI-generated or user-provided)
- **Fix:** Set `securityLevel: "strict"`, `htmlLabels: false`

### MEDIUM: XSS via rehype-raw in Markdown
- **Files:** `web/components/CoMarkerEditor.tsx:1686`, `web/components/CoWriterEditor.tsx`
- **Issue:** `rehype-raw` plugin passes raw HTML through React Markdown without sanitization
- **Impact:** XSS if markdown content includes user-controlled HTML
- **Fix:** Remove `rehypeRaw` or sanitize with DOMPurify

### MEDIUM: Pickle Deserialization
- **Files:** `src/services/rag/components/retrievers/dense.py:138`, `src/services/rag/components/indexers/vector.py:133`
- **Issue:** `pickle.load()` on cached embedding files without integrity validation
- **Impact:** Arbitrary code execution if cache files are tampered with
- **Fix:** Use safer serialization (JSON/msgpack) or add HMAC integrity checks

### MEDIUM: subprocess shell=True
- **File:** `scripts/install_all.py:515`
- **Issue:** `subprocess.run("npm install", shell=True)` -- development script but bad practice
- **Fix:** Use `subprocess.run(["npm", "install"], shell=False)`

### LOW: Missing Input Validation on kb_name
- **File:** `src/api/routers/knowledge.py` (multiple endpoints)
- **Issue:** `kb_name` path parameter has no regex validation; used in file operations
- **Mitigation:** Code uses `Path.resolve()` downstream, but explicit validation is better

### LOW: Docker Runs as Root
- **File:** `Dockerfile` (no `USER` directive in final stage)
- **Issue:** Production container runs as root, increasing blast radius
- **Fix:** Add `RUN useradd -m deeptutor` and `USER deeptutor`

### LOW: Folder Linking Without Scope Restriction
- **File:** `src/knowledge/manager.py:537-560`
- **Issue:** `link_folder` expands user-provided paths without restricting to safe directories
- **Fix:** Add allowlist of parent directories

### INFO: Dependency Version Ranges Too Broad
- **File:** `requirements.txt`
- **Issue:** Open-ended ranges (e.g., `openai>=1.30.0`) could pull breaking or vulnerable versions
- **Fix:** Pin upper bounds or use lockfile

---

## Contribution Opportunities

### Bugs

1. **File:** `src/api/main.py:162-168`
   - **Issue:** CORS wildcard `["*"]` with `allow_credentials=True` -- browsers actually reject this combination per CORS spec, meaning credentials are silently dropped
   - **Fix:** Use specific origin from env var: `allow_origins=[os.getenv("CORS_ORIGIN", "http://localhost:3000")]`
   - **Effort:** trivial
   - **PR-worthy:** high

2. **File:** `web/components/Mermaid.tsx:16`
   - **Issue:** `securityLevel: "loose"` bypasses Mermaid's built-in XSS protections
   - **Fix:** Change to `"strict"`
   - **Effort:** trivial
   - **PR-worthy:** high

### Security Fixes

3. **File:** `web/components/CoMarkerEditor.tsx`, `web/components/CoWriterEditor.tsx`
   - **Issue:** `rehype-raw` allows unsanitized HTML in markdown rendering
   - **Fix:** Add DOMPurify sanitization or remove rehype-raw
   - **Effort:** small
   - **PR-worthy:** high

4. **File:** `Dockerfile` (final stage)
   - **Issue:** No non-root user for production container
   - **Fix:** Add `USER` directive with dedicated app user
   - **Effort:** small
   - **PR-worthy:** medium

5. **File:** `src/services/rag/components/retrievers/dense.py:138`
   - **Issue:** Unsafe pickle deserialization of cached embeddings
   - **Fix:** Migrate to numpy `.npy` format or add HMAC verification
   - **Effort:** medium
   - **PR-worthy:** medium

### Missing Tests

6. **Directory:** `tests/agents/`
   - **Issue:** Zero unit tests for all 8 agents (research, solve, guide, chat, question, ideagen, co_writer)
   - **Fix:** Add tests with mocked LLM responses for each agent's core logic
   - **Effort:** large
   - **PR-worthy:** high

7. **Directory:** `tests/api/`
   - **Issue:** No tests for any FastAPI router endpoints
   - **Fix:** Add httpx AsyncClient tests for each router (chat, knowledge, solve, research, etc.)
   - **Effort:** large
   - **PR-worthy:** high

8. **File:** `web/tests/`
   - **Issue:** Only 1 E2E file with 4 accessibility checks; no component or integration tests
   - **Fix:** Add Playwright tests for core user flows (upload KB, ask question, solve problem)
   - **Effort:** large
   - **PR-worthy:** medium

### Documentation Gaps

9. **File:** (missing) `docs/guide/api-reference.md`
   - **Issue:** No API reference documentation beyond auto-generated OpenAPI
   - **Fix:** Document key endpoints with examples, authentication, error codes
   - **Effort:** medium
   - **PR-worthy:** medium

10. **File:** `config/README.md`
    - **Issue:** Config docs exist but don't cover all YAML options or env variable interactions
    - **Fix:** Add complete configuration reference with all supported keys
    - **Effort:** small
    - **PR-worthy:** low

### Code Improvements

11. **Files:** Multiple config loading functions across `src/agents/`, `src/api/`, `src/services/`
    - **Issue:** Config loading duplicated in 3+ places with different signatures
    - **Fix:** Consolidate into single `ConfigManager` entry point
    - **Effort:** medium
    - **PR-worthy:** medium

12. **Files:** API routers (14 bare `except: pass` blocks)
    - **Issue:** Silent failures hide bugs and make debugging difficult
    - **Fix:** Replace with specific exception types, add logging
    - **Effort:** small
    - **PR-worthy:** medium

13. **File:** `pyproject.toml` (MyPy config)
    - **Issue:** `check_untyped_defs = false` and `disallow_untyped_defs = false` make type checking ineffective
    - **Fix:** Gradually enable strict mode, starting with `check_untyped_defs = true`
    - **Effort:** medium
    - **PR-worthy:** low

### Feature Ideas

14. **Rate limiting on API endpoints**
    - **Issue:** No rate limiting; LLM-backed endpoints could be abused
    - **Fix:** Add `slowapi` or similar middleware with per-IP limits
    - **Effort:** small
    - **PR-worthy:** high

15. **Coverage reporting in CI**
    - **Issue:** No coverage metrics tracked
    - **Fix:** Add `pytest-cov` to CI, set minimum threshold, report to PR comments
    - **Effort:** small
    - **PR-worthy:** medium

---

## Draft PRs

### PR 1: Harden CORS and Mermaid Security

- **PR Title:** `fix: harden CORS configuration and Mermaid XSS protections`
- **Branch:** `fix/security-cors-mermaid`
- **Files:**
  - `src/api/main.py` (lines 162-168)
  - `web/components/Mermaid.tsx` (lines 13-31, 90)
  - `.env.example` (add CORS_ORIGIN variable)
- **Changes:**
  - Replace `allow_origins=["*"]` with `allow_origins=[os.getenv("CORS_ORIGIN", "http://localhost:3000")]`
  - Set `allow_credentials` based on whether origin is explicitly configured
  - Change Mermaid `securityLevel` from `"loose"` to `"strict"`
  - Set `htmlLabels: false`
  - Add `CORS_ORIGIN` to `.env.example` with documentation
- **Effort:** 1 hour
- **Impact:** Fixes the two highest severity security issues. CORS wildcard is a deployment risk for anyone running this in production. Mermaid loose security enables XSS through AI-generated diagram content.

### PR 2: Add API Router Test Suite

- **PR Title:** `test: add FastAPI router test suite with httpx`
- **Branch:** `feat/api-router-tests`
- **Files:**
  - `tests/api/__init__.py` (new)
  - `tests/api/test_knowledge_router.py` (new)
  - `tests/api/test_chat_router.py` (new)
  - `tests/api/test_settings_router.py` (new)
  - `tests/api/conftest.py` (new -- shared fixtures)
  - `pyproject.toml` (add pytest-httpx, pytest-cov)
  - `.github/workflows/tests.yml` (add coverage reporting)
- **Changes:**
  - Create test fixtures with `httpx.AsyncClient` against FastAPI test app
  - Mock LLM and RAG services to test API contract without external dependencies
  - Test key endpoints: knowledge CRUD, chat streaming, settings get/set, system health
  - Add `pytest-cov` with 30% minimum threshold as starting point
  - Add coverage report upload to CI
- **Effort:** 4-6 hours
- **Impact:** Addresses the biggest quality gap. API routers are the primary interface and currently have zero test coverage. This would catch regressions in endpoint contracts, validation, and error handling.

### PR 3: Eliminate Silent Failures and Standardize Error Handling

- **PR Title:** `fix: replace bare except clauses with specific error handling`
- **Branch:** `fix/error-handling-cleanup`
- **Files:**
  - All files containing `except:` or `except Exception` with `pass` (14 locations across `src/api/routers/`, `src/services/`, `src/agents/`)
- **Changes:**
  - Replace all `except: pass` with specific exception types and logging
  - Standardize API error responses using a shared `error_response()` helper
  - Add structured logging context to all catch blocks
  - Ensure all exceptions are logged at appropriate levels (warning for expected, error for unexpected)
- **Effort:** 2-3 hours
- **Impact:** Silent failures are one of the hardest bugs to diagnose. This change improves observability across the entire backend, making production debugging feasible and preventing data loss from swallowed errors.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 5 |
| Documentation | 7 |
| Test Coverage | 3 |
| Contribution Potential | 9 |

**Summary:** DeepTutor has a well-architected codebase with clean separation of concerns, good i18n support, and solid CI/CD infrastructure. The main weaknesses are low test coverage (<15%), permissive security defaults (CORS wildcard, Mermaid loose mode, rehype-raw), and inconsistent error handling. The project is highly approachable for contributions -- the architecture is clear, conventions are documented, and there are significant improvements available at every difficulty level.
