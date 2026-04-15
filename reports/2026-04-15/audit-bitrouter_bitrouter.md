Now I have everything I need. Here's the full report:

---

# Marketing Audit: bitrouter/bitrouter

## Quick Overview

BitRouter is an open-source, agent-native routing proxy for LLM agents. It sits between AI agents (Claude Code, OpenClaw, Codex CLI, etc.) and upstream providers (OpenAI, Anthropic, Google, OpenRouter), handling multi-provider routing, streaming, tools-as-a-service, guardrails (AI firewall), MCP gateway, observability/spend tracking, and agentic payments. Think of it as a local, Rust-based alternative to LiteLLM or OpenRouter, purpose-built for autonomous agent workflows.

- **Tech stack**: Rust 2024, 10-crate workspace, Warp (HTTP), sea-orm (DB), ratatui (TUI), cargo-dist + release-plz (releases)
- **Activity level**: Extremely active -- 237 commits in the last month, releasing roughly every 2 weeks (now at v0.24.0). PRs are merged within hours. Maintainer (`takasaki404`) is very responsive. Bot-authored PRs (copilot-swe-agent, claude, release-bot) are also common.
- **Stars/Community**: Active Discord, Twitter presence, badges in README

## Quick Win PRs (prioritize these)

### 1. Documentation Improvements

| Issue | Location | Details |
|-------|----------|---------|
| **3 skeleton README files** | `bitrouter-accounts/README.md`, `bitrouter-blob/README.md`, `bitrouter-providers/README.md` | Only have title + repo link. No description, no module list, no feature flags. Compare with `bitrouter-guardrails/README.md` which is well-documented. |
| **6 lib.rs missing crate-level docs** | `bitrouter-core/src/lib.rs`, `bitrouter-api/src/lib.rs`, `bitrouter-providers/src/lib.rs`, `bitrouter-guardrails/src/lib.rs`, `bitrouter-tui/src/lib.rs`, `bitrouter-config/src/lib.rs` | No `//!` doc comments at the top. These show on docs.rs/crates.io. |
| **Missing SECURITY.md** | Root | No security policy. Project handles auth, JWT, API keys, crypto payments -- a SECURITY.md is expected. |
| **No examples/ directory** | Root or any crate | No runnable examples anywhere. Even a simple "start a proxy" example would help adoption. |

### 2. Code Quality

| Issue | Location | Details |
|-------|----------|---------|
| **Missing Cargo.toml metadata** | All workspace crates | Missing `keywords` and `categories` fields for crates.io discoverability. e.g., `keywords = ["llm", "proxy", "routing", "ai-agent", "openai"]` |
| **Large undocumented files** | `bitrouter-providers/src/google/generate_content/api.rs` (1847 lines), `bitrouter-providers/src/anthropic/messages/api.rs` (1691 lines) | Module-level doc comments would help contributors navigate these. |

### 3. Tests

| Issue | Location | Details |
|-------|----------|---------|
| **bitrouter-accounts has no tests** | `bitrouter-accounts/src/` | Database/session management crate with zero test coverage. |
| **bitrouter-blob has no tests** | `bitrouter-blob/src/` | Storage backend with no tests at all. |
| **No integration test directories** | Any crate `tests/` dir | All tests are inline `#[cfg(test)]` modules. No `tests/` directories for integration tests. |
| **Open issue for e2e framework** | Issue: "feat(test): automated e2e test framework" | Maintainer explicitly wants test contributions. |

### 4. CI/CD

| Issue | Details |
|-------|---------|
| **No code coverage reporting** | No codecov/coveralls integration. Adding `cargo-llvm-cov` or `cargo-tarpaulin` to CI with a badge would be valuable. |
| **No dependency audit in CI** | No `cargo audit` step. Given the crypto/payment features, this matters. |
| **Missing crates.io badge for sub-crates** | Only root crate has a badge. Sub-crate READMEs could link to their crates.io pages. |

### 5. DX Improvements

