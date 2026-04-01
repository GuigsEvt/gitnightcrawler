# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is a Claude Code / Cursor plugin providing 35+ AI-powered skills for Apache Airflow and data engineering workflows. It includes an MCP server (`astro-airflow-mcp`) for interacting with Airflow APIs, skills for DAG authoring/testing/debugging, data analysis with Jupyter integration, dbt integration via Cosmos, and migration tooling (Airflow 2->3). Built by the Astronomer team (commercial Airflow platform).

- **Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic, Typer CLI, Ruff linting, `ty` type checker, pytest, Docker, GitHub Actions CI
- **Activity level**: ~54 commits since Jan 2025, multiple active contributors (Kaxil Naik, Taylor Murphy, Milton Li, Greg Neiheisel, Tatiana Al-Chueyr). PRs merge in 2 hours to 4 days. 6 open PRs (2 draft). Very responsive maintainers.

---

## Quick Win PRs

### 1. Documentation Improvements

**No broken links found.** README is comprehensive. However:

- **Missing `py.typed` marker** for the main package `astro-airflow-mcp`. The `skills/analyzing-data/scripts/` has one but the published package doesn't. This matters for downstream consumers using type checkers.
- **CONTRIBUTING.md references `prek`** but doesn't explain what it is or link to its repo for new contributors unfamiliar with it.
- **No badges in README** -- no PyPI version badge, no CI status badge, no Python version badge. Most mature projects have these.

### 2. Code Quality

- **Broad `except Exception as e: return str(e)` pattern** in all tool files (`tools/dag.py`, `tools/dag_run.py`, `tools/task.py`, `tools/asset.py`) -- swallows specific errors, loses stack traces, no logging. The codebase already defines `NotFoundError` and `ReadOnlyError` in `adapters/base.py`.
- **~80 functions missing return type hints** across tools/, skills/analyzing-data/scripts/ (cache.py, warehouse.py, config.py).
- **No `py.typed` marker** in `astro-airflow-mcp/src/astro_airflow_mcp/`.

### 3. Tests

- **`auth.py` (TokenManager) has no tests** -- critical authentication path untested.
- **`resources.py` has no tests** -- 4 resource-serving functions.
- **`utils.py` has no dedicated test file** in main package.
- **No test coverage reporting** configured (no `--cov` in pytest, no coveralls/codecov integration).

### 4. CI/CD

- **No README badges** for CI status, PyPI version, Python versions, license.
- **No test coverage reporting** in CI (pytest-cov not configured).
- **No dependabot/renovate** configuration for dependency updates.

### 5. DX Improvements

- **No `.env.example`** file for the MCP server -- users must guess required env vars.
- **Dockerfile defaults to stdio mode** but the comment about HTTP mode could be clearer with a `docker-compose.yml` for development (separate from `docker-compose.test.yml`).

---

## Draft PRs

### PR 1: Add CI/PyPI/License badges to README

- **PR Title**: `docs: add CI status, PyPI, and license badges to README`
- **Branch**: `docs/readme-badges`
- **Files to change**: `README.md`
- **Changes**: Add badge row after the title:
  ```markdown
  [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
  [![PyPI](https://img.shields.io/pypi/v/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![Python](https://img.shields.io/pypi/pyversions/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![License](https://img.shields.io/github/license/astronomer/agents)](https://github.com/astronomer/agents/blob/main/LICENSE)
  ```
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- zero risk, standard practice, improves project visibility

### PR 2: Add `py.typed` marker for typed package

- **PR Title**: `feat: add py.typed marker for PEP 561 compliance`
- **Branch**: `feat/py-typed-marker`
- **Files to change**:
  - Create `astro-airflow-mcp/src/astro_airflow_mcp/py.typed` (empty file)
  - Update `astro-airflow-mcp/pyproject.toml` to include it in package data if needed
- **Changes**: Add empty `py.typed` file so downstream type checkers recognize the package as typed. The project already uses `ty` for type checking so this aligns with existing goals.
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- trivial change, aligns with project's type-checking direction, standard Python packaging practice

### PR 3: Add test coverage reporting to CI

- **PR Title**: `ci: add pytest-cov and coverage reporting`
- **Branch**: `ci/test-coverage`
- **Files to change**:
  - `astro-airflow-mcp/pyproject.toml` -- add `pytest-cov` to test dependencies, add `[tool.coverage.run]` config
  - `.github/workflows/ci.yml` -- add `--cov` flag to pytest, upload coverage artifact
  - `.github/workflows/astro-airflow-mcp-ci.yml` -- same
- **Changes**: Add pytest-cov dependency, configure coverage source, add `--cov --cov-report=xml` to pytest invocations, optionally add codecov upload step.
- **Effort**: 30 minutes
- **Merge likelihood**: **Medium-High** -- useful for maintainers, but they may have opinions on coverage provider (codecov vs coveralls vs none). Open an issue first to gauge interest.

---

## Notes

- **No red flags.** Active team, fast PR merges, clean codebase, well-documented contributing process.
- **Maintainers are Astronomer employees** -- they're building this as a product extension, so quality bar is high. PRs need to be clean and follow their `prek` hooks.
- **Best approach**: Fork, run `pip install prek && prek install` for hooks, ensure `prek run` passes before submitting. Keep PRs small and focused (per CONTRIBUTING.md).
- **PR #1 (badges) is the lowest-risk entry point** -- submit it first to establish contributor relationship.
- **Avoid**: Refactoring error handling patterns or adding type hints to tool files without discussing in an issue first -- these touch core product logic and the team may have specific plans.
