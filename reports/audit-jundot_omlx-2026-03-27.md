Now I have enough information to compile the full audit report.

# Audit: jundot/omlx

## Repository Overview

**oMLX** is a high-performance LLM inference server optimized for Apple Silicon Macs. It provides an OpenAI- and Anthropic-compatible API backed by MLX (Apple's ML framework) with continuous batching, tiered KV caching (hot RAM + cold SSD), multi-model serving with LRU eviction, vision-language model support, tool calling, structured output, MCP integration, model evaluation benchmarks, and a native macOS menubar app. The project targets local inference on M1-M4 hardware and is distributed via Homebrew and DMG.

**Tech Stack:** Python 3.10+, MLX, mlx-lm, FastAPI, Uvicorn, Pydantic, PyObjC (macOS app), Tailwind CSS (admin UI), setuptools.

**Maturity:** Growing -- classified as "Alpha" in PyPI classifiers (Development Status :: 3 - Alpha), but has 90 test files, 120+ source files (~108k LoC), conventional commits, multilingual docs, a Homebrew formula, and regular releases (v0.2.22). Active development with solid architecture.

## Code Quality Assessment

### Architecture and Organization
Excellent modular design. Clear separation: `engine/` (inference), `cache/` (tiered KV management), `api/` (protocol adapters), `admin/` (dashboard), `eval/` (benchmarks), `mcp/` (tool protocol), `models/` (model wrappers), `integrations/` (Claude Code, OpenCode, Codex). Shared base classes (`BaseEngine`, `BaseBenchmark`, `BaseModel`) reduce duplication. The `scheduler.py` and `engine_core.py` follow vLLM's design patterns.

### Error Handling
Strong custom exception hierarchy in `exceptions.py` with 20+ specific types carrying structured metadata (request_id, model_name, block_id). Consistent use of try/except across ~1,500 occurrences. `secrets.compare_digest()` for timing-safe key comparison. Minor: some broad `except Exception` catches in eval modules.

### Test Coverage
90 test files covering all major subsystems: cache (6 files), engine (3), API (4), admin (4), Anthropic compat (2), MCP (3), settings, benchmarks, tool calling. Integration tests for e2e streaming, real model inference, server endpoints, and cache consistency. Markers for slow/integration test separation. No CI pipeline to enforce test runs.

### Documentation
README in 4 languages (EN, ZH, JA, KO). Contributing guide, quantization docs. Good docstrings throughout auth, server, scheduler modules. SPDX license headers on all files. Admin UI has i18n support (multiple locales).

### Dependency Health
- Pins 3 dependencies to specific git commits (mlx-lm, mlx-embeddings, mlx-vlm) -- fragile for reproducibility but necessary for tracking upstream changes
- `transformers>=5.0.0` is a very forward-looking pin
- No lock file (no `requirements.txt` or `uv.lock` committed)
- No pinned transitive dependencies

## Security Findings

### Medium: Default CORS allows all origins (`*`)
**File:** `omlx/settings.py:116`, `omlx/server.py:1029-1036`
Default `cors_origins: ["*"]` combined with `allow_methods=["*"]` and `allow_headers=["*"]`. While appropriate for a local-only server, if exposed to a network, any webpage could make API calls including model loading/unloading.

### Medium: No rate limiting on API endpoints
**File:** `omlx/server.py`
No rate limiting middleware. A malicious client can flood the server with requests, causing resource exhaustion on the local machine. The `memory_monitor.py` provides some resource awareness but doesn't throttle incoming requests.

### Medium: Code execution in eval benchmarks
**File:** `omlx/eval/humaneval.py:9-11`, `omlx/eval/livecodebench.py`, `omlx/eval/mbpp.py`
HumanEval/MBPP/LiveCodeBench execute model-generated code via subprocess. Mitigations exist (timeout, memory limits via `resource.setrlimit`, temp file cleanup), but no container/sandbox isolation. Documented with a security note, but still risky.

### Low: No CI/CD pipeline
**File:** `.github/` (missing `workflows/`)
No GitHub Actions or equivalent CI. Tests, linting, and security checks are not automatically enforced on PRs. Only issue templates exist.

### Low: Git commit-pinned dependencies
**File:** `pyproject.toml:33-35, 62`
Three core dependencies pinned to git commit SHAs. If those commits are force-pushed or repos become unavailable, builds break. No integrity verification beyond git.

### Info: API key minimum length is 4 characters
**File:** `omlx/admin/auth.py:170`
While validated, 4 characters is very weak. Acceptable for a local tool but worth noting.

### Info: Session tokens not persistent by default
**File:** `omlx/admin/auth.py:25`
Random secret key generated if `OMLX_SECRET_KEY` not set -- sessions invalidate on restart. Documented and by design, but could confuse users.

## Contribution Opportunities

### Bugs

No critical bugs found in the current codebase. The codebase is well-maintained with only 1 TODO comment.

### Security Fixes

1. **File:** `omlx/settings.py:116`
   **Issue:** Default CORS `["*"]` is overly permissive
   **Fix:** Change default to `["http://127.0.0.1:*", "http://localhost:*"]` for local-only access; document how to open up for network use
   **Effort:** trivial
   **PR-worthy:** medium

2. **File:** `omlx/server.py` (lifespan function area, ~line 1028)
   **Issue:** No rate limiting on API endpoints
   **Fix:** Add optional rate limiting middleware (e.g., `slowapi` or custom token bucket) configurable via settings
   **Effort:** small
   **PR-worthy:** medium

### Missing Tests

1. **File:** `.github/workflows/` (missing)
   **Issue:** No CI pipeline -- tests are never run automatically
   **Fix:** Add GitHub Actions workflow for pytest, ruff, mypy on push/PR
   **Effort:** small
   **PR-worthy:** high

2. **File:** `omlx/eval/` (humaneval.py, mbpp.py, livecodebench.py)
   **Issue:** Eval modules have minimal unit test coverage for code execution paths
   **Fix:** Add tests for `_extract_code`, sandbox resource limits, timeout handling
   **Effort:** medium
   **PR-worthy:** medium

### Documentation Gaps

1. **File:** `docs/` (missing)
   **Issue:** No API reference documentation beyond README
   **Fix:** Add OpenAPI schema export or dedicated API docs page
   **Effort:** medium
   **PR-worthy:** medium

2. **File:** `docs/` (missing)
   **Issue:** No security hardening guide for network-exposed deployments
   **Fix:** Document best practices: API keys, CORS configuration, firewall rules
   **Effort:** small
   **PR-worthy:** medium

### Code Improvements

1. **File:** `omlx/admin/routes.py` (3,812 lines)
   **Issue:** Monolithic routes file -- largest file in the codebase
   **Fix:** Split into sub-routers: model management, chat, benchmark, download, settings
   **Effort:** medium
   **PR-worthy:** high

2. **File:** `omlx/oq.py` (~99,647 lines)
   **Issue:** Extremely large single file (quantization logic)
   **Fix:** Split into modules: calibration, quantization strategies, weight manipulation, evaluation
   **Effort:** large
   **PR-worthy:** medium

3. **File:** `pyproject.toml:33-35`
   **Issue:** Git commit-pinned dependencies are fragile
   **Fix:** Publish or vendor these dependencies; at minimum add a `requirements.txt` lock file
   **Effort:** medium
   **PR-worthy:** medium

### Feature Ideas

1. **File:** `omlx/server.py`
   **Issue:** No Prometheus/metrics endpoint
   **Fix:** Add `/metrics` endpoint exposing request counts, latency histograms, cache hit rates, memory usage
   **Effort:** medium
   **PR-worthy:** high

2. **File:** `omlx/server.py`
   **Issue:** No request tracing/correlation IDs in HTTP responses
   **Fix:** Add `X-Request-ID` header propagation for debugging
   **Effort:** trivial
   **PR-worthy:** low

## Draft PRs

### PR 1: Add CI/CD with GitHub Actions

- **PR Title:** `ci: add GitHub Actions workflow for tests and linting`
- **Branch:** `ci/github-actions`
- **Files:** `.github/workflows/ci.yml` (new)
- **Changes:** Create a workflow that runs on push/PR to main: (1) matrix test across Python 3.10-3.13 on macOS-latest runners, (2) run `ruff check`, (3) run `mypy`, (4) run `pytest` excluding slow/integration markers. Cache pip dependencies. Add status badge to README.
- **Effort:** 1-2 hours
- **Impact:** Prevents regressions, enforces code quality on all contributions, standard for any serious open-source project.

### PR 2: Split admin routes into sub-routers

- **PR Title:** `refactor: split admin routes.py into modular sub-routers`
- **Branch:** `refactor/admin-routes-split`
- **Files:** `omlx/admin/routes.py` (modify), `omlx/admin/routes/` (new directory with `models.py`, `chat.py`, `benchmark.py`, `download.py`, `settings.py`, `__init__.py`)
- **Changes:** Extract the 3,800-line monolith into FastAPI sub-routers by domain. Each sub-router handles its own endpoints and dependencies. The main `routes.py` imports and mounts them. Update tests to import from new locations.
- **Effort:** 4-6 hours
- **Impact:** Dramatically improves maintainability. Currently the single largest barrier to contribution -- new contributors can't easily navigate or modify admin functionality.

### PR 3: Restrict default CORS and add security docs

- **PR Title:** `fix: restrict default CORS origins to localhost`
- **Branch:** `fix/cors-default`
- **Files:** `omlx/settings.py`, `omlx/config.py`, `docs/security.md` (new), `tests/test_settings.py`
- **Changes:** Change default `cors_origins` from `["*"]` to `["http://127.0.0.1:*", "http://localhost:*"]`. Update tests. Add a `docs/security.md` guide covering: API key setup, CORS configuration for remote access, firewall recommendations, session security.
- **Effort:** 1-2 hours
- **Impact:** Closes the most accessible security gap. Users who expose oMLX to a network currently have no protection from cross-origin attacks by default.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 7 |
| Test Coverage | 7 |
| Contribution Potential | 8 |
