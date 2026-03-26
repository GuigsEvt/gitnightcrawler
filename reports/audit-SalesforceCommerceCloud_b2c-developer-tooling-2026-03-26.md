Now I have all the data. Here's the full report:

---

# Marketing Audit: SalesforceCommerceCloud/b2c-developer-tooling

## Quick Overview

A professional monorepo providing developer tooling for Salesforce B2C Commerce Cloud. It includes a CLI (`@salesforce/b2c-cli`), a TypeScript SDK (`@salesforce/b2c-tooling-sdk`), an MCP server for AI assistants (`@salesforce/b2c-dx-mcp`), a VS Code extension, and Managed Runtime utilities. It replaces the older `sfcc-ci` tool.

- **Tech stack**: TypeScript, Node.js (ESM), oclif (CLI), pnpm monorepo, Mocha/Chai/MSW (tests), VitePress (docs), Changesets (versioning)
- **Activity level**: **Very active** -- 80 commits in 2026, ~10/week. PRs merge within hours to 1 day. 288 PRs total, 7 open issues. Salesforce-sponsored with CLA requirement.

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Location | Details |
|------|----------|---------|
| **Missing README for plugin-example-config** | `packages/b2c-plugin-example-config/` | No README.md exists at all. Package published to npm without any documentation. |
| **Missing npm badges on sub-packages** | `packages/b2c-dx-mcp/README.md`, `packages/mrt-utilities/README.md` | No npm version/download badges. `b2c-cli/README.md` has oclif badge but no npm version badge. |
| **Root README missing badges** | `README.md` | Only has CI badge. Missing: license badge, npm version badges for packages. |
| **VS Code extension README minimal** | `packages/b2c-vs-extension/README.md` | Missing license section, thin compared to other packages. |
| **Missing `bugs`/`homepage` in package.json** | `packages/b2c-plugin-example-config/package.json`, `packages/mrt-utilities/package.json` | Missing standard npm metadata fields. |

### 2. Code Quality

| Item | Location | Details |
|------|----------|---------|
| **Debug console.log in VS Code extension** | `packages/b2c-vs-extension/src/content-tree/content-fs-provider.ts:162` | `console.log` for debug archive path, should use logger |
| **8 console.log statements in mrt proxy** | `packages/mrt-utilities/src/utils/ssr-proxying.ts` lines 597, 691, 702, 707, 729, 733, 756, 902 | Debug logging using console.log instead of proper logger |
| **`any` type with eslint-disable** | `packages/b2c-cli/src/commands/sandbox/ips.ts:53` | `response?: any` with explicit eslint-disable comment |
| **CLI commands using console.log** | `packages/b2c-cli/src/commands/sandbox/realm/list.ts`, `sandbox/ips.ts`, `sandbox/realm/usage.ts` | Should use `this.log()` per oclif convention |

### 3. Tests

| Item | Details |
|------|---------|
| **mrt-utilities index files untested** | `src/middleware/index.ts`, `src/streaming/index.ts`, `src/metrics/index.ts` have no corresponding test files |
| **SDK coverage at 58%** | 173 source files vs 101 test files -- 72 files with no tests |
| **MCP coverage at 59%** | 46 source files vs 27 test files |
| **CLI command tests sparse** | ~21 commands but only ~10 have unit tests |
| **Coverage threshold at 5%** | SDK package enforces only 5% minimum -- could be raised incrementally |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No npm version badges in workflows** | Could add package version badges to CI summary |
| **Missing CodeQL / security scanning** | No SAST workflow despite being a Salesforce project. Could add `github/codeql-action` |
| **No Dependabot (using Renovate)** | Already handled but Renovate config could be verified for completeness |

### 5. DX Improvements

| Item | Location | Details |
|------|----------|---------|
| **`.vscodeignore.bak` backup file** | `packages/b2c-vs-extension/.vscodeignore.bak` | Orphaned backup file in repo |
| **Generic error messages** | Various | Some error paths could have more specific user-facing messages |

---

## Draft PRs

### PR #1: Add README and npm metadata to plugin-example-config

- **PR Title**: `docs: add README and npm metadata to b2c-plugin-example-config`
- **Branch**: `docs/plugin-example-readme`
- **Files to change**:
  - `packages/b2c-plugin-example-config/README.md` (create)
  - `packages/b2c-plugin-example-config/package.json` (add `bugs`, `homepage`)
- **Changes**: Create a README with package description, installation, usage example (reference the existing `extending.md` guide), and license. Add `bugs` and `homepage` fields pointing to GitHub.
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- pure documentation, no code risk, fills obvious gap for an npm-published package

### PR #2: Add npm version badges to package READMEs

- **PR Title**: `docs: add npm version badges to package READMEs`
- **Branch**: `docs/npm-badges`
- **Files to change**:
  - `README.md` (add license badge)
  - `packages/b2c-dx-mcp/README.md` (add npm version badge)
  - `packages/mrt-utilities/README.md` (add npm version badge)
  - `packages/b2c-cli/README.md` (add npm version badge)
- **Changes**: Add shields.io badges for npm version. Example: `[![npm](https://img.shields.io/npm/v/@salesforce/b2c-dx-mcp)](https://www.npmjs.com/package/@salesforce/b2c-dx-mcp)`. Add Apache-2.0 license badge to root README.
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- cosmetic, standard practice for npm packages, improves discoverability

### PR #3: Replace console.log with proper logging in mrt-utilities

- **PR Title**: `fix: replace console.log with proper logger in ssr-proxying`
- **Branch**: `fix/mrt-proxy-logging`
- **Files to change**:
  - `packages/mrt-utilities/src/utils/ssr-proxying.ts` (8 console.log calls)
- **Changes**: Replace 8 `console.log` calls (lines 597, 691, 702, 707, 729, 733, 756, 902) with the project's logging utility. These are already guarded by `if (logging)` conditionals, so just need to swap `console.log` to the appropriate logger method.
- **Effort**: 20 minutes
- **Merge likelihood**: **Medium-High** -- code quality improvement, small blast radius, but need to verify the project's preferred logging pattern for mrt-utilities. Check if a logger is already available in that package.

---

## Notes

- **No red flags**. Maintainers are responsive (PRs merge same-day). Active Salesforce-sponsored project with clear governance.
- **CLA required**. Must sign Salesforce CLA before any PR can merge. Do this first.
- **3pl-guard workflow**. Adding new dependencies triggers a manual review workflow -- avoid PRs that add deps.
- **Changeset required**. Non-trivial changes need a changeset file. Doc-only changes may not.
- **Best approach**: Start with PR #1 or #2 (pure docs, no CLA friction for review). Reference the CONTRIBUTING.md guidelines. Keep PRs atomic.
- **Open issues to claim**: Issue #148 ("sfcc-ci Migration Guide Page") was recently addressed in PR #272 -- check if it can be closed. Issue #153 ("Easy setup for eCDN Code Deployment Certificates") is tagged `enhancement` and could be a good medium-effort contribution.
