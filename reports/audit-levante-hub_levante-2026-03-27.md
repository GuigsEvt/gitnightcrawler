Now I have everything needed. Here's the full report:

---

# Marketing Audit: levante-hub/levante

## Quick Overview

Levante is a cross-platform Electron desktop AI chat application with multi-provider support (OpenRouter, Anthropic, OpenAI, Google, Groq, xAI, Hugging Face, Ollama/local). It emphasizes privacy-first design with local-only storage, encrypted API keys, and full Model Context Protocol (MCP) client integration including an MCP Store. Currently in open beta.

**Tech Stack:** Electron 37 + React 19 + TypeScript 5.9 + Zustand + Vercel AI SDK 6 + shadcn/ui + Tailwind CSS + SQLite (@libsql) + Winston logging + Vitest/Playwright + pnpm

**Activity Level:**
- 614 commits since Jan 2025 (~8/day)
- 32 stars, 12 forks, 26 open issues
- Beta releases every 1-2 days
- 2-3 core maintainers (Oliver Montes, Saul Gomez, Alejandro Gomez)
- PRs merged within days, high merge rate (18/20 recent PRs merged)
- `good first issue` and `help wanted` labels exist

---

## Quick Win PRs

### 1. Documentation Improvements

**README gaps:**
- No badges for CI status, version, or downloads count
- No "Development Setup" section in README (only "download from website" -- devs need to look at CONTRIBUTING.md separately)
- Missing screenshot/GIF of MCP Store feature (major differentiator)
- No "Troubleshooting" or FAQ section
- The `docs/GETTING_STARTED.md` is referenced but README doesn't link directly to it for developers

**Broken/missing links:**
- README links to `levanteapp.com` and Discord but no GitHub Discussions or issue templates
- Several docs are in Spanish (e.g., `diagnostico-auto-connect-mcp.md`, `plan-integracion-logging-oauth.md`) -- inconsistent language

**Missing docs:**
- No API/IPC reference documentation (35+ IPC channels undocumented outside CLAUDE.md)
- No changelog/CHANGELOG.md file

### 2. Code Quality

**`any` type epidemic -- 315+ instances:**
- `src/preload/preload.ts` -- 39 `any` types in the IPC bridge
- `src/main/ipc/mcpHandlers/configuration.ts` -- 15 instances (service params all `any`)
- `src/main/utils/encryption.ts` -- provider params typed as `any`
- `catch (error: any)` pattern used throughout instead of `error: unknown`

**Console methods in production code (18 files):**
- `src/renderer/stores/mcpStore.ts` -- 15+ `console.error` calls (should use Winston)
- `src/renderer/stores/chatStore.ts` -- 4 instances
- `src/renderer/stores/miniChatStore.ts` -- 3 instances

**Silent error catches (6 instances):**
- `src/main/services/widgetProxy.ts:512,522` -- completely empty `catch {}`
- `src/renderer/services/modelService.ts:781` -- `.catch(() => {})`

**@ts-ignore suppressions:**
- `src/main/services/inference/HFInferenceClient.ts` -- 10 instances
- SVG/PNG imports in 4 renderer components (missing asset type declarations)

**TODOs:**
- `src/renderer/components/mcp/config/import-export.tsx:407` -- Phase 4 dropdown
- `src/main/services/runtime/runtimeManager.ts:460` -- size calculation

### 3. Tests

**Current state:** 21 test files, heavy focus on OAuth (8 files). Major gaps:

**Missing test files for core services:**
- `DatabaseService` -- zero tests for the primary data layer
- `PreferencesService` -- zero tests for config management
- `AIService` / chat streaming -- no tests
- `ModelFetchService` -- no provider fetch tests
- `AttachmentStorageService` -- no tests
- Most Zustand stores untested (only `skillsStore` has tests)
- No tests for any IPC handlers

**Infrastructure:**
- CI only runs `typecheck` -- no `pnpm test` or `pnpm lint` in CI pipeline
- No test coverage reporting configured
- No E2E tests in CI

