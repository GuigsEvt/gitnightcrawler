Here's the full audit report:

---

# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is an AI agent tooling suite for data engineering workflows. It includes an MCP server for Apache Airflow (with v2/v3 compatibility), a CLI tool (`af`), and 32 skills that extend AI coding agents (Claude Code, Cursor, VS Code) for Airflow DAG authoring, warehouse discovery, dbt integration, and data lineage. Built and maintained by Astronomer (the company behind Astronomer Cosmos and managed Airflow).

- **Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic, typer, SQLAlchemy, Jupyter kernel integration
- **Activity**: 52 commits since Jan 2025, ~4/week. 293 stars, 33 forks. 7 open PRs, 15 open issues. Last commit 1 day ago. Multiple active contributors from Astronomer team (@tayloramurphy, @kaxil, @josh-fell, @jlaneve, @TJaniF).
- **Responsiveness**: PRs get reviewed and merged within days. Very active maintainers.

## Quick Win PRs

### 1. Documentation Improvements

- **README**: Comprehensive, all links valid. No broken links found.
- **CONTRIBUTING.md**: Exists but could use more detail on how to test skills individually.
- **Missing**: No `CHANGELOG.md` exists. With 52+ commits and PyPI releases, a changelog would help users track changes.
- **Skills documentation**: Each SKILL.md is well-written. No obvious gaps.

### 2. Code Quality

**Missing return type hints in `skills/analyzing-data/scripts/`:**
- `cache.py`: 8 functions missing return type hints (`_ensure_cache_dir`, `_save_json`, `learn_concept`, `lookup_pattern`, `record_pattern_outcome`, `list_patterns`, `_is_stale`, etc.)
- `config.py`: 4 functions missing return types (`_check_legacy_path`, `get_kernel_venv_dir`, `get_kernel_connection_file`, `get_config_dir`)
- `warehouse.py`: 2 functions missing return types (`get_warehouse_config_path`, `_load_env_file`)

**Hardcoded timeout values in `skills/analyzing-data/scripts/`:**
- `cli.py`: `timeout=60.0` appears 4 times, `timeout=30.0` once
- `kernel.py`: Various timeouts (2, 30, 10, 5, 1.0 seconds) should be named constants

**No bare except clauses, no unused imports, no TODO/FIXME/HACK comments.** Codebase is clean.

### 3. Tests

- **MCP server** (`astro-airflow-mcp/tests/`): 17 test files, comprehensive coverage across tools, adapters, CLI, and config.
- **Skills tests**: Only `analyzing-data` has tests (unit + integration). Other skills with scripts (e.g., `airflow/hooks/`) have no tests.
- **Missing**: No tests for hook scripts (`airflow-skill-suggester.sh`, `warm-uvx-cache.sh`).
- **Missing `__init__.py`** in `skills/analyzing-data/scripts/` (exists in tests subdirectories but not the parent).

### 4. CI/CD

- **Existing**: `ci.yml` (pre-commit, unit-test, integration-test, typecheck), `astro-airflow-mcp-ci.yml` (multi-Python, Docker), `astro-airflow-mcp-publish.yml` (PyPI via OIDC).
- **Missing badges**: README has no CI status badge, no PyPI version badge, no Python version badge. These are easy wins.
- **Missing**: No dependabot or renovate config for dependency updates.

### 5. DX Improvements

- **Issue #168**: `af runs list` should show most recent runs first. Simple sort fix.
- **Missing**: No `Makefile` at repo root (the MCP subpackage has one). A root Makefile with `make test`, `make lint`, `make install-dev` would help contributors.
- **Missing**: No `.devcontainer/` or `devcontainer.json` for GitHub Codespaces support.

## Draft PRs

### PR 1: Add CI/README badges

- **PR Title**: `docs: add CI status and PyPI badges to README`
- **Branch**: `docs/add-badges`
- **Files to change**: `README.md`
- **Changes**: Add badges after the title line:
  ```markdown
  [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
  [![MCP CI](https://github.com/astronomer/agents/actions/workflows/astro-airflow-mcp-ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/astro-airflow-mcp-ci.yml)
  [![PyPI](https://img.shields.io/pypi/v/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![Python](https://img.shields.io/pypi/pyversions/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![License](https://img.shields.io/github/license/astronomer/agents)](LICENSE)
  ```
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- zero-risk, purely additive, maintainers will appreciate the visibility

### PR 2: Add return type hints to analyzing-data scripts

- **PR Title**: `fix: add missing return type hints in analyzing-data scripts`
- **Branch**: `fix/type-hints-analyzing-data`
- **Files to change**:
  - `skills/analyzing-data/scripts/cache.py` (8 functions)
  - `skills/analyzing-data/scripts/config.py` (4 functions)
  - `skills/analyzing-data/scripts/warehouse.py` (2 functions)
- **Changes**: Add return type annotations to all 14 functions. Examples:
  - `def _ensure_cache_dir():` -> `def _ensure_cache_dir() -> None:`
  - `def learn_concept(...)` -> `def learn_concept(...) -> dict[str, Any]:`
  - `def get_kernel_venv_dir()` -> `def get_kernel_venv_dir() -> Path:`
- **Effort**: 20 minutes
- **Merge likelihood**: **High** -- they already run `ty` type checker in CI and have strict ruff rules; this aligns with their existing standards

### PR 3: Extract timeout constants in analyzing-data scripts

- **PR Title**: `refactor: extract hardcoded timeout values to named constants`
- **Branch**: `refactor/timeout-constants`
- **Files to change**:
  - `skills/analyzing-data/scripts/cli.py`
  - `skills/analyzing-data/scripts/kernel.py`
- **Changes**: Define constants at module level (`KERNEL_STARTUP_TIMEOUT = 60.0`, `DEFAULT_EXECUTION_TIMEOUT = 30.0`, `SHUTDOWN_TIMEOUT = 5.0`, etc.) and replace all hardcoded values.
- **Effort**: 30 minutes
- **Merge likelihood**: **Medium-High** -- improves maintainability, follows their existing pattern (see `cache.py` which already has `DEFAULT_TTL_DAYS = 90`)

## Notes

- **No red flags.** Maintainers are highly active (last commit yesterday), PRs get reviewed quickly, clean codebase with good practices.
- **Best approach**: Start with the badges PR (zero risk, instant merge). Follow with type hints PR since they already enforce typing via `ty` in CI.
- **Community-friendly**: CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md all exist. Apache 2.0 license. Clear PR checklist.
- **Feature requests**: 11 open issues from @tayloramurphy are roadmap items for new skills. These are larger contributions but explicitly welcomed. Issue #168 (CLI sort order) is a simple bug fix that could be another quick win.
- **Avoid**: The dbt skills are vendored via git submodule from `dbt-labs/dbt-agent-skills` -- contribute to that repo separately if targeting dbt skills.
