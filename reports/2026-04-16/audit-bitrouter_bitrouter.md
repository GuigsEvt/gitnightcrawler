Audit complete. Report written to `.serena/marketing_audit.md`.

**Summary of top 3 quick wins:**

1. **Expand 3 stub crate READMEs** (30 min, HIGH merge likelihood) -- `bitrouter-accounts`, `bitrouter-blob`, `bitrouter-providers` are 3-line stubs while other crates have 20-50 line docs
2. **Add PR template + SECURITY.md** (20 min, HIGH) -- issue templates exist but no PR template, no security policy
3. **Add docs.rs badge** (5 min, HIGH) -- standard for crates.io packages, trivial change

The repo is very active (130 commits/month, PRs merged same day), well-maintained with strict CI, and the maintainer clearly values documentation. Pure docs PRs are the safest entry point -- avoid code changes initially given the strict Rust quality gates.
