Now I have everything. Here's the report:

---

# Marketing Audit: lightspeed-core/lightspeed-stack

## Quick Overview

Lightspeed Core Stack (LCS) is a Red Hat-backed, AI-powered assistant built on FastAPI that answers product questions using LLM services, agents, and RAG databases. It integrates with Llama Stack and supports multiple LLM providers (OpenAI, Azure, WatsonX, vLLM, RHEL AI). Includes A2A protocol support, MCP server integration, conversation caching, quota management, and comprehensive authentication/authorization.

- **Tech stack:** Python 3.12+, FastAPI, Pydantic, SQLAlchemy, Llama Stack, uv package manager
- **Activity:** ~592 commits in 2025-2026, 10+ open PRs, 10 open issues. Very active -- multiple PRs merged daily
- **Maintainers:** Pavel Tisnovsky (~400 commits) is the primary maintainer, extremely responsive (PRs merged same day)
- **Stats:** 28 stars, 77 forks, Apache 2.0 license
- **CI:** 21 GitHub Actions workflows (linters, type checkers, security, tests, builds)

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details | Effort |
|------|---------|--------|
| **Issue #1346: Fix misleading docstring** | `_unregister_toolgroup_async` in `tests/e2e/utils/llama_stack_utils.py` says it returns restoration data, but returns `None`. Filed by maintainer. One-line fix. | 5 min |
| **Issue #1021: ConversationDetails example invalid** | OpenAPI docs show incorrect example for ConversationDetails | 15 min |
| **Issue #1020: Incorrect example class name** | OpenAPI docs reference wrong class name | 15 min |
| **Missing CHANGELOG.md** | No changelog exists despite 3 tagged releases (0.4.0, 0.4.1, 0.4.2) | 30 min |
| **Hardcoded version in badge** | README line 9 has tag badge linking to hardcoded `0.4.2` release | 5 min |
| **Issue #1334: config.json missing defaults** | RagConfiguration inline/tool fields missing default values in docs | 15 min |
| **Issue #1333: score_multiplier constraint** | docs/config.json has weaker minimum constraint than code | 15 min |

### 2. Code Quality

| Item | File | Details |
|------|------|---------|
| **Missing `-> None` on `__init__` methods** | `src/models/responses.py` | 8 `__init__` methods (lines 1701, 1795, 1877, 2030, 2105, 2147, 2240, 2545) missing `-> None` return annotation |
| **Missing `-> None` on `__init__` methods** | `src/authorization/resolvers.py` | Lines 77, 273 missing `-> None` |
| **TODOs that should be issues** | `src/authentication/jwk_token.py:49` | `TODO: handle connection errors, timeouts` |
| **TODOs that should be issues** | `src/metrics/__init__.py:45,51` | `TODO: Add metric for token usage` (x2) |
| **Hardcoded magic numbers** | `src/app/endpoints/a2a.py:819` | `300.0` timeout should be a named constant |
| **Hardcoded magic numbers** | `src/authentication/jwk_token.py:32` | `maxsize=3, ttl=3600` should be constants |

### 3. Tests

| Item | Details | Effort |
|------|---------|--------|
| **Missing tests: utils module** | No tests for `mcp_oauth_probe.py`, `quota.py`, `schema_dumper.py`, `stream_interrupts.py`, `tool_formatter.py`, `token_counter.py` | varies |
| **Missing tests: a2a_storage** | No tests for `context_store.py` (ABC), `postgres_context_store.py`, `storage_factory.py` | 1-2h each |
| **Missing tests: runners** | No tests for `quota_scheduler.py` | 1h |
| **Incomplete TODO in test** | `tests/unit/cache/test_postgres_cache.py:339` - `TODO: LCORE-721` - test stub exists but not implemented | 30 min |
| **E2E step not implemented** | `tests/e2e/features/steps/health.py:73` - `TODO: add step implementation` | 15 min |

### 4. CI/CD

| Item | Details |
|------|---------|
| Already excellent | 21 workflows covering all linters, tests, security, builds. Not much to add. |
| **Potential: Add CodeQL** | GitHub's code scanning could complement Bandit | 

### 5. DX Improvements

| Item | Details |
|------|---------|
| **Missing .env.example** | No environment variable template despite requiring API keys (OPENAI_API_KEY, etc.) |
| **Missing examples/README.md** | 27 YAML example files with no index explaining which is for what |

## Draft PRs

### PR 1: Fix misleading docstring (Issue #1346)

- **PR Title:** `docs: fix misleading docstring in _unregister_toolgroup_async`
- **Branch:** `docs/fix-unregister-docstring`
- **Files to change:** `tests/e2e/utils/llama_stack_utils.py`
- **Changes:** Replace docstring `"Unregister a toolgroup by identifier; return (provider_id, provider_shield_id) for restore."` with `"Unregister a toolgroup by identifier."`
- **Effort:** 5 minutes
- **Merge likelihood:** **HIGH** -- Filed by primary maintainer @tisnik, exact fix specified in issue body, one-line change

### PR 2: Add `-> None` return type annotations to response `__init__` methods

- **PR Title:** `fix: add missing return type annotations to response __init__ methods`
- **Branch:** `fix/response-init-type-annotations`
- **Files to change:** `src/models/responses.py`, `src/authorization/resolvers.py`
- **Changes:** Add `-> None` to 10 `__init__` method signatures. The project enforces mypy strict mode (`disallow_untyped_defs`), so these are valid improvements.
- **Effort:** 15 minutes
- **Merge likelihood:** **HIGH** -- Project has strict type checking (mypy, pyright), these are unambiguous fixes that align with project standards

### PR 3: Add unit tests for `utils/token_counter.py`

- **PR Title:** `test: add unit tests for token_counter utility`
- **Branch:** `test/token-counter-unit-tests`
- **Files to change:** Create `tests/unit/utils/test_token_counter.py`
- **Changes:** Add pytest unit tests covering the token counting utility. Follow existing test patterns in `tests/unit/utils/` (conftest.py fixtures, AsyncMock, etc.). Project requires 60% coverage threshold -- this helps close the gap.
- **Effort:** 1 hour
- **Merge likelihood:** **MEDIUM-HIGH** -- Project values test coverage (60% unit threshold), but external test PRs may need more review. Check if a Jira ticket is needed (CONTRIBUTING.md mentions Jira ticket in PR title).

## Notes

- **Very active project** -- maintainer @tisnik merges PRs same day, sometimes within hours
- **Red Hat internal processes** -- CONTRIBUTING.md mentions Jira tickets (LCORE-xxx, RSPEED-xxx) in PR titles. External contributors may not have Jira access. Issue #1346 is the safest target since it was explicitly filed as a GitHub issue.
- **PR template exists** -- `.github/PULL_REQUEST_TEMPLATE.md` must be filled out
- **AI disclosure required** -- CONTRIBUTING.md requires marking AI-generated code with "Assisted-by:" or "Generated-by:"
- **No PR backlog** -- only 10 open PRs, all recent. Maintainers are responsive.
- **Best approach:** Start with Issue #1346 (docstring fix) as it's explicitly filed by the maintainer, trivially small, and clearly desired. This establishes contributor credibility for larger PRs.
- **Issue #1315** (Add SUPPORT.md) is already an open PR -- avoid duplicating that.
