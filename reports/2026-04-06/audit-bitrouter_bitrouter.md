Now I have enough to produce the report.

# Marketing Audit: bitrouter/bitrouter

## Quick Overview

BitRouter is a modular, trait-based LLM routing proxy written in Rust. It aggregates upstream providers (OpenAI, Anthropic, Google), routes tool calls via MCP/REST, and provides guardrails, agentic payments (402/MPP), and a CLI+TUI for agent session management. Designed as a local-first proxy for autonomous AI agents rather than a cloud SaaS gateway.

- **Tech stack**: Rust (edition 2024), 10-crate workspace, Warp HTTP, SeaORM, Ratatui TUI, cargo-dist releases
- **Activity level**: ~200 commits since March 2025, ~50/week recently. 4-5 active contributors (Archer, takasaki404, Spikel, Copilot). PRs merged same-day. Very active.
- **Version**: 0.19.0, published to crates.io
- **Stars**: Growing (has star-history chart in README)

---

## Quick Win PRs

### 1. Documentation Improvements

| Issue | Location | Severity |
|-------|----------|----------|
| **Broken links to old org name** | `README.md:87,102` — links to `github.com/AIMOverse/bitrouter/issues` instead of `github.com/bitrouter/bitrouter/issues` | HIGH |
| **No rustfmt.toml** | Root — no formatting config, relies on defaults | LOW |
| **No clippy.toml** | Root — no clippy config, relies on defaults | LOW |
| **Missing crate-level doc comments** | Most crate `lib.rs` files lack `//! ...` module-level docs for docs.rs | MEDIUM |
| **No docs.rs badge** | README has no link to docs.rs published documentation | LOW |

### 2. Code Quality

| Issue | Location | Severity |
|-------|----------|----------|
| **2 TODO comments** | `bitrouter-api/src/mpp/state.rs:510`, `bitrouter-core/src/api/mcp/convert.rs:22` | LOW |
| **No `#[deny(missing_docs)]`** | Any crate — public API items lack enforcement | MEDIUM |

### 3. Tests

| Issue | Location | Severity |
|-------|----------|----------|
| **No integration tests** | No `tests/` directory in any crate — all tests are inline `#[cfg(test)]` | MEDIUM |
| **bitrouter-accounts has minimal tests** | Only 1 module with tests in the accounts crate | MEDIUM |
| **bitrouter-blob has minimal tests** | Only 1 module with tests | LOW |
| **No benchmarks** | Issue #42 open for benchmarking, no `benches/` dirs exist | MEDIUM |

### 4. CI/CD

| Issue | Location | Severity |
|-------|----------|----------|
| **No docs.rs badge** | README — missing crate docs badge | LOW |
| **No code coverage** | No codecov/coveralls integration in CI | MEDIUM |
| **No security audit workflow** | No `cargo audit` or `cargo deny` in CI | MEDIUM |

### 5. DX Improvements

| Issue | Location | Severity |
|-------|----------|----------|
| **No Dockerfile** | Root — no containerization at all | MEDIUM |
| **No `.dockerignore`** | Root | LOW |
| **No `Makefile`** | Root — CONTRIBUTING.md references `cargo nextest run` and other commands but no convenience wrapper | LOW |

---

## Draft PRs

### PR #1: Fix broken links to old AIMOverse org

- **PR Title**: `fix(readme): update issue links from AIMOverse to bitrouter org`
- **Branch**: `fix/readme-org-links`
- **Files to change**: `README.md`
- **Changes**:
  - Line 87: Replace `https://github.com/AIMOverse/bitrouter/issues` with `https://github.com/bitrouter/bitrouter/issues`
  - Line 102: Same replacement
- **Effort**: 5 minutes
- **Merge likelihood**: **HIGH** — obvious bug, zero risk, maintainers clearly migrated from AIMOverse org

---

### PR #2: Add `cargo audit` security check to CI

- **PR Title**: `ci(security): add cargo-audit dependency vulnerability check`
- **Branch**: `ci/cargo-audit`
- **Files to change**: `.github/workflows/ci.yml`
- **Changes**: Add a new job after `fmt`:
  ```yaml
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rustsec/audit-check@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
  ```
- **Effort**: 15 minutes
- **Merge likelihood**: **HIGH** — standard Rust CI practice, no code changes, security-conscious project (has guardrails crate)

---

### PR #3: Add Dockerfile for self-hosted deployment

- **PR Title**: `feat(docker): add multi-stage Dockerfile for self-hosted deployment`
- **Branch**: `feat/dockerfile`
- **Files to change**: `Dockerfile`, `.dockerignore`
- **Changes**:
  - Multi-stage build: `rust:1.85-slim` builder -> `debian:bookworm-slim` runtime
  - Builder: `cargo build --release --all-features`
  - Runtime: copy binary, expose 8787, `ENTRYPOINT ["bitrouter", "serve"]`
  - `.dockerignore`: target/, .git/, .serena/, .claude/
- **Effort**: 30 minutes
- **Merge likelihood**: **MEDIUM** — README touts self-hosting but provides no container story. Maintainers may have opinions on feature flags to include. Open an issue first to gauge interest.

---

## Notes

- **Very active project** — PRs merged same-day, multiple contributors, frequent releases (v0.18 -> v0.19 in days)
- **No PR backlog** — 0 open PRs currently, all recent ones merged quickly
- **Maintainer responsiveness**: HIGH — Archer (primary) merges fast
- **Conventional commits enforced** — PR title validation in CI, follow the pattern
- **Best approach**: The broken links PR (#1) is the safest bet for a first contribution. Follow up with the CI security audit (#2). Open an issue before the Dockerfile (#3).
- **Red flags**: None. Clean, well-maintained codebase with clear guidelines.
