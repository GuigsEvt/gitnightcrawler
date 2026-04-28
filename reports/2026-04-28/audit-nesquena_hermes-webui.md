Security audit complete. Report written to `SECURITY_AUDIT.md`.

**Key findings summary:**

| Severity | Count |
|----------|-------|
| Critical | 3 |
| High | 6 |
| Medium | 9 |
| Low | 5 |

**Overall risk: HIGH**

The three critical findings are all in Docker deployment:
1. **Passwordless sudo** for container users (trivial root escalation)
2. **World-writable temp directory** storing credential data
3. **Environment variable injection** via unvalidated temp files

The most impactful AI-specific finding is **prompt injection via workspace paths** (HIGH) -- workspace names are interpolated directly into the agent's system prompt without sanitization.

Positive notes: the auth system is well-implemented (PBKDF2 600k iterations, HMAC-signed cookies, rate limiting), the codebase has only 1 runtime dependency (pyyaml), and there are ~42k lines of tests including dedicated security regression tests.