| Issue | Details |
|-------|---------|
| **No Dockerfile** | No containerized deployment option. Many users deploying proxies want Docker. |
| **No example bitrouter.yaml** | Config is described in docs but no complete annotated example file in the repo root. |
| **CONTRIBUTING.md missing local dev setup** | No mention of required Rust version, how to install cargo-nextest, or how to run with specific feature flags. |

## Draft PRs

### PR 1: Flesh out thin crate READMEs

- **PR Title**: `docs: add descriptions to accounts, blob, and providers READMEs`
- **Branch**: `docs/crate-readmes`
- **Files to change**:
  - `bitrouter-accounts/README.md` -- Add purpose (session/account management via sea-orm), module list, feature flags (sqlite, postgres, mysql)
  - `bitrouter-blob/README.md` -- Add purpose (blob storage backends), feature flags (fs), module list
  - `bitrouter-providers/README.md` -- Add purpose (provider adapters), supported providers, feature flags (openai, anthropic, google, rest, mcp, acp, agentskills)
- **Changes**: Follow the pattern in `bitrouter-guardrails/README.md` and `bitrouter-core/README.md`. Include: title, repo link, 2-3 sentence description, `## Includes` section listing modules, `## Feature Flags` section if applicable.
- **Effort**: 30 minutes
- **Merge likelihood**: **High** -- Pure docs, no code changes, follows existing patterns, fills an obvious gap

### PR 2: Add crate-level doc comments to lib.rs files

- **PR Title**: `docs: add crate-level doc comments to lib.rs files`
- **Branch**: `docs/lib-rs-docs`
- **Files to change**:
  - `bitrouter-core/src/lib.rs` -- Add `//!` block describing transport-neutral contracts
  - `bitrouter-api/src/lib.rs` -- Add `//!` block describing HTTP API layer
  - `bitrouter-providers/src/lib.rs` -- Add `//!` block describing provider adapters
  - `bitrouter-guardrails/src/lib.rs` -- Add `//!` block describing firewall engine
  - `bitrouter-config/src/lib.rs` -- Add `//!` block describing config loading
  - `bitrouter-tui/src/lib.rs` -- Add `//!` block describing terminal UI
- **Changes**: Add 3-5 line `//!` doc comments at the top of each file. Content derived from DEVELOPMENT.md and existing crate READMEs. These comments appear on docs.rs.
- **Effort**: 20 minutes
- **Merge likelihood**: **High** -- Pure docs, improves crates.io/docs.rs presence, no behavioral change

### PR 3: Add SECURITY.md

- **PR Title**: `docs: add SECURITY.md with vulnerability reporting policy`
- **Branch**: `docs/security-policy`
- **Files to change**:
  - `SECURITY.md` (new file)
- **Changes**: Create a standard security policy covering: supported versions, how to report vulnerabilities (email or GitHub Security Advisories), expected response timeline, disclosure policy. This is especially important given BitRouter handles API keys, JWT auth, crypto payments, and acts as a proxy for sensitive LLM traffic.
- **Effort**: 15 minutes
- **Merge likelihood**: **High** -- Standard open-source hygiene, GitHub surfaces this prominently, no code changes

## Notes

- **No red flags**: Maintainer is extremely active (237 commits/month), PRs merge in hours, bot automation is mature (daily maintenance, model updates, release automation).
- **Best approach**: This project values conventional commits strictly (CI validates PR titles). Use exact format: `docs: add descriptions to accounts, blob, and providers READMEs`. Keep PRs small and focused.
- **Maintainer uses AI agents**: Claude Code and Copilot SWE agent PRs are merged regularly. The maintainer is technically sophisticated and will review quickly.
- **Open issues to reference**: The e2e test framework issue is a good one to comment on before submitting test PRs. The "Integration opportunity: list bitrouter on Agoragentic" issue shows the maintainer is open to community contributions.
- **Avoid**: Don't submit code-heavy PRs without discussing in an issue first. Don't use `#[allow()]`, `.unwrap()`, or add dead code (per CLAUDE.md guidelines). Don't re-export public module items.
