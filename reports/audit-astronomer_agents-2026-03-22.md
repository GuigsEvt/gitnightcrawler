Here's the full audit report:

# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is an AI agent toolkit for data engineering workflows built around Apache Airflow. It bundles an MCP server (`astro-airflow-mcp`) for Airflow REST API integration, a CLI tool (`af`), and 32 skills (22 local + 10 vendored from dbt-labs) that extend AI coding agents with specialized capabilities for DAG development, data warehousing, lineage tracing, and dbt integration. Works with Claude Code, Cursor, VS Code, and any MCP-compatible client.

- **Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic, Typer, uv (package manager), prek (pre-commit hooks), ruff (linting), ty (type checking)
- **Activity level**: Very active -- 20+ commits in last 3 weeks, multiple PRs merged weekly, fast review turnaround (PRs merged same day or within days)
- **Maintainers**: Astronomer team (josh-fell, kaxil, others), responsive to external PRs (#162, #163 from external contributors merged quickly)

---

## Quick Win PRs

### 1. Documentation Improvements

**1a. README missing `airflow-plugins` skill**
The `airflow-plugins` skill (added in #154, March 9) exists in `skills/airflow-plugins/` but is **not listed in README.md's skills tables**. Every other local skill has a row.

**1b. README missing `managing-astro-deployments` and `troubleshooting-astro-deployments` skills**
Both exist in `skills/` but are absent from README.md.

**1c. CONTRIBUTING.md missing MCP server dev setup**
References the MCP server ("See its README for specific development instructions") but doesn't include `make install-dev` / `make test`. Contributors have to discover this.

**1d. Error message has shell syntax instead of Python**
`base.py:18-19` uses `${READ_ONLY_ENV_VAR}` (shell-style `$`) in a Python f-string. Outputs `($AF_READ_ONLY=true)` instead of `(AF_READ_ONLY=true)`.

### 2. Code Quality

- Codebase is well-maintained. Ruff + prek hooks + ty type checking enforced in CI.
- Late-stage imports in `server.py` with `# noqa: E402, F401` for side-effect registration could use an explanatory comment.
- No TODO/FIXME/HACK comments found -- clean codebase.

### 3. Tests

**3a. Missing test files for MCP resources and prompts**
- `resources.py` -- no dedicated test (4 resource endpoints)
- `prompts.py` -- no dedicated test (3 prompt definitions)
- Multiple CLI modules (`cli/dags.py`, `cli/runs.py`, `cli/tasks.py`, `cli/assets.py`, `cli/instances.py`, `cli/context.py`, `cli/output.py`) -- no dedicated tests

**3b. Skills-level tests only cover `analyzing-data`**
CI only runs tests for `skills/analyzing-data/scripts/tests/`. No validation of SKILL.md frontmatter across all 32 skills.

### 4. CI/CD

**4a. No badges in README** -- No CI status, PyPI version, or license badge.

**4b. No SKILL.md frontmatter validation** -- No CI job validates that all SKILL.md files have required `name` and `description` fields.

**4c. No link checker** -- No automated broken link detection in docs.

### 5. DX Improvements

**5a. No `.env.example`** -- Users must figure out env var names from docs. A template would help onboarding.

**5b. Sparse troubleshooting table** -- Only 3 entries. Missing common issues: "MCP server not starting", "uvx not found", "SSL errors".

---

## Draft PRs

### PR #1: Add missing skills to README

- **PR Title**: `docs: add missing skills to README skill tables`
- **Branch**: `docs/add-missing-readme-skills`
- **Files to change**: `README.md`
- **Changes**:
  - Add `airflow-plugins` row to DAG Development table (after `airflow-hitl` line ~193):
    ```
    | [airflow-plugins](./skills/airflow-plugins/) | Build custom Airflow plugins (operators, hooks, sensors) |
    ```
  - Add `managing-astro-deployments` and `troubleshooting-astro-deployments` rows (new "Deployment & Operations" section or existing table)
  - Run `prek run --all-files` to regenerate TOC
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- purely additive docs fix. PR #154 added airflow-plugins but didn't update README. Maintainers merge docs PRs same-day.

### PR #2: Add CI status badge to README

- **PR Title**: `docs: add CI and PyPI badges to README`
- **Branch**: `docs/add-ci-badge`
- **Files to change**: `README.md`
- **Changes**: Add after line 1:
  ```markdown
  [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
  [![astro-airflow-mcp](https://github.com/astronomer/agents/actions/workflows/astro-airflow-mcp-ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/astro-airflow-mcp-ci.yml)
  [![PyPI](https://img.shields.io/pypi/v/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
  ```
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- standard practice, signals project health

### PR #3: Fix shell syntax in ReadOnlyError message

- **PR Title**: `fix: correct env var display in ReadOnlyError message`
- **Branch**: `fix/readonly-error-message`
- **Files to change**: `astro-airflow-mcp/src/astro_airflow_mcp/adapters/base.py`
- **Changes**: Line 18-19, change `(${READ_ONLY_ENV_VAR}=true)` to `({READ_ONLY_ENV_VAR}=true)` -- removes erroneous `$` prefix in the f-string interpolation
- **Effort**: 5 minutes
- **Merge likelihood**: **High** -- single-line bug fix, improves user-facing error message, existing `test_read_only.py` covers this path

---

## Notes

- **No red flags**: Maintainers are very active and responsive. External contributions welcomed and merged quickly.
- **PR #164 (open)**: External contributor improving skill scores across 12 skills -- community engagement is healthy.
- **Best approach**: Small, focused PRs. Docs-only PRs get merged fastest. Use conventional commits. Run `prek run --all-files` before submitting.
- **prek not pre-commit**: This project uses [prek](https://github.com/astral-sh/prek), a faster alternative. CONTRIBUTING.md is correct.
- **Submodules**: Clone with `--recurse-submodules` to get vendored dbt skills.
- **Safest first contribution**: The missing README entries (PR #1) -- zero risk, high visibility, clearly an oversight from PR #154.
