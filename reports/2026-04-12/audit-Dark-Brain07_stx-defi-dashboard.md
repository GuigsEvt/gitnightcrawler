Now I have a full picture. Here's the report:

---

# Marketing Audit: Dark-Brain07/stx-defi-dashboard

## Quick Overview

A Next.js 14 DeFi analytics dashboard for the Stacks blockchain, integrating Hiro Chainhooks for real-time on-chain event streaming, DeFiLlama for TVL data, and CoinGecko for price feeds. Tracks protocol TVL rankings (ALEX, Arkadiko, StackingDAO, Velar, Bitflow), wallet portfolios, and network status. The **core functional code is small** (~4 lib modules, ~5 React components, a handful of API routes), but the repo contains **~1,100+ auto-generated filler files** (services, hooks, stores, tests with names like `BnsResolver-3-42.ts`, `VectorMath-5-8.ts`) that are boilerplate stubs with no real logic.

**Tech stack:** Next.js 14, React 18, TypeScript, TailwindCSS, Recharts, @stacks/connect + transactions + network, axios, vitest (unused)

**Activity level:**
- 1,287 commits -- all created within a 12-day window (Mar 30 - Apr 11, 2026), formulaic messages like `feat(clarity): sBTC bridging logic implementation for VectorMath`
- 12 stars, 0 forks, 0 PRs ever, 12 open issues
- Single contributor (no `git shortlog` output = likely default config)
- **Clearly auto-generated commit history and file padding**

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Details |
|-------|---------|
| **README: missing `.env.example`** | README references `CHAINHOOK_API_KEY` and `NEXT_PUBLIC_NETWORK` but no `.env.example` file exists. The env block uses `......` instead of a proper format |
| **README: no test/lint scripts** | No mention of how to run tests, lint, or type-check |
| **README: hardcoded localhost** | Uses `http://localhost:3000` -- should note `http://127.0.0.1:3000` as fallback |
| **API docs skeletal** | `docs/API.md` has 4 one-line endpoint descriptions with zero request/response examples, no status codes, no auth info |
| **CONTRIBUTING.md barebones** | 4 lines, no code style guide, no dev setup instructions, no issue template guidance |
| **LICENSE truncated** | Only contains the first sentence of the MIT license -- missing the full permission/warranty text |

### 2. Code Quality

| Issue | Details |
|-------|---------|
| **Silent `catch {}` blocks** | `defi-protocols.ts:52` and `stacks-api.ts:82` swallow errors silently -- should at least `console.error` |
| **No ESLint config** | No `.eslintrc`, no `eslint` in devDependencies, no lint script |
| **No Prettier config** | Inconsistent formatting (minified config files vs normal code) |
| **`next.config.js` minified** | Single-line unreadable format |
| **`tailwind.config.ts` minified** | Single-line, hard to maintain |
| **`postcss.config.js` minified** | Same issue |
| **Hardcoded data in `page.tsx`** | Dashboard stats are hardcoded (`$142.5M`, `12,847` wallets) instead of fetched from API routes that already exist |
| **`getTotalTVL()` double-fetches** | Calls `fetchTVL()` internally, so calling both in the API route fetches twice |

### 3. Tests

| Issue | Details |
|-------|---------|
| **No `vitest.config.ts`** | vitest is in devDependencies but there's no config file |
| **No `test` script in `package.json`** | Cannot run `npm test` |
| **229 test files are trivial stubs** | All auto-generated tests are either `expect(true).toBe(true)` or basic `toBeDefined()` checks |
| **Zero tests for actual core code** | No tests for `ChainhookManager`, `DeFiProtocols`, `StacksAPI`, `WalletService`, or any React components |
| **No test coverage config** | No coverage thresholds or reports |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **CI is a no-op** | `.github/workflows/ci.yml` runs `npm install` then `echo "Build successful"` -- never runs `next build`, tests, or lint |
| **No type-check step** | `tsc --noEmit` is not in CI |
| **No badges in README** | No CI status badge, license badge, or version badge |
| **No branch protection guidance** | No PR template, no `CODEOWNERS` |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **No `.env.example`** | Developers have no idea what env vars are needed |
| **No Docker setup** | No `Dockerfile` or `docker-compose.yml` |
| **No `npm test` script** | Package.json only has `dev`, `build`, `start` |
| **No `next-env.d.ts`** | Referenced in tsconfig `include` but doesn't exist |

