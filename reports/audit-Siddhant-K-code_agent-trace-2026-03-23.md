I now have enough data for a comprehensive report.

# Marketing Audit: Siddhant-K-code/agent-trace

## Quick Overview

**agent-strace** is an "strace for AI agents" -- it captures and replays every tool call, prompt, and response from Claude Code, Cursor, or any MCP client. Supports Claude Code hooks (full session capture), MCP stdio/HTTP proxy mode, and a Python decorator API. Features include session replay, phase detection, cost estimation, secret redaction, and OTLP export to Datadog/Honeycomb/New Relic/Splunk/Jaeger.

- **Tech stack**: Pure Python 3.10+ (zero runtime dependencies), Hatchling build, unittest, PyPI distribution
- **Activity level**: 21 commits since Jan 2025, last commit 2026-03-22 (yesterday). Very active solo maintainer. Only 3 PRs (all self-authored and merged). 16 stars, 2 forks, 5 open issues (all feature requests by the author).
- **Merge likelihood**: High for quality contributions -- the maintainer clearly cares about code quality (ADRs, zero-dep philosophy, comprehensive tests). No external contributor PRs yet, so a good first contribution would get attention.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **No README badges** | `README.md` line 1 | Missing: PyPI version, Python versions, license, CI status, downloads. Every mature PyPI package has these. |
| **Typo in CLI output** | `cli.py:75` | Says `agent-trace replay` but should be `agent-strace replay` (missing the `s`) |
| **No CONTRIBUTING.md** | Root | Missing contributor guide. Standard for OSS projects. |
| **No CHANGELOG.md** | Root | 9 releases with no changelog file. Only git tags exist. |
| **Missing `py.typed` marker** | `src/agent_trace/` | No PEP 561 marker for type-checking consumers |
| **Outdated model pricing** | `cost.py:24-30` | Claude model names are outdated (`sonnet`/`opus`/`haiku` without version numbers like `sonnet-4`). Also no Gemini/DeepSeek pricing. |
| **README says `pytest` but CI uses `unittest`** | `README.md:537-538` | "Running tests" section says `pytest` but CI runs `python -m unittest discover`. Could confuse contributors. |

### 2. Code Quality

| Issue | Location | Details |
|-------|----------|---------|
| **No `py.typed` marker** | `src/agent_trace/` | PEP 561 compliance: add empty `py.typed` file |
| **`__init__.py` missing public API exports** | `src/agent_trace/__init__.py` | Only exports `__version__`. Should re-export `TraceEvent`, `SessionMeta`, `EventType`, `start_session`, `end_session`, `trace_tool`, `trace_llm_call`, `log_decision` for clean `from agent_trace import ...` usage |
| **Mutable default in PRICING dict** | `cost.py:121` | `estimate_cost()` mutates the module-level `PRICING` dict when custom prices are passed. This is a bug in multi-call scenarios. |
| **No `__all__` in any module** | All source files | No explicit public API surface |

### 3. Tests

| Issue | Location | Details |
|-------|----------|---------|
| **No `test_cli.py`** | `tests/` | CLI module (`cli.py`, 500 lines) has zero test coverage. The largest module untested. |
| **No `test_proxy.py`** | `tests/` | MCP stdio proxy (`proxy.py`, ~350 lines) has no tests |
| **No test coverage reporting** | CI workflow | No coverage tool configured, no coverage badge |

### 4. CI/CD

| Issue | Location | Details |
|-------|----------|---------|
| **No Python 3.14 in CI matrix** | `.github/workflows/test.yml` | Tests 3.10-3.13 but 3.14 is available |
| **No linting/formatting CI** | `.github/workflows/` | No ruff, flake8, mypy, or black checks |
| **No badges in README** | `README.md` | No CI status, PyPI version, license, or download badges |
| **No dependabot/renovate** | `.github/` | No automated dependency updates (though zero-dep makes this less critical) |
| **No release automation** | `.github/workflows/publish.yml` | Manual release creation triggers publish. Could auto-tag on version bump. |

