

# Marketing Audit: pento/claudaborative-editing

## Quick Overview

MCP server that enables Claude Code to collaboratively edit WordPress posts in real time alongside human editors in the Gutenberg block editor, using the Yjs CRDT protocol for conflict-free merging. Includes a companion WordPress plugin that adds AI action controls (proofread, review, translate) directly in the Gutenberg editor UI.

**Tech stack:** TypeScript, Node.js, Yjs CRDT, MCP SDK, WordPress REST API, React (@wordpress/scripts), PHP, Vitest, Playwright, Jest, PHPUnit

**Activity level:** Very active -- 49 commits since Jan 2025, ~4-5 commits/week in March-April 2026. PRs are merged within hours/days. Maintainer (pento, a WordPress core committer) is highly responsive. Currently 2 open PRs (#64, #65), 8 open issues. Conventional commit style enforced.

---

## Quick Win PRs

### 1. Documentation Improvements

| Opportunity | Details |
|---|---|
| **README missing tools** | README documents ~25 tools but is missing 7: `wp_edit_block_text`, `wp_insert_inner_block`, `wp_close_post`, `wp_block_types`, `wp_upload_media`, notes tools (`wp_list_notes`, `wp_add_note`, `wp_reply_to_note`, `wp_resolve_note`, `wp_update_note`, `wp_update_note`), and `wp_update_command_status`. These are all documented in CLAUDE.md but not in README. |
| **README missing plugin section** | Issue #42 explicitly requests: "Update the root README.md: Mention the WordPress plugin and its purpose, link to plugin's readme." Currently no mention of the companion plugin in the root README. |
| **No CONTRIBUTING.md** | No contributing guide exists. Standard for open-source projects to have one. |
| **No README badges** | No CI status, npm version, or license badges. Every similar MCP project has these. |
| **Missing `homepage` and `bugs` in package.json** | `homepage` and `bugs` fields are empty -- npm listing will lack links. |

### 2. Code Quality

| Opportunity | Details |
|---|---|
| **Already excellent** | TypeScript strict mode, zero lint warnings, zero TODO/FIXME comments, comprehensive ESLint config. Very little to improve here. |
| **`.serena/` in git status** | The `.serena/` directory (AI tool cache) is untracked but not in `.gitignore`. Should be added. |

### 3. Tests

| Opportunity | Details |
|---|---|
| **94.6% coverage -- strong** | 977 tests passing. The gaps are mostly in `src/index.ts` (CLI entry, 0%) and edge cases in `session-manager.ts` (91%). |
| **src/index.ts untested** | CLI entry point at 0% coverage. Could add tests for `--version`, `--help` flag parsing. |

### 4. CI/CD

| Opportunity | Details |
|---|---|
| **No badges in README** | CI passes on Node 20/22/24 matrix but there's no badge showing this. |
| **No Dependabot/Renovate** | No automated dependency update config. Adding `dependabot.yml` for npm + composer would be a quick win. |

### 5. DX Improvements

| Opportunity | Details |
|---|---|
| **No CONTRIBUTING.md** | New contributors have no guidance on how to set up the dev environment, run tests, or submit PRs. |
| **Plugin README sparse** | `wordpress-plugin/README.md` lacks installation instructions for end users (only has dev setup), FAQ, and screenshots -- directly requested in issue #42. |

---

## Draft PRs

### PR 1: Add missing tools to README + mention WordPress plugin

- **PR Title:** `docs: add missing MCP tools and WordPress plugin section to README`
- **Branch:** `docs/readme-completeness`
- **Files to change:** `README.md`
- **Changes:**
  - Add badges at top: CI status (`![Build](https://github.com/pento/claudaborative-editing/actions/workflows/ci.yml/badge.svg)`), npm version (`![npm](https://img.shields.io/npm/v/claudaborative-editing)`), license (`![License](https://img.shields.io/github/license/pento/claudaborative-editing)`)
  - Add "Editing" section with `wp_edit_block_text` and `wp_insert_inner_block`
  - Add `wp_close_post` to Posts table
  - Add `wp_block_types` to a new "Block Types" section
  - Add "Media" section with `wp_upload_media`
  - Add "Notes" section with all 5 note tools
  - Add "Commands" section with `wp_update_command_status`
  - Add "WordPress Plugin" section referencing `wordpress-plugin/` and linking to its README
- **Effort:** 30-45 minutes
- **Merge likelihood:** **High** -- directly addresses open issue #42, purely additive, maintainer has explicitly requested this work

### PR 2: Add CONTRIBUTING.md

- **PR Title:** `docs: add contributing guide`
- **Branch:** `docs/contributing`
- **Files to change:** `CONTRIBUTING.md` (new file)
- **Changes:**
  - Prerequisites (Node 20+, npm, Docker for e2e)
  - Dev setup (`npm install`, `npm run dev`)
  - Build/test/lint commands (reference existing scripts)
  - PR guidelines (conventional commits, run `npm run lint` and `npm test` before submitting)
  - WordPress plugin development section (separate `npm install`, `composer install`, build commands)
  - Link to issue #42 for documentation work and other open issues
- **Effort:** 20-30 minutes
- **Merge likelihood:** **High** -- standard open-source practice, no code changes, low review burden

### PR 3: Add Dependabot configuration + .gitignore cleanup

- **PR Title:** `chore: add Dependabot config and gitignore .serena directory`
- **Branch:** `chore/dependabot-gitignore`
- **Files to change:** `.github/dependabot.yml` (new), `.gitignore`
- **Changes:**
  - Create `.github/dependabot.yml` with npm + composer ecosystems, weekly schedule, grouped updates
  - Add `.serena/` to `.gitignore`
- **Effort:** 10-15 minutes
- **Merge likelihood:** **Medium-High** -- Dependabot is standard practice, `.serena/` cleanup is obvious. Maintainer may have preferences on update frequency.

---

## Notes

- **No red flags.** Maintainer (pento) is a WordPress core committer, actively merging PRs (3 merged in last 48 hours). Very responsive.
- **Issue #42 is the golden ticket.** It's an open documentation issue filed by the maintainer with explicit acceptance criteria. A PR addressing any part of it will almost certainly be welcomed.
- **PR #64 is open** (shared command definitions refactor) -- avoid overlapping with that work.
- **Best approach:** Start with PR 1 (README completeness) as it directly addresses issue #42 with zero risk. Reference the issue in the PR description. Keep the PR focused -- don't try to do everything in #42 at once.
- **Code quality is exceptional** -- don't try to "improve" code patterns, the maintainer clearly has strong opinions and enforces them via strict linting + CI. Stick to documentation and infrastructure contributions.
