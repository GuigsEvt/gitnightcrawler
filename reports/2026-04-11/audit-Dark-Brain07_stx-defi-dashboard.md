# Marketing Audit: Dark-Brain07/stx-defi-dashboard

## Quick Overview

Real-time DeFi analytics dashboard for the Stacks blockchain, powered by Hiro Chainhooks. Tracks TVL, protocol rankings, wallet portfolios, and on-chain activity via CoinGecko and DeFiLlama APIs. Frontend is Next.js 14 + React 18 + TailwindCSS + Recharts with Clarity smart contracts.

**Tech stack:** Next.js 14, React 18, TypeScript 5.3, TailwindCSS 3.4, Recharts, Vitest, @stacks/connect, Clarity

**Activity level:** 1,037 commits in ~11 days (Mar 30 - Apr 10, 2026) -- heavily AI-generated. 12 stars, 0 forks, 12 open issues, 0 PRs ever submitted. Maintainer appears active (issues were filed recently). Zero community contributions so far -- first-mover advantage.

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Severity |
|-------|----------|----------|
| README lacks setup prerequisites (Node version, npm) | `README.md` | Medium |
| No `.env.example` -- `CHAINHOOK_API_KEY` and `NEXT_PUBLIC_NETWORK` referenced but undocumented | Root | High |
| `CONTRIBUTING.md` is 7 lines of boilerplate, no real guidance | `CONTRIBUTING.md` | Medium |
| `docs/API.md` is 13 lines -- just an endpoint list, no request/response examples | `docs/API.md` | Medium |
| `CHANGELOG.md` has single entry, no semver structure | `CHANGELOG.md` | Low |
| `LICENSE` is truncated / incomplete MIT text | `LICENSE` | Low |
| No architecture diagram or data flow explanation | Missing | Medium |

### 2. Code Quality

| Issue | Location | Severity |
|-------|----------|----------|
| **404 numbered duplicate files** (43% of codebase) -- AI-generated stubs like `WalletManager-1-2.ts` | `src/hooks/`, `src/services/`, `src/stores/`, `src/utils/`, `src/components/` | Critical |
| Silent error swallowing in API clients (returns zeroes) | `src/lib/stacks-api.ts`, `src/lib/defi-protocols.ts` | High |
| No input validation on any API route | `src/app/api/` (14 routes) | High |
| Missing error boundaries in React pages | `src/app/` pages | Medium |
| Typo: "Intializing" in all generated files | All numbered files | Low |
| 91 Clarity contracts with no TypeScript bindings | `contracts/lib/` | Medium |

### 3. Tests

| Issue | Location | Severity |
|-------|----------|----------|
| All 527 test files are empty stubs (`expect(true).toBe(true)`) | `src/__tests__/` | Critical |
| No real tests for `stacks-api.ts`, `defi-protocols.ts`, `chainhooks.ts`, `wallet.ts` | Missing | High |
| No API route tests | Missing | High |
| No component rendering tests | Missing | Medium |
| Vitest configured but never meaningfully used | `package.json` | Medium |

### 4. CI/CD

| Issue | Location | Severity |
|-------|----------|----------|
| CI runs `echo "Build successful"` instead of `npm run build` | `.github/workflows/ci.yml` | Critical |
| No TypeScript type-checking step | `.github/workflows/ci.yml` | High |
| No test execution in CI | `.github/workflows/ci.yml` | High |
| No linting step | `.github/workflows/ci.yml` | Medium |
| No badges in README (build status, license, etc.) | `README.md` | Low |
| **Build will fail anyway** -- `plain-crypto-js@4.2.1` is a known supply chain attack package (issues #11, #13) | `package-lock.json` | Critical |

### 5. DX Improvements

| Issue | Location | Severity |
|-------|----------|----------|
| No `.env.example` template | Missing | High |
| No Docker/docker-compose setup | Missing | Medium |
| No `npm run lint` script in package.json | `package.json` | Medium |
| All feature pages show hardcoded `"--"` placeholders | `src/app/` pages | Medium |
| No pre-commit hooks or formatting config (prettier/eslint) | Missing | Medium |

---

## Draft PRs

### PR #1: Remove `plain-crypto-js` supply chain attack from lockfile

- **PR Title:** `fix(security): remove compromised plain-crypto-js from lockfile`
- **Branch:** `fix/remove-plain-crypto-js`
- **Files to change:** `package-lock.json`
- **Changes:** Run `npm audit`, identify how `plain-crypto-js` entered the dependency tree (likely a compromised transitive dependency of axios or similar). Remove it from `package-lock.json`. If it's a direct dependency, remove from `package.json` too. Regenerate lockfile with `npm install`. Reference issues #11 and #13.
- **Effort:** 15-30 minutes
- **Merge likelihood:** **HIGH** -- Two open issues (#11, #13) already flagging this. Maintainer is clearly aware and would welcome the fix. Security fixes get merged fast.

### PR #2: Fix CI pipeline to actually build and type-check

- **PR Title:** `ci: add real build, typecheck and test steps to CI pipeline`
- **Branch:** `fix/ci-pipeline`
- **Files to change:** `.github/workflows/ci.yml`
- **Changes:** Replace `echo "Build successful"` with actual steps: `npx tsc --noEmit` (typecheck), `npm run build` (Next.js build), `npx vitest run` (tests). Add Node caching. Add a build status badge to README.
- **Effort:** 20-30 minutes
- **Merge likelihood:** **HIGH** -- Current CI is a no-op. Any maintainer would want real checks. Non-controversial, purely additive.

### PR #3: Add `.env.example` and improve setup documentation

- **PR Title:** `docs: add .env.example and improve setup instructions`
- **Branch:** `docs/setup-instructions`
- **Files to change:** `.env.example` (new), `README.md`, `docs/API.md`
- **Changes:** Create `.env.example` with documented variables (`CHAINHOOK_API_KEY`, `NEXT_PUBLIC_NETWORK=mainnet`). Expand README with prerequisites (Node 20+, npm), step-by-step setup, and environment variable descriptions. Expand `docs/API.md` with example request/response payloads for each endpoint.
- **Effort:** 30-45 minutes
- **Merge likelihood:** **HIGH** -- Zero barrier to entry, purely additive docs improvement. First thing any new contributor or user needs.

---

## Notes

**Red flags:**
- Codebase is heavily AI-generated -- 1,037 commits in 11 days, 404 duplicate numbered files, all tests are stubs. This is a scaffolded/padded repository, not organic development.
- 12 stars but 0 forks and 0 PRs ever -- unclear if maintainer is actively seeking contributions or just farming GitHub activity.
- The `plain-crypto-js` supply chain issue (issues #11, #13) suggests the lockfile may have been generated with a compromised npm state or the dependency was injected.
- All feature pages are empty placeholders with hardcoded `"--"` values -- the app doesn't actually work.

**Best approach:**
- PR #1 (security fix) is the highest-signal contribution -- addresses two open issues, is clearly needed, and demonstrates competence.
- PR #2 (CI) and PR #3 (docs) are safe bets as they're non-controversial and additive.
- Keep PR descriptions professional and reference existing issues where applicable.
- Submit one PR at a time, starting with the security fix. Wait for maintainer response before submitting more to gauge responsiveness.
