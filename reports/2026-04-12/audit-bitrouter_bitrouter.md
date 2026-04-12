Found a broken link issue. Now I have everything I need.

# Marketing Audit: bitrouter/bitrouter

## Quick Overview

BitRouter is an open-source Rust proxy purpose-built for autonomous LLM agents. It provides unified multi-provider routing (OpenAI, Anthropic, Google), tool routing (MCP, REST), agent firewalling/guardrails, agentic payments (402/MPP/Solana), and observability -- all via CLI + TUI. It positions itself as the "agentic proxy" alternative to OpenRouter (cloud-only) and LiteLLM (Python).

- **Tech stack**: Rust 2024, Warp (HTTP), sea-orm (DB), tokio (async), ratatui (TUI), cargo-dist (releases)
- **Activity**: ~115 commits in last 4 weeks, multiple PRs merged daily. v0.22.0 released April 12, 2026.
- **Stats**: 73 stars, 1 fork, Apache 2.0 license
- **Maintainer responsiveness**: Very high -- PRs merged within hours, 7 open issues, 1 open PR

---

## Quick Win PRs

### 1. Documentation Improvements

**a) Broken links in README.md (lines 87, 102)**
Two issue links point to `https://github.com/AIMOverse/bitrouter/issues` instead of `https://github.com/bitrouter/bitrouter/issues`. This is a remnant from a repo rename/transfer.

**b) Stub READMEs for 3 sub-crates**
`bitrouter-providers/README.md`, `bitrouter-accounts/README.md`, and `bitrouter-blob/README.md` are 3-line stubs (just crate name + GitHub link). Other crates like `bitrouter-core`, `bitrouter-guardrails`, `bitrouter-observe` have substantive READMEs. These stubs show up on crates.io as the crate description.

**c) No `examples/` directory**
No runnable examples anywhere in the workspace. A `bitrouter.yaml` example config and a basic usage example would help new users.

**d) Missing docs.rs badge on sub-crate READMEs**
None of the sub-crate READMEs have crates.io or docs.rs badges.

### 2. Code Quality

The codebase is exceptionally clean:
- Zero `unwrap()`, `expect()`, or `panic!()` in production code
- Zero `#[allow(xxx)]` directives
- Zero TODO/FIXME/HACK comments
- 1,708 doc comments across the codebase

**No easy code quality PRs available.** This is a well-disciplined project.

### 3. Tests

- No dedicated `tests/` integration test directories (tests are in-module `#[cfg(test)]`)
- Open issue #299 explicitly requests an "automated e2e test framework" -- this is a large effort, not a quick win
- No test coverage reporting configured (no tarpaulin, llvm-cov, or codecov)

**a) Add test coverage reporting to CI** -- add `cargo-llvm-cov` or `cargo-tarpaulin` step to CI with a Codecov badge.

### 4. CI/CD

Already comprehensive (8 workflow files covering CI, release, model updates, maintenance). Minor additions:

**a) Add Codecov/coverage badge to README**
No coverage reporting exists. Adding `cargo-llvm-cov` + Codecov upload to `ci.yml` and a badge to README would be visible.

**b) Add `cargo-deny` for dependency auditing**
No supply chain security scanning. `cargo-deny` checks for license conflicts, security advisories, and duplicate deps.

### 5. DX Improvements

**a) No Dockerfile**
Distribution is via cargo-dist (shell installers, npm, Homebrew), but no Docker image. For a proxy server, a Docker image is table stakes.

**b) No `rustfmt.toml`**
CI enforces `cargo fmt` but there's no config file documenting the style. Minor but shows intentionality.

**c) Missing example config file**
No sample `bitrouter.yaml` in the repo. Users must run the wizard or read DEVELOPMENT.md to understand config structure.

---

## Draft PRs

### PR #1: Fix broken issue links in README

- **PR Title**: `fix(docs): correct issue tracker links from AIMOverse to bitrouter org`
- **Branch**: `fix/readme-issue-links`
- **Files to change**: `README.md`
- **Changes**:
  - Line 87: Replace `https://github.com/AIMOverse/bitrouter/issues` with `https://github.com/bitrouter/bitrouter/issues`
  - Line 102: Same replacement
- **Effort**: 5 minutes
- **Merge likelihood**: **HIGH** -- obvious bug, zero risk, maintainer will merge immediately. These are broken links sending users to the wrong org.

### PR #2: Add substantive READMEs for providers, accounts, and blob crates

- **PR Title**: `docs: add crate-level READMEs for providers, accounts, and blob`
- **Branch**: `docs/sub-crate-readmes`
- **Files to change**:
  - `bitrouter-providers/README.md` -- Add description of supported providers (OpenAI, Anthropic, Google, MCP, REST, ACP, AgentSkills), feature flags, and usage pattern. Follow the format of `bitrouter-core/README.md`.
  - `bitrouter-accounts/README.md` -- Add description of account/session management, database backends (sqlite/postgres/mysql), and migration system.
  - `bitrouter-blob/README.md` -- Add description of blob storage trait and filesystem backend.
- **Effort**: 30 minutes
- **Merge likelihood**: **HIGH** -- these show up on crates.io. Maintainers already wrote substantive READMEs for 7/10 crates, these 3 were clearly deferred. CONTRIBUTING.md explicitly says "Docs updates for user-facing changes" are expected.

### PR #3: Add Dockerfile for the proxy server

- **PR Title**: `feat: add multi-stage Dockerfile for bitrouter server`
- **Branch**: `feat/dockerfile`
- **Files to change**:
  - `Dockerfile` (new) -- Multi-stage build: `rust:1.80-slim` builder stage, `debian:bookworm-slim` runtime. Expose port 8787. ENTRYPOINT `bitrouter serve`.
  - `.dockerignore` (new) -- Exclude target/, .git/, logs/, run/
  - `README.md` -- Add Docker section under Quick Start
- **Effort**: 1 hour
- **Merge likelihood**: **MEDIUM** -- A proxy server without a Docker image is unusual. However, maintainers may have opinions on the image structure, and the project uses cargo-dist for distribution. Open an issue first to gauge interest.

---

## Notes

- **No red flags**: Maintainer is highly active (115 commits/4 weeks), PRs merge within hours, conventional commits enforced, clean codebase.
- **Best approach**: PR #1 (broken links) is the safest entry point -- submit immediately. Follow with PR #2 (READMEs) which adds clear value and follows existing patterns. For PR #3 (Dockerfile), open an issue first.
- **Low-hanging fruit is scarce**: This project is well-maintained with strong discipline. The code quality, doc coverage, and CI are all above average. The main gaps are in DX (Docker, examples) and the 3 stub READMEs.
- **`good first issue` label exists** but has 0 issues tagged with it. Could suggest maintainers tag issue #42 (benchmarking) or create new ones.
- **Broken links are the #1 quickest win** -- two links point to `AIMOverse/bitrouter` (likely the old org name) instead of `bitrouter/bitrouter`.
