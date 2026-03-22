# Marketing Audit: lightspeed-core/lightspeed-stack

## Quick Overview

Lightspeed Core Stack (LCS) is a Red Hat-maintained, AI-powered assistant built on FastAPI that answers product questions using backend LLM services, agents, and RAG databases. It integrates with Llama Stack for AI operations and supports multiple providers (OpenAI, Azure, Google VertexAI, IBM WatsonX, RHOAI, RHEL AI). It includes A2A protocol support, RBAC authorization, conversation caching, quota management, and Prometheus observability.

- **Tech stack**: Python 3.12-3.13, FastAPI, Llama Stack, Pydantic, SQLAlchemy, Prometheus, Kubernetes
- **Activity level**: ~94 commits/week, 232 merged PRs, 622 total commits. Extremely active with 3 approvers. PRs merged consistently.
- **CI/CD**: 21 GitHub Actions workflows covering linting, testing, security, and builds

## Quick Win PRs

### 1. Documentation Improvements

| Finding | Location | Effort |
|---------|----------|--------|
| No `SECURITY.md` file | Root directory | 30 min |
| No `CODE_OF_CONDUCT.md` | Root directory | 15 min |
| No `.env.example` template | Root directory | 1-2 hr |
| Typo in deprecated field description - missing space after "Deprecated:" | `src/models/responses.py:505` | 5 min |
| Minimal `__init__.py` docstrings in several packages | `src/runners/__init__.py`, `src/models/__init__.py`, `src/utils/__init__.py` | 30 min |

### 2. Code Quality

| Finding | Location | Effort |
|---------|----------|--------|
| TODO: Missing connection error handling for JWT | `src/authentication/jwk_token.py:49` | 1-2 hr |
| TODO: Token usage metrics not fully implemented | `src/metrics/__init__.py:45-52` (LCORE-411) | 4-6 hr |
| Deprecated `rag_chunks` field still present | `src/models/responses.py:484-487` | Needs maintainer input |
| Deprecated `truncated` field with typo | `src/models/responses.py:503-507` | 5 min |

### 3. Tests

The test suite is well-structured (132 unit, 21 integration, 19 e2e feature files) with 60% unit coverage requirement. Few obvious gaps since this is a mature, enterprise-grade project. The best angle here is improving coverage on newer modules.

### 4. CI/CD

Already comprehensive with 21 workflows. No obvious gaps -- they cover formatting, linting, type checking, security scanning, testing on multiple Python versions, and container builds. Badges are present.

### 5. DX Improvements

| Finding | Location | Effort |
|---------|----------|--------|
| No `.env.example` documenting all env vars | Root directory | 1-2 hr |
| README is 55KB/63.5K lines - could benefit from splitting | `README.md` | 4+ hr |

## Draft PRs

### PR #1: Fix typo in deprecated field description

- **PR Title**: `fix: add missing space in deprecated field description`
- **Branch**: `fix/deprecated-field-typo`
- **Files to change**: `src/models/responses.py`
- **Changes**: Line ~505, change `"Deprecated:Whether conversation history was truncated"` to `"Deprecated: Whether conversation history was truncated"` (add space after colon)
- **Effort**: 5 minutes
- **Merge likelihood**: **High** - trivial fix, no risk, follows existing patterns

### PR #2: Add SECURITY.md with security policy

- **PR Title**: `docs: add SECURITY.md with vulnerability reporting guidelines`
- **Branch**: `docs/add-security-md`
- **Files to change**: Create `SECURITY.md` at root
- **Changes**: Standard security policy file with vulnerability reporting instructions. Reference Red Hat's security response process. GitHub will auto-detect this and show it in the Security tab.
- **Effort**: 30 minutes
- **Merge likelihood**: **Medium** - Red Hat projects may have org-level security policies already; check if there's a centralized one first. But adding a project-level file is standard practice and low risk.

### PR #3: Improve package docstrings in __init__.py files

- **PR Title**: `docs: expand package docstrings in __init__.py files`
- **Branch**: `docs/improve-package-docstrings`
- **Files to change**: `src/runners/__init__.py`, `src/models/__init__.py`, `src/utils/__init__.py`, `src/app/endpoints/__init__.py`
- **Changes**: Expand one-line docstrings to include brief descriptions of what each package contains, key classes/functions, and their purposes. Follow Google Python docstring conventions already used in the project.
- **Effort**: 30 minutes
- **Merge likelihood**: **High** - project explicitly enforces pydocstyle and Google docstring conventions; improving minimal docstrings aligns with their standards

## Notes

- **Red flags**: None. This is a well-maintained, enterprise-grade Red Hat project with consistent activity, clear contribution guidelines, and responsive maintainers.
- **Contribution requirements**: PRs must include a JIRA ticket in the title (e.g., `LCORE-XXX`). This may limit external contributions unless you open a GitHub issue first. Check with maintainers.
- **AI-generated code policy**: CONTRIBUTING.md requires marking AI-generated code. Follow their guidelines.
- **Best approach**: Start with PR #1 (typo fix) -- it's unambiguously correct and requires zero discussion. Then PR #3 (docstrings) as it aligns with their enforced standards. Avoid the TODO items unless you coordinate with maintainers first since those are tracked in JIRA (LCORE-411).
- **Gatekeeper**: Pre-commit hooks enforce formatting/linting. Run `uv run make format && uv run make verify` before submitting.
