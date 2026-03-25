# Marketing Audit: SalesforceCommerceCloud/b2c-developer-tooling

## Quick Overview

A Salesforce-maintained TypeScript monorepo providing developer tooling for Agentforce Commerce B2C, including a CLI (`@salesforce/b2c-cli`), an MCP server (`@salesforce/b2c-dx-mcp`), a core SDK (`@salesforce/b2c-tooling-sdk`), a VS Code extension, and MRT utilities. Covers OAuth, WebDAV, SCAPI integration, sandbox lifecycle management, Page Designer content validation, and more.

- **Tech stack**: TypeScript, pnpm monorepo, oclif (CLI), MCP SDK, Mocha/Chai/MSW (tests), VitePress (docs), Changesets (versioning), GitHub Actions (CI/CD)
- **Activity level**: 77 commits since Jan 2025, last commit Mar 25 2026. ~1-2 commits/day. 33 stars, 10 forks. 7 open issues (all enhancement requests). 2 open PRs. Primarily driven by one core contributor (Charles Lavery, ~50% of commits).

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **Missing root CHANGELOG** | No aggregated CHANGELOG.md at repo root -- each package has its own but there's no summary view |
| **No architecture diagram** | README lacks a high-level architecture/package relationship diagram |
| **Missing troubleshooting guide** | Docs site has no troubleshooting section for common errors |
| **Open issue #148** | "sfcc-ci Migration Guide Page" -- maintainers explicitly want this |
| **mrt-utilities missing metadata** | `packages/mrt-utilities/package.json` lacks `bugs` and `homepage` fields |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **`any` type in production code** | ~120 instances of `as any` / `: any` in non-test files. Key files: `packages/b2c-cli/src/commands/slas/client/create.ts`, `packages/b2c-cli/src/commands/sandbox/realm/update.ts` |
| **Missing JSDoc on exported APIs** | `packages/b2c-tooling-sdk/src/clients/**`, `packages/b2c-dx-mcp/src/tools/**` lack documentation for public functions |
| **52 eslint-disable comments** | While justified, some could be resolved properly (e.g., `no-await-in-loop` with `Promise.allSettled`) |

### 3. Tests

| Issue | Details |
|-------|---------|
| **SDK coverage threshold at 5%** | `packages/b2c-tooling-sdk/package.json` has `c8 --check-coverage --lines 5` -- extremely low bar |
| **Test `any` proliferation** | 1,645+ `any` casts in test files -- typed mocks would improve confidence |
| **Missing edge case tests** | Error path testing for OAuth flows, timeout handling, and network failures appears thin |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **No dependency caching badge** | README lacks CI status badge, coverage badge, or npm version badges |
| **No CodeQL/security scanning** | GitHub Advanced Security / CodeQL workflow not present |
| **Coverage not published** | c8 coverage reports generated but not uploaded to Codecov/Coveralls |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **No Docker/devcontainer** | Missing `.devcontainer/` for GitHub Codespaces / containerized dev |
| **No `.nvmrc`** | Node version requirement (>=22.16.0) not captured in `.nvmrc` or `.node-version` |
| **Issue #153** | "Easy setup for eCDN Code Deployment Certificates" -- maintainers want this |

---

## Draft PRs

### PR 1: Add CI status and npm version badges to README

- **PR Title**: `docs: add CI status and npm version badges to README`
- **Branch**: `docs/readme-badges`
- **Files to change**: `README.md`
- **Changes**: Add at top of README after the title:
  ```markdown
  [![CI](https://github.com/SalesforceCommerceCloud/b2c-developer-tooling/actions/workflows/ci.yml/badge.svg)](https://github.com/SalesforceCommerceCloud/b2c-developer-tooling/actions/workflows/ci.yml)
  [![npm @salesforce/b2c-cli](https://img.shields.io/npm/v/@salesforce/b2c-cli)](https://www.npmjs.com/package/@salesforce/b2c-cli)
  [![npm @salesforce/b2c-tooling-sdk](https://img.shields.io/npm/v/@salesforce/b2c-tooling-sdk)](https://www.npmjs.com/package/@salesforce/b2c-tooling-sdk)
  [![npm @salesforce/b2c-dx-mcp](https://img.shields.io/npm/v/@salesforce/b2c-dx-mcp)](https://www.npmjs.com/package/@salesforce/b2c-dx-mcp)
  ```
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- pure docs, zero risk, improves project visibility

### PR 2: Add `.nvmrc` and `.node-version` files

- **PR Title**: `chore: add .nvmrc for consistent Node.js version`
- **Branch**: `chore/add-nvmrc`
- **Files to change**: `.nvmrc` (new), optionally `.node-version` (new)
- **Changes**: Create `.nvmrc` containing `22` (matching the `>=22.16.0` engine requirement in root package.json). This enables `nvm use` / `fnm use` to auto-switch.
- **Effort**: 5 minutes
- **Merge likelihood**: **High** -- standard practice, no code changes, improves onboarding DX

### PR 3: Raise SDK test coverage threshold

- **PR Title**: `chore(sdk): raise minimum test coverage threshold from 5% to 50%`
- **Branch**: `chore/raise-coverage-threshold`
- **Files to change**: `packages/b2c-tooling-sdk/package.json`
- **Changes**: In the `test` script, change `--lines 5` to `--lines 50` (or whatever the current actual coverage is, minus a small margin). Verify current coverage first with `pnpm --filter @salesforce/b2c-tooling-sdk coverage` and set threshold ~5% below actual.
- **Effort**: 15 minutes (run coverage, pick threshold, update)
- **Merge likelihood**: **Medium-High** -- maintainers clearly care about quality (strict TS, 12 CI workflows); a 5% threshold is likely a leftover from early development. Should verify actual coverage first and propose a reasonable number.

---

## Notes

- **Contributor License Agreement**: Salesforce requires a CLA for all external PRs via https://cla.salesforce.com/sign-cla. Sign before submitting.
- **Changesets required**: Any user-facing change needs a changeset (`pnpm changeset`). Docs-only or chore PRs may not need one.
- **Single dominant maintainer**: Charles Lavery handles ~50% of commits and likely reviews most PRs. PRs are merged reasonably quickly (no backlog visible).
- **Corporate repo**: This is Salesforce-sponsored. Only employees have admin rights. External contributions are welcome but may have slower review cycles than community projects.
- **Best approach**: Start with the badges PR (PR 1) -- it's the lowest friction entry point. Follow with `.nvmrc` (PR 2). Both are zero-risk and demonstrate good faith before proposing code changes.
- **Open enhancement issues (#148, #149, #153, #193, #194)** are all fair game for larger contributions if you want to go beyond quick wins.
