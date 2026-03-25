Now I have everything I need. Here's the full report:

---

# Marketing Audit: kintone/mcp-server

## Quick Overview

Kintone MCP Server is a Model Context Protocol server that exposes 20 tools for interacting with Cybozu's Kintone platform (a Japanese no-code business app builder). It lets AI assistants (Claude Desktop, Cursor, etc.) manage Kintone apps, records, form fields, layouts, and files via MCP.

**Tech stack:** TypeScript, Node.js >= 22, pnpm, Zod, vitest, ESLint (flat config), Docker (distroless), release-please

**Activity level:** Very active. ~3-5 commits/week, almost entirely automated Renovate dependency bumps. Maintainer team (`@kintone/extensions-platform`) merges Renovate PRs within 1-2 days. Last feature commit was `2026-02-25` (fix reference table size). The repo is well-maintained but feature development is slow -- most activity is dependency updates.

---

## Quick Win PRs

### 1. Documentation Improvements

**a) License badge label mismatch (BUG)**
- Both `README.md:5` and `README_en.md:5` display `[![License: MIT]...]` but the actual badge URL (`line 12`) and license are **Apache 2.0**
- The badge alt-text says "MIT" while the badge image correctly renders "Apache 2.0"
- Easy fix: change `License: MIT` to `License: Apache 2.0` in both files

**b) URL inconsistency in README_en.md**
- Line 253 uses `https://example.kintone.com` while every other example uses `https://example.cybozu.com`
- Japanese README.md is consistent (all `cybozu.com`) -- the English version deviates

**c) No `.env.example` file**
- 10+ environment variables documented but no template file for quick setup
- Would help developers get started faster

**d) No GitHub issue templates**
- `.github/` has `CODEOWNERS` and `PULL_REQUEST_TEMPLATE.md` but no `ISSUE_TEMPLATE/` directory
- Bug report and feature request templates would improve issue quality

**e) Empty `.devcontainer/` directory**
- CONTRIBUTING.md recommends Dev Container setup but the directory is empty
- The actual config lives in a git submodule (`.gitmodules` references `kintone/dev-container`), but the empty dir is confusing

### 2. Code Quality

**a) TODO comment in source code**
- `src/schema/record/record-for-parameter.ts:147`: `// TODO: ファイルアップロードツール実装後に調整`
- FILE fields are blocked with `z.never()` -- could be tracked as a GitHub issue instead of inline TODO

### 3. Tests

**a) No tests for `src/server/tool-filters.ts`**
- Pure function (`shouldEnableTool`) with clear filter rules -- trivially testable
- 27 lines, simple logic: excludes `kintone-get-apps` and `kintone-add-app` when using API token auth
- Would add coverage to core server logic

**b) No tests for `src/server/index.ts`**
- Main server creation/registration logic -- harder to test but a gap

### 4. CI/CD

**a) Open PR #357: pnpm/action-setup v5 update**
- Renovate opened it 2026-03-17, still open -- could review/approve

**b) Open PR #354: https-proxy-agent v8 update**
- Major version bump, may need manual review/adjustment

### 5. DX Improvements

**a) `.env.example` template**
- Quick reference for all supported env vars with comments

---

## Draft PRs

### PR #1: Fix license badge label in READMEs

- **PR Title:** `docs: fix license badge label from MIT to Apache 2.0`
- **Branch:** `docs/fix-license-badge`
- **Files to change:** `README.md`, `README_en.md`
- **Changes:**
  - `README.md:5` -- change `[![License: MIT]` to `[![License: Apache 2.0]`
  - `README_en.md:5` -- change `[![License: MIT]` to `[![License: Apache 2.0]`
- **Effort:** 2 minutes
- **Merge likelihood:** **High** -- obvious bug, factual correction, zero risk

### PR #2: Fix URL inconsistency in English README troubleshooting

- **PR Title:** `docs: fix example URL in English README troubleshooting section`
- **Branch:** `docs/fix-troubleshooting-url`
- **Files to change:** `README_en.md`
- **Changes:**
  - Line 253: change `https://example.kintone.com` to `https://example.cybozu.com`
  - Aligns with all other examples in both READMEs
- **Effort:** 1 minute
- **Merge likelihood:** **High** -- consistency fix, matches Japanese README

### PR #3: Add unit tests for tool-filters

- **PR Title:** `test: add unit tests for tool-filters`
- **Branch:** `test/tool-filters`
- **Files to change:** Create `src/server/__tests__/tool-filters.test.ts`
- **Changes:**
  - Test `shouldEnableTool` returns `true` for non-excluded tools
  - Test it returns `false` for `kintone-get-apps` and `kintone-add-app` when `isApiTokenAuth: true`
  - Test it returns `true` for those tools when `isApiTokenAuth: false`
  - Follow existing test patterns (vitest, `describe`/`it` blocks)
- **Effort:** 15-20 minutes
- **Merge likelihood:** **High** -- maintainers value test coverage, follows existing patterns, tests core logic

---

## Notes

- **Maintainer responsiveness:** Automated PRs (Renovate) merge in 1-2 days. External PR #368 from `Tom8810` (opened 2026-03-24) is pending review -- watch for response time to gauge external contributor experience
- **Red flags:** None significant. Repo is well-maintained with solid CI/CD, conventional commits, and release automation
- **PR #1 and #2 could be combined** into a single docs PR for efficiency
- **Best approach:** Small, focused PRs. The team uses conventional commits strictly (commitlint enforced). Follow CONTRIBUTING.md exactly. PRs should have clear titles in conventional commit format
- **Language note:** Primary docs are Japanese. If contributing to Japanese docs, verify translations are accurate
- **CODEOWNERS:** All changes require review from `@kintone/extensions-platform`
