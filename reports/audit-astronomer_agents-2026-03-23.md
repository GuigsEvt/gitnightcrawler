Now I have everything I need. Let me produce the report.

# Marketing Audit: astronomer/agents

## Quick Overview

Astronomer Agents is an open-source AI agent tooling suite for data engineering workflows. It provides a **FastMCP server** for Apache Airflow, a **CLI tool (`af`)** for terminal-based Airflow interaction, and **31+ skills** that extend AI coding agents (Claude Code, Cursor) with specialized capabilities for Airflow, data warehouses, and dbt. Built by Astronomer under Apache 2.0.

- **Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic, Typer, pytest, Ruff, `ty` type checker
- **Activity**: ~50 commits since Jan 2025, ~6 active contributors (Kaxil Naik leading with 17), 3 open PRs, PRs merged within 1-3 days. **Very active, responsive maintainers.**

---

## Quick Win PRs

### 1. Documentation Improvements

**a) README: No badges at all**
The README has zero badges -- no CI status, PyPI version, Python version, license, or downloads badge. This is the single most visible improvement.

**b) README: Missing `astro-airflow-mcp` PyPI link**
The README never links to the PyPI package page. Users who want `pip install astro-airflow-mcp` have to guess.

**c) README: Title is just "agents"**
The H1 is `# agents` -- should be `# Astronomer Agents` or similar branded name with a one-liner tagline.

**d) `astro-airflow-mcp/README.md`: Could use a quick-start code snippet**
The sub-package README exists but could benefit from a 3-line "try it now" snippet.

### 2. Code Quality

**a) `ty` type rules are nearly all downgraded to warnings**
`pyproject.toml` lines 111-115 downgrade `invalid-argument-type`, `unresolved-attribute`, `missing-argument`, `invalid-method-override`, `invalid-assignment` all to `warn`. Fixing even one of these to `error` and resolving the underlying issues would be a meaningful quality improvement.

**b) No `py.typed` marker**
The package doesn't include a `py.typed` marker file, so downstream consumers can't use it for type checking.

### 3. Tests

**a) No test coverage reporting**
Neither CI workflow generates coverage reports. Adding `pytest-cov` with a coverage badge would be high-visibility.

**b) Skills directory has minimal test coverage**
Only `skills/analyzing-data/scripts` has tests. The other 30+ skills have no automated validation (even for YAML frontmatter correctness).

**c) SKILL.md frontmatter validation**
No CI step validates that all `skills/*/SKILL.md` files have correct YAML frontmatter (name, description fields). A simple script could catch broken skills before merge.

### 4. CI/CD

**a) No GitHub Actions badges in README**
Four workflows exist but none are surfaced in the README.

**b) No dependabot/renovate config**
No automated dependency update mechanism. Adding `dependabot.yml` for pip/GitHub Actions would be easy.

**c) No release-please or changelog automation**
The project uses hatch-vcs for versioning but has no automated changelog generation.

### 5. DX Improvements

**a) No `.editorconfig`**
No `.editorconfig` file to ensure consistent formatting across IDEs.

**b) `af` CLI has no shell completions documented**
Typer supports shell completion out of the box, but it's not mentioned in the README.

**c) Dockerfile could use multi-stage build**
Current Dockerfile is single-stage. A multi-stage build would reduce image size.

---

## Draft PRs

### PR #1: Add README badges and improve header

- **PR Title**: `docs: add CI/PyPI/license badges and improve README header`
- **Branch**: `docs/readme-badges`
- **Files to change**: `README.md`
- **Changes**:
  Replace lines 1-5 with:
  ```markdown
  # Astronomer Agents

  [![CI](https://github.com/astronomer/agents/actions/workflows/ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/ci.yml)
  [![MCP Server CI](https://github.com/astronomer/agents/actions/workflows/astro-airflow-mcp-ci.yml/badge.svg)](https://github.com/astronomer/agents/actions/workflows/astro-airflow-mcp-ci.yml)
  [![PyPI](https://img.shields.io/pypi/v/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![Python](https://img.shields.io/pypi/pyversions/astro-airflow-mcp)](https://pypi.org/project/astro-airflow-mcp/)
  [![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

  AI agent tooling for data engineering workflows...
  ```
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- purely additive, no code changes, improves project visibility

### PR #2: Add SKILL.md frontmatter validation to CI

- **PR Title**: `ci: add SKILL.md frontmatter validation`
- **Branch**: `ci/validate-skill-frontmatter`
- **Files to change**:
  - `.github/workflows/ci.yml` (add new job)
  - `scripts/validate_skills.py` (new, ~30 lines)
- **Changes**:
  Add a Python script that scans `skills/*/SKILL.md`, parses YAML frontmatter, and asserts `name` and `description` exist. Add a CI job that runs it. This catches broken skills before merge -- directly relevant since PR #147 was literally "Fix airflow-adapter skill frontmatter".
  ```python
  # scripts/validate_skills.py
  import sys, yaml, glob
  errors = []
  for path in sorted(glob.glob("skills/*/SKILL.md")):
      with open(path) as f:
          content = f.read()
      if not content.startswith("---"):
          errors.append(f"{path}: missing YAML frontmatter")
          continue
      fm = content.split("---", 2)[1]
      data = yaml.safe_load(fm)
      for field in ("name", "description"):
          if not data or field not in data:
              errors.append(f"{path}: missing '{field}'")
  if errors:
      print("\n".join(errors))
      sys.exit(1)
  print(f"Validated {len(list(glob.glob('skills/*/SKILL.md')))} skills OK")
  ```
- **Effort**: 30 minutes
- **Merge likelihood**: **High** -- prevents regressions they've already experienced (PR #147), minimal CI cost

### PR #3: Add pytest coverage reporting

- **PR Title**: `ci: add test coverage reporting with pytest-cov`
- **Branch**: `ci/test-coverage`
- **Files to change**:
  - `astro-airflow-mcp/pyproject.toml` (add `pytest-cov` to dev deps, add `[tool.coverage]` config)
  - `.github/workflows/astro-airflow-mcp-ci.yml` (add `--cov` flag, upload coverage artifact)
- **Changes**:
  Add `pytest-cov>=4.0.0` to dev dependencies. Configure `[tool.coverage.run]` with source and omit patterns. Update CI to run `pytest --cov=astro_airflow_mcp --cov-report=xml`. Optionally add coverage badge via codecov or similar.
- **Effort**: 30 minutes
- **Merge likelihood**: **Medium-High** -- standard practice, but maintainers may have opinions on coverage service choice (codecov vs coveralls vs none)

---

## Notes

- **No red flags**: Maintainers are responsive (PRs merged in 1-3 days), the project is actively developed, clean commit history with conventional commits, comprehensive CONTRIBUTING.md.
- **Best approach**: Start with PR #1 (badges) -- it's the easiest, most visible, and hardest to reject. Follow with PR #2 since it addresses a real bug they already hit.
- **Open issues to claim**: Issue #168 (`af runs list: show most recent runs first by default`) is a great first code contribution -- small, well-scoped, clear behavior change.
- **Community**: 6 open PRs show active external contribution. Labels are not heavily used, so clear PR descriptions matter.
- **Avoid**: The dbt-agent-skills submodule is maintained by dbt Labs, not Astronomer -- don't PR into that subtree.
