Security audit complete. Report written to `SECURITY_AUDIT.md`.

**Key findings summary:**

| Severity | Count |
|----------|-------|
| Critical | 2 |
| High | 4 |
| Medium | 5 |
| Low | 4 |

**Top 3 most urgent issues:**

1. **CRITICAL -- Secrets in CI logs**: 40+ production secrets (Stripe, DB, auth, encryption keys) are passed as `vercel deploy --env` CLI flags, which appear in plaintext in GitHub Actions logs. This affects both preview and production deploy workflows.

2. **HIGH -- Unrestricted AI agent in triage workflow**: `--dangerously-skip-permissions` on an `issues: [opened]` trigger means any GitHub user who opens an issue can trigger arbitrary command execution via prompt injection in the issue body.

3. **CRITICAL -- `evaluate_js` MCP tool**: Executes arbitrary JavaScript from LLM outputs in the Electron renderer with zero sandboxing. Direct prompt injection vector when agents process untrusted repositories.

**Overall risk level: HIGH** -- The CI secrets exposure is likely actively leaking credentials in every deployment run.
