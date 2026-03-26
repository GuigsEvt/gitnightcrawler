Now let me compile the full report.

# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer's `agents` repo is an AI agent toolkit for data engineering workflows, built as a **Claude Code plugin** with 20+ auto-discovered skills and a **FastMCP server** (`astro-airflow-mcp`) for Apache Airflow 2.x/3.x. It enables AI coding assistants (Claude Code, Cursor, VS Code Copilot, Windsurf, Cline) to author DAGs, debug pipelines, query data warehouses via Jupyter kernel, trace data lineage, and manage Astro deployments. Apache 2.0 licensed.

**Tech stack:** Python 3.10+, FastMCP, httpx, Pydantic, Typer (CLI), Ruff, prek (pre-commit), GitHub Actions, Docker, Jupyter

**Activity level:** 51 commits since Jan 2025, 290 stars, 31 forks. Multiple active contributors (TJaniF, josh-fell, popey, kaxil, tayloramurphy). PRs merge within hours to days. 8 open PRs (3 drafts). Responsive maintainers.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **No CI/CD badges in README** | `README.md` line 1 | No build status, PyPI version, Python version, or license badges |
| **No CHANGELOG.md** | root | Users have no way to see what changed between releases; relies on git tags only |
| **Missing pyproject.toml metadata** | `astro-airflow-mcp/pyproject.toml` | No `authors`, `license`, `keywords`, `classifiers`, or `project.urls` fields -- hurts PyPI discoverability |

### 2. Code Quality

| Issue | Location | Details |
|-------|----------|---------|
| **Inconsistent SKILL.md casing** | `skills/managing-astro-deployments/skill.md`, `skills/troubleshooting-astro-deployments/skill.md` | Lowercase `skill.md` vs `SKILL.md` used everywhere else |
| **print() instead of logging** | `skills/analyzing-data/scripts/kernel.py:88,95,128,132` | Direct `print()` calls should use `logging` module |
| **Missing `py.typed` marker** | `astro-airflow-mcp/src/astro_airflow_mcp/` | PEP 561 marker missing -- breaks type hints for library consumers |
| **Missing `__all__` in root `__init__.py`** | `astro-airflow-mcp/src/astro_airflow_mcp/__init__.py` | Only has `__version__`, no `__all__` export list |

### 3. Tests

| Issue | Location | Details |
|-------|----------|---------|
| **29 source modules lack dedicated unit tests** | `astro-airflow-mcp/src/` | CLI (7), config (3), discovery (5), tools (6), core (8) modules have no direct test files |
| **No code coverage reporting** | CI workflows | No pytest-cov, no codecov/coveralls integration |

### 4. CI/CD

| Issue | Location | Details |
|-------|----------|---------|
| **No README badges** | `README.md` | Missing: CI status, PyPI version, Python versions, license, coverage |
| **No coverage in CI** | `.github/workflows/astro-airflow-mcp-ci.yml` | Tests run without `--cov` flag |
| **No `make coverage` target** | `astro-airflow-mcp/Makefile` | No coverage target, no docs target |

### 5. DX Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **Docker runs as root** | `astro-airflow-mcp/Dockerfile` | No non-root user, no HEALTHCHECK, single-stage build |
| **No `.dockerignore`** | `astro-airflow-mcp/` | Missing entirely -- bloats Docker context with tests, docs, etc. |
| **No `make docs`/`make release` targets** | `astro-airflow-mcp/Makefile` | Common targets missing |

---

## Draft PRs

### PR 1: Add README badges and PyPI metadata

- **PR Title:** `docs: add CI badges to README and PyPI metadata to pyproject.toml`
- **Branch:** `docs/readme-badges-pypi-metadata`
- **Files to change:**
  - `README.md` -- Add badge block at top (CI status, PyPI version, Python versions, License, Downloads)
  - `astro-airflow-mcp/pyproject.toml` -- Add `authors`, `license`, `keywords`, `classifiers`, `[project.urls]` section
- **Changes:**
  - Insert shields.io / GitHub Actions badge markdown at line 1 of README.md
  - Add to pyproject.toml: `authors = [{name = "Astronomer", email = "support@astronomer.io"}]`, `license = {text = "Apache-2.0"}`, `keywords = ["airflow", "mcp", "data-engineering", "astronomer"]`, standard PyPI classifiers (Development Status, License, Programming Language, Topic), and `[project.urls]` with Homepage, Repository, Documentation, Issues links
- **Effort:** 15-30 minutes
- **Merge likelihood:** **High** -- Pure metadata/docs, no code changes, immediate visibility improvement for PyPI and GitHub

### PR 2: Add `py.typed` marker and fix SKILL.md naming consistency

- **PR Title:** `fix: add py.typed marker and normalize skill.md casing`
- **Branch:** `fix/py-typed-and-skill-casing`
- **Files to change:**
  - Create `astro-airflow-mcp/src/astro_airflow_mcp/py.typed` (empty file)
  - Rename `skills/managing-astro-deployments/skill.md` to `SKILL.md`
  - Rename `skills/troubleshooting-astro-deployments/skill.md` to `SKILL.md`
- **Changes:**
  - Create empty `py.typed` marker file for PEP 561 compliance
  - `git mv` the two lowercase skill.md files to uppercase SKILL.md
- **Effort:** 5-10 minutes
- **Merge likelihood:** **High** -- Trivial fix, improves type-checking support and internal consistency, zero risk

### PR 3: Add `.dockerignore` and harden Dockerfile

- **PR Title:** `chore: add .dockerignore and improve Dockerfile security`
- **Branch:** `chore/docker-improvements`
- **Files to change:**
  - Create `astro-airflow-mcp/.dockerignore`
  - Edit `astro-airflow-mcp/Dockerfile`
- **Changes:**
  - `.dockerignore`: exclude `tests/`, `docs/`, `.github/`, `*.md`, `.git/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `.env*`, `docker-compose*.yml`
  - Dockerfile: Add `RUN useradd -m appuser` + `USER appuser`, add `HEALTHCHECK` instruction, optionally convert to multi-stage build
- **Effort:** 20-30 minutes
- **Merge likelihood:** **Medium-High** -- Standard Docker best practices, reduces image size and attack surface. Maintainers may have opinions on health check implementation.

---

## Notes

- **No red flags.** Active maintainers, responsive PR reviews, clear contribution guidelines.
- PRs merge fastest when they're small, focused, and pass CI. The `prek` hooks must pass (ruff, doctoc, trailing whitespace).
- The repo uses `prek` (not standard pre-commit) -- run `make install-hooks` before submitting.
- Avoid touching skills owned by dbt Labs (submodule at `skills/dbt-labs-skills/`).
- Best approach: Start with PR 1 (badges/metadata) or PR 2 (py.typed/casing) as they're zero-risk and add immediate value.
