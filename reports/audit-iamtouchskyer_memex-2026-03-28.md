I have all the data I need. Here's the report:

---

# Marketing Audit: iamtouchskyer/memex

## Quick Overview

Memex is a Zettelkasten-based persistent memory system for AI coding agents. It stores atomic knowledge cards as markdown files with `[[bidirectional links]]` in `~/.memex/cards/`, synced via git. Works as a Claude Code plugin (hooks + skills) and as an MCP server for VS Code/Copilot, Cursor, Codex, Windsurf. No vector DB -- just markdown + git.

- **Tech stack:** TypeScript, Node.js (ESM), Commander.js, Zod, MCP SDK, Vitest, VS Code extension
- **Activity:** ~50 commits since Jan 2025, very active in the last week. 48 stars, 9 forks, 1 open issue, 1 open PR. Maintainer merges community PRs quickly (multiple merged from different contributors in the last few days). **Very receptive to contributions.**

## Quick Win PRs

### 1. Documentation Improvements

- **README missing `CONTRIBUTING.md`** -- no contribution guidelines exist at all. No code of conduct either.
- **README missing badges** -- no npm version badge, no CI status badge, no license badge, no downloads badge. The top of the README goes straight into text.
- **No `doctor` or `migrate` CLI commands documented** -- `src/commands/doctor.ts` and `src/commands/migrate.ts` exist and were recently added (Phase 3) but the CLI reference section in README only lists 8 commands, missing `doctor`, `migrate`, `import`, and `organize`.
- **Missing image** -- `docs/images/graph-view.png` is referenced in README line 82 but the `docs/images/` directory doesn't exist in the repo (only `docs/superpowers/` exists). This is a **broken image**.
- **No API/MCP tool documentation** -- README mentions "10 MCP tools" but never lists what they are. `src/mcp/operations.ts` has all the tool definitions.
- **`--nested` flag undocumented** -- Phase 2 added `--nested` to `read` and `search` but CLI reference doesn't mention it.

### 2. Code Quality

- **`msg: any` in `src/mcp/server.ts:32`** -- explicit `any` type on MCP transport message handler.
- **`share-card.js` is plain JavaScript** -- `src/share-card/share-card.js` is the only non-TS file in `src/`. Could be converted to TypeScript for consistency.
- **Duplicated magic number** -- Hub threshold `10` is hardcoded in both `src/commands/organize.ts:71` and `src/lib/formatter.ts:20`. The formatter defines `const HUB_THRESHOLD = 10` but organize.ts uses a raw `10`.
- **Missing npm keywords** -- `package.json` keywords are `["memory", "zettelkasten", "agent", "cli", "knowledge-management"]`. Missing: `mcp`, `claude`, `ai`, `cursor`, `copilot`, `vscode` -- these would significantly improve discoverability on npm.

### 3. Tests

- **Missing test file for `import` command** -- `src/commands/import.ts` has zero test coverage. Every other command in `src/commands/` has a test file in `tests/commands/`. This is the most obvious gap.
- **Coverage thresholds incomplete** -- `vitest.config.ts` only sets `statements: 70%`. No `branches`, `functions`, or `lines` thresholds.
- **No coverage reporting in CI** -- the GitHub Actions workflow runs `npm test` but doesn't generate or upload coverage reports.

### 4. CI/CD

- **No badges in README** -- CI status, npm version, license, downloads badges are all missing.
- **No npm publish workflow** -- publishing appears manual (`npm run build && npm publish`). A release workflow on tag push would be valuable.
- **No lint/typecheck step in CI** -- the workflow only runs `build` and `test`, but no explicit `tsc --noEmit` typecheck step (build does tsc, but a separate check is standard).
- **Missing Node 18 in CI matrix** -- package says "Node.js 18+" in prerequisites but CI matrix only tests `[20, 22]`.

### 5. DX Improvements

- **No `.nvmrc` file** -- would help contributors use the right Node version.
- **No `engines` field in `package.json`** -- should specify `"node": ">=18"` to match documented requirements.
- **No Dockerfile** -- would simplify MCP server deployment.
- **Broken image reference** -- `docs/images/graph-view.png` doesn't exist, so README renders a broken image for everyone.

## Draft PRs

### PR 1: Add missing test file for import command

- **PR Title:** `test: add unit tests for import command`
- **Branch:** `test/import-command`
- **Files to change:** Create `tests/commands/import.test.ts`
- **Changes:** Test all 4 code paths in `importCommand()`: (1) no source -> lists importers, (2) unknown source -> error, (3) missing source dir -> error, (4) successful import with dry-run and normal mode. Follow the exact pattern used in existing test files like `tests/commands/archive.test.ts` (mock CardStore, use vitest mocks).
- **Effort:** 30-45 min
- **Merge likelihood:** **High** -- every other command has tests, this is a clear gap, and the maintainer recently merged a test coverage PR (#15).

### PR 2: Fix broken image + update CLI reference in README

- **PR Title:** `docs: fix broken graph-view image and update CLI reference`
- **Branch:** `docs/readme-fixes`
- **Files to change:** `README.md`, add `docs/images/graph-view.png` (screenshot needed)
- **Changes:** (1) Either add the missing `docs/images/graph-view.png` or remove the broken `![Graph View]` reference. (2) Add missing commands to CLI reference: `import`, `organize`, `doctor`, `migrate`. (3) Document `--nested` flag on `read` and `search`. (4) Add npm/CI/license badges at top.
- **Effort:** 20-30 min
- **Merge likelihood:** **High** -- fixes a broken image visible to every visitor, and docs PRs have low review friction.

### PR 3: Add npm keywords for discoverability + engines field

- **PR Title:** `chore: improve npm discoverability with keywords and engines field`
- **Branch:** `chore/npm-metadata`
- **Files to change:** `package.json`
- **Changes:** (1) Add keywords: `"mcp"`, `"claude-code"`, `"ai"`, `"cursor"`, `"copilot"`, `"vscode"`, `"markdown"`, `"persistent-memory"`. (2) Add `"engines": { "node": ">=18" }`. (3) Optionally add `.nvmrc` with `20`.
- **Effort:** 5-10 min
- **Merge likelihood:** **High** -- zero risk, pure metadata improvement, directly helps the project get discovered on npm.

## Notes

- **Maintainer is very active** -- merging PRs within hours/days. Multiple external contributors have had PRs merged in the last week. This is an ideal time to contribute.
- **1 open PR (#23)** from `kagura-agent` -- multi-directory search feature. No backlog.
- **1 open issue (#22)** -- usage question, not a bug. Maintainer hasn't responded yet (opened today).
- **Best approach:** Small, focused PRs. The maintainer clearly prefers conventional commit messages. Start with PR #3 (5 min, zero risk) to establish contributor relationship, then follow up with PR #1 and #2.
- **Red flag:** The `docs/images/` directory is referenced but doesn't exist -- this is either a build artifact issue or the image was never committed. Confirm before PRing.
