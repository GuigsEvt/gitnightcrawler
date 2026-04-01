Now I have everything needed. Here's the report:

---

# Marketing Audit: waybarrios/vllm-mlx

## Quick Overview

vLLM-MLX is a GPU-accelerated inference server for Apple Silicon that brings vLLM-like capabilities (OpenAI/Anthropic-compatible API, continuous batching, paged KV cache) to Mac via the MLX framework. It supports text, image, video, and audio models with 400+ tok/s on M4 Max. 718 stars, 178 forks.

**Tech stack:** Python 3.10+, MLX, FastAPI, Gradio, mlx-lm/mlx-vlm/mlx-audio/mlx-embeddings, pytest, ruff/black/mypy

**Activity level:** Extremely active -- 48 commits in 4 weeks, PRs merged same-day. Issue #238 is titled **"Looking for collaborators"** -- maintainer is explicitly asking for help. Merge likelihood is HIGH.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **Wrong project URLs in pyproject.toml** | `project.urls` point to `github.com/vllm-mlx/vllm-mlx` (doesn't exist) instead of `github.com/waybarrios/vllm-mlx`. Lines 102-104. |
| **Missing Codecov badge in README** | CI uploads coverage to Codecov but no badge in README. Easy add. |
| **No SECURITY.md** | No vulnerability reporting instructions. Standard community file. |
| **No CODE_OF_CONDUCT.md** | Missing for a project with 718 stars and open collaborator call. |
| **No CHANGELOG.md** | 0.2.7 released but no changelog tracking versions/features. |
| **`docs/reference/index.md`** | References exist in docs but the index file has no structured navigation to models.md, cli.md, configuration.md. |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **CI lint inconsistency (Issue #239)** | CI uses `black` for formatting but `.pre-commit-config.yaml` uses `ruff format`. These can conflict. Already filed as issue -- easy PR to unify on ruff-format. |
| **mypy non-blocking in CI** | `continue-on-error: true` means type errors are invisible. Fix or remove the job. |
| **Ruff rule mismatch** | CI runs `--select E,F,W` but pyproject.toml configures `E,F,W,I,N,UP,B,SIM`. CI is more lenient than local. |

### 3. Tests

| Issue | Details |
|-------|---------|
| **Python 3.13 not in test matrix (Issue #225)** | pyproject.toml declares 3.13 support, CI only tests 3.10/3.11/3.12. One-line fix. |
| **No test for `model_registry.py`** | `test_model_registry.py` exists but verify coverage of registration edge cases. |
| **Missing pytest-cov in Apple Silicon job** | Coverage only collected on Ubuntu matrix, not macOS ARM64. |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **Add PyPI publish workflow** | No automated release pipeline. Project is installable but not on PyPI. |
| **Add dependabot.yml** | No dependency update automation. |
| **Add `codecov/codecov-action` token** | Current upload uses `fail_ci_if_error: false` with no token -- likely silent failures. |
| **Pin action versions with SHA** | `actions/checkout@v4` etc. should use SHA pins for supply chain security. |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **Add Dockerfile** | No containerization despite being a server. Basic Dockerfile for non-Mac testing/dev. |
| **Add `.env.example`** | Server supports `--api-key` but no example env file for config. |
| **Add `py.typed` marker** | Package has type hints but no PEP 561 `py.typed` marker for downstream type checking. |

---

## Draft PRs

### PR #1: Fix incorrect project URLs in pyproject.toml

- **PR Title:** `fix: correct project URLs in pyproject.toml`
- **Branch:** `fix/project-urls`
- **Files to change:** `pyproject.toml`
- **Changes:**
  ```diff
  -Homepage = "https://github.com/vllm-mlx/vllm-mlx"
  -Documentation = "https://github.com/vllm-mlx/vllm-mlx#readme"
  -Repository = "https://github.com/vllm-mlx/vllm-mlx"
  +Homepage = "https://github.com/waybarrios/vllm-mlx"
  +Documentation = "https://github.com/waybarrios/vllm-mlx#readme"
  +Repository = "https://github.com/waybarrios/vllm-mlx"
  +Issues = "https://github.com/waybarrios/vllm-mlx/issues"
  ```
- **Effort:** 5 minutes
- **Merge likelihood:** **HIGH** -- obvious bug fix, zero risk

---

### PR #2: Add Python 3.13 to CI test matrix

- **PR Title:** `ci: add Python 3.13 to test matrix`
- **Branch:** `fix/ci-python313`
- **Files to change:** `.github/workflows/ci.yml`
- **Changes:** Add `"3.13"` to `matrix.python-version` array in `test-matrix` job (line 53). Addresses Issue #225.
  ```diff
       matrix:
  -      python-version: ["3.10", "3.11", "3.12"]
  +      python-version: ["3.10", "3.11", "3.12", "3.13"]
  ```
- **Effort:** 5 minutes
- **Merge likelihood:** **HIGH** -- fixes a filed issue, one-line change, project already declares 3.13 support

---

### PR #3: Unify formatting on ruff-format, remove black dependency

- **PR Title:** `ci: unify on ruff-format, drop black`
- **Branch:** `fix/lint-ruff-format`
- **Files to change:** `.github/workflows/ci.yml`, `pyproject.toml`
- **Changes:**
  - In CI lint job: replace `pip install ruff black` with `pip install ruff`, replace `black --check` with `ruff format --check`
  - In pyproject.toml: remove `"black>=23.0.0"` from `[project.optional-dependencies.dev]`, remove `[tool.black]` section
  - Align CI ruff select rules with pyproject.toml (`E,F,W,I,N,UP,B,SIM` not just `E,F,W`)
- **Effort:** 15 minutes
- **Merge likelihood:** **HIGH** -- addresses Issue #239, pre-commit already uses ruff-format, reduces dependencies

---

## Notes

- **Maintainer is actively seeking collaborators** (Issue #238 "Looking for collaborators" + Issue #186 "Contributing guidelines and PR review process"). This is the ideal time to contribute.
- PRs are merged same-day or next-day. Very responsive.
- 42 open PRs -- some may be stale, but active ones get fast attention.
- The project is growing fast (718 stars) and has real users (Claude Code integration is a major draw).
- Best approach: start with PR #1 (URL fix) as an ice-breaker, then follow with #2 and #3 which close filed issues.
