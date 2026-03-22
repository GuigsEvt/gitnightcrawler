

# Marketing Audit: waybarrios/vllm-mlx

## Quick Overview

vllm-mlx brings native Apple Silicon GPU acceleration to vLLM by integrating MLX, mlx-lm, mlx-vlm, mlx-audio, and mlx-embeddings. It provides an OpenAI and Anthropic-compatible API server for running LLMs, vision-language models, audio, and embeddings locally on Mac with continuous batching, paged KV cache, MCP tool calling, and multimodal support. Claims 400+ tok/s on Apple Silicon.

**Tech Stack:** Python 3.10-3.13, MLX, FastAPI, uvicorn, Pydantic, transformers, pytest, ruff/black/mypy

**Activity Level:**
- 637 stars, 110 forks
- ~67 commits since Jan 2025 (very active, ~2-3/week)
- 28 open PRs, 7 merged, 15 closed out of last 50
- Active external contributors (Thump604, janhilgard, patanet7, otarkhan)
- Maintainer merges PRs but is selective (7/50 merged = 14% merge rate)
- Multiple PRs from same day (March 21-22) -- very active right now

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **Missing CI/coverage badge** | README has License, Python, Apple Silicon, GitHub badges but NO CI status badge and NO codecov badge despite codecov being configured in CI |
| **Missing PyPI badge** | No PyPI version badge even though package is versioned (0.2.6) |
| **No CHANGELOG** | No CHANGELOG.md or RELEASES file exists |
| **Issue #186 is open** | "Contributing guidelines and PR review process" -- maintainer explicitly wants help here |

### 2. Code Quality

| Item | Details |
|------|---------|
| **mypy runs with `continue-on-error: true`** | Type checking is non-blocking in CI -- 19 `type: ignore` / `noqa` across 5 files. Fixing these and removing `continue-on-error` would be a solid PR |
| **Ruff config mismatch** | pyproject.toml selects `["E", "F", "W", "I", "N", "UP", "B", "SIM"]` but CI runs `--select E,F,W --ignore E402,E501,E731,F811,F841` -- CI is weaker than local config |
| **Dead placeholder in batched.py:670** | `"content": "XXXXXXXXXX"` -- looks like a debug placeholder left in production code |
| **No `py.typed` marker** | Package doesn't declare PEP 561 typed support |

### 3. Tests

| Item | Details |
|------|---------|
| **39 test files but uneven coverage** | No test for `cli.py` (1000+ lines), `benchmark.py` (1500+ lines), `gradio_app.py`, `embedding.py` server endpoints |
| **No test for Anthropic adapter end-to-end** | `test_anthropic_adapter.py` exists but limited scope |
| **Missing edge case tests** | Tool parsers have tests but no fuzz/malformed-input tests |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No GitHub issue/PR templates** | `.github/` only has `workflows/` -- no `ISSUE_TEMPLATE/`, no `PULL_REQUEST_TEMPLATE.md` |
| **No dependabot config** | No `.github/dependabot.yml` for automated dependency updates |
| **No release automation** | No release workflow, no publish-to-PyPI action |
| **codecov but no badge** | Codecov upload exists in CI but no badge in README |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **No Dockerfile** | No containerization at all -- many users would want a Docker-based setup (though macOS-only limits this) |
| **No `.env.example`** | Server supports API keys but no example env file |
| **Issue #184 open** | "Add OpenTelemetry support for observability" -- maintainer wants this |

---

## Draft PRs

### PR #1: Add CI badge, codecov badge, and GitHub Actions status to README

- **PR Title:** `docs: add CI status and codecov badges to README`
- **Branch:** `docs/add-ci-badges`
- **Files to change:** `README.md`
- **Changes:** Add after existing badges:
  ```markdown
  [![CI](https://github.com/waybarrios/vllm-mlx/actions/workflows/ci.yml/badge.svg)](https://github.com/waybarrios/vllm-mlx/actions/workflows/ci.yml)
  [![codecov](https://codecov.io/gh/waybarrios/vllm-mlx/badge.svg)](https://codecov.io/gh/waybarrios/vllm-mlx)
  ```
- **Effort:** 5 minutes
- **Merge likelihood:** **High** -- zero-risk change, purely additive, maintainer already has codecov configured

---

### PR #2: Add GitHub issue and PR templates

- **PR Title:** `chore: add issue and PR templates`
- **Branch:** `chore/github-templates`
- **Files to change:**
  - `.github/ISSUE_TEMPLATE/bug_report.md` (new)
  - `.github/ISSUE_TEMPLATE/feature_request.md` (new)
  - `.github/PULL_REQUEST_TEMPLATE.md` (new)
- **Changes:** Standard GitHub templates customized for the project (bug report asking for macOS version, Apple Silicon chip, MLX version; feature request; PR template with checklist for tests/lint/docs). Directly addresses open issue #186.
- **Effort:** 15 minutes
- **Merge likelihood:** **High** -- issue #186 explicitly asks for this, and the maintainer is dealing with 28 open PRs that need better structure

---

### PR #3: Remove debug placeholder and align CI ruff config with pyproject.toml

- **PR Title:** `fix: remove debug placeholder and align CI lint rules with pyproject.toml`
- **Branch:** `fix/lint-alignment`
- **Files to change:**
  - `vllm_mlx/engine/batched.py` -- replace `"XXXXXXXXXX"` with proper content or empty string
  - `.github/workflows/ci.yml` -- update ruff select to match pyproject.toml rules (`I,N,UP,B,SIM`)
- **Changes:** Fix the `"XXXXXXXXXX"` debug string in batched.py:670 and sync the CI ruff configuration to use the same rule set as the local `.pre-commit-config.yaml` / `pyproject.toml`
- **Effort:** 20 minutes
- **Merge likelihood:** **Medium-High** -- the debug placeholder is clearly a bug, lint alignment is a sensible improvement, but expanding lint rules may surface new warnings that need fixing

---

## Notes

- **PR merge rate is low (14%)** -- maintainer is selective. Keep PRs small, well-tested, and non-controversial.
- **28 open PRs** -- there's a backlog. Documentation and CI PRs are less likely to conflict and more likely to get attention.
- **Issue #186** is a direct invitation for contributing guidelines work -- referencing it in a PR will help.
- **Best approach:** Start with PR #1 (badges) as a zero-friction introduction, then follow up with templates (PR #2) which addresses an open issue. Avoid large feature PRs until you have a merged PR establishing trust.
- **Red flag:** The `transformers >= 5.0.0` dependency pin is very aggressive (current stable is 4.x). This could cause installation issues for users -- could be another easy fix PR but needs maintainer confirmation first.
