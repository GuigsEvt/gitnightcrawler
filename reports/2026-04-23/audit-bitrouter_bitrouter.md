Report written to `.serena/marketing-audit.md`.

**Summary of findings:**

**Top 3 Quick Win PRs:**

1. **`docs: add README badges and crate-level documentation`** -- No badges (crates.io, docs.rs, CI, license) and no `//!` crate-level docs on any of the 9 library crates. 30-45 min, high merge likelihood.

2. **`fix(api): remove allow(too_many_arguments) in mpp state`** -- Single `#[allow(clippy::too_many_arguments)]` at `bitrouter-api/src/mpp/state.rs:865` directly violates their own CLAUDE.md rule #1. Refactor to a params struct. 15-30 min, high merge likelihood.

3. **`ci: add cargo-deny for license and vulnerability auditing`** -- No supply chain security checks in CI. Standard practice for published crates. 30-45 min, medium-high merge likelihood (open issue first).

**Key stats:** 76 stars, 7 weeks old, very active (352 commits), 1 primary dev, strict quality bar, responsive to PRs. Two crates have zero test coverage (`bitrouter-accounts`, `bitrouter-blob`). All panics are in test code only. Clean, well-documented project -- good contribution target.
