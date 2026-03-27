Now I have enough data. Let me compile the report.

# Audit: HKUDS/DeepTutor

## Repository Overview

DeepTutor is an AI-powered personalized learning assistant built by HKU Data Science Lab. It provides multi-agent collaboration (solver, researcher, question generator, guide, idea generator, co-writer) with RAG-based knowledge management over uploaded documents. Users upload PDFs/documents, build knowledge bases with vector embeddings, and interact via chat-style interfaces where specialized agents handle different learning tasks. The system supports multiple LLM providers (OpenAI, Anthropic, DeepSeek, Azure, Ollama) and embedding providers (OpenAI, Jina, Cohere, HuggingFace).

**Tech Stack:**
- Backend: Python 3.10+, FastAPI, Uvicorn, WebSockets
- Frontend: Next.js 16, React 19, TypeScript 5, Tailwind CSS 3.4
- RAG: LlamaIndex, LightRAG, RAGAnything with Docling
- Vector: FAISS (optional), numpy cosine similarity fallback
- Storage: File-based (JSON, pickle) -- no SQL database
- Containerization: Docker multi-stage, supervisord

**Maturity:** Growing -- v0.5.0, active development, 239 Python files, 99 TS/TSX files, 609 total files. Good documentation but minimal test coverage.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 7/10** -- Well-structured multi-agent architecture with clear separation:
- `src/agents/` -- Agent implementations (solve, research, question, chat, guide, ideagen, co_writer)
- `src/api/routers/` -- 14 FastAPI router modules
- `src/tools/` -- Code execution, RAG, search, PDF parsing
- `src/services/` -- LLM, embedding, TTS, RAG pipelines, config
- `web/` -- Clean Next.js app with context providers, typed components

Configuration management uses YAML with environment variable overrides and a merge system (`load_config_with_main`). The config drift validator at startup (`src/api/main.py:37-119`) is a nice touch.

### Error Handling Patterns
**Score: 7/10** -- Generally good. Comprehensive try/catch in agents and tools. Code executor (`src/tools/code_executor.py`) has thorough error handling for timeout, syntax errors, and runtime failures. Some bare `except Exception` clauses exist but are documented. Logging is structured with a custom logger (`src/logging/logger.py`).

### Test Coverage
**Score: 2/10** -- Only 6 actual test files covering config, prompts, JSON utils, and RAG pipelines. No tests for:
- API endpoints (14 routers, 141+ endpoints)
- Agent logic
- Code executor
- Frontend (1 E2E audit file exists but is minimal)

### Documentation Quality
**Score: 8/10** -- Excellent README (1,565 lines), CONTRIBUTING.md, inline docstrings on major classes, config README. Multi-language support (8 languages). `.env.example` well-documented.

### Dependency Health
**Score: 7/10** -- Recent versions (React 19, Next.js 16, FastAPI 0.100+). `numpy<2.0.0` pinned for compatibility. `safety<3.0.0` pinned due to upstream breakage. Pre-commit hooks include detect-secrets and bandit. `pip-audit` disabled due to Windows bug.

---

## Security Findings

### Critical

None found.

### High

| # | Finding | Location |
|---|---------|----------|
| H1 | **Mermaid XSS via `dangerouslySetInnerHTML`** | `web/components/Mermaid.tsx:90` |

Mermaid is initialized with `securityLevel: "loose"` (line 16) and renders SVG output directly into the DOM via `dangerouslySetInnerHTML`. The `chart` prop comes from LLM-generated markdown. With `securityLevel: "loose"`, mermaid allows HTML in labels, which could enable XSS if an attacker controls document content fed to the LLM. Should use `securityLevel: "strict"` or `"antiscript"`.

### Medium

| # | Finding | Location |
|---|---------|----------|
| M1 | **CORS wildcard with credentials** | `src/api/main.py:162-168` |
| M2 | **Pickle deserialization for embeddings** | `src/services/rag/components/retrievers/dense.py:138` |
| M3 | **No authentication on any endpoint** | `src/api/main.py` (all routers) |
| M4 | **No rate limiting** | `src/api/main.py` |
| M5 | **Docker runs as root** | `Dockerfile` (no USER directive) |

