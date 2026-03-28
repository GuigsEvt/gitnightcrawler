# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered personalized learning assistant built by HKUDS (Hong Kong University Data Science). It combines multi-agent collaboration with RAG (Retrieval-Augmented Generation) to provide document-based Q&A, interactive learning visualization, knowledge reinforcement through exercises/exams, and deep research/idea generation. The system processes uploaded documents into knowledge bases, then orchestrates specialized agents (solve, research, guide, ideagen, question, co-writer) to deliver adaptive tutoring experiences.

**Tech Stack:**
- **Backend:** Python 3.10+ / FastAPI / Uvicorn / Pydantic v2
- **Frontend:** Next.js 16 / React 19 / TypeScript 5 / Tailwind CSS 3
- **RAG:** LlamaIndex, RAGAnything, FAISS, Docling
- **LLM Providers:** OpenAI, Anthropic, DashScope (pluggable)
- **Deployment:** Docker (multi-stage), Supervisord, GitHub Actions CI/CD
- **License:** AGPL-3.0

**Maturity:** Growing (v0.6.0, ~76K LOC, active development, CI/CD in place, but <5% test coverage)

---

## Code Quality Assessment

### Architecture and Organization
Well-structured modular architecture with clear separation: `src/agents/` (6 agent modules), `src/api/` (13 routers), `src/services/` (LLM, RAG, embedding, search), `src/tools/`, `src/knowledge/`. Frontend uses Next.js app router with context-based state. Configuration managed through YAML + env layering with drift detection at startup. **Score: 7/10** - clean separation, but several god-files (GlobalContext.tsx at 2178 LOC, reporting_agent.py at 1333 LOC).

### Error Handling Patterns
Custom error hierarchy (`DeepTutorError` → `ConfigurationError`, `ValidationError`, `ServiceError`, `LLMServiceError`). Pydantic-based output validation across agent outputs. Retry mechanism via Tenacity with exponential backoff. 1188 try/except blocks across 135 files, but inconsistent - some bare `except Exception:` catches, mixed logging levels. **Score: 6/10**.

### Test Coverage
**Critically low.** Only 6 test files exist covering config manager, prompt manager, JSON utils, and RAG pipeline integration. Zero tests for: all 13 API routers, all 6 agent modules, LLM clients, knowledge base operations, chat sessions, frontend components. pytest configured with markers but largely unused. **Score: 2/10**.

### Documentation Quality
Excellent README (56K, multi-language), configuration docs, `.env.example` files, inline docstrings in core modules. VitePress docs site. Communication channels documented. Missing: API documentation, architecture decision records, contributing guide depth. **Score: 7/10**.

### Dependency Health
Current versions across the board (FastAPI >=0.100, Pydantic >=2.0, React 19, Next.js 16). `safety<3.0.0` pinned due to broken v3. Pre-commit hooks include bandit and detect-secrets. No `pip-audit` in CI. **Score: 7/10**.

---

## Security Findings

### Critical
| Finding | Details |
|---------|---------|
| **Wildcard CORS with credentials** | `src/api/main.py:162-168` — `allow_origins=["*"]` combined with `allow_credentials=True`. Any website can make authenticated cross-origin requests. |

### Medium
| Finding | Details |
|---------|---------|
| **Pickle deserialization** | `src/services/rag/components/retrievers/dense.py:138` — `pickle.load()` on cached embeddings. Internal-only but exploitable if app is compromised. |
| **No authentication** | No auth/authz layer. Designed for local use but CORS suggests possible network exposure. |
| **Optional SSL bypass** | `src/services/llm/providers/open_ai.py:22-23` — `DISABLE_SSL_VERIFY` env var disables TLS verification. |

### Low
| Finding | Details |
|---------|---------|
| **shell=True in install script** | `scripts/install_all.py:515` — `subprocess.run("npm install", shell=True)`. Hardcoded command, dev-only. |

### Info
| Finding | Details |
|---------|---------|
| **No rate limiting** | API endpoints have no request throttling. |
| **No HTTPS enforcement** | No TLS redirect or HSTS headers. |

---

## Contribution Opportunities

### Bugs

1. **File:** `src/api/main.py:162-168`
   - **Issue:** CORS `allow_origins=["*"]` with `allow_credentials=True` is both a security vulnerability and violates the CORS spec (browsers ignore `*` when credentials are sent)
   - **Fix:** Read allowed origins from config/env, default to `["http://localhost:3782"]`
   - **Effort:** trivial
   - **PR-worthy:** high

### Security Fixes

2. **File:** `src/services/rag/components/retrievers/dense.py:138`, `src/services/rag/components/indexers/vector.py:133`
   - **Issue:** Pickle deserialization for embedding cache is unsafe if files are tampered
   - **Fix:** Replace with `numpy.save()`/`numpy.load()` for array serialization
   - **Effort:** small
   - **PR-worthy:** medium

3. **File:** `scripts/install_all.py:515`
   - **Issue:** `shell=True` in subprocess call
   - **Fix:** Use `["npm", "install"]` array form with `shell=False`
   - **Effort:** trivial
   - **PR-worthy:** low

### Missing Tests

