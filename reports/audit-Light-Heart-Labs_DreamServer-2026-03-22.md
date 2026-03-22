# Audit: Light-Heart-Labs/DreamServer

## Repository Overview

Dream Server is a fully local AI stack deploying LLM inference, chat, voice (STT/TTS), AI agents, workflow automation, RAG, image generation, and privacy tools on user hardware with a single command. It supports Linux (NVIDIA + AMD), Windows (WSL2), and macOS (Apple Silicon) through a modular Bash installer that auto-detects GPU hardware and selects appropriate models. The project bundles 19 pre-integrated services (llama-server, Open WebUI, ComfyUI, n8n, Whisper, Kokoro TTS, Qdrant, SearXNG, etc.) orchestrated via Docker Compose with GPU-specific overlays.

**Tech stack:** Bash (installer/CLI ~170 .sh files), Python/FastAPI (dashboard-api, services ~126 .py files), React/Vite/Tailwind (dashboard UI ~80 JS/TS/JSX/TSX files), Docker Compose (layered GPU overlays), YAML manifests (extension system).

**Maturity:** **Growing** — v2.3.3 with active development, comprehensive CI (10 workflows), 350+ tests, modular architecture, but some areas (CLI, frontend) still maturing.

---

## Code Quality Assessment

### Architecture and Organization
**Rating: Excellent**

Clean separation of concerns following "functional core, imperative shell":
- `installers/lib/` — 11 pure-function libraries (no side effects)
- `installers/phases/` — 13 sequential install steps
- `extensions/services/` — 19 manifest-based service extensions
- `scripts/` — 20+ operational scripts
- Standardized module headers (Purpose, Expects, Provides)
- Layered Docker Compose: base + GPU overlay + extension compose files merged by `resolve-compose-stack.sh`

### Error Handling Patterns
**Rating: Very Good**

Follows explicit "Let It Crash > KISS > Pure Functions > SOLID" philosophy:
- Bash: `set -euo pipefail` everywhere, trap handlers for context
- Python: Narrow exception catches at I/O boundaries only, `raise HTTPException` instead of swallowing
- No `eval()`, `exec()`, or `subprocess(shell=True)` anywhere
- Safe env loading via `safe-env.sh` (no shell injection)

### Test Coverage
**Rating: Good but Uneven**

~350+ tests across 4 frameworks (Bash, BATS, pytest, Vitest):
- **Excellent:** GPU detection, tier mapping, API auth, manifest validation (parametrized boundary tests)
- **Good:** Dashboard API routers (191 pytest functions), privacy shield, config loading
- **Weak:** dream-cli (1,963 lines, essentially untested), installer phases (syntax checks only), frontend (4 hook tests, no component/e2e tests)

### Documentation Quality
**Rating: Very Good**

- Comprehensive README (29KB), CLAUDE.md with architecture guide
- `docs/` directory with HOW-DREAM-SERVER-WORKS, EXTENSIONS, INSTALLER-ARCHITECTURE, HARDWARE-GUIDE
- CONTRIBUTING.md, FAQ.md, QUICKSTART.md, CHANGELOG.md
- Standardized module headers in all Bash files
- Missing: API docs (no OpenAPI export), runbook for ops

### Dependency Health
**Rating: Good**

- npm: Modern deps (React 18, Vite 5, Tailwind 3), `package-lock.json` present
- Python: Semver ranges in dashboard-api (good), hard-pinned in APE service (inflexible), **no Python lockfile**
- Docker: Core images pinned (`open-webui:v0.7.2`, `llama.cpp:server-cuda-b8248`), base images float (`nginx:alpine`, `python:3.11-slim`)
- Pre-commit: gitleaks, private key detection, large file checks

---

## Security Findings

### Critical
None found.

### High
None found.

### Medium

| # | Finding | Location |
|---|---------|----------|
| M1 | **Curl-to-shell installation pattern** — Docker installer downloads `get.docker.com` to temp file then executes. While better than piping directly, still susceptible to MITM if HTTPS is compromised. | `dream-server/installers/phases/05-docker.sh:64,89` |
| M2 | **No Python dependency lockfile** — `requirements.txt` uses semver ranges without a lockfile, allowing silent dependency changes between installs. | `dream-server/extensions/services/dashboard-api/requirements.txt` |

### Low

