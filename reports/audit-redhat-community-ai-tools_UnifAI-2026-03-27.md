# Marketing Audit: redhat-community-ai-tools/UnifAI

## Quick Overview

UnifAI is a production-grade platform for building and running multi-agent AI workflows over enterprise knowledge. It connects internal data sources (Slack, Jira, documents) into a unified vector store, then queries them through composable, visual multi-agent pipelines defined as YAML blueprints or built with a drag-and-drop UI. Supports local execution (LangGraph) and distributed execution (Temporal) with real-time streaming, A2A and MCP protocol support.

**Tech Stack:**
- Backend: Python 3.11+, Flask, LangGraph, Temporal, Redis, Celery
- Frontend: React 18, TypeScript, Vite, TailwindCSS, Radix UI, Zustand
- Storage: MongoDB, Qdrant (vectors), Redis (streams), RabbitMQ
- Auth: Keycloak (OAuth 2.0 / OIDC)
- Deployment: Helm, Helmfile, OpenShift/Kubernetes, Docker, Jenkins CI

**Activity Level:**
- ~1,002 commits since Jan 2025 — very active
- 33 stars, 11 forks
- 10 open PRs (including 1 draft), 5 recently merged
- PRs merge within days — maintainers are responsive
- Last updated: 2026-03-27 (today)
- Internal Red Hat project (GENIE Jira tickets), but open source under Apache 2.0

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **RAG README env vars section is empty** | `rag/README.md:76-79` | Section header "Environment Variables" exists but the actual variable list is missing. The config file `rag/config/app_config.py` references `MONGODB_IP`, `QDRANT_IP`, `QDRANT_URL`, `RABBITMQ_URL`, etc. |
| **No CONTRIBUTING.md** | Root | README says "Contributions are welcome!" but no contribution guidelines exist (code style, PR process, testing, setup) |
| **No LICENSE badge or shields in README** | `README.md` | No badges for license, CI status, Python version, or build status |
| **Project structure typo** | `README.md:258` | Lists `sessions/` but actual directory is `session/` (no 's') |
| **Missing root .env.example** | Root | Multiple modules load env vars but no `.env.example` files exist anywhere to guide setup |

### 2. Code Quality

| Issue | Location | Details |
|-------|----------|---------|
| **print() instead of logging** | `rag/core/monitoring/service.py:60` | `print(f"Logging metrics...")` should use `logger.info()` |
| **Wildcard imports** | `multi-agent/lib/mas/elements/tools/builtin/__init__.py` | Uses `*` imports instead of explicit |
| **No linting config** | Root | No `.flake8`, `ruff.toml`, `.pylintrc`, or pyproject linting config. No `eslint` config for frontend beyond what Vite provides |
| **No pre-commit hooks** | Root | No `.pre-commit-config.yaml` for automated code quality |

### 3. Tests

| Issue | Location | Details |
|-------|----------|---------|
| **No tests for RAG module** | `rag/` | Zero test files — entire RAG pipeline is untested |
| **No tests for backend module** | `backend/` | Zero test files |
| **No frontend tests** | `ui/` | No test framework configured (no vitest, jest, or testing-library) |
| **No CI test runner** | `.github/workflows/` | Has security scanning but no workflow that runs pytest |

### 4. CI/CD

| Issue | Location | Details |
|-------|----------|---------|
| **No test workflow** | `.github/workflows/` | 6 workflows exist but none run unit tests |
| **No lint workflow** | `.github/workflows/` | No automated linting in CI |
| **No README badges** | `README.md` | Missing CI status, license, Python version badges |
| **No build verification** | `.github/workflows/` | No workflow to verify frontend builds (`pnpm build`) |

### 5. DX Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **No docker-compose.yml** | Root | 6 Dockerfiles but no compose file for local dev. Setting up MongoDB + Qdrant + RabbitMQ + Redis + Temporal manually is painful |
| **No .env.example files** | Any module | Developers must read source code to discover required env vars |
| **No Makefile** | Root | Common commands (install deps, run tests, start dev) are scattered across READMEs |

---

## Draft PRs

### PR #1: Add docker-compose.yml for local development

- **PR Title:** `feat: add docker-compose for local development setup`
- **Branch:** `feat/docker-compose-dev`
- **Files to change:** Create `docker-compose.yml` at root
- **Changes:** Add compose file with services: MongoDB, Qdrant, RabbitMQ, Redis, and optionally Temporal. Include volume mounts, health checks, and environment variable defaults. Add a brief section to `README.md` under Quick Start pointing to `docker compose up -d`.
- **Effort:** 30-45 min
- **Merge likelihood:** **High** — This is the single biggest DX gap. The project requires 4-5 infrastructure services and provides zero local orchestration. Every new contributor has to figure this out manually.

### PR #2: Fix RAG README missing env vars + add .env.example files

- **PR Title:** `docs: add environment variable documentation and .env.example files`
- **Branch:** `docs/env-vars-documentation`
- **Files to change:**
  - `rag/README.md` — Fill in the empty "Environment Variables" section by reading `rag/config/app_config.py`
  - `rag/.env.example` — Create with all required vars and comments
  - `multi-agent/.env.example` — Create with vars from `multi-agent/config/`
  - `backend/.env.example` — Create with vars from `backend/config/`
- **Changes:** Document every environment variable each module needs, with defaults and descriptions. Fix the blank section in RAG README.
- **Effort:** 20-30 min
- **Merge likelihood:** **High** — Fills an obvious documentation gap the maintainers clearly intended to complete (the empty section header proves it).

### PR #3: Add CONTRIBUTING.md

- **PR Title:** `docs: add CONTRIBUTING.md with development guidelines`
- **Branch:** `docs/contributing-guide`
- **Files to change:** Create `CONTRIBUTING.md` at root
- **Changes:** Add sections for: prerequisites, local setup (reference docker-compose), code style, testing, commit conventions (they use GENIE ticket prefixes), PR process, and how to add new elements (nodes, tools, LLMs, providers). Reference the modular architecture already described in README.
- **Effort:** 20-30 min
- **Merge likelihood:** **High** — README explicitly says contributions are welcome but provides no guidance. Standard open-source best practice.

---

## Notes

- **Active internal team:** This is clearly a Red Hat internal project (GENIE Jira tickets, 2 core authors) that's been open-sourced. PRs are reviewed and merged quickly (1-3 days).
- **CodeRabbit enabled:** They use AI code review (`.coderabbit.yaml`), so PRs get automated feedback. Keep PRs clean.
- **No external contributor PRs visible:** All PRs are from the internal team. Being an early external contributor gives high visibility.
- **Best approach:** Start with the docs PR (#2) since it's the lowest risk and most obviously needed (empty README section). Follow with docker-compose (#1) for maximum impact.
- **Red flag:** The project is Apache 2.0 but `multi-agent/pyproject.toml` lists license as "Proprietary" — this is a minor inconsistency worth flagging but probably not worth a PR on its own.
- **Commit style:** They use GENIE ticket numbers in branch names but commit messages are informal. Use conventional commits for external contributions.
