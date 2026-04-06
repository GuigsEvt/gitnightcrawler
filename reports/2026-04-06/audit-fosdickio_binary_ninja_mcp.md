Now I have all the data. Let me compile the report.

# Marketing Audit: fosdickio/binary_ninja_mcp

## Quick Overview

Binary Ninja MCP is a plugin that exposes Binary Ninja's reverse engineering capabilities (decompilation, disassembly, renaming, cross-references, patching, etc.) through HTTP endpoints and the Model Context Protocol (MCP), enabling seamless integration with LLM clients like Claude Desktop, Cline, Cursor, and more. It's a dual-component system: a Python Binary Ninja plugin (server) and a TypeScript MCP bridge.

- **Tech stack**: Python 3.12+ (plugin), TypeScript/Node 18+ (bridge), MCP SDK, HTTP server
- **License**: GPL-3.0
- **Stars**: 299 | **Forks**: 63 | **Open issues**: 23
- **Activity**: ~3 commits/month in 2026, last merge Apr 6 2026. PRs get merged within days-weeks. Active maintainers: `fosdickio` (owner), `CX330Blake` (co-maintainer, frequent contributor).
- **Open PRs**: 4 open (some stale since Jan/Feb 2026), 4 open issues with no assignees

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **No CONTRIBUTING.md** | No contribution guidelines exist. The README says "Contributions are welcome" with zero detail on dev setup, code style, or PR process. |
| **No CHANGELOG.md** | Version is 1.1.0 in plugin.json but no changelog tracks releases. |
| **No CODE_OF_CONDUCT.md** | Missing community standards document. |
| **`plugin.json` longdescription empty** | `"longdescription": ""` -- should have a proper description for the BN Plugin Manager. |
| **README: "two separate components"** | Line 23 says "two separate components" but there are arguably three (plugin, bridge, scripts). Minor wording fix. |
| **README: missing troubleshooting section** | No FAQ or common issues section. Issues #45, #56, #68 suggest users hit recurring problems. |

### 2. Code Quality

| Item | Details |
|------|---------|
| **13 functions missing return type hints** in `binary_operations.py | Lines ~387, 694, 919, 1003, 1226, 1433, 1450, 1649, 2195, 2344, 3576. **Note**: PR #65 is open addressing pydantic-related type hints in the bridge -- different scope, no conflict. |
| **TODO comment** | `binary_operations.py:2093`: `var_map = {} # TODO: Implement this functionality` |
| **No `pyproject.toml`** | Project has `ruff.toml` and `plugin.json` but no standard Python project metadata file. |
| **No `py.typed` marker** | PEP 561 compliance missing. |
| **Large files** | `binary_operations.py` (3766 LOC), `http_server.py` (2386 LOC) -- not a quick PR but worth noting. |

### 3. Tests

| Item | Details |
|------|---------|
| **Zero test files** | No `tests/`, no `test_*.py`, no `*.test.ts`. Nothing. |
| **No test infrastructure** | No pytest config, no jest config, no test CI workflow. |
| **Utility functions are easily testable** | `utils/string_utils.py`, `utils/number_utils.py` are pure functions -- perfect test targets with zero Binary Ninja dependency. |

### 4. CI/CD

| Item | Details |
|------|---------|
| **Single workflow** | Only `.github/workflows/lint-format.yml` (Ruff check + format). |
| **No test CI** | No workflow to run tests (once they exist). |
| **No type checking CI** | No mypy/pyright workflow. |
| **No issue templates** | No `.github/ISSUE_TEMPLATE/` directory. |
| **No PR template** | No `.github/pull_request_template.md`. |
| **No badges** | README has zero badges (no CI status, no Python version, no license badge). |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **Bridge hardcoded URL** | `bridge/binja_mcp_bridge.py:16` has `binja_server_url = "http://localhost:9009"` hardcoded. |
| **No `.editorconfig`** | Missing editor configuration for consistent formatting across IDEs. |
| **No pre-commit hooks** | No `.pre-commit-config.yaml` for local developer linting. |
| **Issue #68 (function_at return type bug)** | Open since Mar 17 -- looks like a straightforward bug fix. |

