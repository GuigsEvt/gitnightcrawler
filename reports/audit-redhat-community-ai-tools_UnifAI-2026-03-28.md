Now I have everything needed for the report.

# Marketing Audit: redhat-community-ai-tools/UnifAI

## Quick Overview

UnifAI is a production-grade multi-agent AI orchestration platform by Red Hat community contributors. It lets teams connect enterprise data sources (Slack, Jira, PDFs) into a unified vector store, then query them through composable, visual multi-agent pipelines defined as YAML blueprints or via a drag-and-drop UI. Supports LangGraph (local) and Temporal (distributed) execution, RAG ingestion, A2A and MCP protocols, and real-time NDJSON streaming.

**Tech stack:** Python 3.11+ (Flask, LangGraph, Temporal, Celery), React 18 + TypeScript (Vite, Tailwind, Radix UI), MongoDB, Qdrant, Redis, RabbitMQ, Keycloak, Helm/OpenShift.

**Activity level:** ~1000 commits since Jan 2025. 33 stars, 11 forks. 7 open PRs, 2 open issues. Active development with PRs being merged regularly (last merge Mar 17). Repo created Nov 2025. Maintainers: @oodeh, @nirsisr (per CODEOWNERS). PRs use JIRA-style branch naming (GENIE-XXXX).

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **No CONTRIBUTING.md** | README says "Contributions are welcome!" but there's no dedicated file with guidelines, coding standards, PR process, or development setup |
| **No .env.example files** | All 4 Python services (multi-agent, rag, backend, sso-backend) require env vars but provide zero templates. RAG README even says "Create a `.env` file" with no example |
| **No README badges** | Zero badges for license, build status, Python version, Node version |
| **No SECURITY.md** | No security vulnerability reporting policy |
| **No CODE_OF_CONDUCT.md** | Standard for Red Hat open-source projects |
| **Missing docker-compose** | No local dev compose file despite 5+ services. Only Helm charts exist |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **No Python linting config** | No ruff, flake8, black, isort, or pylint configuration anywhere |
| **No JS/TS linting** | No eslint or prettier config. `ui/package.json` has no lint scripts |
| **No type checking** | No mypy or pyright config for Python; no strict TS checking |
| **No pre-commit hooks** | No `.pre-commit-config.yaml` |
| **16+ TODO/FIXME comments** | Including 4x `# TODO: Add authorization check` in API endpoints (`multi-agent/adapters/inbound/flask/endpoints/`) and debug print statements in `orchestrator_phase_provider.py` |

### 3. Tests

| Issue | Details |
|-------|---------|
| **RAG module: 0 tests** | Entire `rag/` module has no test files whatsoever |
| **Backend module: 0 tests** | Entire `backend/` module has no test files |
| **UI: 0 tests** | No jest/vitest setup, no test files for React components |
| **Multi-agent has tests** | Good test infra exists here (50+ files, pytest configured) -- could serve as template |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **No test workflow** | No GitHub Actions for pytest, jest, or vitest on PR/push |
| **No lint workflow** | No CI linting enforcement |
| **Pip audit mostly commented out** | `security-pip-auditing.yaml` has most content commented out |
| **Typo in workflow filename** | `security-container-vulerability-scanning.yaml` (missing 'n' in vulnerability) |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **No docker-compose.yml** | Contributors must manually run 5+ services + MongoDB + Qdrant + RabbitMQ |
| **No Makefile** | No centralized `make dev`, `make test`, `make lint` commands |
| **Quick Start gaps** | Backend module not mentioned in Quick Start. No mention of required env vars |

---

## Draft PRs

### PR #1: Add .env.example files for all services

- **PR Title:** `docs: add .env.example files for all service modules`
- **Branch:** `docs/add-env-examples`
- **Files to change:**
  - Create `multi-agent/.env.example` (extract from `multi-agent/config/app_config.py` and README)
  - Create `rag/.env.example` (extract from `rag/config/` and `rag/infrastructure/config/`)
  - Create `backend/.env.example` (extract from `backend/config/app_config.py`)
  - Create `shared-resources/sso-backend/.env.example`
- **Changes:** Document all required and optional environment variables with sensible defaults and comments. Reference these files from each module's README.
- **Effort:** 1-2 hours
- **Merge likelihood:** **HIGH** -- Zero-risk improvement, makes onboarding much easier. Directly addresses a gap the RAG README already acknowledges.

### PR #2: Add CONTRIBUTING.md and community docs

- **PR Title:** `docs: add CONTRIBUTING.md, SECURITY.md, and CODE_OF_CONDUCT.md`
- **Branch:** `docs/community-guidelines`
- **Files to change:**
  - Create `CONTRIBUTING.md` -- dev setup, PR process, coding standards, element extension guide
  - Create `SECURITY.md` -- vulnerability reporting policy
  - Create `CODE_OF_CONDUCT.md` -- standard Contributor Covenant (common for Red Hat projects)
  - Update `README.md` -- add badges (license, Python version, Node version) and link to CONTRIBUTING.md
- **Changes:** Standard open-source community files. CONTRIBUTING.md should reference the existing module READMEs and describe how to add new elements (nodes, tools, LLMs, retrievers) since the README already mentions this is modular.
- **Effort:** 1-2 hours
- **Merge likelihood:** **HIGH** -- Standard practice for Red Hat open-source projects. The README already invites contributions but provides no structure.

### PR #3: Add Python linting with ruff + CI workflow

- **PR Title:** `chore: add ruff linting configuration and CI workflow`
- **Branch:** `chore/add-ruff-linting`
- **Files to change:**
  - Create `ruff.toml` at repo root (or add `[tool.ruff]` to `multi-agent/pyproject.toml`)
  - Create `.github/workflows/lint.yaml` -- run ruff on PR for all Python modules
  - Add `ruff` to dev dependencies
- **Changes:** Configure ruff with sensible defaults (line length 120, target Python 3.11, select E/F/W/I rules). Start with `--fix` auto-fixable rules only. Add a GitHub Actions workflow that runs on pull_request for `.py` files. Fix any existing violations that are auto-fixable.
- **Effort:** 2-3 hours (including fixing auto-fixable violations)
- **Merge likelihood:** **MEDIUM-HIGH** -- ruff is fast and non-disruptive. Start conservative (few rules) and expand. The team uses CodeRabbit for reviews already, showing they value automated quality checks.

---

## Notes

- **Active project**: 1000+ commits in ~4 months, PRs merged regularly. Not abandoned.
- **Internal-first development**: Branch naming (GENIE-XXXX) suggests JIRA-tracked internal project recently open-sourced. Contribution norms may still be forming.
- **CODEOWNERS enforced**: PRs need approval from @oodeh or @nirsisr (plus others per module). Expect reviews within a few days.
- **CodeRabbit enabled**: AI code review bot active on PRs -- your PR will get automated feedback.
- **Red flag -- commit quality**: Recent commits have vague messages ("deleted", "fix", "port updated"). This is normal for internal projects that recently went public.
- **Best approach**: Start with documentation PRs (env examples, CONTRIBUTING.md) as they're zero-risk and demonstrate understanding of the project. Follow up with linting/CI after building trust with maintainers.
- **Workflow filename typo** (`security-container-vulerability-scanning.yaml`) is a trivial fix that could be bundled into a CI improvement PR.