### 4. CI/CD

**Current CI is minimal** -- only typecheck on PR/push:

**Missing:**
- `pnpm lint` step in CI (lint exists locally but not enforced)
- `pnpm test` step in CI (tests exist but never run in CI)
- Test coverage reporting (Codecov/Coveralls)
- No CI badges in README
- No dependency update automation (Dependabot/Renovate)
- No CODEOWNERS file
- No PR template (`.github/pull_request_template.md`)
- No issue templates (`.github/ISSUE_TEMPLATE/`)

### 5. DX Improvements

- `.env.example` exists but is minimal -- missing comments explaining each variable
- No Docker/devcontainer setup (could help onboarding despite being an Electron app)
- No `Makefile` or consolidated dev scripts
- `.nvmrc` says `24.x` but CI uses `22.20.0` -- version mismatch
- `engines` in package.json requires `>=24.0.0` but CI builds on Node 22

---

## Draft PRs

### PR #1: Add lint and test steps to CI

- **PR Title:** `ci: add lint and test steps to CI workflow`
- **Branch:** `ci/add-lint-and-tests`
- **Files to change:** `.github/workflows/ci.yml`
- **Changes:**
  - Add `lint` job: `pnpm lint` step after install
  - Add `test` job: `pnpm test` step after install
  - Keep existing `typecheck` job
  - All three can run in parallel
- **Effort:** 15 minutes
- **Merge likelihood:** **HIGH** -- Tests and lint already exist, just not running in CI. This is a clear oversight. The project has `--max-warnings 0` lint config, showing they care about quality.

### PR #2: Add CI status badge and version badge to README

- **PR Title:** `docs: add CI and version badges to README`
- **Branch:** `docs/readme-badges`
- **Files to change:** `README.md`
- **Changes:**
  - Add GitHub Actions CI badge: `![CI](https://github.com/levante-hub/levante/actions/workflows/ci.yml/badge.svg)`
  - Add GitHub release version badge
  - Add Discord badge with member count (they already have a Discord link)
- **Effort:** 10 minutes
- **Merge likelihood:** **HIGH** -- Zero risk, purely additive, improves repo appearance.

### PR #3: Fix Node.js version mismatch between .nvmrc/package.json and CI

- **PR Title:** `fix: align Node.js version across .nvmrc, package.json, and CI`
- **Branch:** `fix/node-version-alignment`
- **Files to change:** `.nvmrc`, `package.json` (engines field), `.github/workflows/ci.yml`
- **Changes:**
  - `.nvmrc` currently says `24.x`, CI uses `22.20.0`, `package.json` engines require `>=24.0.0`
  - Either update CI to Node 24 (matching package.json) or relax engines constraint
  - Recommend updating CI to match package.json since that's the declared requirement
- **Effort:** 10 minutes
- **Merge likelihood:** **HIGH** -- This is a real bug. Contributors following `.nvmrc` will use Node 24 while CI builds on 22, meaning version-specific features could break silently.

---

## Notes

**Positive signals:**
- Very active project (8 commits/day, beta releases every 1-2 days)
- Clean CONTRIBUTING.md with fork-based workflow
- `good first issue` and `help wanted` labels exist
- Responsive maintainers (PRs merged within days)
- Well-structured codebase with clear architecture

**Red flags:**
- Small team (2-3 people) -- PRs may take a few days to review
- All PRs target `develop` branch, NOT `main` (important for contributors)
- Commons Clause license may deter some contributors
- Some docs in Spanish, which could be a barrier for international contributors
- Heavy reliance on CLAUDE.md (AI-assisted development conventions) -- unusual for open source

**Best approach:**
- Target `develop` branch for all PRs
- Start with CI improvements (PR #1) -- low risk, high value, demonstrates competence
- Follow conventional commit style strictly
- Keep PRs small and focused
- Reference existing issues where possible (e.g., issue #231 for tech debt)
