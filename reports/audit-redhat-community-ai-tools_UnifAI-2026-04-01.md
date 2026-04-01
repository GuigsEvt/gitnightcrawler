Here's the full audit report:

---

# Marketing Audit: redhat-community-ai-tools/UnifAI

## Quick Overview

UnifAI is a production-grade platform for building and running multi-agent AI workflows over enterprise knowledge. It lets teams ingest data from Slack, Jira, and documents into a vector store (Qdrant), then query them through composable agent pipelines defined as YAML blueprints or built with a visual drag-and-drop UI. Supports local execution (LangGraph) or distributed (Temporal), with A2A and MCP protocol support.

**Tech stack:** Python 3.11+ (Flask, LangGraph, Temporal, Celery), React 18 + TypeScript + Vite + Tailwind, MongoDB, Qdrant, Redis, RabbitMQ, Keycloak, Helm/OpenShift

**Activity level:** 722 commits in last ~4 months. PRs merged within 1-6 days. 34 stars, 11 forks. 5-6 active contributors (Odai Odeh, Nir Rashti, MayaCrmi, Lina-AbuYousef, yhabushi79, sfiresht). Very active -- last merge was yesterday (2026-03-31). 2 open issues (#69, #70) both about auth -- matches TODOs in code.

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **Missing CONTRIBUTING.md** | No contributing guide at all. README says "Contributions are welcome!" but gives no guidance on how to contribute, code style, PR process, or CoC |
| **Missing issue/PR templates** | No `.github/ISSUE_TEMPLATE/` or `.github/PULL_REQUEST_TEMPLATE.md` |
| **README gaps** | No badges (CI status, license, Python version, npm). No "Getting Help" or "Community" section. No link to issues page |
| **Missing env example** | No `.env.example` files for any service -- new contributors have to guess environment variables |
| **Project structure typo** | README shows `sessions/` in project tree but actual dir is `session/` (no s) |

### 2. Code Quality

| Item | Details |
|------|---------|
| **No Python linter config** | No ruff.toml, .flake8, pyproject.toml [tool.ruff], or black config. Zero linting enforcement |
| **No JS linter config** | No .eslintrc, .prettierrc, or biome config for the React/TS frontend |
| **Print statements in prod code** | `multi-agent/run/scripts/main.py:182-183`, `multi-agent/lib/mas/catalog/spec_discoverer.py:144` -- should use logging |
| **22+ TODO/FIXME comments** | Scattered across `multi-agent/lib/mas/core/iem/utils.py` (8 TODOs), `multi-agent/adapters/inbound/flask/endpoints/` (4 auth TODOs), `rag/bootstrap/app_container.py` (2), MCP tool_registry (4), and others |
| **Hardcoded URLs/IPs** | `multi-agent/run/scripts/main.py:204,262` has hardcoded `10.46.254.131`, `multi-agent/adapters/inbound/flask/endpoints/actions.py:93` has `localhost:3000/sse`, `global_utils/src/global_utils/docling/client.py:33` has `docling-service:5001` |
| **No py.typed marker** | `multi-agent` publishes as a package but has no `py.typed` for PEP 561 compliance |

### 3. Tests

| Item | Details |
|------|---------|
| **Tests only for multi-agent** | `multi-agent/tests/` has a good structure (unit, integration, e2e, chaos, perf). But `rag/`, `backend/`, `global_utils/`, and `ui/` have **zero test files** |
| **No frontend tests** | No jest/vitest config, no `*.test.tsx` files anywhere in `ui/` |
| **No test CI workflow** | None of the 6 GitHub Actions workflows run pytest or any test suite |
| **Missing pytest in CI** | `pyproject.toml` has pytest config but no CI job triggers it |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No test workflow** | No GHA workflow runs `pytest` or `pnpm test` |
| **No lint workflow** | No GHA workflow runs any linter (Python or JS) |
| **No build check workflow** | No GHA verifies `pnpm build` succeeds for the UI |
| **Missing badges** | README has no CI status badge, license badge, Python version badge, or code coverage badge |
| **No Dependabot** | No `.github/dependabot.yml` for automated dependency updates |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **No docker-compose.yml** | Individual Dockerfiles exist but no compose file to spin up the full stack locally. README Quick Start assumes you manually install MongoDB, Qdrant, etc. |
| **No .env.example** | New contributors have no reference for required env vars |
| **No Makefile / task runner** | Each service has different run commands; a root Makefile or `justfile` would unify DX |
| **No pre-commit hooks** | No `.pre-commit-config.yaml` despite multiple Python projects |

---

## Draft PRs

### PR 1: Add CONTRIBUTING.md, issue templates, and PR template

- **PR Title:** `docs: add CONTRIBUTING.md, issue templates, and PR template`
- **Branch:** `docs/contributing-guide`
- **Files to change:**
  - Create `CONTRIBUTING.md` (development setup, code style, PR process, issue reporting)
  - Create `.github/ISSUE_TEMPLATE/bug_report.md`
  - Create `.github/ISSUE_TEMPLATE/feature_request.md`
  - Create `.github/PULL_REQUEST_TEMPLATE.md`
- **Changes:** Standard open-source contribution infrastructure. The CONTRIBUTING.md should reference the module-specific ARCHITECTURE.md files and the hexagonal architecture pattern used in multi-agent and rag. Issue templates should include sections for module affected, expected behavior, and reproduction steps.
- **Effort:** 30-45 minutes
- **Merge likelihood:** **HIGH** -- README explicitly says "Contributions are welcome!" but provides zero guidance. This is table-stakes for any open-source project. Red Hat projects typically have these.

### PR 2: Add README badges and .env.example files

- **PR Title:** `docs: add badges to README and .env.example files for all services`
- **Branch:** `docs/badges-and-env-examples`
- **Files to change:**
  - Edit `README.md` -- add badges (License: Apache 2.0, Python 3.11+, Node 22+, TypeScript, PRs Welcome)
  - Create `multi-agent/.env.example` (ENGINE_NAME, MONGODB_IP, REDIS_IP, TEMPORAL_IP, etc. -- derive from `global_utils/src/global_utils/config/config.py` defaults)
  - Create `rag/.env.example` (MONGODB_IP, QDRANT_HOST, CELERY_BROKER, etc.)
  - Create `ui/.env.example` (VITE_API_URL, etc.)
- **Changes:** Badges add visual credibility. Env examples eliminate the #1 friction point for new contributors. Extract all env vars from config files and Dockerfiles.
- **Effort:** 45 minutes
- **Merge likelihood:** **HIGH** -- zero risk, pure DX improvement, addresses real onboarding friction

### PR 3: Add docker-compose.yml for local development

- **PR Title:** `feat: add docker-compose for local development stack`
- **Branch:** `feat/docker-compose-dev`
- **Files to change:**
  - Create `docker-compose.yml` (MongoDB, Qdrant, Redis, RabbitMQ + optionally the app services)
  - Edit `README.md` Quick Start section to reference compose file
- **Changes:** Define services for the shared infrastructure (MongoDB, Qdrant, Redis, RabbitMQ) so `docker compose up` gives you a working backend. Each service already has a Dockerfile. Map ports matching the defaults in config files (MongoDB 27017, Qdrant 6333, Redis 6379, RabbitMQ 5672).
- **Effort:** 1-2 hours
- **Merge likelihood:** **HIGH** -- the Quick Start section assumes you have MongoDB and Qdrant running but gives no guidance on setting them up. This is the most impactful DX improvement possible. Helm charts exist for production but nothing for local dev.

---

## Notes

- **Active and responsive maintainers** -- PRs merged within days, multiple merges per week. No red flags.
- **Red Hat-backed** -- project uses GENIE ticket prefixes (internal Jira), UBI9 base images, OpenShift-native Helm charts. Likely has corporate backing and standards.
- **Best approach:** Start with PR 1 (CONTRIBUTING.md) as it establishes you as a thoughtful contributor. Follow with PR 2 (badges + env examples) and PR 3 (docker-compose). All are non-controversial, additive-only changes.
- **Open issues #69 and #70** both request auth checks on endpoints -- matches the 4 TODO comments in `multi-agent/adapters/inbound/flask/endpoints/`. These would be medium-effort PRs but directly address filed issues.
- **No external contributor PRs yet** -- all PRs are from the core team. Being an early external contributor increases visibility.
- **Commit messages are informal** -- "odai comment", "fix", "port updated". A linting/conventional-commits PR would be valuable but might be culturally sensitive -- gauge after initial contributions.
