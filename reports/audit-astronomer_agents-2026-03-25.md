Now I have everything I need. Let me compile the report.

---

# Marketing Audit: astronomer/agents

## Quick Overview

**astronomer/agents** is an AI agent tooling suite for data engineering workflows. It provides an MCP (Model Context Protocol) server for Apache Airflow, a CLI tool (`af`), and 22+ skills that extend AI coding agents (Claude Code, Cursor, VS Code, etc.) with specialized capabilities for DAG authoring, data warehouse querying, lineage tracing, dbt integration, and Airflow migration. Built by Astronomer, Apache 2.0 licensed.

**Tech stack:** Python 3.10+, FastMCP, httpx, Pydantic, Typer (CLI), Polars/Pandas (data analysis), Jupyter kernels, Docker, uv (package manager), Ruff (linting), prek (pre-commit)

**Activity level:** Very active -- 290 stars, 31 forks, ~51 commits since Jan 2025. PRs are merged within 1-3 days. Maintainers are responsive. Multiple open PRs and issues indicate active development. Last merge: March 24, 2026.

---

## Quick Win PRs

### 1. Documentation Improvements

**1a. Root README missing badges**
The root `README.md` has zero badges -- no CI status, no license badge, no PyPI version, no Python version. The sub-package README (`astro-airflow-mcp/README.md`) already has them. Adding badges to the root README is a 5-minute fix that increases project credibility.

**1b. Broken CI badge URL in astro-airflow-mcp/README.md**
Line 36: `https://github.com/astronomer/astro-airflow-mcp/actions/workflows/ci.yml` -- this points to a separate repo `astro-airflow-mcp`, but the actual CI lives at `astronomer/agents`. Same for the license badge link on line 39. These badges likely 404.

**1c. CONTRIBUTING.md project structure is outdated**
The structure diagram (line 51-61) shows a simplified tree that omits `.cursor-plugin/`, `vendor/`, `AGENTS.md`, `CODE_OF_CONDUCT.md`, and the `astro-airflow-mcp/` CLI components. Also missing: `--recurse-submodules` in the clone command (line 34).

**1d. No CHANGELOG file**
The project has no `CHANGELOG.md`. With 166+ PRs and PyPI releases, a changelog would help users track breaking changes. The publish workflow uses git tags, so a `CHANGELOG.md` generated from PR titles would be valuable.

### 2. Code Quality

**2a. Duplicate skill.md / SKILL.md files**
Every skill directory contains both `SKILL.md` and `skill.md` (22 pairs = 44 files). They have identical line counts and appear to be duplicates. This is likely for case-insensitive platform compatibility but creates confusion -- should be symlinks or documented.

**2b. No `py.typed` marker in astro-airflow-mcp**
The package uses extensive type hints and runs `ty` for type checking but doesn't ship a `py.typed` marker file, so downstream consumers can't benefit from the types.

### 3. Tests

**3a. Root CI only tests `analyzing-data` scripts**
The `ci.yml` workflow runs unit/integration/typecheck only for `skills/analyzing-data/scripts/`. The 20+ test files in `astro-airflow-mcp/tests/` are covered by a separate workflow (`astro-airflow-mcp-ci.yml`) that only triggers on changes to `astro-airflow-mcp/**`. There's no unified test run on PRs touching root files.

**3b. No test coverage reporting**
Neither CI workflow generates coverage reports or uploads to Codecov/Coveralls. Adding `pytest-cov` + a coverage badge is low-effort and high-visibility.

### 4. CI/CD

**4a. No badges on root README**
As noted above -- adding CI, PyPI, License, and Python version badges.

**4b. No dependabot/renovate configuration**
No `.github/dependabot.yml` or `renovate.json`. The project uses `uv.lock` and multiple `pyproject.toml` files that would benefit from automated dependency updates.

**4c. No release-drafter or changelog automation**
Releases are manual via git tags. Adding a `release-drafter` GitHub Action would auto-generate release notes from PR labels.

### 5. DX Improvements

**5a. Missing `.env.example` template**
The README references `~/.astro/agents/.env` for credentials but there's no `.env.example` or template file. Users have to read the docs to know which env vars to set.

