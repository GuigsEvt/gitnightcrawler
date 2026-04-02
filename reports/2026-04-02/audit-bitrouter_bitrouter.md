# Marketing Audit: bitrouter/bitrouter

## Quick Overview
BitRouter is a modular, trait-based LLM routing proxy written in Rust. It connects to upstream providers (OpenAI, Anthropic, Google, OpenRouter) and exposes provider-specific APIs with agent-native features: guardrails/firewall, MCP gateway, agent skills registry, agentic payments (402/MPP stablecoins), and per-request observability. Deployable as a local aggregator, cloud server, or SDK.

- **Tech stack:** Rust 2024 edition, 9-crate workspace, Warp HTTP, SeaORM (SQLite/Postgres/MySQL), Ratatui TUI
- **Activity:** ~180 commits since Jan 2025, 2-3 active contributors (Archer, Spikel/KelsenL), version 0.17.0
- **CI/CD:** 8 GitHub workflows (CI, CD, nightly, release-plz, Claude code review)
- **PR responsiveness:** Active -- recent PRs merged regularly with conventional commit enforcement

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Details |
|-------|----------|---------|
| Minimal/stub crate READMEs | `bitrouter-accounts/README.md`, `bitrouter-blob/README.md`, `bitrouter-providers/README.md` | Only contain a GitHub link (103 bytes, 99 bytes, 104 bytes). Other crates have proper descriptions, modules lists, and usage examples. |
| Missing doc comments on public items | `bitrouter-accounts/src/` (10+ files undocumented), `bitrouter-providers/src/` (16 files undocumented) | Only 50-52% file coverage vs 91% for guardrails |
| No usage examples directory | Root level | No `examples/` directory. Other Rust projects typically include runnable examples showing SDK usage |
| README roadmap items stale | `README.md` roadmap section | Mix of completed items (checkmarks) and pending items -- could be cleaned up or linked to issues |

### 2. Code Quality

| Issue | Location | Details |
|-------|----------|---------|
| **`#[allow(clippy::too_many_arguments)]` violation** | `bitrouter-api/src/mpp/state.rs:865` | CLAUDE.md explicitly forbids `#[allow(...)]`. Function `submit_close_tx()` has 8 params -- needs refactoring into a struct |
| 4 TODO comments in production code | `bitrouter-core/src/api/mcp/convert.rs:22`, `bitrouter-api/src/mpp/state.rs:510`, `bitrouter/src/main.rs:537-538` | Unresolved TODOs that could be addressed or converted to tracked issues |
| No `rustfmt.toml` or `clippy.toml` | Root | Project relies on defaults. A `rustfmt.toml` with explicit settings would document formatting expectations |
| Empty tool provider file | `bitrouter-config/providers/tools/bitrouter.yaml` | 0 bytes -- placeholder that should either be populated or removed |

### 3. Tests

| Issue | Location | Details |
|-------|----------|---------|
| **bitrouter-accounts: ZERO tests** | `bitrouter-accounts/` | 21 source files handling account/session management, database operations, migrations -- no test coverage at all |
| bitrouter-observe: minimal tests | `bitrouter-observe/` | Only 3 test functions for an observability/metrics crate |
| bitrouter-blob: no meaningful tests | `bitrouter-blob/` | Test module exists but has 0 test functions |
| No integration test directory | Root `tests/` | No workspace-level integration tests |

### 4. CI/CD

| Issue | Location | Details |
|-------|----------|---------|
| Missing security audit workflow | `.github/workflows/` | No `cargo audit` or `cargo deny` in CI to check for vulnerable dependencies |
| No dependency caching optimization | `.github/workflows/ci.yml` | Could add Rust/cargo caching to speed up CI builds |
| Missing code coverage reporting | `.github/workflows/` | No coverage tool (tarpaulin, llvm-cov) integrated |

### 5. DX Improvements

| Issue | Location | Details |
|-------|----------|---------|
| No Dockerfile | Root | No containerization for easy deployment -- common request for cloud-deployable services |
| No example config file | Root or `examples/` | Users must read docs to understand config format. An `examples/bitrouter.example.yaml` with comments would help |
| Minimal home_readme template | `templates/home_readme.md` | Only 12 bytes. Could include useful getting-started content |

---

## Draft PRs

### PR #1: Fix `#[allow]` violation by refactoring `submit_close_tx`

- **PR Title:** `refactor(api): remove #[allow] by extracting submit_close_tx params into struct`
- **Branch:** `fix/remove-allow-too-many-args`
- **Files to change:** `bitrouter-api/src/mpp/state.rs`
- **Changes:** Create a `CloseSubmitParams` struct to bundle the 8 parameters of `submit_close_tx()`, then update the function signature and all call sites. Remove the `#[allow(clippy::too_many_arguments)]` attribute.
- **Effort:** 30-60 minutes
- **Merge likelihood:** **HIGH** -- directly fixes a documented guideline violation in CLAUDE.md. Clean, focused change.

### PR #2: Add `cargo audit` security workflow

- **PR Title:** `ci: add cargo-audit dependency security check`
- **Branch:** `ci/cargo-audit`
- **Files to change:** `.github/workflows/ci.yml` (or new `.github/workflows/audit.yml`)
- **Changes:** Add a job that runs `cargo install cargo-audit && cargo audit` on PRs and on a weekly schedule. Standard security practice for Rust projects.
- **Effort:** 15-30 minutes
- **Merge likelihood:** **HIGH** -- low-risk addition, industry standard practice, no code changes needed.

### PR #3: Expand stub crate READMEs (accounts, blob, providers)

- **PR Title:** `docs: expand README for bitrouter-accounts, bitrouter-blob, and bitrouter-providers`
- **Branch:** `docs/crate-readmes`
- **Files to change:** `bitrouter-accounts/README.md`, `bitrouter-blob/README.md`, `bitrouter-providers/README.md`
- **Changes:** Add module descriptions, feature flags, key types/traits, and usage notes matching the style of well-documented crates like `bitrouter-guardrails/README.md` and `bitrouter-observe/README.md`. Content derived from existing code and DEVELOPMENT.md.
- **Effort:** 30-45 minutes
- **Merge likelihood:** **HIGH** -- pure documentation improvement, no code risk. Maintainers already have strong docs culture (5 major docs files).

---

## Notes

- **No red flags.** Active maintainers, PRs merged regularly, conventional commits enforced, comprehensive CI.
- **Best approach:** Start with PR #1 (the `#[allow]` fix) -- it fixes a documented violation, is purely mechanical, and shows you've read the contribution guidelines.
- **Avoid:** Don't submit large refactors or add features without discussion. The CONTRIBUTING.md explicitly asks for small, focused PRs.
- **Community:** Discord at `discord.gg/G3zVrZDa5C` -- worth joining before submitting to gauge maintainer preferences.
- **The empty `bitrouter-config/providers/tools/bitrouter.yaml`** (0 bytes) is likely intentional as a placeholder for future built-in tool definitions, so ask before removing it.
