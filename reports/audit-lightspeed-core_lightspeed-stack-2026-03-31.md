Now I have all the data. Let me compile the report.

# Marketing Audit: lightspeed-core/lightspeed-stack

## Quick Overview

Lightspeed Core Stack (LCS) is a Red Hat-backed, AI-powered assistant built on FastAPI that provides answers using LLM services (via Llama Stack), agents, RAG databases, and MCP tool integration. It supports multiple auth providers (K8s, JWK, Azure Entra ID, API key), conversation caching (SQLite/Postgres), token quota management, and the A2A protocol. Designed for enterprise deployment on OpenShift/Kubernetes.

**Tech stack:** Python 3.12/3.13, FastAPI, Llama Stack, Pydantic, SQLAlchemy, uv package manager, Prometheus metrics, behave (BDD), pytest

**Activity level:** Extremely active -- 774 commits since Jan 2025, ~434 in March 2026 alone. PRs merge daily. Primary maintainer `tisnik` (Pavel Tisnovsky) is very responsive. 10 open PRs, 10 open issues. JIRA-driven workflow (`LCORE-XXXX` prefix required on PR titles).

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **Missing `.env.example`** | No `.env.example` or environment variable reference exists. The README mentions env vars (`LIGHTSPEED_STACK_CONFIG`, etc.) but there's no central template. |
| **Missing CODE_OF_CONDUCT.md** | Standard OSS file absent. Apache 2.0 project should have one. |
| **22 `__init__.py` files lacking docstrings** | ~18% of modules missing module-level docstrings (pydocstyle would flag these). Most are `__init__.py` files. |
| **README length** | 55KB README is massive. Could benefit from a table of contents refresh or splitting into sub-docs (some sections already link to `docs/`). |

### 2. Code Quality

| Item | Details |
|------|---------|
| **3 TODO comments** | `src/metrics/__init__.py:45,51` -- token usage metric TODO (LCORE-411). `src/authentication/jwk_token.py:49` -- missing error handling for connection timeouts. |
| **`version.py` is trivial** | Single constant file that could be auto-generated or pulled from `pyproject.toml`. Low-hanging cleanup. |

### 3. Tests

| Item | Details |
|------|---------|
| **16 untested source modules** | Key gaps: `quota/quota_limiter.py` (abstract base), `quota/revokable_quota_limiter.py`, `quota/token_usage_history.py`, `utils/mcp_oauth_probe.py`, `utils/quota.py`, `utils/schema_dumper.py`, `utils/stream_interrupts.py`, `runners/quota_scheduler.py`, `version.py` |
| **Quota package** | 5 of 11 quota modules have no tests. This is the biggest coverage gap. |
| **Utils package** | 6 of 23 utility modules untested (26% gap). |

### 4. CI/CD

| Item | Details |
|------|---------|
| **Already excellent** | 24 GitHub Actions workflows covering unit tests, integration, e2e, all linters, security (bandit), dependency checks, PR title validation, builds. Dependabot + Renovate configured. |
| **Missing: badge in README** | No CI status badges in README.md header. Easy add. |
| **Missing: CodeQL** | No GitHub CodeQL security scanning workflow (they use bandit, but CodeQL adds SAST). |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **No `.env.example`** | Developers must read scattered docs to find required env vars. |
| **docker-compose docs** | Both compose files exist but aren't well-documented in README quick-start. The getting started guide in `docs/getting_started.md` covers it, but a 3-line quick-start in README would help. |

---

## Draft PRs

### PR 1: Add unit tests for `version.py`

- **PR Title:** `LCORE-XXXX: Add unit test for version module`
- **Branch:** `test/version-module`
- **Files to change:** Create `tests/unit/test_version.py`
- **Changes:** Simple test asserting `__version__` is a valid semver string. ~10 lines. Pattern: import version, assert it matches `r"^\d+\.\d+\.\d+"`.
- **Effort:** 10 minutes
- **Merge likelihood:** **HIGH** -- Project requires 60% unit coverage, trivial test, follows existing patterns in `tests/unit/conftest.py`. No controversy.

### PR 2: Add unit tests for `utils/schema_dumper.py`

- **PR Title:** `LCORE-XXXX: Add unit tests for schema_dumper utility`
- **Branch:** `test/schema-dumper-tests`
- **Files to change:** Create `tests/unit/utils/test_schema_dumper.py`
- **Changes:** Test the schema dumping functions with sample Pydantic models. Follow existing test patterns from `tests/unit/utils/`. Cover happy path + edge cases (empty model, nested model).
- **Effort:** 30 minutes
- **Merge likelihood:** **HIGH** -- Fills a clear coverage gap in utilities, follows existing patterns, no API changes.

### PR 3: Add CI status badges to README

- **PR Title:** `LCORE-XXXX: Add CI status badges to README`
- **Branch:** `docs/readme-badges`
- **Files to change:** `README.md` (add badges at top)
- **Changes:** Add workflow status badges for key workflows (unit tests, linting, security). Format: `![Unit Tests](https://github.com/lightspeed-core/lightspeed-stack/actions/workflows/unit_tests.yaml/badge.svg)` for unit_tests, black, pylint, bandit workflows. Insert after the title line.
- **Effort:** 10 minutes
- **Merge likelihood:** **HIGH** -- Pure docs change, high visibility, standard OSS practice. Maintainer `tisnik` is actively merging docs PRs (multiple per day).

---

## Notes

- **No red flags.** This is an actively maintained Red Hat project with a very responsive primary maintainer.
- **PR title format is mandatory:** Must match `LCORE-XXXX:` pattern (enforced by `pr-title-checker.yaml`). You need a JIRA ticket number. Check open issues or file one first.
- **AI disclosure required:** CONTRIBUTING.md says to mark AI-generated code with `Assisted-by:` or `Generated-by:` trailer.
- **CodeRabbit AI reviews all PRs** -- expect automated review feedback.
- **Best approach:** Start with the README badges PR (pure docs, zero risk) or `version.py` test (trivial). Comment on an open issue first to signal intent. Submit during weekdays when `tisnik` is most active (merges happen daily, often same-day).
- **Coverage thresholds:** Unit tests require 60% coverage, integration 10%. Test PRs directly help maintain these thresholds.
- **Avoid:** Large refactors or architectural changes -- this is an enterprise project with strict JIRA tracking and design review processes (`docs/design/`).
