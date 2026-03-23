Now I have all the data needed. Let me compile the report.

# Marketing Audit: fosdickio/binary_ninja_mcp

## Quick Overview

Binary Ninja MCP is a plugin + MCP bridge that connects Binary Ninja (a reverse engineering tool) to LLM clients via the Model Context Protocol. It exposes 50+ tools for decompilation, cross-references, binary patching, type management, and more through an HTTP server, allowing AI assistants to interact with binaries in real-time. Supports 7+ MCP clients including Claude Desktop, Cline, Cursor, and Claude Code.

**Tech stack:** Python 3.12+ (plugin/server), TypeScript/Node.js (MCP bridge), Binary Ninja API, FastMCP, Axios, Zod

**Activity level:**
- 273 stars, 61 forks -- strong traction for a niche tool
- 49 commits since Jan 2025, last commit yesterday (2026-03-22)
- 5 open PRs, 20+ open issues
- Active maintainer (fosdickio) + prolific contributor (CX330Blake)
- PRs get merged, but with delays (some sit for weeks/months) -- patience needed
- GPL-3.0 license

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **No CONTRIBUTING.md** | Repo says "Contributions are welcome" but has zero contribution guidelines |
| **No issue/PR templates** | Missing `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md` |
| **README tool table inconsistency** | Some functions show parameters `get_il(name_or_address, view, ssa)`, others don't -- inconsistent formatting |
| **Missing badge** | No CI status badge in README despite having GitHub Actions |
| **Bridge README is sparse** | `bridge/README.md` likely has minimal content vs the extensive main README |
| **No changelog** | 49 commits, version 1.1.0, but no CHANGELOG.md |
| **Missing troubleshooting section** | 20+ open issues, many about setup problems (Windows auto-setup, proxy issues) -- a FAQ/troubleshooting section would help |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **No type hints on many functions** | Core files like `binary_operations.py`, `endpoints.py`, `http_server.py` are 1000+ lines -- likely missing return type annotations (PR #65 already addresses some pydantic-related ones) |
| **No `py.typed` marker** | Missing for typed package consumers |
| **Config dataclass unused fields** | `config.py` defines `BinaryNinjaConfig.api_version` and `log_level` but these may not be wired up |
| **CORS wildcard** | `Access-Control-Allow-Origin: *` is a security concern for network-exposed mode (`exposeToNetwork`) |
| **`continue-on-error: false`** in CI | This is the default, the lines are redundant |

### 3. Tests

| Issue | Details |
|-------|---------|
| **Zero test files** | No `tests/` directory, no `test_*.py` files anywhere |
| **Utility functions are easily testable** | `number_utils.py` (277 lines of pure conversion logic) and `string_utils.py` are perfect candidates for unit tests with no Binary Ninja dependency |
| **No pytest config** | No `pyproject.toml`, `setup.cfg`, or `conftest.py` |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **Python-only CI** | No TypeScript linting/type-checking in CI (bridge has `tsconfig.json` with strict mode but no CI step) |
| **No dependency caching** | CI installs pip packages every run without caching |
| **No release automation** | No GitHub Releases workflow, no semantic versioning automation |
| **Missing `pyproject.toml`** | No Python project metadata file -- can't `pip install` the project |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **No `.env.example`** | Environment variables (`BINJA_MCP_HOST`, `BINJA_MCP_PORT`) are documented in code but no template |
| **Missing pre-commit hooks** | Ruff is in CI but no `.pre-commit-config.yaml` for local dev |
| **No Makefile or dev scripts** | No unified dev workflow commands (lint, format, test, build bridge) |
| **Open bug: Issue #68** | `function_at` return-type bug in bridge -- straightforward fix |

---

## Draft PRs

### PR 1: Add unit tests for utility modules

- **PR Title:** `test: add unit tests for number_utils and string_utils`
- **Branch:** `test/utility-unit-tests`
- **Files to change:**
  - Create `tests/__init__.py`
  - Create `tests/test_number_utils.py`
  - Create `tests/test_string_utils.py`
  - Create `pyproject.toml` (minimal, just pytest config)
- **Changes:**
  - Test `parse_possible_address()`, `convert_number()`, all base conversions in `number_utils.py`
  - Test `escape_for_json()`, `try_parse_int()` in `string_utils.py`
  - These modules are pure Python with zero Binary Ninja dependencies -- fully testable
  - Add `[tool.pytest.ini_options]` section to a minimal `pyproject.toml`
- **Effort:** 1-2 hours
- **Merge likelihood:** **High** -- maintainer recently added Ruff CI (#54), showing appetite for quality tooling. Tests are a natural next step and address a clear gap. Zero risk of breaking anything.

### PR 2: Add CI status badge + CONTRIBUTING.md

- **PR Title:** `docs: add CI badge and contribution guidelines`
- **Branch:** `docs/contributing-and-badge`
- **Files to change:**
  - `README.md` (add badge after title)
  - Create `CONTRIBUTING.md`
  - Create `.github/ISSUE_TEMPLATE/bug_report.md`
  - Create `.github/ISSUE_TEMPLATE/feature_request.md`
- **Changes:**
  - Add `![Ruff](https://github.com/fosdickio/binary_ninja_mcp/actions/workflows/lint-format.yml/badge.svg)` badge to README line 1
  - CONTRIBUTING.md: setup instructions, Ruff requirements, PR process (keep brief, reference existing README)
  - Issue templates: standard bug report (OS, BN version, MCP client, steps to reproduce) and feature request
- **Effort:** 30-45 minutes
- **Merge likelihood:** **High** -- low risk, highly visible improvement. The maintainer already accepts community PRs and this makes their life easier by getting better-structured issues.

### PR 3: Add pre-commit config and TypeScript CI

- **PR Title:** `ci: add pre-commit hooks and TypeScript type-checking`
- **Branch:** `ci/pre-commit-and-ts-check`
- **Files to change:**
  - Create `.pre-commit-config.yaml` (ruff + ruff-format hooks)
  - `.github/workflows/lint-format.yml` (add TS type-check job, add pip cache)
- **Changes:**
  - Add `.pre-commit-config.yaml` with `ruff` and `ruff-format` mirrors
  - Add a `typescript` job to the existing workflow: checkout, setup node, `npm ci` in `bridge/`, `npx tsc --noEmit`
  - Add `pip cache` step to the existing ruff job
  - Remove redundant `continue-on-error: false` lines
- **Effort:** 45 minutes
- **Merge likelihood:** **Medium-High** -- extends their existing CI investment. The TypeScript bridge currently has no CI validation at all, which is a gap. Pre-commit is optional (developers can ignore it) so low friction.

---

## Notes

- **Maintainer is active but slow to merge** -- PR #58 took 3 months to merge, PR #60 took 2 months. Several external PRs (#62, #63, #65, #66) have been open for 1-2 months with no review. Don't expect fast turnaround.
- **Active co-maintainer CX330Blake** is very active and may review/champion PRs.
- **5 open PRs** already -- not a backlog crisis but shows the maintainer batches reviews.
- **20 open issues** with several being feature requests -- good signal for what the maintainer wants.
- **Best approach:** Keep PRs small, focused, and non-controversial. Tests and docs are safest. Reference existing issues where possible. The maintainer clearly values code quality (added Ruff linting infra) so quality-focused PRs align well.
- **Avoid:** Large refactors, feature PRs that compete with existing open PRs (#61, #62, #63), or anything touching core plugin logic without prior discussion.