**5b. No `Makefile` at root level**
The `astro-airflow-mcp/` subdirectory has a comprehensive Makefile but the root project has none. A root Makefile with `make test`, `make lint`, `make setup` would improve contributor onboarding.

---

## Draft PRs

### PR 1: Add badges and fix broken links in READMEs

- **PR Title:** `docs: add badges to root README and fix broken CI links`
- **Branch:** `docs/readme-badges`
- **Files to change:**
  - `README.md` -- Add badges after line 1 (CI status, PyPI version, Python, License, Stars)
  - `astro-airflow-mcp/README.md` -- Fix CI badge URL from `astronomer/astro-airflow-mcp` to `astronomer/agents` (lines 36, 39)
- **Changes:**
  ```markdown
  # agents
  
  [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
  [![PyPI - Version](https://img.shields.io/pypi/v/astro-airflow-mcp.svg?color=blue)](https://pypi.org/project/astro-airflow-mcp)
  [![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
  [![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://github.com/astronomer/agents/blob/main/LICENSE)
  ```
  Fix astro-airflow-mcp/README.md line 36: `astronomer/astro-airflow-mcp` -> `astronomer/agents`
  Fix astro-airflow-mcp/README.md line 39: same pattern for license link
- **Effort:** 15 minutes
- **Merge likelihood:** **High** -- Pure docs improvement, no code changes, fixes broken links

### PR 2: Add .env.example and root Makefile for contributor DX

- **PR Title:** `docs: add .env.example template and root Makefile`
- **Branch:** `docs/contributor-dx`
- **Files to change:**
  - Create `~/.astro/agents/.env.example` (or document in repo as `examples/.env.example`)
  - Create root `Makefile` with targets: `setup`, `lint`, `test`, `test-mcp`, `test-analyzing-data`
- **Changes:**
  - `.env.example`: Template with all documented env vars (SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, etc.) with placeholder values
  - `Makefile`: Wrapper targets that delegate to sub-projects (`cd astro-airflow-mcp && make ci`, `cd skills/analyzing-data/scripts && uv run pytest`)
- **Effort:** 30 minutes
- **Merge likelihood:** **Medium-High** -- Improves contributor onboarding, follows the pattern already established in `astro-airflow-mcp/Makefile`

### PR 3: Add test coverage reporting to CI

- **PR Title:** `ci: add pytest-cov and coverage badge`
- **Branch:** `ci/test-coverage`
- **Files to change:**
  - `astro-airflow-mcp/pyproject.toml` -- Add `pytest-cov` to dev dependencies
  - `.github/workflows/astro-airflow-mcp-ci.yml` -- Add `--cov` flag, upload coverage artifact
  - `.github/workflows/ci.yml` -- Same for analyzing-data tests
  - `README.md` -- Add coverage badge
- **Changes:**
  - Add `pytest-cov>=4.0` to dev dependencies
  - Modify pytest commands: `pytest --cov=astro_airflow_mcp --cov-report=xml tests/`
  - Optional: Add Codecov upload step with `codecov/codecov-action@v4`
- **Effort:** 45 minutes
- **Merge likelihood:** **Medium** -- Standard practice, but maintainers may have opinions on coverage thresholds and reporting service choice

---

## Notes

- **Maintainer activity:** Very active, responsive. PRs merged in 1-3 days. No red flags.
- **External contributions welcome:** CONTRIBUTING.md exists, Code of Conduct in place, Apache 2.0 license. Open issues tagged with feature requests.
- **Open issue #168** (`af runs list: show most recent runs first by default`) is a trivial code fix -- good first issue candidate.
- **Open issue #132** (`Dag skills should use any linters the user has configured`) is a feature enhancement that could be a good contribution.
- **Best approach:** Start with PR 1 (badges + broken links) -- it's a no-brainer merge. Follow up with PR 2 after establishing credibility.
- **Careful with:** The duplicate `SKILL.md`/`skill.md` pattern -- it may be intentional for multi-platform support (Claude Code uses `SKILL.md`, Cursor uses `skill.md`). Investigate before filing a PR.
