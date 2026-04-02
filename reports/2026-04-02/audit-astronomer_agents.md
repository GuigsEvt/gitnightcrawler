Now I have everything. Here's the full audit report:

---

# Marketing Audit: astronomer/agents

## Quick Overview

The `astronomer/agents` repo provides AI agent tooling for data engineering workflows. It bundles an MCP server for Apache Airflow (supporting both v2 and v3 REST APIs), a CLI tool (`af`), and 22+ skills that extend AI coding agents (Claude Code, Cursor, etc.) with specialized capabilities for Airflow DAG development, data warehouse analysis, dbt integration, and data lineage tracing. Built by Astronomer, Apache 2.0 licensed.

**Tech stack:** Python 3.10+, FastMCP, Pydantic v2, httpx, Typer (CLI), hatchling (build), Ruff (linting), ty (type checking), prek (pre-commit), pytest

**Activity level:** Very active -- 55 commits since Jan 2025, 12 contributors, 3-5 commits/week. PRs get merged within 1-7 days. 9 open PRs. Responsive maintainers (Kaxil Naik, Greg Neiheisel, Josh Fell, Taylor Murphy).

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details | Effort |
|------|---------|--------|
| **No badges in main README** | `astro-airflow-mcp/README.md` has CI, PyPI, Python, License badges but the root `README.md` has zero badges | 5 min |
| **No CHANGELOG** | No CHANGELOG.md file exists. Active projects with PyPI releases benefit from one | 30 min |
| **Missing GitHub Issue/PR templates** | `.github/ISSUE_TEMPLATE/` and `.github/pull_request_template.md` don't exist. CONTRIBUTING.md references bug reports/feature requests but has no structured templates | 20 min |
| **Broken CI badge URL** | `astro-airflow-mcp/README.md` links to `github.com/astronomer/astro-airflow-mcp/actions/...` but the repo is actually `astronomer/agents` | 2 min |
| **Root README lacks `af` CLI usage examples** | Section mentions `af health`, `af dags list` but no output examples or screenshots | 15 min |
| **No architecture diagram** | The MCP server has a clean adapter pattern (v2/v3) but no visual architecture diagram in README | 20 min |

### 2. Code Quality

| Item | Details | Effort |
|------|---------|--------|
| **Clean codebase** | No TODO/FIXME/HACK comments found. Type hints are comprehensive. Ruff is well-configured. | N/A |
| **Zero issues found** | Linting config is thorough (E, W, F, I, B, C4, UP, ARG, SIM, etc.). Modern Python patterns used throughout | N/A |

This area is well-maintained -- not a good quick-win target.

### 3. Tests

| Item | Details | Effort |
|------|---------|--------|
| **No test coverage reporting** | 34 test files exist but no coverage config (`[tool.coverage]` in pyproject.toml) and no coverage badge | 15 min |
| **No CI coverage upload** | Workflows run tests but don't measure or report coverage (no `pytest-cov`, no Codecov/Coveralls) | 30 min |
| **Skills have no tests** | 22 skills are markdown-only (expected), but only `analyzing-data` has Python scripts with tests. Other skills with hooks (`airflow/hooks/`) have no tests for the shell scripts | 1-2 hrs |

### 4. CI/CD

| Item | Details | Effort |
|------|---------|--------|
| **No Dependabot/Renovate config** | No `.github/dependabot.yml` for automated dependency updates | 10 min |
| **No GitHub Actions for skill validation** | Skills are markdown with YAML frontmatter but no CI validates frontmatter schema | 45 min |
| **No release-please / auto-changelog** | Releases are manual. No automated changelog generation | 30 min |

### 5. DX Improvements

| Item | Details | Effort |
|------|---------|--------|
| **No `warehouse.yml` example file** | README shows config but no example file in the repo at e.g. `examples/warehouse.yml` | 10 min |
| **No `.env.example`** | Credentials documented in README but no template file for `~/.astro/agents/.env` | 5 min |
| **Docker instructions incomplete** | Dockerfile exists in `astro-airflow-mcp/` but no mention in root README, no docker-compose for end users | 20 min |

