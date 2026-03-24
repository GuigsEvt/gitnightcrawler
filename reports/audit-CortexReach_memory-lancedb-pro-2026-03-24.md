Now I have all the data I need. Here's the audit report:

---

# Audit: CortexReach/memory-lancedb-pro

## Repository Overview

Memory LanceDB Pro is an OpenClaw plugin providing LLM-powered long-term memory backed by LanceDB. It features hybrid retrieval (vector + BM25), cross-encoder reranking (Jina, Voyage, Pinecone, TEI, DashScope, SiliconFlow), multi-scope isolation, smart 6-category extraction (profile, preferences, entities, events, cases, patterns), Weibull decay lifecycle, tiered memory management (core/working/peripheral), admission control governance, session reflection, and a CLI for memory administration. Supports OpenAI, Gemini, Jina, Ollama, and any OpenAI-compatible embedding provider.

**Tech stack:** TypeScript (ESM), Node.js, LanceDB (embedded vector DB), Apache Arrow, OpenAI SDK, proper-lockfile, JSON5, Commander (CLI). No build step -- runs via `jiti` transpilation.

**Maturity:** Growing. v1.1.0-beta.10, active development with 42 test files, CI pipeline, multi-language README (8 languages), CHANGELOG, detailed plugin manifest schema. Feature-rich but still in beta.

## Code Quality Assessment

### Architecture and Organization
- **Good modular structure:** 36 source files in `src/` with clear separation (store, embedder, retriever, scopes, migration, tools, smart-extractor, decay, tiers, admission-control, reflection, OAuth).
- **Main entry point is massive:** `index.ts` at 3,744 lines acts as both plugin registration and orchestration. Should be split.
- `cli.ts` (1,349 lines) and `src/tools.ts` (~67KB) are also oversized.
- Clean import graph with no circular dependencies detected.
- Configuration schema in `openclaw.plugin.json` is extremely thorough (1,200 lines).

### Error Handling Patterns
- **Strong overall.** Descriptive error messages with context, `{ cause: err }` pattern for error chaining.
- Graceful degradation: rerank API timeout falls back to cosine similarity.
- **Weakness:** Silent `catch {}` blocks in JSON parsing (smart-metadata.ts, access-tracker.ts) suppress errors without logging.
- Path validation includes symlink resolution, permission checks, and dangling symlink detection.

### Test Coverage
- **42 test files** covering unit, integration, regression, and E2E.
- Tests use Node.js built-in test runner (`node --test`) and raw assertion scripts.
- Good regression tests (CJK recursion, rerank regression, plugin manifest consistency).
- Test script in `package.json` is a single 2,000-char chain of `&&` commands -- fragile.
- **Gap:** No tests for admission-control scoring logic, no tests for the OAuth token refresh flow, no tests for the massive `index.ts` plugin lifecycle.

### Documentation Quality
- README in 8 languages (EN, JA, CN, KO, ES, FR, IT, PT-BR, RU, TW).
- Detailed architecture doc (`docs/memory_architecture_analysis.md`), OpenClaw integration playbook, long-context chunking guide.
- CHANGELOG maintained.
- **Gap:** No inline JSDoc on exported functions. No API reference. No contributor guide.

### Dependency Health
- 6 runtime deps, 3 devDeps -- minimal footprint.
- `@lancedb/lancedb ^0.26.2` -- active project.
- `openai ^6.21.0` -- current.
- `apache-arrow 18.1.0` -- pinned exact, could lag.
- `proper-lockfile ^4.1.2` -- mature, stable.
- `commander` is a devDependency but imported in `cli.ts` which ships as part of the plugin -- potential runtime issue if not bundled.

## Security Findings

### Medium: Inconsistent SQL Escaping in `delete()` (store.ts:695,728)
**Rating: Medium**

