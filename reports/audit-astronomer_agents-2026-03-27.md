Now I have everything I need. Here's the report:

---

# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is an AI agent toolkit for data engineering workflows, providing an MCP server for Apache Airflow, a CLI tool (`af`), and 30+ specialized skills for tasks like DAG authoring, debugging, data warehouse querying, dbt integration, and lineage tracing. It works as a plugin for Claude Code, Cursor, VS Code Copilot, and 20+ other AI agents.

- **Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic, Typer, Ruff, uv, prek (pre-commit)
- **Stars**: 290 | **Forks**: 33
- **Activity**: ~51 commits since Jan 2025, last commit 3 days ago (Mar 24)
- **PR responsiveness**: Very active -- PRs merged within 1-3 days. Multiple maintainers (kaxil, josh-fell, tayloramurphy, schnie)
- **Open PRs**: 7 | **Open Issues**: 4

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **No CHANGELOG** | No CHANGELOG.md exists despite multiple PyPI releases |
| **No issue templates** | `.github/ISSUE_TEMPLATE/` missing entirely |
| **No PR template** | `.github/PULL_REQUEST_TEMPLATE.md` missing |
| **Skill naming inconsistency** | 2 skills use lowercase `skill.md` instead of `SKILL.md`: `skills/managing-astro-deployments/skill.md` and `skills/troubleshooting-astro-deployments/skill.md` |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **Missing type hints** | `skills/analyzing-data/scripts/cache.py` -- `_load_json()`, `_save_json()`, `learn_concept()` lack return type annotations |
| **Overall quality** | Excellent -- Ruff linting, bandit security, ty type-checking all configured. No dead imports, no TODOs/FIXMEs |

### 3. Tests

| Issue | Details |
|-------|---------|
| **Good coverage already** | Unit tests, integration tests, Docker Compose test infra all present |
| **No coverage reporting** | No `pytest-cov` in MCP package's CI, no coverage badge |
| **Missing test**: `test_auth.py` | `auth.py` exists but no dedicated test file |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **No badges in README** | Missing CI status, PyPI version, Python version, license badges |
| **No coverage reporting** | No codecov/coveralls integration |
| **No dependabot** | No `.github/dependabot.yml` for automated dependency updates |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **Open issue #168** | `af runs list` should show most recent runs first (sorting fix) |
| **Open issue #132** | DAG skills should use user-configured linters |

## Draft PRs

### PR 1: Fix skill.md naming inconsistency

- **PR Title**: `fix: rename lowercase skill.md to SKILL.md for consistent auto-discovery`
- **Branch**: `fix/skill-md-naming`
- **Files to change**:
  - `skills/managing-astro-deployments/skill.md` -> rename to `SKILL.md`
  - `skills/troubleshooting-astro-deployments/skill.md` -> rename to `SKILL.md`
- **Changes**: `git mv` both files from `skill.md` to `SKILL.md`. All other 28+ skills use uppercase `SKILL.md`. The plugin docs explicitly reference `SKILL.md` as the expected filename.
- **Effort**: 5 minutes
- **Merge likelihood**: **High** -- Obvious consistency fix, zero risk, aligns with documented convention

### PR 2: Add GitHub issue and PR templates

- **PR Title**: `docs: add GitHub issue and PR templates`
- **Branch**: `docs/github-templates`
- **Files to change**:
  - Create `.github/ISSUE_TEMPLATE/bug_report.md` (frontmatter: name, about, labels)
  - Create `.github/ISSUE_TEMPLATE/feature_request.md`
  - Create `.github/PULL_REQUEST_TEMPLATE.md` (checklist: description, testing, prek passes)
- **Changes**: Standard GitHub templates adapted to this project's conventions. Bug template should include: description, steps to reproduce, expected vs actual behavior, environment (Airflow version, Python version, agent type). PR template should reference the CONTRIBUTING.md checklist (prek hooks, documentation, tests).
- **Effort**: 20 minutes
- **Merge likelihood**: **High** -- Standard community practice, they already have CONTRIBUTING.md and CODE_OF_CONDUCT.md but lack these templates

### PR 3: Add CI/PyPI/license badges to README

- **PR Title**: `docs: add CI status, PyPI, and license badges to README`
- **Branch**: `docs/readme-badges`
- **Files to change**:
  - `README.md` -- Add badge row after title/before description
- **Changes**: Add badges for: CI status (`ci.yml`), PyPI version (`astro-airflow-mcp`), Python versions (3.10+), License (Apache-2.0). Use standard shields.io/GitHub badge URLs. Must run `doctoc` after since README uses auto-generated TOC.
- **Effort**: 15 minutes
- **Merge likelihood**: **Medium-High** -- They already have a scarf tracking snippet (PR #151), badges are a natural addition. Note: they use `prek` with doctoc hook so the TOC will auto-update.

## Notes

- **Very active repo** -- Multiple Astronomer employees contributing regularly (kaxil, josh-fell, tayloramurphy, schnie). External contributions also merged (vojay-dev PR #154).
- **Fast merge cadence** -- PRs typically reviewed and merged within 1-3 days.
- **No "good first issue" or "help wanted" labels** -- but maintainers are clearly welcoming external contributions.
- **Best approach**: Fork, create focused single-purpose PRs. Reference the naming convention from their own docs (CLAUDE.md/AGENTS.md) when submitting the skill.md fix.
- **Low risk of abandonment** -- Backed by Astronomer (commercial company), consistent activity since inception.
- **The skill.md rename is the easiest possible PR** -- 2 file renames, undeniable improvement, references their own documentation.
