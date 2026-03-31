Now I have everything I need. Let me compile the report.

---

# Marketing Audit: redhat-community-ai-tools/UnifAI

## Quick Overview

UnifAI is a platform for building and running multi-agent AI workflows over enterprise knowledge. It connects internal data sources (Slack, Jira, documents) into a unified vector store, then queries them through composable, visual multi-agent pipelines defined as YAML blueprints or via a drag-and-drop UI. Execution runs locally (LangGraph) or distributed (Temporal) with real-time NDJSON streaming.

**Tech stack:**
- **Backend:** Python 3.11+, Flask, LangChain/LangGraph, Temporal, Celery, Pydantic
- **Frontend:** React 18, TypeScript, Vite, Tailwind, Radix UI, Zustand, React Flow
- **Infrastructure:** MongoDB, Qdrant, RabbitMQ, Redis, Keycloak, Helm/OpenShift
- **CI:** GitHub Actions (6 workflows), Jenkins, CodeRabbit

**Activity level:** Very active -- 30+ commits in the last 8 days, 6 open PRs, PRs merged within 1-2 days. Internal Red Hat team using GENIE ticket tracking. ~2-3 core contributors.

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **No CONTRIBUTING.md** | Zero contribution guidelines despite README saying contributions are welcome |
| **No .env.example** | 20+ env vars across 3 services with zero template files |
| **No docker-compose.yml** | Local dev requires manually running 6+ services -- no compose file exists |
| **Typo in workflow filename** | `security-container-vulerability-scanning.yaml` -- "vulerability" should be "vulnerability" |
| **README typo** | Commit `8212f05` title: "improvments" -> "improvements" |
| **No badges in README** | No license badge, no CI status badges, no Python/Node version badges |

### 2. Code Quality

| Item | Details |
|------|---------|
| **79 print() calls in multi-agent/lib** | Production code using `print()` instead of `logging` (especially `policies.py` with 30 occurrences) |
| **19 print() calls in rag/** | HTTP blueprint handlers using print for debugging |
| **No ESLint config** | Frontend has zero linting configuration checked in |
| **No Prettier config** | No code formatting enforcement |
| **Security workflow disabled** | Container scanning only runs on `workflow_dispatch`, PR trigger commented out |
| **Trivy exit-code 0** | Vulnerability scanner set to never fail (TODO in code to switch to exit-code 1) |

### 3. Tests

| Item | Details |
|------|---------|
| **Zero frontend tests** | No `.test.ts`, `.test.tsx`, or `__tests__` directory in `ui/` |
| **No test script in package.json** | `ui/package.json` has no `test` script at all |
| **No RAG tests** | `rag/` module has no test directory or test files |
| **No backend tests** | `backend/` module has no test directory |
| **Multi-agent tests exist** | Good coverage with unit/integration/e2e/chaos -- this is the exception |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No lint CI workflow** | No Python linting (ruff/flake8) or frontend linting in CI |
| **No type-check CI** | No `tsc --noEmit` or `mypy` in any workflow |
| **No test CI workflow** | No workflow runs pytest or any test suite on PR |
| **Missing badges** | README has no CI status, license, or version badges |
| **PR trigger disabled on security scan** | Lines 3-8 of security workflow are commented out |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **No docker-compose.yml** | Biggest DX gap -- requires 6+ manual service setups for local dev |
| **No Makefile or task runner** | No unified entry point for common dev operations |
| **No pre-commit hooks** | No `.pre-commit-config.yaml` for linting/formatting |
| **Missing pyproject.toml for rag/** | RAG uses legacy `setup.py` while multi-agent uses modern `pyproject.toml` |

---

## Draft PRs

### PR #1: Add .env.example files for all services

- **PR Title:** `docs: add .env.example templates for all services`
- **Branch:** `docs/env-example-templates`
- **Files to change:**
  - Create `multi-agent/.env.example` (ENGINE_NAME, MONGODB_IP, MONGODB_PORT, TEMPORAL_HOST, TEMPORAL_NAMESPACE, TEMPORAL_TASK_QUEUE, REDIS_URL, REDIS_STREAM_TTL)
  - Create `rag/.env.example` (MONGODB_IP, MONGODB_PORT, MONGO_DB, QDRANT_IP, QDRANT_PORT, RABBITMQ_IP, USE_REMOTE_DOCLING, DOCLING_SERVICE_URL, USE_REMOTE_EMBEDDING, EMBEDDING_SERVICE_URL, EMBEDDING_SERVICE_MODEL, EMBEDDING_DIM, PORT, UPLOAD_FOLDER)
  - Create `ui/.env.example` (RAG_HOST, MULTIAGENT_HOST, NODE_ENV)
  - Create `backend/.env.example` (MONGODB_IP, MONGODB_PORT, PORT)
- **Changes:** Extract all env var references from config files and READMEs, create commented `.env.example` with sensible defaults
- **Effort:** 30 minutes
- **Merge likelihood:** **HIGH** -- zero-risk, universally appreciated, fills obvious gap

### PR #2: Add CONTRIBUTING.md and README badges

- **PR Title:** `docs: add CONTRIBUTING.md and README badges`
- **Branch:** `docs/contributing-and-badges`
- **Files to change:**
  - Create `CONTRIBUTING.md` (prerequisites, setup steps, PR guidelines, code style, issue templates)
  - Edit `README.md` -- add badges at top (Apache-2.0 license, Python 3.11+, TypeScript, PRs Welcome)
- **Changes:** Standard contributing guide following Red Hat community patterns. Badges using shields.io.
- **Effort:** 45 minutes
- **Merge likelihood:** **HIGH** -- essential for any open-source project, especially one from Red Hat that explicitly welcomes contributions

### PR #3: Replace print() with logging in multi-agent service

- **PR Title:** `fix: replace print() with proper logging in multi-agent lib`
- **Branch:** `fix/print-to-logging`
- **Files to change:**
  - `multi-agent/lib/mas/elements/tools/common/execution/policies.py` (30 print calls)
  - `multi-agent/lib/mas/elements/tools/common/execution/executor.py` (5 print calls)
  - `multi-agent/lib/mas/templates/service.py` (4 print calls)
  - `multi-agent/lib/mas/actions/registry/action_discoverer.py` (4 print calls)
  - ~15 other files with 1-3 print calls each
- **Changes:** Import `logging`, create module-level `logger = logging.getLogger(__name__)`, replace `print()` with appropriate `logger.info()` / `logger.debug()` / `logger.error()`. Matches existing TODOs asking for "proper logging system."
- **Effort:** 1-2 hours
- **Merge likelihood:** **HIGH** -- addresses explicit TODOs in code, standard practice, improves observability in production

---

## Notes

- **Active maintainers**: Team is actively merging PRs (last merge: March 30). Response time appears to be 1-2 days.
- **Internal project going open-source**: Uses GENIE ticket IDs (likely Jira), suggesting this is a Red Hat internal project opened to the community. Contributions that help "externalize" the project (docs, DX, env templates) will be especially welcome.
- **No external contributors yet**: All PRs come from the `redhat-community-ai-tools` org. Being an early external contributor gives high visibility.
- **Best approach**: Start with PR #1 (.env.example) -- it's non-controversial, immediately useful, and demonstrates you understand the codebase. Follow up with CONTRIBUTING.md to establish yourself as a community member.
- **Red flag**: The zero frontend/RAG/backend test coverage is notable but too large to tackle as a quick PR. Mention it in an issue instead.
- **Typo in CI filename** (`vulerability`) is a trivial fix but shows attention to detail -- could be bundled with PR #2.
