Now I have all the data needed. Here's the report:

---

# Marketing Audit: redhat-community-ai-tools/UnifAI

## Quick Overview

UnifAI is a platform for building and running multi-agent AI workflows over enterprise knowledge. It provides a visual blueprint builder for composing agent graphs (LangGraph or Temporal execution), a RAG pipeline for document ingestion/search (MongoDB, Qdrant, RabbitMQ), and a React 18 frontend. It's designed for OpenShift/Kubernetes deployment via Helm charts, with Keycloak SSO integration.

**Tech stack:** Python 3.11+ (Flask, LangGraph, Temporal, Celery), React 18 / TypeScript (Vite, Radix UI, Zustand), MongoDB, Qdrant, RabbitMQ, Redis, Keycloak, Helm/OpenShift

**Activity level:** ~1,002 commits since Jan 2025. 13 open PRs, 7 merged in the last 2 weeks. PRs merge within days. Uses JIRA-style tracking (GENIE-xxxx). Very active, fast-moving project.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Severity |
|-------|----------|----------|
| **No CONTRIBUTING.md** | Root | High |
| **No CODE_OF_CONDUCT.md** | Root | Medium |
| **No SECURITY.md** | Root | Medium |
| **LICENSE not referenced in README** | `README.md` line 289 (end of file, no license section) | Low |
| **RAG README missing env vars table** | `rag/README.md` lines 76-80 — section header present but no content follows | High |
| **No .env.example files** for any service | `backend/`, `multi-agent/`, `rag/` | High |
| **SSO Backend README incomplete** | `shared-resources/sso-backend/README.md` — only 30 lines, no setup instructions | Medium |
| **Contributing section is a stub** | `README.md` lines 287-289 — generic one-liner, no link to guidelines | Low |

### 2. Code Quality

| Issue | Location | Count |
|-------|----------|-------|
| **No linting config** (ruff/flake8/black/isort) | Entire repo | - |
| **Bare except clauses** | `multi-agent/lib/mas/elements/tools/ssh_exec/ssh_exec.py`, `multi-agent/lib/mas/elements/nodes/common/agent/phases/unified_phase_provider.py`, test files | 7 |
| **Unpinned requirements.txt** | `backend/requirements.txt` (0 pins), `multi-agent/requirements.txt` (0 pins), `global_utils/requirements.txt` (0 pins) | 3 files |
| **TODO/FIXME comments** | Scattered across `rag/`, `multi-agent/`, `global_utils/` | 23+ |
| **print() instead of logging** | `.github/scripts/backup_qdrant.py`, `scripts/migrate_mcp_endpoint.py` | 31+ |
| **Commented-out code** | `backup_qdrant.py`, `tool_registry.py` | Multiple |

### 3. Tests

| Issue | Location |
|-------|----------|
| **No test infrastructure for backend** | `backend/` has zero test files |
| **No test infrastructure for RAG** | `rag/` has zero test files |
| **No test infrastructure for UI** | `ui/` has zero test files (no vitest/jest config) |
| **No pytest in backend requirements** | `backend/requirements.txt` |
| Multi-agent has good test infra | `multi-agent/tests/` (unit, integration, e2e, chaos, performance) |

### 4. CI/CD

| Issue | Location |
|-------|----------|
| **Workflow filename typo** | `security-container-vulerability-scanning.yaml` should be `vulnerability` | 
| **No Python linting CI** | No ruff/flake8 workflow |
| **No test runner CI** | No pytest workflow for any module |
| **No TypeScript/ESLint CI** | No frontend CI workflow |
| **Missing repo badges** | `README.md` — no CI status, license, Python version, or coverage badges |
| **Trivy exit-code: '0'** | `security-container-vulerability-scanning.yaml:74` — scans never fail (TODO in code) |
| **vulnerability-scan runs-on: linux** | Line 19 — should likely be `ubuntu-latest` |

### 5. DX Improvements

| Issue | Location |
|-------|----------|
| **No Makefile or docker-compose for local dev** | Root — each service has a Dockerfile but no orchestration for local development |
| **No pre-commit hooks config** | No `.pre-commit-config.yaml` |
| **No editorconfig** | No `.editorconfig` for consistent formatting |

