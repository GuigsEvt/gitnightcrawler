Now I have everything needed. Here's the report:

---

# Marketing Audit: SalesforceCommerceCloud/b2c-developer-tooling

## Quick Overview

B2C Developer Tooling is Salesforce's official monorepo for Commerce Cloud B2C development tools. It provides a CLI (`b2c-cli`) built on oclif, a Node.js SDK (`b2c-tooling-sdk`), and an MCP server (`b2c-dx-mcp`) for AI-assisted commerce development. Currently in **Developer Preview**.

- **Tech stack**: TypeScript, Node.js 22+, pnpm monorepo, oclif (CLI), Mocha/Chai/MSW (testing), VitePress + TypeDoc (docs), Changesets (versioning)
- **Activity level**: Very active -- 66 commits in the last 30 days, multiple PRs merged daily. Maintained by Salesforce employees. PRs from external contributors are accepted but scrutinized (3PL guard, peer review required).

## Quick Win PRs

### 1. Documentation Improvements

| Issue | File | Details |
|-------|------|---------|
| Typo: "arbitrars" | `CONTRIBUTING.md:10` | `"final arbitrars"` should be `"final arbiters"` |
| Unclear phrasing | `CONTRIBUTING.md:58` | `"Increase code coverage, not versa."` -- missing word, should be `"not vice versa"` or `"not decrease it"` |
| Typo in SDK data | `packages/b2c-tooling-sdk/data/script-api/dw.web.ClickStreamEntry.md:74,182` | `"rewritting"` should be `"rewriting"`, `"than"` should be `"then"` |

### 2. Code Quality

| Issue | File | Details |
|-------|------|---------|
| `console.warn` instead of SDK logger | `packages/b2c-tooling-sdk/src/config/resolver.ts:336` | Comment on line 333-335 explicitly says this should use `getLogger()`. Easy fix: import logger and replace `console.warn`. |

### 3. Tests

Major untested areas (by package):

**b2c-cli** (89% file coverage):
- `src/commands/logs/` -- 3 files, 0 tests
- `src/commands/scaffold/` -- 7 files, 0 tests
- `src/commands/setup/instance/` -- 6 files, 0 tests
- `src/utils/` -- 16 source files, only 7 tested

**b2c-tooling-sdk** (61% file coverage):
- `src/docs/` -- 5 files, 0 tests
- `src/errors/` -- 2 files, 0 tests
- `src/i18n/` -- 3 files, 0 tests
- `src/instance/` -- 1 file, 0 tests

**b2c-dx-mcp** (65% file coverage):
- `src/tools/storefrontnext/page-designer-decorator/` -- 10+ rule files, 0 tests

### 4. CI/CD

Already solid -- 12 workflows covering CI, e2e, docs, publishing, 3PL guard, preview releases, Renovate. No obvious gaps.

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| `console.warn` in config resolver | Developers won't see warnings if they've configured a custom log level. Using the SDK logger respects user config. |

---

## Draft PRs

### PR #1: Fix typos in CONTRIBUTING.md

- **PR Title**: `docs: fix typos in CONTRIBUTING.md`
- **Branch**: `docs/fix-contributing-typos`
- **Files to change**: `CONTRIBUTING.md`
- **Changes**:
  - Line 10: `arbitrars` -> `arbiters`
  - Line 58: `Increase code coverage, not versa.` -> `Increase code coverage, not decrease it.`
- **Effort**: 5 minutes
- **Merge likelihood**: **HIGH** -- zero-risk doc fix, no code changes, no review friction

### PR #2: Replace console.warn with SDK logger in ConfigResolver

- **PR Title**: `fix: use SDK logger instead of console.warn in ConfigResolver`
- **Branch**: `fix/config-resolver-logging`
- **Files to change**: `packages/b2c-tooling-sdk/src/config/resolver.ts`
- **Changes**:
  - Add `import {getLogger} from '../logging/index.js';` (or appropriate path)
  - Replace `console.warn(...)` on line 336 with `getLogger().warn(...)`
  - Remove the TODO-like comments on lines 333-335
- **Effort**: 15 minutes (including finding the correct import path and testing)
- **Merge likelihood**: **HIGH** -- the code comments literally ask for this change. Addresses a known TODO left by maintainers.

### PR #3: Add tests for b2c-tooling-sdk error module

- **PR Title**: `test: add unit tests for errors module`
- **Branch**: `test/sdk-errors-module`
- **Files to change**: Create `packages/b2c-tooling-sdk/test/errors/` with test files matching `src/errors/` source files
- **Changes**:
  - Follow existing test patterns (Mocha + Chai, MSW for HTTP)
  - Test error class instantiation, message formatting, error code handling
  - Use existing `.mocharc.json` config
- **Effort**: 30-60 minutes
- **Merge likelihood**: **MEDIUM-HIGH** -- maintainers have 80% coverage thresholds and accept test contributions, but test PRs need to follow their patterns closely. The `errors` module is likely small and self-contained.

---

## Notes

- **No red flags** -- repo is very active (66 commits/month), maintained by a Salesforce team, PRs are reviewed and merged regularly.
- **3PL Guard**: Any PR adding new dependencies will be flagged and require maintainer approval. Stick to zero-dependency changes.
- **Changesets required**: Non-trivial changes need a changeset (`pnpm changeset`). Doc-only fixes may not need one.
- **Best approach**: Start with PR #1 (typo fix) to establish contributor status, then follow up with PR #2. Both are unambiguously correct changes that require minimal review.
- **Caution**: This is a Salesforce corporate open-source project. They're selective about external contributions. Quick doc/quality fixes are the best entry point.
