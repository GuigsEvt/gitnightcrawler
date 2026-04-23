# Marketing Audit: iamtouchskyer/memex

## Quick Overview

Memex is a Zettelkasten-based persistent memory system for AI agents. Markdown cards stored in `~/.memex/cards/` with `[[wikilinks]]`, distributed as CLI + MCP server + Claude Code plugin + VS Code extension + Pi extension. No vector DB required -- just markdown files readable by both agents and humans, with optional semantic search via OpenAI/Local/Ollama embeddings.

- **Tech stack**: TypeScript (strict), ESM, Node16, 4 core deps (commander, gray-matter, zod, @modelcontextprotocol/sdk)
- **Activity**: Very active -- 23 commits in April 2026, last commit 2026-04-22. 7 open issues, 1 open PR.
- **Responsiveness**: External PRs merged within days (e.g., #50, #53). Maintainer is active and receptive.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Severity |
|-------|----------|----------|
| ARCHITECTURE.md shows v0.1.26, should be v0.1.30 | `docs/ARCHITECTURE.md:8` | Low |
| Missing `homepage` field in package.json | `package.json` | Low |
| Missing `bugs` field in package.json | `package.json` | Low |
| Missing `engines` field in package.json (no Node version requirement) | `package.json` | Medium |
| No CHANGELOG.md | Root | Medium |
| VS Code extension README uses absolute GitHub URLs but main README uses relative paths for screenshots -- inconsistent | `README.md`, `vscode-extension/README.md` | Low |
| Missing Pi upgrade instructions in README | `README.md` ~line 210 | Low |

### 2. Code Quality

| Issue | Location | Severity |
|-------|----------|----------|
| No linter configured (no eslint, prettier, or biome) | Root | Medium |
| marketplace.json version v0.1.8, should be v0.1.30 | `.claude-plugin/marketplace.json:12` | High |
| VS Code extension pinned to `^0.1.21` dependency | `vscode-extension/package.json:49` | Medium |
| Stale .vsix build artifacts committed | `vscode-extension/*.vsix` (4 files) | Low |

### 3. Tests

| Issue | Location | Severity |
|-------|----------|----------|
| `src/commands/import.ts` has no test file (45 lines, untested) | Missing `tests/commands/import.test.ts` | Medium |
| No test for the OpenClaw importer edge cases | `src/importers/openclaw.ts` | Low |

### 4. CI/CD

| Issue | Location | Severity |
|-------|----------|----------|
| No badge in README (build status, npm version, coverage) | `README.md` | Medium |
| Release workflow node matrix uses 20/22, test uses 22/24 -- inconsistent | `.github/workflows/publish.yml` vs `test.yml` | Low |
| Issue #45: Release workflow conflicts with branch protection | `.github/workflows/release.yml` | Medium |
| Issue #42: npm auto-publish auth missing | `.github/workflows/publish.yml` | Medium |

### 5. DX Improvements

| Issue | Location | Severity |
|-------|----------|----------|
| No CONTRIBUTING.md (guidelines buried in AGENTS.md) | Root | Medium |
| Issue #68: `serve` fails to open browser on Windows (needs `shell: true`) | `src/commands/serve.ts` | High |
| Issue #67: `sync --init` creates divergent main/master branches | `src/lib/sync.ts` | High |

---

## Draft PRs

### PR 1: Add npm/CI badges and package.json metadata

- **PR Title**: `docs: add badges and missing package.json metadata`
- **Branch**: `docs/badges-and-metadata`
- **Files to change**:
  - `README.md` -- Add shields.io badges (npm version, CI status, license) at top
  - `package.json` -- Add `engines`, `homepage`, `bugs` fields
- **Changes**:
  ```
  // package.json - add after "license" field:
  "engines": { "node": ">=22" },
  "homepage": "https://github.com/iamtouchskyer/memex#readme",
  "bugs": { "url": "https://github.com/iamtouchskyer/memex/issues" },
  
  // README.md - add after title line:
  [![npm](https://img.shields.io/npm/v/@touchskyer/memex)](https://www.npmjs.com/package/@touchskyer/memex)
  [![CI](https://github.com/iamtouchskyer/memex/actions/workflows/test.yml/badge.svg)](https://github.com/iamtouchskyer/memex/actions/workflows/test.yml)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  ```
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- pure additive, zero risk, improves discoverability

### PR 2: Fix stale version references across project

- **PR Title**: `chore: sync version references to 0.1.30`
- **Branch**: `fix/version-sync`
- **Files to change**:
  - `docs/ARCHITECTURE.md:8` -- Update v0.1.26 to v0.1.30
  - `.claude-plugin/marketplace.json:12` -- Update v0.1.8 to v0.1.30
  - `vscode-extension/package.json:5,49` -- Update extension version and dependency
- **Changes**: Simple string replacements of version numbers
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- obvious correctness fix, maintainer already bumped package.json but missed these files

### PR 3: Fix Windows browser open in serve command (Issue #68)

- **PR Title**: `fix: Windows browser auto-open in serve command (#68)`
- **Branch**: `fix/windows-browser-open`
- **Files to change**:
  - `src/commands/serve.ts` -- Add `shell: true` option to `exec`/`execFile` call for the `start` command on Windows
- **Changes**: Note -- PR #66 already exists for this. Could review/improve that PR instead, or submit if #66 is stale.
- **Effort**: 20 minutes (including test)
- **Merge likelihood**: **High** -- fixes a reported issue, simple fix, PR #66 already validates the approach

---

## Notes

- **Maintainer is active and responsive** -- merges external PRs within days. Good candidate for contributions.
- **PR #66 already open** for the Windows browser fix -- check if it needs review help rather than a competing PR.
- **No linter** configured -- adding one could be valuable but is opinionated and may face pushback. Better to ask first.
- **CONTRIBUTING.md missing** -- the instructions exist in AGENTS.md but aren't discoverable by human contributors. A lightweight CONTRIBUTING.md pointing to AGENTS.md would help.
- **Best approach**: Start with PR 1 (badges) or PR 2 (version sync) -- these are zero-controversy, high-visibility, and demonstrate attention to detail. Follow up with a test PR for `import.ts` once trust is established.
- **Red flags**: None significant. Active maintainer, clean codebase, tests pass, CI works.