**M1**: `allow_origins=["*"]` combined with `allow_credentials=True`. While browsers reject this combination, it signals intent to allow all origins. Production deployments need explicit origin whitelist.

**M2**: `pickle.load(f)` on `embeddings.pkl`. Data is internally generated but if an attacker gains write access to the knowledge base directory, they can achieve arbitrary code execution via crafted pickle.

**M3**: Designed as single-user local app, but Docker/cloud deployments expose all endpoints (file upload, code execution, config changes) without auth.

**M5**: No `USER` directive in Dockerfile -- container runs as root by default.

### Low

| # | Finding | Location |
|---|---------|----------|
| L1 | **ThemeScript dangerouslySetInnerHTML** | `web/components/ThemeScript.tsx:34` |
| L2 | **Verbose debug logging** | `src/logging/logger.py` |
| L3 | **Static file mount without traversal protection** | `src/api/main.py:187` |

**L1**: Static string, no user input -- safe but worth noting.
**L3**: FastAPI's `StaticFiles` handles traversal protection, but the mount at `/api/outputs` exposes the full `data/user/` tree.

### Info

| # | Finding | Location |
|---|---------|----------|
| I1 | All YAML loading uses `yaml.safe_load()` | 13 instances |
| I2 | No `eval()`/`exec()` usage | Entire codebase |
| I3 | Subprocess uses list form (`shell=False`) | `src/tools/code_executor.py:299` |
| I4 | Code executor has workspace isolation + import guard | `src/tools/code_executor.py:219-274` |
| I5 | `.secrets.baseline` configured (detect-secrets) | Root |
| I6 | No hardcoded API keys found | Entire codebase |

---

## Contribution Opportunities

### Bugs

1. **File:** `web/components/Mermaid.tsx:16`
   **Issue:** `securityLevel: "loose"` allows HTML injection in mermaid diagrams
   **Fix:** Change to `securityLevel: "strict"` or `"antiscript"`
   **Effort:** trivial
   **PR-worthy:** high

### Security Fixes

1. **File:** `src/api/main.py:162-168`
   **Issue:** CORS allows all origins with credentials
   **Fix:** Read allowed origins from config/env, default to `["http://localhost:3782"]`
   **Effort:** small
   **PR-worthy:** high

2. **File:** `src/services/rag/components/retrievers/dense.py:132-138`
   **Issue:** Pickle deserialization for embeddings
   **Fix:** Replace `pickle.load` with `np.load()` using `.npy` format; update vector indexer to match
   **Effort:** small
   **PR-worthy:** medium

3. **File:** `Dockerfile:84-100`
   **Issue:** Container runs as root
   **Fix:** Add `RUN useradd -m deeptutor` and `USER deeptutor` before `ENTRYPOINT`
   **Effort:** small
   **PR-worthy:** high

4. **File:** `src/api/main.py`
   **Issue:** No rate limiting on any endpoint
   **Fix:** Add `slowapi` middleware with per-IP limits
   **Effort:** small
   **PR-worthy:** medium

### Missing Tests

1. **File:** `tests/` (missing)
   **Issue:** No API endpoint tests for 14 routers
   **Fix:** Add pytest + httpx `TestClient` tests for each router
   **Effort:** large
   **PR-worthy:** high

2. **File:** `tests/tools/` (missing)
   **Issue:** No tests for code executor (the highest-risk component)
   **Fix:** Test workspace isolation, import guard, timeout, error handling
   **Effort:** medium
   **PR-worthy:** high

3. **File:** `tests/agents/` (missing)
   **Issue:** Only `test_json_utils.py` exists; no agent logic tests
   **Fix:** Add unit tests for agent state machines and tool dispatch
   **Effort:** large
   **PR-worthy:** medium

### Documentation Gaps

