# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is an AI agent tooling plugin for data engineering workflows, providing 20+ skills and an MCP server for Apache Airflow integration. It works with Claude Code, Cursor, and 25+ MCP-compatible AI agents. Skills cover DAG authoring, debugging, data lineage, warehouse exploration, dbt integration, and Airflow 2-to-3 migration.

- **Tech stack**: Python 3.10+, Markdown (SKILL.md), FastMCP, httpx, Pydantic, ruff, uv/prek, GitHub Actions
- **Activity**: ~50 commits since Jan 2025, 284 stars, 30 forks. PRs merge in 2-48 hours on average. 7 open PRs (4 drafts), 12+ open issues. Very active, responsive maintainers.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **Missing badges in README** | `README.md` | No badges for PyPI version, CI status, license, Python version, or stars. Every popular repo has these. |
| **No CHANGELOG** | Root | No CHANGELOG.md exists despite 50 commits and PyPI releases. Maintainers track changes only via git log. |
| **README skill table incomplete** | `README.md` | The skill list mentions categories but doesn't list all 20 skills individually with descriptions. `airflow-hitl`, `airflow-plugins`, `troubleshooting-astro-deployments` are missing from the feature table. |
| **astro-airflow-mcp README missing badges** | `astro-airflow-mcp/README.md` | No PyPI badge, no install count, no version badge for the published package. |
| **No usage examples in skills** | `skills/*/SKILL.md` | Skills describe *what* to do but many lack concrete before/after examples showing the output. |

### 2. Code Quality

| Issue | Location | Details |
|-------|----------|---------|
| **Missing `py.typed` marker** | `astro-airflow-mcp/src/astro_airflow_mcp/` | Package published to PyPI but has no `py.typed` file, so downstream consumers can't benefit from type checking. |
| **No `__all__` exports** | `astro-airflow-mcp/src/astro_airflow_mcp/__init__.py` | Public API is implicit. Adding `__all__` clarifies the public surface. |
| **AGENTS.md is a symlink to CLAUDE.md** | Root `AGENTS.md` | Works locally but may confuse contributors or break on some platforms. Consider making it a standalone file or documenting why it's a symlink. |

### 3. Tests

| Issue | Location | Details |
|-------|----------|---------|
| **No test coverage reporting** | `astro-airflow-mcp/pyproject.toml` | pytest-cov not configured. No coverage badge. No way to know what % is tested. |
| **Skills have no tests** | `skills/` | 20 skills with zero automated tests. The `analyzing-data` skill is the only one with tests. Hook scripts (`warm-uvx-cache.sh`, `airflow-skill-suggester.sh`) are untested. |
| **No smoke test for plugin loading** | Root | No test verifies that `.claude-plugin/plugin.json` is valid JSON or that all skills are discoverable. |

### 4. CI/CD

| Issue | Location | Details |
|-------|----------|---------|
| **No CI badge in README** | `README.md` | CI runs but there's no status badge showing build health. |
| **No Dependabot / Renovate** | `.github/` | No dependency update automation. `pyproject.toml` dependencies could go stale. |
| **No release-please or automated changelog** | `.github/workflows/` | Releases are manual. No automated changelog generation. |
| **Missing CodeQL / security scanning** | `.github/workflows/` | No SAST workflow despite having a SECURITY.md. |

### 5. DX Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **No Makefile at root** | Root | `astro-airflow-mcp/` has a Makefile but the root project doesn't. Common tasks (lint, test, install) require reading docs. |
| **No `.env.example`** | Root | README mentions env vars (`AIRFLOW_API_URL`, etc.) but no template file exists. |
| **No Docker Compose for local dev** | Root | Integration tests need PostgreSQL but there's no docker-compose.yml for local development. |

---

## Draft PRs

### PR 1: Add README badges and fix skill table completeness

- **PR Title**: `docs: add status badges and complete skill listing in README`
- **Branch**: `docs/readme-badges`
- **Files to change**: `README.md`, `astro-airflow-mcp/README.md`
- **Changes**:
  - Add badges at top of `README.md`: CI status (`![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)`), PyPI version, license (Apache 2.0), Python 3.10+, GitHub stars
  - Add badges to `astro-airflow-mcp/README.md`: PyPI version (`astro-airflow-mcp`), Python version, license
  - Add missing skills to the feature table: `airflow-hitl`, `airflow-plugins`, `troubleshooting-astro-deployments`
- **Effort**: 20 minutes
- **Merge likelihood**: **High** -- purely additive, no code changes, improves discoverability. Maintainers merged similar doc PRs (#158, #162) in hours.

### PR 2: Add pytest-cov configuration and coverage badge

- **PR Title**: `chore: add test coverage reporting with pytest-cov`
- **Branch**: `chore/test-coverage`
- **Files to change**: `astro-airflow-mcp/pyproject.toml`, `.github/workflows/astro-airflow-mcp-ci.yml`, `README.md`
- **Changes**:
  - Add `pytest-cov` to dev dependencies in `pyproject.toml`
  - Add `[tool.coverage.run]` and `[tool.coverage.report]` sections
  - Update CI to run `pytest --cov=astro_airflow_mcp --cov-report=xml`
  - Optionally add Codecov upload step and badge
- **Effort**: 30 minutes
- **Merge likelihood**: **High** -- standard practice, no behavior change, gives maintainers visibility into test gaps.

### PR 3: Add `.env.example` and root Makefile

- **PR Title**: `chore: add .env.example and root Makefile for common tasks`
- **Branch**: `chore/dx-improvements`
- **Files to change**: `.env.example` (new), `Makefile` (new), `README.md` (link to Makefile)
- **Changes**:
  - Create `.env.example` with all documented env vars (`AIRFLOW_API_URL`, `AIRFLOW_USERNAME`, `AIRFLOW_PASSWORD`, `AIRFLOW_AUTH_TOKEN`, warehouse vars) with placeholder comments
  - Create root `Makefile` with targets: `lint`, `format`, `test`, `test-integration`, `typecheck`, `install`, `clean` (mirroring what's in `astro-airflow-mcp/Makefile` and `CONTRIBUTING.md`)
  - Add one line to README pointing to Makefile for dev setup
- **Effort**: 30 minutes
- **Merge likelihood**: **Medium-High** -- reduces onboarding friction. The `.env.example` is uncontroversial. Makefile may need discussion on exact targets but aligns with existing pattern in `astro-airflow-mcp/`.

---

## Notes

- **No red flags**: Maintainers are active, PRs merge fast, codebase is clean and well-organized.
- **Best approach**: Small, focused PRs. The maintainers clearly prefer atomic changes (see PR #162 -- single-line clarification merged in 4 days). Don't bundle unrelated changes.
- **Avoid**: Touching skill content (domain expertise needed), refactoring MCP server code (active development), anything touching hooks (complex integration points).
- **Good first issues**: The open issues #132 (linter config), #105 (codebase analysis), and #84 (monitoring skill) could be approachable but are larger scope.
- **PR etiquette**: Reference the CONTRIBUTING.md checklist. Run `prek run --all-files` before submitting. Keep conventional commit style.
