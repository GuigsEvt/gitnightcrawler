Now I have everything I need. Here's the full report:

---

# Marketing Audit: astronomer/agents

## Quick Overview

**astronomer/agents** is an AI agent toolkit for data engineering workflows built by Astronomer. It includes a FastMCP server for Apache Airflow (v2/v3), a CLI tool (`af`) for terminal-based Airflow interaction, and 32 specialized skills that extend AI coding agents (Claude Code, Cursor) with capabilities for DAG development, dbt integration, data lineage, and warehouse management. Apache 2.0 licensed.

**Tech stack:** Python 3.10+, FastMCP, httpx, Pydantic, Typer, Ruff, Hatchling, GitHub Actions, Docker

**Activity level:** Very active. ~52 commits since Jan 2025, regular commits every 1-3 days. 7 open PRs (3 drafts, 1 WIP). PRs typically merge within hours to 1 day. Multiple active contributors. Maintainers are responsive.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **No README badges** | README has zero badges -- no CI status, PyPI version, license, Python version, or downloads badge. This is unusual for a project of this quality. |
| **No changelog** | No CHANGELOG.md exists. Releases rely solely on git tags. |
| **MCP server README gaps** | `astro-airflow-mcp/README.md` could benefit from a "Supported Airflow Versions" compatibility matrix. |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **Inconsistent skill filenames** | 2 skills use lowercase `skill.md` instead of `SKILL.md`: `skills/managing-astro-deployments/skill.md` and `skills/troubleshooting-astro-deployments/skill.md`. All other 30 skills use uppercase. May break auto-discovery. |
| **Overall quality is excellent** | Type hints comprehensive, Ruff + ty + Bandit configured, no dead code, no unused imports, no TODOs. Very little to fix here. |

### 3. Tests

| Issue | Details |
|-------|---------|
| **Skills scripts lack tests** | Only `skills/analyzing-data/scripts/tests/` has tests. Other skills with Python scripts (hooks) have no test coverage. |
| **No test coverage reporting** | No coverage tool configured (pytest-cov), no coverage badge, no coverage gates in CI. |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **No badges in README** | CI, PyPI, license badges all missing. |
| **No dependabot/renovate** | No automated dependency update config found. |
| **No CodeQL / security scanning in CI** | Bandit is configured locally but not as a separate CI step. |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **Issue #168** | `af runs list` should show most recent runs first by default -- simple sort fix. |
| **No .env.example** | Warehouse config uses `~/.astro/agents/warehouse.yml` but no example template ships with the repo. |

---

## Draft PRs

### PR 1: Add README badges (CI, PyPI, License, Python)

- **PR Title:** `docs: add status badges to README`
- **Branch:** `docs/readme-badges`
- **Files to change:** `README.md`
- **Changes:** Add badge row after the `# agents` heading:
  ```markdown
  [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
  [![PyPI](https://img.shields.io/pypi/v/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![Python](https://img.shields.io/pypi/pyversions/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![License](https://img.shields.io/github/license/astronomer/agents)](https://github.com/astronomer/agents/blob/main/LICENSE)
  ```
- **Effort:** 5 minutes
- **Merge likelihood:** **High** -- zero-risk improvement, standard open-source practice, maintainers clearly care about docs quality.

### PR 2: Fix inconsistent skill.md filenames to SKILL.md

- **PR Title:** `fix: rename lowercase skill.md to SKILL.md for consistency`
- **Branch:** `fix/skill-filename-case`
- **Files to change:**
  - `skills/managing-astro-deployments/skill.md` -> rename to `SKILL.md`
  - `skills/troubleshooting-astro-deployments/skill.md` -> rename to `SKILL.md`
- **Changes:** `git mv` both files to uppercase. No content changes needed.
- **Effort:** 2 minutes
- **Merge likelihood:** **High** -- clear bug/inconsistency. 30/32 skills use `SKILL.md`. Auto-discovery likely expects uppercase. Easy review.

### PR 3: Add pytest-cov and coverage reporting to CI

- **PR Title:** `ci: add test coverage reporting with pytest-cov`
- **Branch:** `ci/test-coverage`
- **Files to change:**
  - `astro-airflow-mcp/pyproject.toml` -- add `pytest-cov` to dev dependencies, add `[tool.pytest.ini_options]` with `--cov` flags
  - `.github/workflows/astro-airflow-mcp-ci.yml` -- add coverage upload step or summary comment
- **Changes:** Add `pytest-cov` dependency, configure minimum coverage threshold, optionally add Codecov integration or coverage badge.
- **Effort:** 15-30 minutes
- **Merge likelihood:** **Medium** -- useful improvement but maintainers may have opinions on coverage tool choice or thresholds. Open an issue first to discuss.

---

## Notes

- **No red flags.** Maintainers are active and responsive. PRs merge fast when they're clean.
- **Best approach:** PRs 1 and 2 are near-zero risk. Submit them directly without an issue. PR 3 warrants opening an issue first.
- **Stale PR warning:** PR #103 has been in draft for 7+ weeks -- avoid overlapping with that work (DAG skill refactoring).
- **Contribution guidelines exist** (`CONTRIBUTING.md`) with clear expectations: run `prek run --all-files`, write tests, keep commits clean.
- **The codebase is exceptionally well-maintained.** Type hints, linting, CI, docs are all solid. Finding "quick wins" is harder than usual because the quality bar is high.