### 5. DX Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **No `.gitignore` for trace directory** | Root `.gitignore` | `.agent-traces/` is not in `.gitignore`. Users will accidentally commit traces. |
| **No `--json` output flag for `list`/`stats`** | `cli.py` | Machine-readable output would help scripting |
| **record-http URL is `--url` not positional** | `cli.py:396` | `record-http --url <url>` is awkward; should be positional like `record-http <url>` |

---

## Draft PRs

### PR #1: Add README badges and fix CLI typo

- **PR Title**: `docs: add PyPI/CI/license badges and fix CLI output typo`
- **Branch**: `docs/readme-badges`
- **Files to change**: `README.md`, `src/agent_trace/cli.py`
- **Changes**:
  - Add badge row at top of README (after `# agent-trace`):
    ```markdown
    [![PyPI](https://img.shields.io/pypi/v/agent-strace)](https://pypi.org/project/agent-strace/)
    [![Python](https://img.shields.io/pypi/pyversions/agent-strace)](https://pypi.org/project/agent-strace/)
    [![License](https://img.shields.io/github/license/Siddhant-K-code/agent-trace)](LICENSE)
    [![Tests](https://github.com/Siddhant-K-code/agent-trace/actions/workflows/test.yml/badge.svg)](https://github.com/Siddhant-K-code/agent-trace/actions/workflows/test.yml)
    ```
  - Fix `cli.py:75`: change `agent-trace replay` to `agent-strace replay`
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- pure docs improvement, zero risk, high visibility

### PR #2: Add CLI tests for untested `cli.py` module

- **PR Title**: `test: add unit tests for CLI argument parsing and command dispatch`
- **Branch**: `test/cli-tests`
- **Files to change**: `tests/test_cli.py` (new)
- **Changes**:
  - Test `build_parser()` returns correct subcommands
  - Test argument parsing for each subcommand (record, replay, list, stats, export, etc.)
  - Test `cmd_list`, `cmd_stats`, `cmd_replay` with a temp `TraceStore`
  - Test error cases (missing session, invalid filter)
  - Test `cmd_setup` output is valid JSON with correct hook structure
- **Effort**: 1-2 hours
- **Merge likelihood**: **High** -- the maintainer clearly values tests (12 test files already). CLI is the largest untested module.

### PR #3: Add `.agent-traces/` to `.gitignore` and add `py.typed` marker

- **PR Title**: `chore: add .agent-traces to .gitignore and py.typed marker`
- **Branch**: `chore/gitignore-pytyped`
- **Files to change**: `.gitignore`, `src/agent_trace/py.typed` (new, empty file)
- **Changes**:
  - Append `.agent-traces/` to `.gitignore` so users don't commit trace data
  - Create empty `src/agent_trace/py.typed` for PEP 561 compliance
  - Add `py.typed` to `pyproject.toml` package data if needed
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- prevents real user footgun (committing trace data), standard Python packaging practice

---

## Notes

- **Active maintainer**: Last commit yesterday, regular release cadence (v0.1.0 through v0.5.0). Responds to own PRs quickly.
- **Solo project**: All 3 PRs are self-authored. No external contributions yet -- being the first external contributor gets visibility.
- **Open issues are a roadmap**: Issues #4-#8 are all feature requests by the author. Could pick one to implement (e.g., #5 "Shareable HTML replays" or #6 "Subagent tracing").
- **Zero-dep philosophy is sacred**: ADR-0003 explicitly decided on zero runtime dependencies. Any PR adding a dependency will be rejected.
- **Best approach**: Start with PR #1 (badges + typo fix) as an easy intro. Follow with PR #3, then PR #2. These build trust for larger feature PRs.
- **Bug found**: `cost.py:121` mutates module-level `PRICING` dict -- this is a legitimate bug worth fixing (use a local copy instead). Good candidate for a `fix:` PR.
