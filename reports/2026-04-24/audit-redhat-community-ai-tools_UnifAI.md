# Marketing Audit: redhat-community-ai-tools/UnifAI

## Quick Overview

UnifAI is a production-grade platform for building and running multi-agent AI workflows over enterprise knowledge. It connects internal data sources (Slack, Jira, documents) into a unified vector store, then lets users query them through composable, visual multi-agent pipelines defined as YAML blueprints or built via a drag-and-drop UI. Supports LangGraph (local) and Temporal (distributed) execution engines, with A2A and MCP protocol support.

**Tech Stack:**
| Layer | Technologies |
|-------|-------------|
| Multi-Agent Backend | Python 3.11+, Flask, LangGraph, Temporal, Redis |
| RAG Backend | Python 3.11+, Flask, Celery, Qdrant, RabbitMQ |
| Frontend | React 18, TypeScript, Vite, Tailwind CSS, Radix UI |
| Auth | Keycloak (OAuth 2.0 / OIDC) |
| Storage | MongoDB, Qdrant, Redis |
| Deployment | Helm, OpenShift / Kubernetes, Docker |

**Activity Level:** Very high -- ~146 commits/month, 6 active contributors, PRs merged within days. Last merge was yesterday (April 23). 35 stars, 15 forks. Red Hat-affiliated team using Jira (GENIE project) for tracking. Only 2 open issues on GitHub.

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **Missing CONTRIBUTING.md** | No contribution guide exists. The README says "Contributions are welcome!" but gives no instructions on how to contribute, coding standards, or PR process. |
| **Missing CODE_OF_CONDUCT.md** | Standard for any Red Hat open-source project. |
| **Missing SECURITY.md** | No security policy despite having security-focused CI workflows. |
| **Missing .env.example** | No environment variable template despite heavy env-var usage across all backends (`ENGINE_NAME`, `MONGODB_IP`, etc.). New contributors have to reverse-engineer config. |
| **UI package.json name mismatch** | `ui/package.json` has `"name": "rest-express"` -- clearly a leftover from scaffolding. Should be `"unifai-ui"` or similar. |
| **No badges in README** | No CI status badges, license badge, or Python/Node version badges. |

### 2. Code Quality

| Item | Details |
|------|---------|
| **Workflow filename typo** | `.github/workflows/security-container-vulerability-scanning.yaml` -- "vulerability" should be "vulnerability". |
| **524 Python files without return type hints** | Massive opportunity, but too large for a single PR. Could target high-visibility files like API endpoints. |
| **28+ TODO comments** | Several are stale or tracking missing features (authorization checks, logging, schema validation). |
| **UI license mismatch** | Root project is Apache 2.0 but `ui/package.json` says `"license": "MIT"`. Should be aligned. |

### 3. Tests

| Item | Details |
|------|---------|
| **Zero frontend tests** | No `.test.ts`, `.spec.ts`, or any test files in `ui/`. No test framework configured in `package.json` (no vitest, jest, etc.). |
| **71 Python test files exist** | Good coverage on backend, but no CI workflow runs them (no pytest GitHub Action). |
| **No test CI workflow** | Tests exist but aren't run in CI -- only security scanning and dep verification workflows exist. |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No lint/typecheck CI** | No workflow for Python linting (ruff/flake8) or TypeScript type-checking. |
| **No test runner CI** | Despite 71 test files and extensive pytest markers in `pyproject.toml`, no CI workflow runs tests. |
| **Missing badges** | No status badges for any existing workflows. |
| **Container scan TODO** | `security-container-vulerability-scanning.yaml:74` has `exit-code: '0'` with a TODO to switch to `'1'`. |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **No docker-compose.yml** | Quick Start requires manually setting up MongoDB, Qdrant, Redis, RabbitMQ, Temporal. A `docker-compose.yml` for local dev would be a huge DX win. |
| **No Makefile or task runner** | No unified way to run all services. Each component has its own instructions. |
| **Missing .env.example** | Contributors have no template for required environment variables. |

---

## Draft PRs

### PR #1: Fix workflow filename typo + add README badges

- **PR Title:** `fix: correct typo in container vulnerability scanning workflow filename`
- **Branch:** `fix/workflow-filename-typo`
- **Files to change:**
  - Rename `.github/workflows/security-container-vulerability-scanning.yaml` to `.github/workflows/security-container-vulnerability-scanning.yaml`
  - `README.md` -- add badges at top (license, Python version, CI status)
- **Changes:**
  - `git mv` the workflow file to fix the "vulerability" -> "vulnerability" typo
  - Add badge block after the title in README:
    ```markdown
    [![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
    [![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
    [![Security Scan](https://github.com/redhat-community-ai-tools/UnifAI/actions/workflows/security-pip-auditing.yaml/badge.svg)](https://github.com/redhat-community-ai-tools/UnifAI/actions/workflows/security-pip-auditing.yaml)
    ```
- **Effort:** 10 minutes
- **Merge likelihood:** **High** -- trivial fix, no code changes, improves professionalism. The typo is in a filename visible to all contributors.

---

### PR #2: Add CONTRIBUTING.md and fix UI package.json metadata

- **PR Title:** `docs: add CONTRIBUTING.md and fix UI package metadata`
- **Branch:** `docs/contributing-guide`
- **Files to change:**
  - Create `CONTRIBUTING.md` (standard Red Hat OSS template: fork, branch, PR process, coding standards, test instructions)
  - `ui/package.json` -- change `"name": "rest-express"` to `"name": "unifai-ui"`, change `"license": "MIT"` to `"license": "Apache-2.0"`
- **Changes:**
  - CONTRIBUTING.md covering: prerequisites, local setup, branch naming (matches their `GENIE-XXXX/type/description` convention), PR expectations, code style
  - Fix the two metadata fields in package.json
- **Effort:** 30 minutes
- **Merge likelihood:** **High** -- the README explicitly welcomes contributions but provides no guide. Package metadata fixes are objectively correct (name is wrong, license is mismatched).

---

### PR #3: Add .env.example files for all backends

- **PR Title:** `docs: add .env.example templates for local development`
- **Branch:** `docs/env-examples`
- **Files to change:**
  - Create `multi-agent/.env.example`
  - Create `rag/.env.example`
  - Create `backend/.env.example`
- **Changes:**
  - Extract all `os.getenv()` / `os.environ` references from each backend's config files
  - Create commented `.env.example` files with all variables, defaults, and descriptions
  - Add a note in the root README Quick Start section pointing to these files
- **Effort:** 45 minutes
- **Merge likelihood:** **High** -- directly addresses the biggest barrier to new contributor onboarding. No code changes, purely additive.

---

## Notes

- **No red flags.** Maintainers are active (merged PRs yesterday), responsive, and the project is clearly funded by Red Hat. CODEOWNERS is well-defined with `@odaiodeh` and `@nirsisr` as default reviewers.
- **Work is tracked in Jira** (GENIE project), not GitHub Issues. Only 2 open GH issues. Branch naming follows `GENIE-XXXX/type/description`.
- **Best approach:** Submit small, focused PRs. The typo fix (PR #1) is the ideal first contribution -- zero risk, high visibility, establishes you as a contributor. Follow up with docs PRs.
- **Avoid:** Large refactors, type hint PRs across many files, or anything touching the core engine without prior discussion. The team has strong opinions (hexagonal architecture, Cursor commands for code review).
- **docker-compose.yml** would be high-impact but needs discussion first -- the team is Helm/K8s-first and may have opinions about local dev workflows. Open an issue before submitting.
