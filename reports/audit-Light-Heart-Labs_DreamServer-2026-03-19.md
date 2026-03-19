# Audit: Light-Heart-Labs/DreamServer

## Repository Overview

DreamServer is a fully local AI stack that bundles LLM inference, chat UI, voice (STT/TTS), agents, workflows, RAG, image generation, and privacy tools into a single deployable platform. It targets user-owned hardware with a one-command installer supporting Linux (NVIDIA + AMD), Windows (WSL2), and macOS (Apple Silicon). The project auto-detects GPU hardware, maps it to inference tiers, and configures 19 interconnected Docker services accordingly.

**Tech stack:**
- **Shell/Bash** (165 files) — Installer, CLI (`dream-cli`, 1,884 lines), libraries, tests
- **Python** (126 files) — FastAPI dashboard API, privacy shield, token tracking
- **React/Vite/Tailwind** (73 files) — Dashboard frontend
- **Docker Compose** (10 compose files) — Service orchestration with GPU overlays
- **YAML** (160 files) — Extension manifests, CI workflows, configs

**Maturity: Growing** — Well-structured architecture, 60+ test scripts, 9 CI workflows, 20+ contributors, but some gaps in frontend testing and pre-commit automation.

---

## Code Quality Assessment

### Architecture and Organization
**Score: 8/10**

Excellent separation of concerns:
- **Functional core / imperative shell**: `installers/lib/` (pure functions) vs `installers/phases/` (side effects)
- **13-phase modular installer** with standardized headers (Purpose, Expects, Provides, Modder notes)
- **Extension system** with manifest-driven auto-discovery — each of 19 services is a self-contained directory with `manifest.yaml` + optional `compose.yaml`
- **Compose layering**: base + GPU overlay + extension fragments merged dynamically by `resolve-compose-stack.sh`
- **Dashboard API**: Clean router separation (agents, features, privacy, setup, updates, workflows)

Minor concerns:
- `dream-cli` at ~1,884 lines could benefit from modularization
- GPU memory calculation logic duplicated across detection functions
- Health check retry patterns repeated in 3+ modules

### Error Handling Patterns
**Score: 8/10**

Follows stated philosophy: "Let It Crash > KISS > Pure Functions > SOLID"

- **Shell**: `set -euo pipefail` in main scripts + trap handlers with phase tracking. However, library files (`installers/lib/*.sh`) don't enforce strict mode independently — they rely on callers.
- **Python**: Zero instances of `except Exception: pass`. Narrow, specific catches at I/O boundaries (`asyncio.TimeoutError`, `aiohttp.ClientError`, `json.JSONDecodeError`). FastAPI routers raise `HTTPException` with proper status codes.
- **Concerns**: 109 occurrences of `|| true` and 311 of `2>/dev/null` — mostly intentional for optional operations but worth periodic review.

### Test Coverage
**Score: 7/10**

- **Shell tests**: 60+ scripts (9,400 LOC) covering unit, integration, smoke, contract, robustness, and security testing
- **Python tests**: 12 test files for dashboard-api with good security and GPU detection coverage
- **React tests**: Only 6 test files for 7+ components — weakest area
- **CI**: 13 sequential test steps in `test-linux.yml`, 6-distro matrix smoke tests
- **Gaps**: No codecov integration, no E2E browser tests, limited concurrent request testing

### Documentation Quality
**Score: 8/10**

- Root README (30KB) with platform matrix, comparison tables, contributor credits
- `CLAUDE.md` (comprehensive) with design philosophy, architecture concepts, and development commands
- `SECURITY.md` with secret rotation, network isolation, encryption guidance
- `.env.example` (159 lines) with variable documentation
- `.env.schema.json` for validation
- `docs/` folder with 38+ resources
- Missing: API reference docs, contribution guide with PR standards

### Dependency Health
**Score: 8/10**

- Python deps semver-locked (`fastapi>=0.109.0,<0.120.0`, `aiohttp>=3.9.0,<4.0.0`)
- React deps current (React 18, Vite 5, Tailwind 3.4)
- Minor `httpx` version range mismatch between main and test requirements
- No SBOM or lockfile committed for full reproducibility
- Gitleaks v8.21.2 for secret scanning in CI

---

## Security Findings

### Critical

