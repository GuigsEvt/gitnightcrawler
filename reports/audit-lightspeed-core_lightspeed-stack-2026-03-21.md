Now I have all the data. Here's the report:

---

# Marketing Audit: lightspeed-core/lightspeed-stack

## Quick Overview

Lightspeed Core Stack (LCS) is a Red Hat-backed AI-powered assistant built on FastAPI that provides answers using LLM services, agents, and RAG databases. It integrates with Llama Stack for AI operations and supports multiple LLM providers (OpenAI, Azure, RHEL AI, VertexAI, WatsonX). The project implements A2A protocol, conversation caching, quota management, and various authentication strategies (Kubernetes, JWK, Red Hat Identity).

**Tech stack:** Python 3.12/3.13, FastAPI, Pydantic, Llama Stack, SQLAlchemy, Prometheus, uv package manager, pytest + behave (BDD)

**Activity level:** Extremely active -- 622 commits in March 2026 alone, 10 PRs merged in the last 2 days, 10+ open PRs. PRs are merged within hours to 1-2 days. Maintained by Red Hat engineers (tisnik, major, asimurka, anik120, karthikjeeyar). This is an enterprise-backed project with fast PR turnaround.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Description | File | Effort |
|-------|-------------|------|--------|
| **#1356** | Typo: "can be **send**" should be "can be **sent**" | `docs/openapi.md:4296` | 1 min |
| **#1020** | Example uses wrong class name `StatusResponse` instead of `FeedbackStatusUpdateResponse` | `docs/openapi.json:~7550` | 5 min |
| **#1334** | `RagConfiguration` inline/tool fields missing `"default": []` in JSON schema | `docs/config.json:1140-1155` | 5 min |
| **#1333** | `score_multiplier` has `"minimum": 0` in schema but runtime enforces `gt=0` -- needs `"exclusiveMinimum": true` | `docs/config.json:288` | 5 min |

### 2. Code Quality

| Finding | Description | File | Effort |
|---------|-------------|------|--------|
| **#1346** | Misleading docstring claims return value but function returns `None` | `tests/e2e/utils/llama_stack_utils.py:41` | 2 min |
| **TODO cleanup** | 3 stale TODO comments from specific developers | `src/authentication/jwk_token.py:49`, `src/metrics/__init__.py:45,51` | 10 min |
| **Renovate config** | `renovate.json` only enables `tekton` manager -- could add `pip_requirements`, `pep621` for Python dep tracking | `renovate.json` | 10 min |

### 3. Tests

- Test infrastructure is comprehensive (188 test files, 60% unit coverage requirement)
- Open PRs #1366 and #1367 are already consolidating test fixtures -- don't compete with those
- No obvious missing test directories or `__init__.py` files

### 4. CI/CD

- Already has 20 GitHub Actions workflows covering linting, testing, security, builds
- No badges in README -- could add build status, coverage, Python version badges
- No `.pre-commit-config.yaml` -- project uses manual `hooks/pre-commit` shell script; a PR to add proper pre-commit framework could be valuable but may be opinionated

### 5. DX Improvements

- No Dependabot configuration exists (`.github/dependabot.yml`) -- only minimal Renovate for Tekton
- Could add a `SECURITY.md` policy file
- Missing GitHub issue templates beyond basic bug/RFE

---

## Draft PRs

### PR #1: Fix typo in OpenAPI docs (Issue #1356)

- **PR Title:** `docs: fix typo "send" -> "sent" in Attachment model description`
- **Branch:** `docs/fix-attachment-typo`
- **Files to change:** `docs/openapi.md`
- **Changes:** Line 4296 -- change "can be **send**" to "can be **sent**"
- **Effort:** 5 minutes
- **Merge likelihood:** **HIGH** -- existing open issue, one-character fix, docs-only, no CI risk

### PR #2: Fix schema/runtime mismatch for score_multiplier and RagConfiguration defaults (Issues #1333 + #1334)

- **PR Title:** `docs: fix config.json schema to match runtime validation`
- **Branch:** `docs/fix-config-schema`
- **Files to change:** `docs/config.json`
- **Changes:**
  - Add `"exclusiveMinimum": true` to `score_multiplier` field (~line 288) to match `gt=0` in `src/models/config.py`
  - Add `"default": []` to `RagConfiguration.inline` and `RagConfiguration.tool` fields (~lines 1140-1155)
- **Effort:** 15 minutes
- **Merge likelihood:** **HIGH** -- two confirmed open issues, schema-only changes, no runtime impact

### PR #3: Fix misleading docstring in e2e test utility (Issue #1346)

- **PR Title:** `fix: correct misleading docstring in _unregister_toolgroup_async`
- **Branch:** `fix/unregister-toolgroup-docstring`
- **Files to change:** `tests/e2e/utils/llama_stack_utils.py`
- **Changes:** Line 41 -- change docstring from "Unregister a toolgroup by identifier; return (provider_id, provider_shield_id) for restore." to "Unregister a toolgroup by identifier."
- **Effort:** 5 minutes
- **Merge likelihood:** **HIGH** -- existing open issue, single-line docstring fix, test-only file

---

## Notes

- **No red flags.** This is a well-maintained, actively developed Red Hat project. PRs are reviewed and merged quickly (same-day to 1-2 days).
- **Contribution process:** Requires Jira ticket IDs in PR titles (e.g., `LCORE-xxxx`). For external contributors, reference the GitHub issue number instead.
- **CodeRabbit AI** reviews PRs automatically -- expect fast initial feedback.
- **Best approach:** Reference the existing GitHub issue number in the PR. Keep changes minimal and focused. The maintainers clearly prefer small, targeted PRs.
- **Avoid:** Don't compete with active PRs (#1366, #1367 for test refactoring, #1342 for MCP docs). Don't touch core auth/runtime code without deep context.
- **Caution:** The `docs/openapi.md` and `docs/openapi.json` files may be auto-generated. Verify whether changes should be made to source models instead. If auto-generated, the fix for #1356 would need to go in the Pydantic model's docstring/description field instead.