---

## Draft PRs

### PR #1: Add CONTRIBUTING.md, LICENSE badge, and community governance files

- **PR Title:** `docs: add CONTRIBUTING.md, CODE_OF_CONDUCT.md, and SECURITY.md`
- **Branch:** `docs/community-governance`
- **Files to change:**
  - Create `CONTRIBUTING.md` — development setup, PR guidelines, code style, issue reporting (reference existing ARCHITECTURE.md files and GENIE issue tracking)
  - Create `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1
  - Create `SECURITY.md` — vulnerability disclosure via Red Hat's security process
  - Edit `README.md` — add license badge at top, link Contributing section to CONTRIBUTING.md
- **Changes:** Add standard OSS governance files. The Contributing section at line 287-289 gets expanded with a link to the new file. Add Apache 2.0 badge in README header.
- **Effort:** 30-45 minutes
- **Merge likelihood:** **High** — standard OSS hygiene, zero risk, Red Hat projects typically expect these files

### PR #2: Add .env.example files for all services

- **PR Title:** `docs: add .env.example templates for backend, multi-agent, and rag`
- **Branch:** `docs/env-examples`
- **Files to change:**
  - Create `backend/.env.example` — variables from `backend/README.md` (MONGO_DB, PORT, RAG_URL, etc.)
  - Create `multi-agent/.env.example` — variables from `multi-agent/README.md` (MONGODB_IP, ENGINE_NAME, TEMPORAL_HOST, etc.)
  - Create `rag/.env.example` — variables extracted from `rag/bootstrap/app_container.py` and README (MONGODB_IP, QDRANT_IP, RABBITMQ_IP, PORT, etc.)
  - Fix `rag/README.md` lines 76-80 — fill in the empty environment variables table
- **Changes:** Each .env.example has commented variables with descriptions and safe defaults. RAG README gets its missing env var documentation filled in.
- **Effort:** 30-45 minutes
- **Merge likelihood:** **High** — improves onboarding, no code changes, fixes a documented gap

### PR #3: Add ruff linting configuration and fix bare except clauses

- **PR Title:** `chore: add ruff linting config and fix bare except clauses`
- **Branch:** `chore/add-ruff-linting`
- **Files to change:**
  - Create `pyproject.toml` at root (or add `[tool.ruff]` section) — configure line-length, target Python 3.11, enable pyflakes/pycodestyle/isort rules
  - Edit `multi-agent/lib/mas/elements/tools/ssh_exec/ssh_exec.py` — replace 3 bare `except:` with `except Exception:`
  - Edit `multi-agent/lib/mas/elements/nodes/common/agent/phases/unified_phase_provider.py` — replace bare `except:` with `except Exception:`
  - Edit test files with bare excepts similarly
- **Changes:** Add ruff config targeting minimal, non-breaking rules (E, F, I for starters). Fix the 7 bare except clauses to catch `Exception` instead. Don't auto-fix everything — keep scope narrow.
- **Effort:** 1 hour
- **Merge likelihood:** **Medium-High** — linting config is valuable for a growing project, but maintainers may want to customize rules. Keep PR small and focused.

---

## Notes

- **Active maintainers:** Project is very active (1000+ commits in 3 months, PRs merge in days). Good signal for contribution acceptance.
- **PR naming convention:** All PRs use GENIE-xxxx prefix tied to JIRA. External PRs (like #115 `feature/clone-workflow`) don't use this prefix — follow that pattern for external contributions.
- **CodeRabbit enabled:** PRs get automated architecture review via CodeRabbit. Ensure submissions align with ARCHITECTURE.md files.
- **Red Hat ecosystem:** This is a Red Hat community project. Governance files (CONTRIBUTING, CODE_OF_CONDUCT, SECURITY) are especially expected and will be well-received.
- **The workflow filename typo** (`vulerability` -> `vulnerability`) is a trivial fix but renaming a workflow file can break references. Best paired with another CI improvement.
- **Best approach:** Start with docs PRs (governance files, .env.examples) — zero risk, high value, fast merge. Code quality PRs next.