**C1: Dashboard API binds to 0.0.0.0 inside container**
- **File**: `dream-server/extensions/services/dashboard-api/Dockerfile:40` and `main.py:496`
- **Issue**: `uvicorn --host 0.0.0.0` inside the container. While docker-compose binds published ports to `127.0.0.1`, the container itself listens on all interfaces. Network misconfiguration or container escape exposes the API.
- **Fix**: Default to `127.0.0.1` or use `DASHBOARD_API_HOST` env var

### Medium

**M1: SQL injection surface in token-spy (mitigated)**
- **File**: `dream-server/extensions/services/token-spy/db.py:88`
- `f"ALTER TABLE usage ADD COLUMN {col} {typedef}"` — mitigated by allowlist + regex validation on lines 72-87, but defense-in-depth could be stronger

**M2: .env file permissions not enforced at container runtime**
- Generated with `chmod 600` during install, but no enforcement in Docker build or volume mounts

**M3: Global async session without cleanup**
- **File**: `dream-server/extensions/services/dashboard-api/helpers.py:25-46`
- `_aio_session` and `_httpx_client` lazy-initialized but never closed on shutdown — potential connection leaks

**M4: Token tracking file race condition**
- **File**: `dream-server/extensions/services/dashboard-api/helpers.py:49-76`
- Concurrent JSON file writes unprotected — data corruption risk under load

**M5: SearXNG binds to 0.0.0.0 internally**
- **File**: `dream-server/config/searxng/settings.yml:4`
- Mitigated by compose port binding but unnecessary exposure

### Low

**L1: API key auto-generation without persistence warning** — `security.py:14-23` generates key on startup if not set, could cause consistency issues

### Info

- All subprocess calls use argument lists (no `shell=True`) — good
- `secrets.compare_digest()` used for API key comparison — timing-attack resistant
- `no-new-privileges:true` on user-facing containers — good hardening
- All services default to `127.0.0.1` port binding in compose — good
- Non-root container users (`dreamer:dreamer`) — good practice

---

## Contribution Opportunities

### Bugs

1. **File**: `dream-server/extensions/services/dashboard-api/helpers.py:49-76`
   - **Issue**: Token tracking JSON file writes have no file locking — concurrent requests can corrupt data
   - **Fix**: Use `fcntl.flock()` or migrate to SQLite for atomic writes
   - **Effort**: small
   - **PR-worthy**: high

2. **File**: `dream-server/extensions/services/dashboard-api/helpers.py:25-46`
   - **Issue**: Global `_aio_session` and `_httpx_client` never closed on app shutdown
   - **Fix**: Add FastAPI `on_event("shutdown")` handler to close sessions
   - **Effort**: trivial
   - **PR-worthy**: high

### Security Fixes

3. **File**: `dream-server/extensions/services/dashboard-api/Dockerfile:40`, `main.py:496`
   - **Issue**: API server binds to `0.0.0.0` — unnecessary network exposure inside container
   - **Fix**: Change to `127.0.0.1` or add `DASHBOARD_API_HOST` env var defaulting to `127.0.0.1`
   - **Effort**: trivial
   - **PR-worthy**: high

4. **File**: `dream-server/config/searxng/settings.yml:4`
   - **Issue**: SearXNG `bind_address: "0.0.0.0"` unnecessary
   - **Fix**: Change to `127.0.0.1`
   - **Effort**: trivial
   - **PR-worthy**: medium

### Missing Tests

5. **File**: `dream-server/extensions/services/dashboard/src/`
   - **Issue**: Only 6 test files for 7+ React components — insufficient frontend coverage
   - **Fix**: Add tests for SetupWizard, TroubleshootingAssistant, Settings, Voice pages
   - **Effort**: medium
   - **PR-worthy**: medium

6. **File**: `dream-server/extensions/services/dashboard-api/tests/`
   - **Issue**: No concurrent request tests for token tracking, no integration tests with real services
   - **Fix**: Add pytest-asyncio concurrency tests for shared state
   - **Effort**: small
   - **PR-worthy**: medium

### Documentation Gaps

7. **File**: Root level (missing)
   - **Issue**: No `CONTRIBUTING.md` with PR standards, branch naming, test requirements
   - **Fix**: Create contributing guide aligned with existing CI checks
   - **Effort**: small
   - **PR-worthy**: medium

8. **File**: `dream-server/extensions/services/dashboard-api/`
   - **Issue**: No API reference documentation (OpenAPI is auto-generated but not documented)
   - **Fix**: Add endpoint documentation or link to `/docs` Swagger UI
   - **Effort**: small
   - **PR-worthy**: low

### Code Improvements

