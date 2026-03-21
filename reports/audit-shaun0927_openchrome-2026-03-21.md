Now I have everything I need. Let me compile the report.

---

# Marketing Audit: shaun0927/openchrome

## Quick Overview

OpenChrome is an open-source MCP (Model Context Protocol) server for browser automation that talks directly to Chrome via CDP (Chrome DevTools Protocol). It enables AI agents to control a real Chrome instance with parallel tab sessions, login session reuse, anti-bot stealth, and a hint engine that prevents LLM wandering. Ships as an npm package (`openchrome-mcp`) with CLI, 45 tools, and MCP server mode.

- **Tech stack**: TypeScript, Node.js (>=18), Puppeteer-core, CDP, Jest, ESLint, Webpack
- **Activity level**: Extremely active -- 300+ commits since Jan 2025, 362 merged PRs, 7 open issues. Single maintainer (shaun0927). PRs merge within hours, often same-day. Last activity: today (2026-03-21).

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **No CHANGELOG.md** | 362 PRs and 1.8.0 release but no changelog. GitHub Releases exist but a `CHANGELOG.md` is standard. |
| **Missing badges** | No CI status badge, no code coverage badge, no npm downloads badge. README has version/release/license only. |
| **docs/ is sparse** | Only `docs/turnstile-guide.md`. No API reference, no architecture doc (CONTRIBUTING.md has a brief ASCII diagram but nothing standalone). |
| **No JSDoc on public API** | `src/mcp-server.ts` (1128 lines) and tool files lack JSDoc comments on exported functions. |

### 2. Code Quality

| Item | Details |
|------|---------|
| **ESLint `no-console: off`** | CLAUDE.md says use `console.error()` for logging, but ESLint doesn't enforce it. 35 `console.log` calls in `src/index.ts`. |
| **`no-explicit-any: off`** | TypeScript strict mode is on, but `any` is freely allowed. Low-hanging tightening opportunity. |
| **No Prettier config** | No `.prettierrc` or formatting tool. Code formatting is unenforceable. |
| **`no-var-requires: off`** | Dynamic `require()` allowed; could use ES imports. |

### 3. Tests

| Item | Details |
|------|---------|
| **144 source files, 104 test files** | 72% file coverage ratio. |
| **7 hint rule files untested** | `error-recovery.ts`, `learned-rules.ts`, `pagination-detection.ts`, `repetition-detection.ts`, `sequence-detection.ts`, `setup-hints.ts`, `success-hints.ts` -- all pure logic, easy to unit test. |
| **30+ tool files untested** | `batch-execute.ts`, `cookies.ts`, `console-capture.ts`, `interact.ts`, `request-intercept.ts`, `query-dom.ts`, etc. |
| **Config module (4 files) untested** | `defaults.ts`, `global.ts`, `index.ts`, `tool-tiers.ts` -- static data, trivial tests. |
| **Dashboard module (8 files) untested** | `ansi.ts`, `activity-tracker.ts`, etc. |
| **Coverage thresholds exist** | 75% lines/functions/statements, 50% branches -- but many modules have 0% coverage. |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No coverage reporting** | CI runs tests but doesn't upload coverage to Codecov/Coveralls. |
| **No CI badge in README** | Workflow exists but no badge displayed. |
| **No GitHub issue/PR templates** | `.github/` has only `workflows/ci.yml`. No `ISSUE_TEMPLATE/`, no `pull_request_template.md`. |
| **No dependabot/renovate** | No automated dependency update config. |
| **No release automation** | Manual version bumps. No `release-please` or `semantic-release`. |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **No `.env.example`** | Environment variables documented in README but no template file. |
| **Docker Compose missing** | Dockerfile exists but no `docker-compose.yml` for easy dev setup. |
| **No `npm run format`** | No formatting script in package.json. |

---

## Draft PRs

### PR 1: Add CI badge, coverage badge, and npm downloads badge to README

- **PR Title**: `docs: add CI status, coverage, and downloads badges to README`
- **Branch**: `docs/readme-badges`
- **Files to change**: `README.md`
- **Changes**: Add after existing badges in the `<p align="center">` block:
  ```html
  <a href="https://github.com/shaun0927/openchrome/actions/workflows/ci.yml"><img src="https://github.com/shaun0927/openchrome/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://www.npmjs.com/package/openchrome-mcp"><img src="https://img.shields.io/npm/dm/openchrome-mcp" alt="npm downloads"></a>
  ```
- **Effort**: 5 minutes
- **Merge likelihood**: **High** -- zero-risk, improves project credibility, maintainer clearly cares about README presentation.

### PR 2: Add GitHub issue and PR templates

- **PR Title**: `docs: add issue and PR templates`
- **Branch**: `docs/github-templates`
- **Files to change**:
  - `.github/ISSUE_TEMPLATE/bug_report.md` (new)
  - `.github/ISSUE_TEMPLATE/feature_request.md` (new)
  - `.github/pull_request_template.md` (new)
- **Changes**: Standard bug report template (OS, Node version, Chrome version, steps to reproduce), feature request template, PR template with checklist matching CONTRIBUTING.md guidelines.
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- project has 362 PRs and active issues but no templates. CONTRIBUTING.md already defines PR expectations; templates codify them.

### PR 3: Add unit tests for untested hint rule modules

- **PR Title**: `test: add unit tests for hint rule modules`
- **Branch**: `test/hint-rules-coverage`
- **Files to change**:
  - `tests/hints/error-recovery.test.ts` (new)
  - `tests/hints/repetition-detection.test.ts` (new)
  - `tests/hints/sequence-detection.test.ts` (new)
  - `tests/hints/success-hints.test.ts` (new)
- **Changes**: Unit tests for 4 hint rule files. These are pure logic modules (pattern matching, rule evaluation) with no CDP/browser dependencies -- mockable with simple input/output patterns. Existing hint tests in `tests/hints/` provide the test pattern to follow.
- **Effort**: 30-45 minutes
- **Merge likelihood**: **High** -- maintainer has 75% coverage thresholds configured, actively merges test improvements, and these modules are core to the hint engine which is a key differentiator.

---

## Notes

- **Single maintainer** -- shaun0927 is the only contributor. PRs merge fast (same day) but all review is self-review. External contributions would likely be welcomed.
- **Very active** -- 362 PRs in ~1 month, shipping features daily. The maintainer iterates fast and values well-structured PRs (conventional commits, clear scope).
- **PR target**: CLAUDE.md specifies PRs should target `develop` branch, not `main`.
- **Best approach**: Small, focused PRs. The maintainer merges fast and prefers conventional commit style. Badge/template PRs are zero-risk entry points. Test PRs demonstrate competence and build trust for larger contributions.
- **Red flag**: The extreme velocity (300+ commits in weeks) suggests heavy AI-assisted development. Code quality is generally good but coverage gaps are real.
