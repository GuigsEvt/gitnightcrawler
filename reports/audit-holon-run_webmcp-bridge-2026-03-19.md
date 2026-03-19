Now I have everything I need. Here's the report:

---

# Marketing Audit: holon-run/webmcp-bridge

## Quick Overview

**webmcp-bridge** is a TypeScript monorepo that bridges local MCP (Model Context Protocol) clients to browser-based WebMCP tools through Playwright. It lets AI agents call browser-native tools via a stdio MCP surface, using native WebMCP when available and injected adapters (e.g., X/Twitter) as fallbacks. The primary use case is human + AI collaboration on the same browser page while keeping auth in the browser session.

**Tech stack:** TypeScript 5.9 (strict), pnpm monorepo, Playwright, Vitest, Zod 4, @modelcontextprotocol/sdk, ESLint 9, Prettier, Changesets, Cloudflare Pages

**Activity level:**
- Created 2026-03-11 (8 days ago), 50 commits, single maintainer (`jolestar`)
- 20 stars, 2 forks
- PRs merged same-day or next-day (very responsive)
- 4 open issues (all feature requests), 1 open PR
- 1 external PR was closed (x402 monetization) -- maintainer is selective

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **Missing README badges** | No CI status, npm version, license, or stars badges at top of README |
| **Missing SECURITY.md link in README** | SECURITY.md exists but README doesn't mention it |
| **No architecture diagram** | README references `docs/images/bridge-architecture.png` -- need to verify it exists and renders on GitHub |
| **adapter-utils undocumented** | No `docs/adapters/utils.md` -- the newest package has no dedicated docs |
| **Missing JSDoc on public exports** | Core types (`types.ts`) and gateway (`gateway.ts`) lack JSDoc comments on exported types/functions |
| **Example board README incomplete** | No mention of required Node/pnpm versions or Playwright browser install step |

### 2. Code Quality

| Item | Details |
|------|---------|
| **adapter-x is 3,497 LOC in one file** | Could be split into modules (auth, timeline, dm, grok, compose) -- but this is a larger refactor, not a quick PR |
| **No `engines` field in package.json** | Root and sub-packages don't specify Node version requirement (CI uses Node 20) |
| **Missing `exports` map validation** | Some packages could benefit from explicit `exports` conditions in package.json |
| **`improve board` commit** | Non-conventional commit message at `d732da5` -- shows room for commit linting |

### 3. Tests

| Item | Details |
|------|---------|
| **No test coverage reporting** | No coverage config in vitest, no coverage badge, no coverage in CI |
| **adapter-utils/test coverage gaps** | Only `index.test.ts` (175 LOC) for 451 LOC of utils -- `playwright.ts` and `stream.ts` appear undertested |
| **testkit barely tested** | Only 22 LOC of tests for the contract test helpers |
| **No integration/E2E test** | No Playwright E2E test running the full bridge against the board demo |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No Dependabot/Renovate** | No automated dependency updates configured |
| **No CI badges in README** | CI runs but no status badge displayed |
| **No commit lint / conventional commit enforcement** | Commit `d732da5` ("improve board") proves this -- could add commitlint |
| **No PR template** | No `.github/PULL_REQUEST_TEMPLATE.md` |
| **No issue templates** | No `.github/ISSUE_TEMPLATE/` directory |
| **Single CI job** | All checks run sequentially in one job -- could parallelize typecheck/lint/test/build |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **No Docker/devcontainer** | No Dockerfile or `.devcontainer/` for consistent dev environments |
| **No `.env.example`** | No env template despite NPM_TOKEN needed for release |
| **No `engines` or `volta` pin** | No guaranteed Node/pnpm version for contributors |
| **Missing `pnpm format` in README** | `format` script exists but not mentioned in Development section |

---

## Draft PRs

### PR #1: Add README badges and CI status

- **PR Title:** `docs: add CI, npm, and license badges to README`
- **Branch:** `docs/readme-badges`
- **Files to change:** `README.md`
- **Changes:** Add badges block after the `# webmcp-bridge` heading:
  ```markdown
  [![CI](https://github.com/holon-run/webmcp-bridge/actions/workflows/ci.yml/badge.svg)](https://github.com/holon-run/webmcp-bridge/actions/workflows/ci.yml)
  [![npm](https://img.shields.io/npm/v/@webmcp-bridge/local-mcp)](https://www.npmjs.com/package/@webmcp-bridge/local-mcp)
  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
  ```
- **Effort:** 5 minutes
- **Merge likelihood:** **High** -- zero risk, improves discoverability and trust signals. Every serious open-source project has these.

### PR #2: Add GitHub issue and PR templates

- **PR Title:** `chore: add issue and pull request templates`
- **Branch:** `chore/github-templates`
- **Files to change:**
  - `.github/ISSUE_TEMPLATE/bug_report.md` (new)
  - `.github/ISSUE_TEMPLATE/feature_request.md` (new)
  - `.github/PULL_REQUEST_TEMPLATE.md` (new)
- **Changes:** Create standard templates aligned with CONTRIBUTING.md guidelines. Bug template should include: environment, steps to reproduce, expected vs actual. PR template should include: description, type of change, checklist (tests, conventional commit, docs updated).
- **Effort:** 15 minutes
- **Merge likelihood:** **High** -- the project already has CONTRIBUTING.md with clear standards, templates enforce them. The closed external PR (#1) suggests maintainer values structured contributions.

### PR #3: Add Dependabot configuration for automated dependency updates

- **PR Title:** `chore: add Dependabot configuration for npm and GitHub Actions`
- **Branch:** `chore/dependabot`
- **Files to change:** `.github/dependabot.yml` (new)
- **Changes:** Configure Dependabot for:
  - `npm` ecosystem (pnpm) with weekly schedule, grouped minor/patch updates
  - `github-actions` ecosystem with weekly schedule
  - Limit to 5 open PRs to avoid noise
- **Effort:** 10 minutes
- **Merge likelihood:** **Medium-High** -- standard practice for active projects. The project uses pinned action versions (`@v4`) already, showing awareness of supply chain concerns. Only risk: maintainer may prefer Renovate or manual updates.

---

## Notes

**Red flags:** None significant. Single maintainer is normal for a week-old project at 20 stars. The one closed external PR (#1 - x402 monetization) was a feature addition, not a quality PR, so the close doesn't signal hostility to contributions.

**Approach recommendations:**
- Start with the badges PR -- it's the safest entry point and demonstrates awareness of the project
- Follow CONTRIBUTING.md strictly: conventional commits, package boundaries, tests for behavior changes
- The maintainer merges PRs fast (same-day) -- submit early in the day
- Avoid large refactors (like splitting adapter-x) as a first contribution
- The project is young and moving fast -- check for conflicts before submitting
- Coverage reporting (vitest + Coveralls/Codecov) would be a strong follow-up PR after templates