9. **File**: `dream-server/installers/lib/*.sh` (all library files)
   - **Issue**: Libraries don't enforce `set -euo pipefail` — rely on callers for strict mode
   - **Fix**: Add guard at top of each library: `[[ "${BASH_SOURCE[0]}" == "$0" ]] && set -euo pipefail`
   - **Effort**: small
   - **PR-worthy**: medium

10. **File**: `dream-server/extensions/services/dashboard-api/routers/workflows.py`
    - **Issue**: Hard-coded service alias `_DEP_ALIASES = {"ollama": "llama-server"}` should be config-driven
    - **Fix**: Move to config.py or read from extension manifests
    - **Effort**: small
    - **PR-worthy**: low

11. **File**: `.pre-commit-config.yaml`
    - **Issue**: Only gitleaks + private-key detection — missing linting, formatting, type checking
    - **Fix**: Add black, mypy, shfmt, conventional-commit hooks
    - **Effort**: small
    - **PR-worthy**: medium

### Feature Ideas

12. **Codecov integration** — Add `pytest-cov` reporting to CI with coverage badges
    - **Effort**: small | **PR-worthy**: medium

13. **Rate limiting middleware** for dashboard-api — APE has it, main API doesn't
    - **Effort**: small | **PR-worthy**: medium

14. **Docker secrets support** — Replace env var secrets with Docker secrets for production hardening
    - **Effort**: medium | **PR-worthy**: high

---

## Draft PRs

### PR 1: Fix async session leak and token file race condition

- **PR Title**: `fix: close async sessions on shutdown and add file locking for token tracking`
- **Branch**: `fix/async-session-cleanup`
- **Files**:
  - `dream-server/extensions/services/dashboard-api/helpers.py`
  - `dream-server/extensions/services/dashboard-api/main.py`
  - `dream-server/extensions/services/dashboard-api/tests/test_helpers.py`
- **Changes**:
  1. Add `@app.on_event("shutdown")` handler in `main.py` to close `_aio_session` and `_httpx_client`
  2. Add `fcntl.flock()` around JSON file writes in `helpers.py` token tracking functions
  3. Add test for session cleanup and concurrent write safety
- **Effort**: 1-2 hours
- **Impact**: Prevents connection leaks on restart and data corruption under concurrent API requests — reliability improvement for production deployments

### PR 2: Harden network binding for dashboard-api and SearXNG

- **PR Title**: `fix: bind dashboard-api and searxng to localhost inside containers`
- **Branch**: `fix/localhost-bind-hardening`
- **Files**:
  - `dream-server/extensions/services/dashboard-api/Dockerfile`
  - `dream-server/extensions/services/dashboard-api/main.py`
  - `dream-server/config/searxng/settings.yml`
  - `dream-server/.env.example` (add `DASHBOARD_API_HOST` documentation)
- **Changes**:
  1. Change Dockerfile CMD to use `--host ${DASHBOARD_API_HOST:-127.0.0.1}`
  2. Change `main.py` `__main__` block to default host to `127.0.0.1`
  3. Change SearXNG `bind_address` to `127.0.0.1`
  4. Document new env var in `.env.example`
- **Effort**: 30 minutes
- **Impact**: Eliminates the 2 critical security findings — defense-in-depth network hardening even when compose port binding is correctly configured

### PR 3: Expand pre-commit hooks with linting and formatting

- **PR Title**: `chore: add black, mypy, shfmt, and conventional-commit pre-commit hooks`
- **Branch**: `chore/expand-precommit-hooks`
- **Files**:
  - `.pre-commit-config.yaml`
  - `pyproject.toml` (or `setup.cfg` for mypy config)
- **Changes**:
  1. Add `black` (Python formatter) with version pin
  2. Add `mypy` (type checker) for `dashboard-api/`
  3. Add `shfmt` (shell formatter) for `.sh` files
  4. Add `commitlint` or `conventional-pre-commit` for commit message validation
  5. Add corresponding config sections in `pyproject.toml`
- **Effort**: 1-2 hours
- **Impact**: Catches formatting, typing, and commit message issues before they reach CI — reduces review friction and enforces consistency across 20+ contributors

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 8 |
| Test Coverage | 7 |
| Contribution Potential | 9 |

**Overall**: A well-engineered infrastructure project with strong architectural foundations, comprehensive shell testing, and solid security posture. The main gaps are frontend test coverage, pre-commit automation, and two easily-fixable network binding issues. High contribution potential due to clear structure, good docs, and actionable improvement areas.