---

## Draft PRs

### PR 1: Add unit tests for utility functions

- **PR Title**: `test: add unit tests for string_utils and number_utils`
- **Branch**: `test/add-utility-tests`
- **Files to change**:
  - Create `tests/__init__.py`
  - Create `tests/test_string_utils.py`
  - Create `tests/test_number_utils.py`
  - Create `pyproject.toml` (add `[tool.pytest]` section)
- **Changes**: Write pytest tests covering all functions in `plugin/utils/string_utils.py` and `plugin/utils/number_utils.py`. These are pure utility functions with no Binary Ninja dependency -- easy to test in isolation. Include edge cases (empty strings, hex overflow, negative numbers, etc.). Add a `[tool.pytest.ini_options]` section to a new `pyproject.toml`.
- **Effort**: 1-2 hours
- **Merge likelihood**: **HIGH** -- Zero tests exist, maintainer recently added Ruff linting (#54/#55) showing they care about code quality. Tests are universally welcomed. No controversy.

### PR 2: Add GitHub issue/PR templates and CI badges

- **PR Title**: `chore: add issue templates, PR template, and README badges`
- **Branch**: `chore/github-templates`
- **Files to change**:
  - Create `.github/ISSUE_TEMPLATE/bug_report.yml`
  - Create `.github/ISSUE_TEMPLATE/feature_request.yml`
  - Create `.github/pull_request_template.md`
  - Edit `README.md` (add badges after title: CI status, Python version, license, npm)
- **Changes**: Add structured issue templates (bug report with repro steps, feature request with use case). Add PR template with checklist (description, testing, screenshots). Add 3-4 badges to README top: `![CI](https://github.com/fosdickio/binary_ninja_mcp/actions/workflows/lint-format.yml/badge.svg)`, Python 3.12+, GPL-3.0, npm package.
- **Effort**: 30 minutes
- **Merge likelihood**: **HIGH** -- Pure DX improvement, no code changes, standard open-source practice. The project has 23 open issues with inconsistent formatting -- templates would help.

### PR 3: Add CONTRIBUTING.md with development setup

- **PR Title**: `docs: add CONTRIBUTING.md with development setup guide`
- **Branch**: `docs/contributing-guide`
- **Files to change**:
  - Create `CONTRIBUTING.md`
  - Edit `README.md` (add link to CONTRIBUTING.md in Contributing section)
- **Changes**: Create a CONTRIBUTING.md covering: prerequisites (Binary Ninja license, Python 3.12+, Node 18+), development setup (clone, install deps, run plugin), code style (Ruff config, how to run linter), PR guidelines (conventional commits, link to issue), and testing instructions. Reference existing `ruff.toml` config. Update the bare-bones "Contributions are welcome" README section to link to the new file.
- **Effort**: 30-45 minutes
- **Merge likelihood**: **HIGH** -- The README explicitly says "Contributions are welcome" but gives zero guidance. Multiple external contributors (CX330Blake, renato-osec, YunshiuanOAO, etc.) would benefit. No code risk.

---

## Notes

- **Maintainer responsiveness**: Good. `fosdickio` merges PRs within days-weeks. `CX330Blake` is an active co-contributor. The project merged 3 PRs in Q1 2026.
- **4 stale open PRs**: #61 (Jan), #62 (Jan), #63 (Feb), #65 (Feb) have no reviews. PRs from external contributors may take longer. Best to keep PRs small and non-controversial.
- **PR #65 overlap warning**: There's an open PR adding return type annotations for pydantic compatibility. Avoid overlapping with this -- focus type hint work on `binary_operations.py` internal functions (different scope).
- **Red flag**: None major. Maintainer is active, project is growing (299 stars), GPL-3.0 license is clear.
- **Best approach**: Start with documentation/templates PRs (PR 2 and 3) as they have zero code risk and establish contributor presence. Follow up with tests (PR 1) for higher impact. Reference specific issues where relevant.