---

## Draft PRs

### PR #1: Add badges and missing templates to root README

- **PR Title:** `docs: add status badges to root README and GitHub issue templates`
- **Branch:** `docs/badges-and-templates`
- **Files to change:**
  - `README.md` -- Add badges after line 1 (before first paragraph):
    ```markdown
    [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
    [![PyPI - astro-airflow-mcp](https://img.shields.io/pypi/v/astro-airflow-mcp.svg?color=blue)](https://pypi.org/project/astro-airflow-mcp)
    [![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
    [![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-green.svg)](./LICENSE)
    ```
  - `.github/ISSUE_TEMPLATE/bug_report.yml` -- Create structured bug report template
  - `.github/ISSUE_TEMPLATE/feature_request.yml` -- Create feature request template
  - `.github/pull_request_template.md` -- Create PR template with checklist
- **Effort:** 20 min
- **Merge likelihood:** **High** -- Pure docs improvement, no code changes, follows patterns already in `astro-airflow-mcp/README.md`

### PR #2: Add Dependabot config for automated dependency updates

- **PR Title:** `ci: add Dependabot configuration for pip and GitHub Actions`
- **Branch:** `ci/dependabot`
- **Files to change:**
  - `.github/dependabot.yml` -- Create with:
    ```yaml
    version: 2
    updates:
      - package-ecosystem: "pip"
        directory: "/astro-airflow-mcp"
        schedule:
          interval: "weekly"
        groups:
          dependencies:
            patterns: ["*"]
      - package-ecosystem: "github-actions"
        directory: "/"
        schedule:
          interval: "weekly"
    ```
- **Effort:** 10 min
- **Merge likelihood:** **High** -- Standard practice, the repo already has hardened workflows and CODEOWNERS. Zero risk.

### PR #3: Add test coverage reporting to CI

- **PR Title:** `ci: add pytest coverage reporting with Codecov integration`
- **Branch:** `ci/coverage-reporting`
- **Files to change:**
  - `astro-airflow-mcp/pyproject.toml` -- Add `pytest-cov` to dev dependencies and `[tool.coverage]` config:
    ```toml
    [tool.coverage.run]
    source = ["src/astro_airflow_mcp"]
    omit = ["*/tests/*"]

    [tool.coverage.report]
    show_missing = true
    fail_under = 0
    ```
  - `.github/workflows/astro-airflow-mcp-ci.yml` -- Add `--cov` flag to pytest invocation and upload coverage artifact
  - `README.md` -- Add coverage badge
- **Effort:** 30 min
- **Merge likelihood:** **Medium** -- Useful but maintainers may have opinions on coverage tool (Codecov vs Coveralls) and minimum thresholds. Open an issue first to ask.

---

## Notes

- **No red flags.** Maintainers are very active (commits within hours of each other). PRs merge within days. 12 contributors. Professional project with CODEOWNERS, security policy, and hardened CI.
- **Best approach:** Start with PR #1 (badges + templates) or PR #2 (Dependabot) -- both are zero-risk, high-value. Open an issue first for PR #3 to align on coverage tool preference.
- **Fix the broken CI badge link** in `astro-airflow-mcp/README.md` (points to wrong repo URL `astronomer/astro-airflow-mcp` instead of `astronomer/agents`) -- could be a standalone 1-line fix PR.
- **PR backlog:** 9 open PRs, oldest from Feb 5 (2 months). One marked "Do not merge yet". Others appear to be in active review. Not a concern.
- **Community-friendly:** Has CONTRIBUTING.md, CODE_OF_CONDUCT.md, Apache 2.0 license. Accepts external PRs (e.g., PR #154 from `vojay-dev`).