1. **File:** `docs/` (missing)
   **Issue:** No security/threat model documentation
   **Fix:** Document trust boundaries, auth requirements for deployment modes
   **Effort:** medium
   **PR-worthy:** medium

2. **File:** `src/api/routers/` (missing)
   **Issue:** No OpenAPI schema descriptions on most endpoints
   **Fix:** Add `summary` and `description` to FastAPI route decorators
   **Effort:** medium
   **PR-worthy:** low

### Code Improvements

1. **File:** `src/tools/code_executor.py:30-82`
   **Issue:** `_load_config()` has 3 nested fallback chains with duplicated logic
   **Fix:** Consolidate into a single config resolution path with a list of candidates
   **Effort:** small
   **PR-worthy:** low

2. **File:** `pyproject.toml:188-211`
   **Issue:** MyPy configured to ignore nearly everything (`check_untyped_defs=false`, `ignore_errors=true` on tests and tools)
   **Fix:** Gradually enable stricter checks, starting with `check_untyped_defs=true`
   **Effort:** large
   **PR-worthy:** low

### Feature Ideas

1. **File:** `src/api/main.py`
   **Issue:** No optional API key authentication for network deployments
   **Fix:** Add `X-API-Key` header middleware, configurable via env var `API_KEY`
   **Effort:** small
   **PR-worthy:** high

2. **File:** `src/api/main.py`
   **Issue:** No request size limits
   **Fix:** Add request body size middleware to prevent abuse on file upload endpoints
   **Effort:** trivial
   **PR-worthy:** medium

---

## Draft PRs

### PR 1: Mermaid XSS + CORS hardening

**PR Title:** `fix: harden mermaid security level and restrict CORS origins`
**Branch:** `fix/security-mermaid-cors`
**Files:**
- `web/components/Mermaid.tsx` (line 16)
- `src/api/main.py` (lines 162-168)

**Changes:**
1. Change `securityLevel: "loose"` to `securityLevel: "strict"` in Mermaid initialization
2. Replace `allow_origins=["*"]` with configurable origins from env var `CORS_ORIGINS` (default `["http://localhost:3782"]`)
3. Restrict `allow_methods` and `allow_headers` to only what's needed

**Effort:** 1-2 hours
**Impact:** Closes two security issues. Mermaid XSS is the highest-severity frontend vulnerability. CORS fix is required for any non-local deployment.

---

### PR 2: Add non-root Docker user

**PR Title:** `fix: run Docker container as non-root user`
**Branch:** `fix/docker-non-root`
**Files:**
- `Dockerfile` (production stage, ~line 100)

**Changes:**
1. Add `RUN useradd --create-home --shell /bin/bash deeptutor` after system dependencies
2. `RUN chown -R deeptutor:deeptutor /app`
3. Add `USER deeptutor` before `ENTRYPOINT`
4. Adjust `mkdir` and `chown` for data directories

**Effort:** 1-2 hours
**Impact:** Container security best practice. Prevents privilege escalation if the application is compromised. Required for many container security policies (CIS Docker Benchmark).

---

### PR 3: Replace pickle with numpy for embedding storage

**PR Title:** `fix: replace pickle with numpy format for embedding storage`
**Branch:** `fix/replace-pickle-embeddings`
**Files:**
- `src/services/rag/components/retrievers/dense.py` (line 132-138)
- `src/services/rag/components/indexers/vector.py` (line ~133)

**Changes:**
1. In vector indexer: replace `pickle.dump(embeddings, f)` with `np.save(f, embeddings)`; save as `embeddings.npy`
2. In dense retriever: replace `pickle.load(f)` with `np.load(f, allow_pickle=False)`; load from `embeddings.npy`
3. Add backward compatibility: if `embeddings.pkl` exists but `embeddings.npy` doesn't, migrate and log a deprecation warning
4. Remove `import pickle` from both files

**Effort:** 2-3 hours
**Impact:** Eliminates insecure deserialization vector. Numpy format is faster, more portable, and cannot execute arbitrary code on load.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 5 |
| Documentation | 8 |
| Test Coverage | 2 |
| Contribution Potential | 9 |
