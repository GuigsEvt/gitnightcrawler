Security audit complete. Report written to `SECURITY_AUDIT.md`.

**Key findings summary:**

| Severity | Count | Most Critical |
|----------|-------|---------------|
| CRITICAL | 2 | Sandbox safety override (trivial fix), Auth bypass via spoofable header |
| HIGH | 7 | Weak CryptoJS encryption, env var exposure to sandbox, CI injection, CDN dependency, Docker root |
| MEDIUM | 10 | CORS, SQL injection in migrations, SSRF kill switch, prompt injection via override config |
| LOW | 4 | Unpinned actions, wildcard deps, session serialization |

**Overall risk: HIGH**

The 3 highest-impact fixes are all low-effort:
1. **Swap the spread order** in `createCodeExecutionSandbox()` (`utils.ts:1824`) -- prevents sandbox escape
2. **Remove `x-request-from` header check** (`index.ts:224`) -- closes auth bypass
3. **Fix `${{ github.base_ref }}`** in CI workflow -- prevents CI runner compromise