The `delete()` method constructs LanceDB filter queries with unescaped `id` values:
```typescript
.where(`id = '${id}'`)         // line 695
.delete(`id = '${resolvedId}'`) // line 728
```
While the UUID regex validation (`/^[0-9a-f]{8}-...-[0-9a-f]{12}$/i`) restricts input to hex chars and dashes (making injection practically impossible), the `getById()` method at line 868 correctly uses `escapeSqlLiteral()`. This inconsistency could become a real vulnerability if the validation logic changes.

### Low: Unrestricted Environment Variable Resolution (index.ts:212-220)
**Rating: Low**

`resolveEnvVars()` allows `${ANY_VAR}` syntax in config values, resolving arbitrary process environment variables. Since config is loaded from the OpenClaw host (not direct user input), the attack surface is limited to config file manipulation. Still, a whitelist approach would be safer.

### Low: OAuth Error Response in Exception Messages (llm-oauth.ts)
**Rating: Low**

OAuth provider error responses (up to 500 chars) are included in thrown Error messages. If a provider returns tokens in error bodies, they could appear in logs.

### Info: Full process.env Propagation to Child Processes (index.ts:523)
**Rating: Info**

Spawned CLI processes inherit all environment variables. Standard Node.js practice, but worth noting for security-conscious deployments.

### Info: No Content Sanitization on Memory Storage
**Rating: Info**

Memory text content is stored as-is without sanitization. If a downstream consumer renders memories as HTML, XSS is possible. Not a vulnerability in this plugin itself, but a concern for integrators.

### Info: No Dependency Vulnerability Scanning in CI
**Rating: Info**

The CI pipeline runs version sync check and tests but does not run `npm audit` or any SAST tool.

## Contribution Opportunities

### Bugs

1. **`commander` as devDependency but required at runtime**
   - File: `package.json:46`, `cli.ts:5`
   - Issue: `commander` is in `devDependencies` but imported by `cli.ts` which is part of the shipped plugin. If installed with `--production`, CLI commands will fail.
   - Fix: Move `commander` to `dependencies`.
   - Effort: trivial
   - PR-worthy: high

2. **Inconsistent SQL escaping in `delete()`**
   - File: `src/store.ts:695,728`
   - Issue: `id` and `resolvedId` not passed through `escapeSqlLiteral()` unlike other query methods.
   - Fix: Apply `escapeSqlLiteral()` to both values.
   - Effort: trivial
   - PR-worthy: high

### Security Fixes

3. **Add `npm audit` to CI pipeline**
   - File: `.github/workflows/ci.yml`
   - Issue: No dependency vulnerability scanning.
   - Fix: Add `npm audit --audit-level=high` step.
   - Effort: trivial
   - PR-worthy: medium

4. **Whitelist allowed env vars in `resolveEnvVars()`**
   - File: `index.ts:212-220`
   - Issue: Arbitrary env var resolution.
   - Fix: Accept only vars matching a known prefix pattern (e.g., `OPENAI_`, `GROQ_`, `MEMORY_PRO_`, `OPENCLAW_`).
   - Effort: small
   - PR-worthy: medium

### Missing Tests

5. **No tests for admission-control scoring**
   - File: `src/admission-control.ts` (entire file, ~500 lines)
   - Issue: Complex scoring logic (weighted features, type priors, recency decay) with zero test coverage.
   - Fix: Add unit tests for `scoreCandidate()`, preset resolution, weight normalization.
   - Effort: medium
   - PR-worthy: high

6. **No tests for `index.ts` plugin lifecycle**
   - File: `index.ts` (3,744 lines)
   - Issue: The core plugin registration, config resolution, hook wiring, and autoCapture/autoRecall logic have no dedicated tests.
   - Fix: Extract testable functions and add unit tests.
   - Effort: large
   - PR-worthy: high

7. **No tests for OAuth token refresh flow**
   - File: `src/llm-oauth.ts`
   - Issue: Token refresh, expiry handling, and PKCE flow untested.
   - Fix: Add tests with mock HTTP server.
   - Effort: medium
   - PR-worthy: medium

