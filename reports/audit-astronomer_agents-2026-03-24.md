I have everything I need. Here's the full audit report:

---

# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is an AI agent tooling suite for data engineering workflows. It bundles an MCP server for Apache Airflow, a CLI tool (`af`), and 30+ skills that extend AI coding agents (Claude Code, Cursor, Copilot, etc.) with specialized capabilities for DAG development, warehouse querying, data lineage, dbt integration, and Airflow migration. Built by Astronomer, Apache 2.0 licensed, works with open-source Airflow 2.x/3.x.

**Tech stack:** Python 3.10+, FastMCP, httpx, Pydantic, Typer (CLI), Hatchling build, uv package manager, Ruff linting, ty type checking, Bandit security scanning, pytest, GitHub Actions CI/CD, Docker.

**Activity level:** Very active -- ~50 commits since Feb 2025, 4+ PRs merged per week, several open PRs from core team members (kaxil, josh-fell, tayloramurphy, schnie). PRs from external contributors (vojay-dev) also merged within days. Maintainers are responsive -- most PRs merged within 1-3 days.

## Quick Win PRs

### 1. Documentation Improvements

**a) README badges are completely missing.**
No shields.io badges for PyPI version, Python versions, license, CI status, downloads, or MCP compatibility. Every mature OSS project has these.

**b) CONTRIBUTING.md references a `tests/` directory at root that doesn't exist.**
The project structure diagram shows `tests/` at root level, but tests are actually in `astro-airflow-mcp/tests/` and `skills/analyzing-data/scripts/tests/`.

**c) No CHANGELOG.md.**
Version history is only tracked via git tags. A changelog would help users understand what changed between releases.

**d) README "Development" section doesn't mention `--recurse-submodules`** in the clone command under "Development Setup" in CONTRIBUTING.md (it does in README.md but not CONTRIBUTING.md).

### 2. Code Quality

**a) Empty `pass` blocks in exception handlers.**
Multiple bare `pass` in except blocks that silently swallow errors:
- `astro-airflow-mcp/src/astro_airflow_mcp/adapters/__init__.py:59,75`
- `astro-airflow-mcp/src/astro_airflow_mcp/cli/registry.py:69`
- `astro-airflow-mcp/src/astro_airflow_mcp/adapters/airflow_v3.py:73`
- `astro-airflow-mcp/src/astro_airflow_mcp/cli/api.py:45,49`

**b) No TODO/FIXME/HACK markers found** -- codebase is clean in that regard.

### 3. Tests

**a) No test coverage reporting.**
Tests exist but no coverage measurement configured (no `--cov` in pytest config, no coveragerc, no codecov/coveralls integration).

**b) Missing tests for several source modules.**
No dedicated tests for: `auth.py`, `constants.py`, `logging.py`, `prompts.py`, `resources.py`, `interpolation.py` (config sub-module). Some may be covered indirectly but explicit test files would increase confidence.

### 4. CI/CD

**a) No badges in README** linking to CI workflow status.

**b) No automated dependency update bot** (Dependabot or Renovate config missing).

**c) No codecov or coverage reporting** in CI pipeline.

### 5. DX Improvements

**a) Issue #168 is a quick fix** -- `af runs list` should show most recent runs first by default. This is a sort-order change.

**b) Issue templates missing** -- no `.github/ISSUE_TEMPLATE/` directory for bug reports or feature requests.

**c) No PR template** -- no `.github/PULL_REQUEST_TEMPLATE.md`.

---

## Draft PRs

### PR #1: Add README badges

- **PR Title:** `docs: add project badges to README`
- **Branch:** `docs/readme-badges`
- **Files to change:** `README.md`
- **Changes:** Add badges after the `# agents` title line (before the description paragraph). Add shields for:
  - PyPI version: `https://img.shields.io/pypi/v/astro-airflow-mcp`
  - Python versions: `https://img.shields.io/pypi/pyversions/astro-airflow-mcp`
  - License: `https://img.shields.io/github/license/astronomer/agents`
  - CI status: `https://img.shields.io/github/actions/workflow/status/astronomer/agents/ci.yml?branch=main`
  - PyPI downloads: `https://img.shields.io/pypi/dm/astro-airflow-mcp`
- **Effort:** 10 minutes
- **Merge likelihood:** **High** -- zero risk, high visibility improvement, maintainers already added scarf tracking pixel so they care about polish.

### PR #2: Add GitHub issue and PR templates

- **PR Title:** `chore: add issue and PR templates`
- **Branch:** `chore/github-templates`
- **Files to change:**
  - `.github/ISSUE_TEMPLATE/bug_report.md` (new)
  - `.github/ISSUE_TEMPLATE/feature_request.md` (new)
  - `.github/ISSUE_TEMPLATE/new_skill.md` (new -- since most issues are skill requests)
  - `.github/PULL_REQUEST_TEMPLATE.md` (new)
- **Changes:** Create standard templates. Bug report template should include OS, Python version, Airflow version, MCP client used. Feature request aligned with CONTRIBUTING.md guidelines. New skill template since 10+ open issues are skill requests. PR template matching the checklist already in CONTRIBUTING.md.
- **Effort:** 20 minutes
- **Merge likelihood:** **High** -- they already have CONTRIBUTING.md with a PR checklist but no template enforcing it. The open issues show need for structure (most have no labels).

### PR #3: Fix CONTRIBUTING.md project structure + add submodule clone instructions

- **PR Title:** `docs: fix project structure and clone instructions in CONTRIBUTING.md`
- **Branch:** `docs/fix-contributing`
- **Files to change:** `CONTRIBUTING.md`
- **Changes:**
  1. Fix project structure diagram: change `tests/` to `astro-airflow-mcp/tests/` and add `skills/analyzing-data/scripts/tests/`
  2. Add `--recurse-submodules` to the git clone command (like README.md already has)
  3. Add note about vendored dbt skills via submodules
- **Effort:** 10 minutes
- **Merge likelihood:** **High** -- factual corrections, no opinion involved. The README already has the correct clone command so this is clearly an oversight.

---

## Notes

- **No red flags.** Maintainers are active (multiple Astronomer employees: kaxil, josh-fell, schnie, tayloramurphy). PRs get merged in 1-3 days. External PRs welcome (vojay-dev's airflow-plugins skill merged in 5 days).
- **No labels on issues** -- all 15 open issues have zero labels. An easy contribution would be proposing a labeling scheme, but that's more of a maintainer task.
- **Best approach:** Start with PR #1 (badges) or PR #3 (CONTRIBUTING fix) as they're zero-controversy, then follow up with PR #2 (templates). All three could be submitted the same day.
- **Open issues to claim:** Issue #168 (`af runs list` sort order) is the easiest code change -- it's a default sort parameter flip in the CLI. Good first code contribution after doc PRs build trust.
