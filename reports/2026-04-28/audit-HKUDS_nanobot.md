Audit complete. Here's the summary:

**20 findings identified** across the HKUDS/nanobot codebase:

| Severity | Count | Key Issues |
|----------|-------|------------|
| CRITICAL | 3 | WebSocket auth bypass (empty secret grants access), SSL verify=False fallback, world-readable config with API keys |
| HIGH | 5 | Default allow-all WebSocket, sandbox disabled by default, API keys as plain strings, Docker SYS_ADMIN, PATH injection |
| MEDIUM | 8 | Gateway on 0.0.0.0, mutable CI action tags, unpinned Docker image, MCP command execution, schema recursion DoS, config path leak, WhatsApp chmod suppression, header injection |
| LOW | 4 | Bridge timing-unsafe comparison, markdown XSS, error message leakage, UUID truncation |

**Overall risk: HIGH**

The codebase has strong fundamentals -- no eval/exec, proper SSRF protection, good path validation, constant-time comparison on Python side, non-root Docker user. But the WebSocket auth bypass (FINDING-01) combined with the default allow-all policy (FINDING-04) creates an unauthenticated RCE path that is the most urgent fix. The config file permissions issue (FINDING-03) is a close second since it exposes 25+ provider API keys to any local user.

Three draft PRs are included targeting the top 3 most impactful fixes.