---

## Draft PRs

### PR #1: Fix CI pipeline to actually build and type-check

- **PR Title:** `fix(ci): run actual build and type-check instead of echo`
- **Branch:** `fix/ci-pipeline`
- **Files to change:** `.github/workflows/ci.yml`, `package.json`
- **Changes:**
  - Add `npm run build` step to CI (replace `echo "Build successful"`)
  - Add `"typecheck": "tsc --noEmit"` script to package.json
  - Add `"test": "vitest run"` script to package.json
  - Add `"lint": "next lint"` script + `eslint-config-next` devDep
  - Add type-check and lint steps to CI
  - Add Node 20 caching (`cache: 'npm'`)
- **Effort:** 15 minutes
- **Merge likelihood:** **High** -- CI doing nothing is objectively broken; every maintainer wants a working CI

### PR #2: Add `.env.example` and fix README setup instructions

- **PR Title:** `docs: add .env.example and improve setup instructions`
- **Branch:** `docs/setup-instructions`
- **Files to change:** `.env.example` (new), `README.md`
- **Changes:**
  - Create `.env.example` with documented vars: `CHAINHOOK_API_KEY`, `NEXT_PUBLIC_NETWORK`, `NEXT_PUBLIC_HIRO_API_URL`
  - Fix README env block (replace `......` with proper comment)
  - Add Prerequisites section (Node 20+, npm)
  - Add testing/lint commands section
  - Add CI badge to README top
  - Fix LICENSE to include full MIT text
- **Effort:** 20 minutes
- **Merge likelihood:** **High** -- pure docs improvement, zero risk, fills obvious gap

### PR #3: Add vitest config and real tests for core modules

- **PR Title:** `test: add vitest config and tests for core library modules`
- **Branch:** `test/core-module-tests`
- **Files to change:** `vitest.config.ts` (new), `package.json`, `src/__tests__/lib/chainhooks.test.ts` (new), `src/__tests__/lib/defi-protocols.test.ts` (new), `src/__tests__/lib/stacks-api.test.ts` (new)
- **Changes:**
  - Create `vitest.config.ts` with path aliases matching tsconfig
  - Add `"test": "vitest run"`, `"test:watch": "vitest"` to package.json
  - Write unit tests for `ChainhookManager` (create/remove hooks, getAll)
  - Write unit tests for `DeFiProtocols` (getByCategory, getTopByTVL, mock fetchTVL)
  - Write unit tests for `StacksAPI` (constructor network selection, response mapping)
- **Effort:** 45 minutes
- **Merge likelihood:** **Medium** -- more substantial change but CONTRIBUTING.md explicitly asks for tests

---

## Notes

**Red flags:**
- **This repo is heavily padded with auto-generated content.** 1,287 commits in 12 days, ~1,000+ filler files with formulaic names (`GameEngine-4-31.ts`, `SessionTracker-2-27.ts`), all containing identical boilerplate class stubs. The real functional code is ~15 files.
- Commit messages follow a template pattern: `{type}(clarity): {topic} implementation for {ClassName}` -- clearly scripted
- 12 open issues that also look templated (`feat:`, `fix:`, `perf:` titles with specific feature requests that feel generated)
- **Zero PRs have ever been submitted or merged** -- unknown how the maintainer responds to contributions
- Single contributor with no visible engagement history

**Assessment:** This appears to be a repository inflated for activity metrics (GitHub stars farming, contribution graph padding). The core dashboard code is legitimate but minimal. Contributing here carries **uncertain ROI** -- the maintainer may not review PRs at all given the auto-generated nature of the repo.

**If you still want to contribute:** Start with PR #1 (CI fix) as a litmus test. It's the smallest, most obviously needed change. If it gets reviewed within a week, proceed with #2 and #3. If no response, move on.
