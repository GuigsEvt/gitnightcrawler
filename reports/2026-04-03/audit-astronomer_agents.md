# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is an AI agent tooling suite for data engineering with Apache Airflow. It includes a FastMCP server for Airflow REST API integration, a CLI tool (`af`), and 23+ extensible skills for Claude Code and Cursor. Skills cover DAG authoring, debugging, deployment, data analysis (Snowflake/BigQuery/Postgres), dbt integration via Cosmos, lineage tracing, and Airflow 2-to-3 migration.

- **Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic, typer, pytest; Markdown-based skills with YAML frontmatter
- **Activity**: 58 commits in 2025, **21 commits in last month** -- very active
- **PR responsiveness**: PRs merged within days. 9 open PRs (4 drafts, some external). Maintainers are responsive and engaged.

---

## Quick Win PRs

### 1. Documentation Improvements

| Finding | Location | Details |
|---------|----------|---------|
| **Missing badges** | `README.md` top | No PyPI version badge, no CI status badge, no license badge, no Python version badge -- most mature OSS repos have these |
| **No CHANGELOG** | Root | No CHANGELOG.md despite 3 tagged releases (`astro-airflow-mcp-0.5.0` through `0.6.0`) |
| **MCP README sparse** | `astro-airflow-mcp/README.md` | Very short, could add usage examples, configuration reference |
| **Contributing guide missing dev setup for skills** | `CONTRIBUTING.md` | Only covers MCP server dev setup, not how to test/preview skills locally |

### 2. Code Quality

| Finding | Location | Details |
|---------|----------|---------|
| **File naming inconsistency** | `skills/troubleshooting-astro-deployments/skill.md`, `skills/managing-astro-deployments/skill.md` | Lowercase `skill.md` while all other 21 skills use `SKILL.md` |
| **No py.typed marker** | `astro-airflow-mcp/src/astro_airflow_mcp/` | Missing `py.typed` for PEP 561 compliance -- downstream consumers can't use type info |
| **No `__all__` exports** | Various `__init__.py` | Public API not explicitly defined |

### 3. Tests

| Finding | Location | Details |
|---------|----------|---------|
| **No tests for skill hooks** | `skills/airflow/hooks/` | `warm-uvx-cache.sh` is untested |
| **No SKILL.md frontmatter validation test** | Root CI | No automated check that all SKILL.md files have valid YAML frontmatter (name, description required) |
| **No link checker** | CI | No automated broken-link detection for README or SKILL files |

### 4. CI/CD

| Finding | Location | Details |
|---------|----------|---------|
| **No CI badge in README** | `README.md` | Missing `![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)` |
| **No dependabot/renovate** | `.github/` | No automated dependency update bot configured |
| **No release automation for skills** | `.github/workflows/` | Only MCP server has publish workflow; no versioned releases for the plugin itself |

### 5. DX Improvements

| Finding | Location | Details |
|---------|----------|---------|
| **Issue #168 open** | GitHub | `af runs list` should show most recent runs first -- simple sort fix |
| **Issue #132 open** | GitHub | DAG skills should use user's configured linters -- skill enhancement |
| **No `make help` target** | `astro-airflow-mcp/Makefile` | Makefile has 20+ targets but no self-documenting help |

---

## Draft PRs

### PR 1: Add README badges and CI status

- **PR Title**: `docs: add PyPI, CI, license, and Python version badges to README`
- **Branch**: `docs/readme-badges`
- **Files to change**: `README.md`
- **Changes**: Add badge row after the title/logo section:
  ```markdown
  [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
  [![PyPI](https://img.shields.io/pypi/v/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![Python](https://img.shields.io/pypi/pyversions/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![License](https://img.shields.io/github/license/astronomer/agents)](LICENSE)
  ```
- **Effort**: 10 minutes
- **Merge likelihood**: **HIGH** -- purely additive, no code changes, standard OSS practice

### PR 2: Fix SKILL.md naming inconsistency

- **PR Title**: `fix: rename lowercase skill.md to SKILL.md for consistency`
- **Branch**: `fix/skill-filename-consistency`
- **Files to change**:
  - `skills/troubleshooting-astro-deployments/skill.md` -> `SKILL.md`
  - `skills/managing-astro-deployments/skill.md` -> `SKILL.md`
- **Changes**: `git mv` both files from lowercase to uppercase. 21/23 skills use uppercase; these 2 are outliers.
- **Effort**: 5 minutes
- **Merge likelihood**: **HIGH** -- obvious consistency fix, zero risk, easy to review

### PR 3: Add frontmatter validation test

- **PR Title**: `test: add SKILL.md frontmatter validation to CI`
- **Branch**: `test/skill-frontmatter-validation`
- **Files to change**: New file `tests/test_skills.py` (or add to existing CI script)
- **Changes**: Simple Python test that globs all `skills/*/SKILL.md`, parses YAML frontmatter, asserts `name` and `description` fields exist and are non-empty. Prevents malformed skills from being merged.
  ```python
  import glob, yaml, pathlib
  
  def test_all_skills_have_valid_frontmatter():
      for path in glob.glob("skills/*/SKILL.md") + glob.glob("skills/*/skill.md"):
          content = pathlib.Path(path).read_text()
          assert content.startswith("---"), f"{path}: missing frontmatter"
          fm = content.split("---")[1]
          data = yaml.safe_load(fm)
          assert "name" in data, f"{path}: missing name"
          assert "description" in data, f"{path}: missing description"
  ```
- **Effort**: 20 minutes
- **Merge likelihood**: **HIGH** -- adds safety net, aligns with their existing CI patterns, zero disruption

---

## Notes

- **No red flags**: Maintainers are active (21 commits last month), PRs get reviewed fast, external contributions are welcome.
- **CODEOWNERS enforced**: `.github/`, `.claude-plugin/`, and `CLAUDE.md` require `@astronomer/agents-approvers` -- keep PRs outside these paths for faster merge.
- **Best approach**: Start with PR 1 (badges) or PR 2 (filename fix) -- both are trivially reviewable. Follow up with PR 3 (validation test) to establish contributor credibility before tackling open issues like #168 or #132.
- **External PRs exist**: Several community PRs are open (#169, #164, #171) showing they accept outside contributions.
- **Pre-commit hooks**: They use `prek` (ruff + doctoc) -- run these before submitting or CI will fail.