### Documentation Gaps

8. **No JSDoc on exported functions**
   - File: All `src/*.ts` files
   - Issue: Public API surface has no documentation. Consumers must read source.
   - Fix: Add JSDoc to all exported types, functions, and classes.
   - Effort: medium
   - PR-worthy: medium

9. **No CONTRIBUTING.md**
   - Issue: No contributor guide, development setup instructions, or PR guidelines.
   - Fix: Add standard contributing guide.
   - Effort: small
   - PR-worthy: low

### Code Improvements

10. **Split `index.ts` (3,744 lines) into smaller modules**
    - File: `index.ts`
    - Issue: Monolithic entry point handles config resolution, plugin lifecycle, hook registration, autoCapture, autoRecall, reflection, and smart extraction wiring.
    - Fix: Extract into `src/plugin-lifecycle.ts`, `src/config-resolver.ts`, `src/hooks.ts`.
    - Effort: large
    - PR-worthy: high

11. **Replace fragile test script chain with proper test runner config**
    - File: `package.json:41`
    - Issue: Test script is a single 2KB `&&` chain. One failure stops all subsequent tests.
    - Fix: Use `node --test test/*.test.mjs` glob pattern or a test runner with `--fail-fast=false`.
    - Effort: small
    - PR-worthy: medium

12. **Pin `apache-arrow` with caret range**
    - File: `package.json:31`
    - Issue: Exact pin `"18.1.0"` prevents patch updates.
    - Fix: Change to `"^18.1.0"`.
    - Effort: trivial
    - PR-worthy: low

### Feature Ideas

13. **Add `memory export/import` CLI commands for backup/restore**
    - Effort: medium
    - PR-worthy: medium

14. **Add metrics/telemetry hooks for monitoring memory operations**
    - Effort: medium
    - PR-worthy: medium

## Draft PRs

### PR 1: fix: consistent SQL escaping in MemoryStore.delete()

- **Branch:** `fix/sql-escape-delete`
- **Files:** `src/store.ts`
- **Changes:**
  - Line 695: Change `id` to `escapeSqlLiteral(id)` in the WHERE clause
  - Line 728: Change `resolvedId` to `escapeSqlLiteral(resolvedId)` in the delete filter
  - Add a test case in a new `test/store-delete-escape.test.mjs` verifying IDs with special chars are handled
- **Effort:** 30 minutes
- **Impact:** Eliminates inconsistent escaping pattern and prevents potential SQL injection if validation logic is ever relaxed. Defense in depth.

### PR 2: fix: move commander to runtime dependencies

- **Branch:** `fix/commander-dependency`
- **Files:** `package.json`
- **Changes:**
  - Move `"commander": "^14.0.0"` from `devDependencies` to `dependencies`
  - Verify CLI commands work after `npm install --production`
- **Effort:** 15 minutes
- **Impact:** Fixes CLI crash in production installs. Users who install with `--production` or as a dependency get broken CLI.

### PR 3: test: add admission-control scoring unit tests

- **Branch:** `test/admission-control-scoring`
- **Files:** `test/admission-control-scoring.test.mjs`, `src/admission-control.ts`
- **Changes:**
  - Export internal scoring functions for testing (or test via public API)
  - Test cases: balanced/conservative/high-recall presets, weight normalization sums to 1, boundary scores at reject/admit thresholds, recency decay calculation, type prior lookups, novelty scoring with empty/full candidate pools
  - Minimum 15 test cases covering the scoring pipeline
- **Effort:** 3-4 hours
- **Impact:** The admission control system is a critical gate for memory quality. Untested scoring logic could silently reject valid memories or admit noise, degrading the entire memory system.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 7 |
| Documentation | 6 |
| Test Coverage | 6 |
| Contribution Potential | 8 |