4. **File:** `tests/` (new files needed)
   - **Issue:** 13 API routers have zero test coverage
   - **Fix:** Add pytest tests for each router using FastAPI TestClient
   - **Effort:** large
   - **PR-worthy:** high

5. **File:** `tests/agents/` (new files needed)
   - **Issue:** All 6 agent modules untested
   - **Fix:** Add unit tests with mocked LLM responses for agent logic
   - **Effort:** large
   - **PR-worthy:** high

### Documentation Gaps

6. **File:** `docs/` or `README.md`
   - **Issue:** No API documentation (13 routers, dozens of endpoints undocumented)
   - **Fix:** Add FastAPI auto-docs setup or OpenAPI spec export
   - **Effort:** small
   - **PR-worthy:** medium

7. **File:** `CONTRIBUTING.md` (new)
   - **Issue:** No contributing guide despite AGPL license
   - **Fix:** Add setup instructions, code style guide, PR process
   - **Effort:** small
   - **PR-worthy:** medium

### Code Improvements

8. **File:** `web/context/GlobalContext.tsx` (2178 LOC)
   - **Issue:** God-object context with all application state in one file
   - **Fix:** Split into domain-specific contexts (SolverContext, ResearchContext, KnowledgeContext, etc.)
   - **Effort:** medium
   - **PR-worthy:** medium

9. **File:** `src/agents/research/agents/reporting_agent.py` (1333 LOC)
   - **Issue:** Monolithic reporting agent handling deduplication, outline gen, citation assembly
   - **Fix:** Extract into separate classes/modules per responsibility
   - **Effort:** medium
   - **PR-worthy:** medium

10. **File:** `pyproject.toml` (mypy config)
    - **Issue:** MyPy excludes agents, routers, RAG services — most of the codebase
    - **Fix:** Gradually enable type checking for excluded modules, add `--strict` for new code
    - **Effort:** medium
    - **PR-worthy:** low

### Feature Ideas

11. **Rate limiting middleware** — Add slowapi or custom rate limiter to FastAPI
    - **Effort:** small
    - **PR-worthy:** medium

12. **Structured JSON logging** — Replace string format logs with JSON for observability tooling
    - **Effort:** small
    - **PR-worthy:** low

---

## Draft PRs

### PR 1: Fix CORS vulnerability
- **PR Title:** `fix: restrict CORS origins and remove wildcard with credentials`
- **Branch:** `fix/cors-configuration`
- **Files:** `src/api/main.py`, `.env.example`, `.env.example_CN`, `src/services/config/unified_config.py`
- **Changes:**
  - Add `CORS_ORIGINS` env var (comma-separated list, default `http://localhost:3782`)
  - Parse origins in `main.py` and pass to `CORSMiddleware`
  - Remove `allow_origins=["*"]`, replace with config-driven list
  - Restrict `allow_methods` and `allow_headers` to what's actually needed
  - Update `.env.example` files with new variable
- **Effort:** 1-2 hours
- **Impact:** Fixes a critical security vulnerability. Wildcard CORS with credentials is exploitable for CSRF attacks and violates browser CORS spec.

### PR 2: Add API router test suite
- **PR Title:** `test: add integration tests for core API routers`
- **Branch:** `test/api-router-coverage`
- **Files:** `tests/api/test_chat.py`, `tests/api/test_knowledge.py`, `tests/api/test_solve.py`, `tests/api/test_config.py`, `tests/api/conftest.py`
- **Changes:**
  - Create `conftest.py` with FastAPI TestClient fixture and mocked services
  - Add tests for chat, knowledge, solve, and config routers (highest traffic endpoints)
  - Test request validation, error responses, and happy paths
  - Mock LLM and RAG services to avoid external dependencies
  - Add to CI workflow
- **Effort:** 2-3 days
- **Impact:** Moves test coverage from ~2% to ~15-20% on the most critical code paths. Prevents regressions in API contract.

### PR 3: Replace pickle with numpy serialization
- **PR Title:** `fix: replace pickle with numpy for embedding cache serialization`
- **Branch:** `fix/unsafe-pickle-deserialization`
- **Files:** `src/services/rag/components/retrievers/dense.py`, `src/services/rag/components/indexers/vector.py`
- **Changes:**
  - Replace `pickle.dump(embeddings, f)` with `numpy.save(f, embeddings)`
  - Replace `pickle.load(f)` with `numpy.load(f, allow_pickle=False)`
  - Add migration logic to detect and convert old pickle caches on first load
  - Update imports (remove pickle, add numpy if not present)
- **Effort:** 2-3 hours
- **Impact:** Eliminates unsafe deserialization vector. numpy's `allow_pickle=False` is immune to arbitrary code execution via crafted files.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 5 |
| Documentation | 7 |
| Test Coverage | 2 |
| Contribution Potential | 9 |

**Summary:** DeepTutor is a feature-rich, well-architected learning platform with strong documentation and clear code organization. The critical gaps are test coverage (nearly nonexistent) and the CORS misconfiguration. The codebase is highly approachable for contributors — the modular agent architecture and clear separation of concerns make it straightforward to add tests, fix security issues, and improve individual modules without touching the rest of the system.
