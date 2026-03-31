Now I have all the data needed. Let me produce the report.

# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is a Claude Code / Cursor plugin providing 33 AI skills and an MCP server for Apache Airflow. It enables data engineers to author, test, debug, and deploy Airflow DAGs, analyze data warehouses (Snowflake, BigQuery, PostgreSQL), manage dbt workflows, and trace data lineage -- all from within their AI coding assistant. The MCP server (`astro-airflow-mcp`) supports both Airflow 2.x and 3.x through a versioned adapter pattern.

**Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic v2, Typer (CLI), pytest, Ruff, uv/hatch, Docker, GitHub Actions

**Activity level**: 52 commits since Jan 2025, last commit 3 days ago (Mar 27 2026). PR-based workflow with numbered PRs (#150-#166 recent). Active maintainers from Astronomer. PRs merge within days. CODEOWNERS enforced on infrastructure files. Responsive and well-maintained.

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **Missing CHANGELOG.md** | No changelog exists. Project uses `hatch-vcs` for versioning but has no human-readable release notes. |
| **Exception class docstrings** | 5+ exception classes lack docstrings: `ReadOnlyError`, `NotFoundError` (base.py), `ConfigError` (loader.py), `AstroCliError`, `AstroCliNotInstalledError`, `AstroCliNotAuthenticatedError` (astro_cli.py) |
| **Incomplete function docstring** | `cli/api.py:72` - `format_output()` has Args section but no Returns section |
| **Submodule init not in README** | Users cloning the repo won't get the 10 dbt skills without running `git submodule update --init` -- not mentioned prominently in install steps |

### 2. Code Quality

| Item | Details |
|------|---------|
| **Generic exceptions** | `airflow_v2.py:334` and `airflow_v3.py:348` raise `Exception()` instead of a specific error type. `APIError` already exists in `models.py` but isn't used here. |
| **Missing return type** | `__main__.py:62` - `def main():` missing `-> None` annotation (only function in codebase without one) |
| **Missing PEP 561 marker** | No `py.typed` file in `src/astro_airflow_mcp/`. The package has comprehensive type hints but doesn't advertise PEP 561 compliance. |
| **Magic numbers** | `airflow_v3.py:63` `timeout=10.0`, `cli/registry.py:86` `timeout=30` -- should use named constants |
| **Missing exception chaining** | `adapters/__init__.py:74-77` catches `Exception` and raises `RuntimeError` without `from e` |
| **Hardcoded instance name** | `"localhost:8080"` duplicated in `config/loader.py:68-69` and `cli/context.py:54` |

### 3. Tests

| Item | Details |
|------|---------|
| **No unit tests for config/interpolation.py** | Has `interpolate_env_vars()` and `interpolate_config_value()` with no dedicated test |
| **No unit tests for discovery/registry.py** | `DiscoveryRegistry` class untested directly |
| **Tools modules only integration-tested** | `tools/dag.py`, `tools/task.py`, `tools/dag_run.py`, `tools/asset.py`, `tools/admin.py`, `tools/diagnostic.py` lack unit tests |
| **Source/test ratio** | 47 source files, 17 test files (2.8:1 ratio) |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No badges in README** | Missing CI status badge, PyPI version badge, Python version badge, license badge |
| **No dependabot/renovate config** | No automated dependency update mechanism in `.github/` |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **Better exception chaining** | `adapters/__init__.py` loses original exception context when auto-detecting Airflow version fails |
| **Constants consolidation** | Timeout values scattered across files instead of centralized in `constants.py` |

---

## Draft PRs

### PR #1: Add py.typed marker for PEP 561 compliance

- **PR Title**: `feat: add py.typed marker for PEP 561 type hint support`
- **Branch**: `feat/py-typed-marker`
- **Files to change**:
  - Create: `astro-airflow-mcp/src/astro_airflow_mcp/py.typed` (empty file)
- **Changes**: Create a single empty file. The package already has comprehensive modern type hints (union `X | Y` syntax, generics, return types). This marker tells type checkers and IDEs that the package ships inline types.
- **Effort**: 5 minutes
- **Merge likelihood**: **HIGH** -- zero-risk change, standard Python packaging practice, the project already uses `ty` for type checking. Maintainers who invested in type hints will appreciate advertising it.

### PR #2: Replace generic Exception with specific error types in adapters

- **PR Title**: `fix: use specific exception types in adapter HTTP error handling`
- **Branch**: `fix/specific-adapter-exceptions`
- **Files to change**:
  - `astro-airflow-mcp/src/astro_airflow_mcp/adapters/airflow_v2.py` (line 334)
  - `astro-airflow-mcp/src/astro_airflow_mcp/adapters/airflow_v3.py` (line 348)
  - `astro-airflow-mcp/src/astro_airflow_mcp/adapters/__init__.py` (lines 74-77, add `from e`)
- **Changes**: Replace `raise Exception(f"HTTP {result['status_code']}...")` with `raise httpx.HTTPStatusError(...)` or a custom `AdapterError(Exception)`. Add exception chaining (`from e`) in `__init__.py:77`. Three small edits.
- **Effort**: 15 minutes
- **Merge likelihood**: **HIGH** -- generic exceptions are a code smell, Bandit security linter is already in dev deps (`bandit[toml]>=1.7.0`), and this improves error handling for downstream consumers.

### PR #3: Add CI status and PyPI badges to README

- **PR Title**: `docs: add CI status and package badges to README`
- **Branch**: `docs/readme-badges`
- **Files to change**:
  - `README.md` (add badge row after title)
- **Changes**: Add badges at top of README:
  - CI status: `![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)`
  - MCP CI: `![MCP CI](https://github.com/astronomer/agents/actions/workflows/astro-airflow-mcp-ci.yml/badge.svg)`
  - PyPI version: `![PyPI](https://img.shields.io/pypi/v/astro-airflow-mcp)`
  - Python versions: `![Python](https://img.shields.io/pypi/pyversions/astro-airflow-mcp)`
  - License: `![License](https://img.shields.io/github/license/astronomer/agents)`
- **Effort**: 10 minutes
- **Merge likelihood**: **MEDIUM** -- common open-source practice, but CODEOWNERS may require specific reviewer approval. Some corporate repos prefer minimal badges. Check existing Astronomer repos for precedent.

---

## Notes

- **No red flags**: Active maintainers, fast PR merges, clean git history, well-structured CODEOWNERS.
- **CODEOWNERS gates**: `.github/`, `.claude-plugin/`, and `CLAUDE.md` changes require `agents-approvers` team review. Stick to `astro-airflow-mcp/` and `skills/` for easier merges.
- **Contribution guide exists**: `CONTRIBUTING.md` is thorough -- follow their conventions (Ruff formatting, `prek` hooks, focused PRs).
- **Best approach**: Open an issue first describing the improvement, reference it in the PR. Keep PRs small and focused. The `py.typed` PR is the safest first contribution.
- **Avoid**: Don't touch CI workflows or plugin config without prior discussion -- those are gated by CODEOWNERS. Don't refactor working code; they prefer focused, incremental changes.
