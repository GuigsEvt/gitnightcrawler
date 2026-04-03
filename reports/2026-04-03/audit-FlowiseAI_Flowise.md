Security audit complete. Report written to `SECURITY_AUDIT.md`.

**Key findings:**

| Severity | Count | Notable |
|----------|-------|---------|
| CRITICAL | 2 | Sandbox escape via object spread, auth bypass via spoofable header |
| HIGH | 6 | Weak CryptoJS encryption, env var exposure, hardcoded secrets, CI injection, Docker root, CDN dep |
| MEDIUM | 10 | CORS, clickjacking, SSRF bypass, path traversal kill switch, prompt injection |
| LOW | 4 | Wildcard deps, session serialization, missing permissions |

**Overall risk: HIGH**

The three most actionable fixes are:
1. **Trivial** -- Reverse the object spread order in `createCodeExecutionSandbox()` (`utils.ts:1824`)
2. **Small** -- Remove `X-Request-From: internal` header trust (`index.ts:226`)
3. **Trivial** -- Fix CI command injection in `proprietary-path-guard.yml:50-58`
