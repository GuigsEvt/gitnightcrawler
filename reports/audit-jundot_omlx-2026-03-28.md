# Audit: jundot/omlx

## Repository Overview

oMLX is an LLM inference server optimized for Apple Silicon Macs, built on top of Apple's MLX framework. It provides an OpenAI/Anthropic-compatible API with continuous batching, a tiered (hot RAM + cold SSD) KV cache, multi-model serving with LRU eviction, a web admin dashboard, a native macOS menu bar app, and MCP tool integration. It supports text LLMs, vision-language models, OCR models, embedding models, and rerankers -- all managed from a single server process.

**Tech stack:** Python 3.10+, FastAPI/Uvicorn, MLX/mlx-lm/mlx-vlm, PyObjC (macOS app), safetensors, Pydantic, Alpine.js (admin UI). ~109K lines of Python across 221 files (54K source, 50K tests, 5K packaging).

**Maturity:** Growing. Alpha status per classifiers, active development (recent commits fix real production issues like kernel panics), comprehensive test suite, multilingual docs, Homebrew formula, macOS .dmg distribution. Version 0.2.24.dev1.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 8/10.** Clean modular layout: `omlx/engine/` (inference engines), `omlx/cache/` (tiered KV cache), `omlx/api/` (adapters), `omlx/admin/` (web UI + routes), `omlx/mcp/` (tool protocol), `omlx/utils/`, `omlx/eval/` (benchmarks). Clear separation of concerns. Some large files warrant splitting: `scheduler.py` (4,583 lines), `server.py` (3,825 lines), `admin/routes.py` (3,812 lines).

### Error Handling
**Score: 7/10.** Generally good -- Pydantic validation on all API requests, proper exception propagation with typed errors (`EnginePoolError`, `ModelNotFoundError`), `CancelledError` handling for async operations, and graceful fallbacks in cache recovery. A few `except Exception: pass` patterns exist but are limited to cleanup code. API key rejection logs the actual key value (see Security).

### Test Coverage
**Score: 8/10.** 88 test files, ~50K LOC. Well-designed mock infrastructure (`MockBatchGenerator`, `MockPagedCacheManager`, `MockTokenizer`, etc.) in centralized `conftest.py` and `mocks.py`. Clear separation: unit tests (default, mocked), `@pytest.mark.slow` (real models), `@pytest.mark.integration` (end-to-end). Async-first testing with `pytest-asyncio`. Coverage is broad across all major subsystems.

### Documentation
**Score: 7/10.** Multilingual READMEs (EN/ZH/KO/JA), CONTRIBUTING.md with dev workflow, oQ quantization deep-dive. Architecture diagram in README. Missing: SECURITY.md, CHANGELOG.md, inline API documentation, architecture decision records.

### Dependency Health
**Score: 6/10.** Three git-pinned dependencies (commit SHAs -- good practice), but two from a third-party account (Blaizzy). No lock file committed. `exclude-newer` date in venvstacks.toml provides some reproducibility. No automated dependency update tooling (Dependabot/Renovate).

---

## Security Findings

### Critical

**1. Missing auth on sub-key creation endpoint**
- **File:** `omlx/admin/routes.py` ~line 1145
- **Issue:** The `POST /api/sub-keys` endpoint appears to lack `Depends(require_admin)`, potentially allowing unauthenticated users to create API keys.
- **Fix:** Add `Depends(require_admin)` dependency to the endpoint.

### High

**2. API key logged in plaintext**
- **File:** `omlx/server.py` ~line 284
- **Issue:** `logger.warning("Rejected API key: %r", api_key_value)` writes the actual rejected key to logs. Logs are accessible via admin panel.
- **Fix:** Redact to `"Rejected API key: [REDACTED]"` or log only a hash/prefix.

**3. No DMG signature verification in auto-updater**
- **File:** `packaging/omlx_app/updater.py`
- **Issue:** Downloads DMG from GitHub releases and mounts/swaps without SHA256 or codesign verification. MITM or compromised GitHub release could execute arbitrary code.
- **Fix:** Verify SHA256 hash from a signed manifest, or validate macOS code signature post-mount.

**4. Unrestricted SSRF via image URL fetching**
- **File:** `omlx/utils/image.py` ~line 50
- **Issue:** `urllib.request.urlopen(url)` accepts arbitrary HTTP/HTTPS URLs from API requests for vision models. Can be used for SSRF against internal services.
- **Fix:** Validate URLs against a whitelist or block private/internal IP ranges.

### Medium

**5. No CSRF protection on admin endpoints**
- **File:** `omlx/admin/` routes
- **Issue:** Cookie-based session auth without CSRF tokens. State-changing POST endpoints are vulnerable to cross-site request forgery.
- **Fix:** Add CSRF middleware or token validation.

**6. CORS allows all origins by default**
- **File:** `omlx/server.py`
- **Issue:** Default CORS configuration allows `*`. Combined with cookie-based admin auth, this widens the CSRF attack surface.
- **Fix:** Default to `localhost` origins only, make configurable.

**7. No SRI verification for vendored JS/CSS**
- **File:** `omlx/admin/vendor_deps.py`
- **Issue:** Downloads Alpine.js, Highlight.js, KaTeX, etc. from CDNs without Subresource Integrity hashes. Compromised CDN could inject malicious scripts.
- **Fix:** Add SHA384/SHA512 integrity checks.

### Low

**8. No rate limiting on login endpoint**
- **File:** `omlx/admin/routes.py`
- **Issue:** Password brute-force possible without rate limiting.
- **Fix:** Add exponential backoff or rate limit middleware.

