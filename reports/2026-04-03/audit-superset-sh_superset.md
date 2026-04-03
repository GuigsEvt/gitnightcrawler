

The security audit is complete. The report has been written to `SECURITY_AUDIT.md` with 13 findings:

| Severity | Count | Key Issues |
|----------|-------|------------|
| **Critical** | 1 | Prompt injection via GitHub Issues triggering unrestricted AI agent with secrets access |
| **High** | 3 | Unauthenticated OAuth client registration, permission bypass defaults, webviewTag without sandbox |
| **Medium** | 7 | Disabled rate limiting, arbitrary JS eval via MCP, unrestricted shell.openExternal, secrets as CLI args, broad git wildcard allowlists, missing CSP on custom protocols |
| **Low** | 2 | Timing leak on PSK length check, SQLite foreign keys disabled |

The report includes 3 draft PRs targeting the highest-impact fixes and 5 contribution opportunities. Let me know if you want any changes to the report or want the draft PRs implemented as actual branches.