| # | Finding | Location |
|---|---------|----------|
| L1 | **Uvicorn binds to 0.0.0.0** inside container — safe due to Docker network isolation but violates defense-in-depth. | `dream-server/extensions/services/dashboard-api/main.py:528` |
| L2 | **CSP allows 'unsafe-inline'** for styles — mitigated by other headers but weakens XSS protection. | `dream-server/extensions/services/dashboard/nginx.conf:42` |
| L3 | **Auto-generated API key on startup** — if `DASHBOARD_API_KEY` not set, generates a random key written to `/data/dashboard-api-key.txt`. Key changes if file is lost. | `dream-server/extensions/services/dashboard-api/security.py:15-22` |
| L4 | **Floating base Docker images** — `nginx:alpine` and `python:3.11-slim` don't use SHA digests, allowing uncontrolled updates. | `dream-server/extensions/services/dashboard-api/Dockerfile`, `dashboard/Dockerfile` |

### Info

| # | Finding | Location |
|---|---------|----------|
| I1 | **Pre-commit hooks well configured** — gitleaks v8.21.2, private key detection, large file checks (500KB limit). | `.pre-commit-config.yaml` |
| I2 | **All ports bound to 127.0.0.1** by default — excellent localhost-only security posture. | `dream-server/docker-compose.base.yml` |
| I3 | **Non-root containers** with `no-new-privileges:true` — proper container hardening. | `docker-compose.base.yml`, `dashboard-api/Dockerfile` |
| I4 | **Timing-safe auth comparison** — `secrets.compare_digest()` prevents timing attacks. | `dashboard-api/security.py` |

---

## Contribution Opportunities

### Bugs

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| B1 | `dashboard-api/security.py:15-22` | API key regenerated on every restart if env var unset and file lost | Read persisted key from file on startup before generating new one | trivial | medium |

### Security Fixes

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| S1 | `dashboard-api/main.py:528` | Uvicorn binds `0.0.0.0` inside container | Change to `127.0.0.1`; Docker port mapping handles external access | trivial | low |
| S2 | `dashboard-api/requirements.txt` | No dependency lockfile | Add `pip-compile` or `poetry.lock` generation to CI | small | high |
| S3 | `dashboard-api/Dockerfile:1`, `dashboard/Dockerfile:1` | Floating base image tags | Pin with SHA256 digests | trivial | medium |
| S4 | `dashboard/nginx.conf:42` | CSP `'unsafe-inline'` for styles | Use nonce-based or hash-based CSP for inline styles | medium | medium |

### Missing Tests

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| T1 | `dream-server/dream-cli` | 1,963-line CLI with no unit tests | Add BATS tests for subcommand parsing, option handling, version comparison | large | high |
| T2 | `installers/phases/*.sh` | 13 installer phases with no functional tests | Add BATS tests for each phase (mock system calls) | large | high |
| T3 | `extensions/services/dashboard/src/` | Only 4 hook tests, no component tests | Add Vitest component tests for SetupWizard, FeatureDiscovery, PreFlightChecks | medium | high |
| T4 | `scripts/resolve-compose-stack.sh` | Minimal testing of compose resolution | Add tests for overlay merging, extension discovery failures, edge cases | small | medium |
| T5 | `dashboard-api/tests/` | No error path tests (timeouts, disk full, permission denied) | Add parametrized tests for I/O failure scenarios | small | medium |