**9. No SECURITY.md**
- **Issue:** No documented security policy or vulnerability reporting process.
- **Fix:** Add `SECURITY.md` with responsible disclosure instructions.

### Info

- Eval/benchmark code uses `subprocess` with `resource.setrlimit` sandboxing -- intentional and adequately isolated.
- `yaml.safe_load()` used correctly everywhere.
- No pickle/marshal deserialization. safetensors used for cache serialization (safe).
- API key comparison uses `secrets.compare_digest` (timing-safe).
- Server binds `127.0.0.1` by default (not `0.0.0.0`).
- Session tokens use `itsdangerous.URLSafeTimedSerializer` with proper expiry.

---

## Contribution Opportunities

### Bugs

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `omlx/admin/routes.py:1145` | Missing auth on sub-key endpoint | Add `Depends(require_admin)` | trivial | high |
| 2 | `omlx/server.py:284` | API key logged in plaintext | Redact key in log message | trivial | high |

### Security Fixes

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 3 | `packaging/omlx_app/updater.py` | No DMG hash verification | Add SHA256 check from release manifest | small | high |
| 4 | `omlx/utils/image.py:50` | SSRF via arbitrary image URLs | Block private IPs, validate URL scheme | small | high |
| 5 | `omlx/admin/` | No CSRF protection | Add CSRF tokens to state-changing endpoints | medium | medium |
| 6 | `omlx/admin/vendor_deps.py` | No SRI for vendored assets | Add integrity hash verification | small | medium |

### Missing Tests

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 7 | `tests/` | No CI/CD pipeline | Add GitHub Actions workflow for pytest + ruff | small | high |
| 8 | `tests/` | No test coverage tracking | Add `pytest-cov` and coverage badge | trivial | medium |
| 9 | `tests/test_admin_auth.py` (missing) | Admin auth not unit-tested | Test session creation, CSRF, expiry edge cases | medium | medium |

### Documentation Gaps

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 10 | `SECURITY.md` (missing) | No security policy | Add vulnerability disclosure process | trivial | high |
| 11 | `CHANGELOG.md` (missing) | No version history | Add changelog from git tags | small | medium |
| 12 | `docs/` | No architecture doc | Document engine pool, cache tiers, request lifecycle | medium | medium |

### Code Improvements

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 13 | `omlx/server.py` (3825 lines) | God file | Extract route handlers into separate modules | large | medium |
| 14 | `omlx/scheduler.py` (4583 lines) | Oversized module | Split scheduling logic from batch management | large | medium |
| 15 | `omlx/admin/routes.py` (3812 lines) | Oversized module | Split into sub-routers (models, settings, chat, downloads) | large | medium |
| 16 | `pyproject.toml` | No lock file for reproducible builds | Add `uv.lock` or `requirements.lock` | trivial | medium |

### Feature Ideas

| # | Description | Effort | PR-worthy |
|---|-------------|--------|-----------|
| 17 | Health check endpoint (`/healthz`) for monitoring/load balancing | trivial | high |
| 18 | Prometheus metrics export (`/metrics`) | medium | medium |
| 19 | Request logging middleware with configurable verbosity | small | medium |

---

## Draft PRs

### PR 1: fix: add auth check to sub-key creation endpoint

- **Branch:** `fix/sub-key-auth`
- **Files:** `omlx/admin/routes.py`
- **Changes:** Add `Depends(require_admin)` to the `POST /api/sub-keys` route handler function signature. This is a one-line change that closes an authentication bypass allowing unauthenticated sub-key creation.
- **Effort:** 15 minutes
- **Impact:** Closes a critical auth bypass. Without this, anyone with network access to the server can mint API keys.

### PR 2: fix: redact API keys in log output and add SECURITY.md

- **Branch:** `fix/security-hardening`
- **Files:** `omlx/server.py`, `SECURITY.md` (new)
- **Changes:**
  1. In `server.py` ~line 284, change `logger.warning("Rejected API key: %r", api_key_value)` to `logger.warning("Rejected API key: %s...%s", api_key_value[:4], api_key_value[-4:])` (or full redaction).
  2. Add `SECURITY.md` with responsible disclosure instructions and contact email.
- **Effort:** 30 minutes
- **Impact:** Prevents credential leakage through logs (accessible via admin panel). Establishes a security reporting channel for the growing project.

### PR 3: ci: add GitHub Actions workflow for tests and linting

- **Branch:** `feat/ci-pipeline`
- **Files:** `.github/workflows/ci.yml` (new)
- **Changes:** Add a GitHub Actions workflow that:
  1. Runs on push/PR to `main`
  2. Sets up Python 3.10/3.11/3.12 matrix on `macos-latest` (Apple Silicon runners)
  3. Installs `.[dev]` dependencies
  4. Runs `ruff check .` and `ruff format --check .`
  5. Runs `pytest -m "not slow and not integration"` with coverage reporting
  6. Uploads coverage to Codecov or similar
- **Effort:** 1-2 hours
- **Impact:** Every PR gets automated quality gates. Currently there is zero CI -- all quality assurance is manual. This is the single highest-leverage infrastructure improvement for the project.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 5 |
| Documentation | 6 |
| Test Coverage | 7 |
| Contribution Potential | 9 |

**Summary:** A well-architected, feature-rich project with strong test infrastructure but notable security gaps (missing auth on endpoints, SSRF, unsigned updates, no CI). The codebase is clean and modular despite a few oversized files. High contribution potential -- the security fixes and CI setup alone would significantly improve the project's production readiness.
