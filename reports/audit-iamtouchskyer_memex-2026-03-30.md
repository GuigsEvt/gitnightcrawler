Now I have everything I need. Here's the report:

---

# Marketing Audit: iamtouchskyer/memex

## Quick Overview

Memex is a Zettelkasten-based persistent memory system for AI coding agents. It stores atomic knowledge cards as markdown files with `[[bidirectional links]]` and YAML frontmatter -- no vector DB or embeddings required. Cards are shared across editors (Claude Code, VS Code, Cursor, Codex, Windsurf) via `~/.memex/cards/` and synced with git. Available as an npm CLI, MCP server, VS Code extension, and Claude Code plugin.

- **Tech stack**: TypeScript, Node.js (ESM), Commander v14 CLI, MCP SDK, Zod, Vitest, gray-matter
- **Activity level**: 55 commits total (repo created 2026-03-20, ~10 days old). Very active -- multiple PRs merged daily. 49 stars, 11 forks. External contributors (litaohz, kagura-agent, shazhou-ww, yuvrajangadsingh) have PRs merged quickly. 1 open issue (#29 semantic search, tagged `help wanted`).

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **No CONTRIBUTING.md** | Repo accepts external PRs but has no contributor guide. Add dev setup, test commands, PR conventions. |
| **No badges in README** | Missing npm version, CI status, license, Node version badges. Standard for npm packages. |
| **server.json version drift** | `server.json` says version `0.1.8` but `package.json` is `0.1.25`. Stale metadata. |
| **Missing CHANGELOG** | 55 commits, no changelog. Conventional commits make this easy to generate. |
| **No JSDoc on exports** | Public functions in `src/lib/*.ts` and `src/commands/*.ts` have no JSDoc comments. |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **`any` type in MCP server** | `server.ts:32` uses `msg: any`. Could use proper MCP transport message type. |
| **No linter configured** | No eslint, prettier, or biome. A basic eslint/biome config would catch regressions. |
| **No `engines` field in package.json** | README says Node 18+ required but `package.json` doesn't enforce it. |
| **postbuild uses cpSync** | `scripts/postbuild.mjs` uses `cpSync` -- could fail silently. Minor. |

### 3. Tests

| Issue | Details |
|-------|---------|
| **No import command test** | `src/commands/import.ts` exists but no `tests/commands/import.test.ts`. |
| **Coverage threshold at 70%** | Could be bumped. Tests exist for most modules. |
| **No coverage report in CI** | CI runs tests but doesn't generate or upload coverage reports. |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **No lint step in CI** | Only builds and tests. Adding a lint check would prevent regressions. |
| **No npm publish workflow** | Package is on npm but no automated publish on tag/release. |
| **No release workflow** | No GitHub Releases being created. Tags + changelogs would improve visibility. |
| **No Dependabot/Renovate** | No automated dependency updates configured. |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **No Dockerfile** | Users in containerized environments can't easily run memex. |
| **No `.editorconfig`** | Multi-contributor repo without consistent editor settings. |
| **No `.nvmrc`** | README says Node 18+ but no `.nvmrc` for automatic version switching. |

---

## Draft PRs

### PR #1: Add badges and CONTRIBUTING.md

- **PR Title**: `docs: add CI/npm badges and CONTRIBUTING.md`
- **Branch**: `docs/badges-and-contributing`
- **Files to change**:
  - `README.md` -- add badge row after title: npm version, CI status, license, Node 18+
  - `CONTRIBUTING.md` -- new file: dev setup (`npm ci && npm run build && npm test`), PR conventions, commit style
- **Changes**:
  - Insert after line 1 of README: `[![CI](https://github.com/iamtouchskyer/memex/actions/workflows/test.yml/badge.svg)](...)` + npm + license badges
  - Create `CONTRIBUTING.md` (~40 lines): prerequisites, local dev, testing, PR guidelines
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- standard open-source hygiene, no code changes, maintainer clearly welcomes external PRs

### PR #2: Fix server.json version drift + add engines field

- **PR Title**: `fix: sync server.json version and add engines field to package.json`
- **Branch**: `fix/version-sync-and-engines`
- **Files to change**:
  - `server.json` -- update `version` from `0.1.8` to match `package.json` (`0.1.25`)
  - `package.json` -- add `"engines": { "node": ">=18" }`
- **Changes**:
  - `server.json` line 9: `"version": "0.1.8"` -> `"version": "0.1.25"`, line 14 same
  - `package.json`: add `engines` field
- **Effort**: 5 minutes
- **Merge likelihood**: **High** -- fixes real inconsistency, zero risk

### PR #3: Add coverage reporting to CI

- **PR Title**: `ci: add coverage report and upload to CI`
- **Branch**: `ci/coverage-report`
- **Files to change**:
  - `.github/workflows/test.yml` -- change `npm test` to `npx vitest run --coverage` on one matrix entry (ubuntu, node 22), add coverage upload step
- **Changes**:
  - Add a separate job or conditional step that runs `npx vitest run --coverage` on ubuntu/node-22 only
  - Upload coverage as artifact or add `codecov/codecov-action` step
  - Optional: add coverage badge to README
- **Effort**: 20 minutes
- **Merge likelihood**: **High** -- repo already has coverage config in vitest, just not wired into CI

---

## Notes

- **No red flags**: Maintainer is very active, merges PRs within hours, accepts external contributions readily.
- **Best approach**: Small, focused PRs. The maintainer merged 4 external contributor PRs in the last week.
- **Open `help wanted` issue**: #29 (semantic search) is tagged `help wanted` -- a bigger contribution opportunity but higher effort.
- **Multiple external contributors** already have merged PRs -- low barrier to entry.
- **Repo is only 10 days old** with 49 stars -- growing fast. Early contributions get high visibility.
