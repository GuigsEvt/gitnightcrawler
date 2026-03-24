# Marketing Audit: lightspeed-core/lightspeed-stack

## Quick Overview

Lightspeed Core Stack (LCS) is a Red Hat-backed, production-grade AI-powered assistant built on FastAPI that provides answers using LLM services (via Llama Stack), agents, and RAG databases. It supports multiple LLM providers (OpenAI, Azure, RHEL AI, WatsonX, VertexAI), multiple auth backends (K8s, JWK, RH Identity), and multiple storage backends (PostgreSQL, SQLite, in-memory).

**Tech stack:** Python 3.12+, FastAPI, Llama Stack 0.5.2, Pydantic, SQLAlchemy, uv package manager, pytest + behave (BDD), 7 linting tools (black, ruff, pylint, pyright, mypy, pydocstyle, bandit), 23 GitHub Actions workflows, OCI containers on RHEL UBI9.

**Activity level:** Extremely active -- 665 commits in 2026, ~325 in March alone, latest commit 2026-03-23. Primary maintainer Pavel Tisnovsky (tisnik) merges PRs within 1-2 days. 5+ active contributors. PRs require Jira ticket in title (LCORE-xxxx pattern).

---

## Quick Win PRs

### 1. Documentation Improvements

**README TODOs (broken placeholder text):**
- `README.md:997` has `"lightspeed-stack-providers==TODO"` in a code example
- `README.md:1031` has `TODO1 TODO2` as placeholder RPM package names
- These are literal TODOs visible to anyone reading the README -- easy cleanup

**Missing CHANGELOG:**
- No CHANGELOG.md or CHANGES file exists despite being at version 0.4.2+
- Production software with 665+ commits this year needs version history

**Missing .env.example:**
- docker-compose.yaml references 10+ env vars (OPENAI_API_KEY, BRAVE_SEARCH_API_KEY, TAVILY_SEARCH_API_KEY, Azure creds, etc.)
- No `.env.example` template exists to guide setup

### 2. Code Quality

**Remaining `# type: ignore` in source (6 occurrences across 4 files):**
- `src/authentication/k8s.py:131` -- ssl_ca_cert assignment
- `src/client.py:175` -- copy with headers
- `src/models/responses.py:1144-1146` -- 3 call-arg ignores
- `src/app/endpoints/rlsapi_v1.py:487` -- arg-type

The project is actively cleaning these up (multiple recent PRs: LCORE-1527, LCORE-1531, LCORE-1532). Each removal is a separate PR opportunity.

**TODOs in source (3):**
- `src/authentication/jwk_token.py:49` -- handle connection errors/timeouts
- `src/metrics/__init__.py:45,51` -- add metric for token usage (2 occurrences)

### 3. Tests

**Untested utility modules:**
- `src/utils/schema_dumper.py` -- no test
- `src/utils/token_counter.py` -- no test
- `src/utils/mcp_oauth_probe.py` -- no test
- `src/utils/tool_formatter.py` -- no test
- `src/utils/stream_interrupts.py` -- no test
- `src/runners/quota_scheduler.py` -- no test

**Incomplete test TODOs:**
- `tests/unit/cache/test_postgres_cache.py` -- has `TODO: LCORE-721` for implementing PostgreSQL cache tests
- `tests/e2e/features/steps/health.py` -- has `TODO: add step implementation`

### 4. CI/CD

CI is comprehensive with 23 workflows. Minor opportunities:
- No code coverage badge in README (coverage is measured but not displayed)
- No CodeQL/SAST badge despite having bandit

### 5. DX Improvements

- Missing `.env.example` (mentioned above)
- The `lightspeed-stack.yaml` default config exists but there's no documented "minimal config" for quick start

---

## Draft PRs

### PR 1: Fix README placeholder TODOs

- **PR Title:** `docs: fix placeholder TODOs in README Containerfile examples`
- **Branch:** `docs/fix-readme-todos`
- **Files to change:** `README.md`
- **Changes:**
  - Line 997: Replace `"lightspeed-stack-providers==TODO"` with actual package reference or a clear placeholder like `"lightspeed-stack-providers>=0.4.0"` (check actual version)
  - Line 1031: Replace `TODO1 TODO2` with either real RPM names or remove the example line with a comment explaining it's optional
- **Effort:** 15 minutes
- **Merge likelihood:** **HIGH** -- Maintainer tisnik regularly merges doc fixes. These are visible embarrassments in the README that look unprofessional. No code changes, no tests needed.

### PR 2: Remove `# type: ignore` from `src/models/responses.py`

- **PR Title:** `fix: remove type ignore comments in responses model`
- **Branch:** `fix/remove-type-ignore-responses`
- **Files to change:** `src/models/responses.py`
- **Changes:** Fix the 3 `# type: ignore[call-arg]` at lines 1144-1146 by properly typing the constructor call or adjusting the model. Follow the pattern of recent PRs (LCORE-1527, LCORE-1531, LCORE-1532) which did exactly this.
- **Effort:** 30-60 minutes (need to understand the model and fix types properly)
- **Merge likelihood:** **HIGH** -- This is an active initiative. Multiple PRs doing exactly this have been merged recently. Follow the LCORE naming convention and reference an existing ticket or create one.

### PR 3: Add unit tests for `src/utils/token_counter.py`

- **PR Title:** `test: add unit tests for token counter utility`
- **Branch:** `test/token-counter-unit-tests`
- **Files to change:** Create `tests/unit/utils/test_token_counter.py`
- **Changes:** Write pytest tests covering the token counting utility. Follow existing test patterns from `tests/unit/utils/` directory. Use `pytest-mock` for any external dependencies. Must achieve the project's style: Google docstrings, complete type hints, pytest fixtures.
- **Effort:** 1-2 hours
- **Merge likelihood:** **MEDIUM-HIGH** -- Project requires 60% unit test coverage and actively values test contributions. However, you need a Jira ticket (LCORE-xxxx) in the PR title per their contributing guide.

---

## Notes

**Red flags:** None significant.
- Maintainer is highly active (235+ commits, merges within 1-2 days)
- Well-documented contribution process
- Strong CI/CD pipeline ensures quality

**Barriers to entry:**
- PR titles require Jira ticket numbers (LCORE-xxxx). External contributors may need to request access or reference a GitHub issue instead
- CodeRabbit AI review is enabled -- PRs get automated review
- The `make verify` pipeline runs 6 linters -- code must pass all of them
- Contributing guide requires marking AI-assisted code (relevant if using Claude)

**Best approach:**
1. Start with the README TODO fix (PR 1) -- zero risk, high visibility, no Jira needed
2. Follow up with type ignore removals -- proven pattern, maintainers are actively accepting these
3. For test PRs, open a GitHub issue first to get a ticket reference, then submit