### Documentation Gaps

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| D1 | `dream-server/extensions/services/dashboard-api/` | No OpenAPI/Swagger export or API docs | Add `/docs` endpoint to FastAPI (it's built-in, just needs enabling) | trivial | high |
| D2 | Root | No security hardening guide for production deployments | Create `docs/SECURITY-HARDENING.md` covering API keys, network exposure, reverse proxy | small | medium |
| D3 | `dream-server/dream-cli` | No `--help` documentation for all subcommands | Add comprehensive `--help` output per subcommand | medium | medium |

### Code Improvements

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| C1 | `dream-server/dream-cli` | Single 1,963-line file handles all CLI logic | Split into `lib/cli-*.sh` modules (status, model, service, config) | medium | high |
| C2 | `extensions/services/ape/requirements.txt` | Hard-pinned versions prevent security patches | Switch to semver ranges consistent with dashboard-api pattern | trivial | low |
| C3 | `extensions/services/dashboard-api/` | Inconsistent version management — version hardcoded in multiple places | Single source of truth via `__version__` in package or `.version` file | small | medium |

### Feature Ideas

| # | Description | Impact | Effort |
|---|-------------|--------|--------|
| F1 | **Dependency update bot** — Add Dependabot or Renovate config for automated PR creation on dep updates | Keeps dependencies current, reduces CVE window | trivial |
| F2 | **Test coverage reporting** — pytest-cov exists in CI but coverage not published; add Codecov/Coveralls integration | Visibility into coverage gaps | small |
| F3 | **E2E test suite** — Playwright or Cypress tests for dashboard UI against mocked API | Catches integration regressions | large |

---

## Draft PRs

### PR #1: Add Python dependency lockfile and pin Docker base images

- **PR Title:** `fix(deps): add Python dependency lockfile and pin Docker base images`
- **Branch:** `fix/pin-dependencies`
- **Files:**
  - `dream-server/extensions/services/dashboard-api/requirements.txt` (add pip-tools constraint)
  - `dream-server/extensions/services/dashboard-api/requirements-lock.txt` (new — generated)
  - `dream-server/extensions/services/dashboard-api/Dockerfile` (pin `python:3.11-slim@sha256:...`)
  - `dream-server/extensions/services/dashboard/Dockerfile` (pin `node:20-alpine@sha256:...`, `nginx:alpine@sha256:...`)
  - `.github/workflows/dashboard.yml` (add `pip-compile --generate-hashes` check)
- **Changes:** Generate a locked requirements file using `pip-compile` from pip-tools. Update Dockerfiles to use SHA256 digests for base images. Add CI step to verify lockfile is up-to-date.
- **Effort:** ~1-2 hours
- **Impact:** Eliminates supply chain risk from floating Python deps and Docker base images. Ensures reproducible builds across environments.

### PR #2: Add BATS unit tests for dream-cli core functions

- **PR Title:** `test(cli): add BATS unit tests for dream-cli subcommands`
- **Branch:** `test/cli-unit-tests`
- **Files:**
  - `dream-server/tests/bats-tests/dream-cli.bats` (new — 200-400 lines)
  - `dream-server/tests/bats-tests/dream-cli-model.bats` (new)
  - `dream-server/tests/bats-tests/dream-cli-service.bats` (new)
  - `dream-server/Makefile` (add `bats-cli` target)
  - `.github/workflows/test-linux.yml` (add CLI BATS step)
- **Changes:** Create BATS test suites for dream-cli's pure functions: version comparison (`_semver_lt`, `_semver_major`), JSON extraction (`_jq`), service resolution, status parsing. Mock Docker/compose calls. Add to CI pipeline.
- **Effort:** ~4-6 hours
- **Impact:** The CLI is the primary user interface (1,963 lines) with zero test coverage. Any regression in subcommand parsing or version logic silently breaks the user experience.

### PR #3: Enable FastAPI OpenAPI docs and add dashboard component tests

- **PR Title:** `feat(dashboard): enable API docs and add component tests`
- **Branch:** `feat/dashboard-testing-docs`
- **Files:**
  - `dream-server/extensions/services/dashboard-api/main.py` (enable `/docs` endpoint)
  - `dream-server/extensions/services/dashboard/src/test/SetupWizard.test.jsx` (new)
  - `dream-server/extensions/services/dashboard/src/test/FeatureDiscovery.test.jsx` (new)
  - `dream-server/extensions/services/dashboard/src/test/PreFlightChecks.test.jsx` (new)
  - `dream-server/extensions/services/dashboard/vitest.config.js` (add coverage config)
  - `.github/workflows/dashboard.yml` (add coverage reporting)
- **Changes:** FastAPI has built-in OpenAPI/Swagger UI — just ensure `docs_url="/docs"` is set (may already be, just needs verification and documentation). Add Vitest component tests for the three most critical dashboard pages using React Testing Library with mocked API responses. Add coverage threshold to CI.
- **Effort:** ~3-5 hours
- **Impact:** API documentation enables third-party integrations and contributor onboarding. Component tests cover the primary user-facing surfaces that currently have zero coverage.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 7 |
| Test Coverage | 6 |
| Contribution Potential | 9 |

**Summary:** DreamServer is a well-architected, actively developed project with strong design principles and good security posture for a local AI stack. The main gaps are in test coverage (CLI and frontend untested), dependency pinning (no Python lockfile), and documentation (no API docs). The modular extension system and clear contribution guidelines make it highly approachable for contributors. The codebase is production-quality in its core installer and API layers, with room for improvement in testing breadth.
