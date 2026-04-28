Security audit complete. Report written to `SECURITY_AUDIT.md`.

**Key findings summary:**

| Severity | Count | Top Issues |
|----------|-------|------------|
| Critical | 2 | Path traversal in render file serving and studio static assets |
| High | 5 | Path traversal in thumbnails, postMessage wildcard, command injection (2x), unpinned Actions |
| Medium | 2 | SSRF in URL downloader, unvalidated version in publish workflow |
| Low | 2 | innerHTML pattern, Docker seccomp disabled |
| Info | 1 | Public analytics key |

**Overall risk: HIGH** -- The path traversal issues (FINDING-1, -2, -3) are the most actionable since the fix is trivial: the `isSafePath()` helper already exists and works correctly in other routes, it just needs to be applied consistently. All three can be fixed in a single small PR.
