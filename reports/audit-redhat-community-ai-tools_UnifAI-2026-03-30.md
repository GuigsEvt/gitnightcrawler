Now I have all the data. Here's the report:

---

# Marketing Audit: redhat-community-ai-tools/UnifAI

## Quick Overview

UnifAI is a production-grade multi-agent AI orchestration platform by Red Hat community contributors. It lets teams compose agentic workflows from pluggable Agents, LLMs, tools, and retrievers via YAML blueprints or a drag-and-drop UI. Includes a RAG pipeline for enterprise knowledge retrieval (Slack, Jira, docs), with execution on LangGraph (local) or Temporal (distributed). Supports A2A and MCP protocols.

**Tech stack:** Python 3.11+ (Flask, LangGraph, Temporal, Celery), React 18 / TypeScript / Vite / Tailwind, MongoDB, Qdrant, Redis, RabbitMQ, Helm/K8s/OpenShift, Keycloak.

**Activity level:** Very active. 33 stars, 11 forks. ~5 core contributors. 6 open PRs as of today, PRs merged within 1-7 days. Created Nov 2025, last merge Mar 29 2026. Commit pace: ~5-10/week. Uses JIRA-style ticket refs (GENIE-xxxx). Apache 2.0 license.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **No CONTRIBUTING.md** | Main README says "Contributions are welcome!" but no guide exists. Standard for Red Hat open-source projects. |
| **No .env.example** | No `.env.example` or `.env.template` anywhere. New contributors can't figure out required env vars without reading code. Needs files in `multi-agent/`, `rag/`, and root. |
| **No README badges** | No license badge, no CI status badge, no Python/Node version badges at top of README. |
| **Typo in workflow filename** | `.github/workflows/security-container-vulerability-scanning.yaml` — "vulerability" should be "vulnerability" |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **No Python linting config** | No `ruff.toml`, `.flake8`, `.pylintrc`, or `mypy.ini`. 968 Python files with no enforced style. |
| **No frontend linting config** | No `.eslintrc`, `.prettierrc` in `ui/`. 259 TypeScript files with no enforced formatting. |
| **No pre-commit hooks** | No `.pre-commit-config.yaml` for automated checks before commits. |

### 3. Tests

| Issue | Details |
|-------|---------|
| **RAG backend has ZERO tests** | `rag/` directory has 0 test files. This is a core business module (ingestion, chunking, search). Multi-agent has 61 test files. |
| **No test coverage config** | No `.coveragerc` or coverage settings in pyproject.toml. No coverage reporting in CI. |
| **No frontend tests** | No test files visible in `ui/`. No vitest/jest config. |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **No lint/format CI workflow** | Existing workflows: security scanning, dep verification, DB backup. Missing: lint check, type check, test runner. |
| **No test CI workflow** | Tests exist for multi-agent but no GitHub Action runs them on PR. |
| **No PR/issue templates** | No `.github/ISSUE_TEMPLATE/` or `PULL_REQUEST_TEMPLATE.md`. |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **No docker-compose.yml** | Local dev requires manually running MongoDB, Qdrant, RabbitMQ, Redis, Temporal. A compose file would massively simplify onboarding. |
| **No Makefile** | No unified `make dev`, `make test`, `make lint` commands across the monorepo. |

---

## Draft PRs

### PR #1: Fix workflow filename typo + add README badges

- **PR Title:** `fix: correct typo in security workflow filename and add README badges`
- **Branch:** `fix/readme-badges-and-typo`
- **Files to change:**
  - Rename `.github/workflows/security-container-vulerability-scanning.yaml` → `.github/workflows/security-container-vulnerability-scanning.yaml`
  - Edit `README.md` — add badge block at line 1 before the title:
    ```
    [![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
    [![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)]()
    [![Node 22+](https://img.shields.io/badge/node-22+-green.svg)]()
    ```
- **Effort:** 10 minutes
- **Merge likelihood:** **High** — zero-risk cosmetic fix + visible typo correction. Maintainers merged similar small PRs quickly.

### PR #2: Add .env.example files for all services

- **PR Title:** `docs: add .env.example files for multi-agent, rag, and ui`
- **Branch:** `docs/env-examples`
- **Files to create:**
  - `multi-agent/.env.example` — extract from code: `ENGINE_NAME`, `MONGODB_IP`, `REDIS_URL`, `TEMPORAL_HOST`, LLM API keys, etc.
  - `rag/.env.example` — extract from code: `MONGODB_IP`, `QDRANT_HOST`, `RABBITMQ_URL`, embedding config, etc.
  - `ui/.env.example` — extract from code: `VITE_API1_URL`, `VITE_API2_URL`, SSO config, etc.
- **Effort:** 30-45 minutes (need to grep for `os.environ` / `os.getenv` / `import.meta.env` across the codebase)
- **Merge likelihood:** **High** — directly improves onboarding, no code changes, low risk. Common first-contributor PR.

### PR #3: Add docker-compose.yml for local development

- **PR Title:** `feat: add docker-compose for local development dependencies`
- **Branch:** `feat/docker-compose-dev`
- **Files to create:**
  - `docker-compose.yml` — services: MongoDB, Qdrant, Redis, RabbitMQ (the 4 infrastructure deps). No app containers, just infra.
  - Update `README.md` Quick Start section to reference `docker compose up -d`
- **Effort:** 45-60 minutes
- **Merge likelihood:** **High** — the README already documents these as prerequisites. Wrapping them in a compose file is a natural DX improvement that doesn't conflict with their Helm/K8s production deployment.

---

## Notes

- **No red flags.** Active maintainers (5 core), PRs merged in 1-7 days, consistent commit history. Red Hat community backing.
- **JIRA tracking** — all branches/PRs reference GENIE-xxxx tickets, indicating a structured internal workflow. External contributions should be clean and self-contained to avoid friction.
- **Best approach:** Start with PR #1 (typo fix + badges) as an intro, then follow up with PR #2 (.env.example). These are unambiguously helpful and require no architectural decisions from maintainers.
- **CodeRabbit** is enabled (`.coderabbit.yaml`) — PRs will get automated review. Keep changes focused.
- **Bigger opportunities** for later: CONTRIBUTING.md, docker-compose, PR/issue templates, adding ruff config + CI lint workflow, RAG test scaffolding.
