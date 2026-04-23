Now I have everything needed. Here's the full report:

---

# Security Audit: safishamsi/graphify

## Repository Overview

Graphify is a Python-based knowledge graph builder designed as a skill/plugin for AI coding assistants (Claude Code, Codex, Gemini CLI, Aider, Cursor, etc.). It takes a folder of code, docs, papers, images, or videos and builds a queryable knowledge graph using tree-sitter for AST extraction and optional LLM-based semantic extraction. It supports multiple output formats (JSON, HTML vis.js, Obsidian vault, Neo4j Cypher, GraphML, SVG, wiki) and can serve a graph via MCP stdio server. The project also provides git hooks for auto-rebuilding and a file watcher for live updates.

- **Tech stack**: Python 3.10+, tree-sitter, NetworkX, optional dependencies (mcp, neo4j, pypdf, watchdog, faster-whisper, yt-dlp, matplotlib)
- **Languages**: Python only
- **Maturity**: Growing (v0.4.27, active development, comprehensive test suite, good security awareness)
- **Categories detected**: ai|actions|mobile

## Critical & High Severity Findings

### Finding 1: SSRF DNS Rebinding / TOCTOU in URL Validation

- **Severity**: HIGH
- **Category**: SSRF
- **Location**: `graphify/security.py:50-63`
- **Description**: `validate_url()` resolves the hostname via `socket.getaddrinfo()` and checks if the resolved IP is private/reserved. However, the actual fetch in `safe_fetch()` resolves the hostname again independently via `opener.open()`. A DNS rebinding attack can return a public IP during validation and a private/internal IP (e.g., `169.254.169.254`) during the actual fetch, bypassing the SSRF protection.
- **Impact**: An attacker who controls a DNS server can trick graphify's `ingest` command into fetching cloud metadata endpoints (AWS IMDSv1, GCP metadata) or internal services. This requires the attacker to convince a user to run `graphify add <attacker-controlled-url>`.
- **Fix**: Resolve DNS once in `validate_url()`, then pass the resolved IP directly to the opener (e.g., override the Host header and connect to the IP). Alternatively, use a custom `HTTPHandler` that resolves once and pins the IP for the connection.
- **Confidence**: Medium (requires attacker-controlled DNS + user running `graphify add`)

### Finding 2: Neo4j Cypher Injection via Node Label (f-string in `push_to_neo4j`)

- **Severity**: HIGH
- **Category**: Injection
- **Location**: `graphify/export.py:907-911`
- **Description**: In `push_to_neo4j()`, the `ftype` (Neo4j node label derived from `file_type`) is sanitized via `_safe_label()` which strips non-alphanumeric characters. However, the label is interpolated directly into a Cypher query string via f-string: `f"MERGE (n:{ftype} {{id: $id}}) SET n += $props"`. While `_safe_label()` mitigates injection by stripping special chars, the `rel` variable in the edge query (line 916) uses `_safe_rel()` which similarly sanitizes. The pattern of f-string interpolation for Cypher labels/types is inherently fragile -- any regression in the sanitization functions would open Cypher injection.
- **Impact**: If sanitization is bypassed (e.g., future code change weakens regex), attacker-controlled graph data could execute arbitrary Cypher queries against the Neo4j database, potentially exfiltrating or modifying data.
- **Fix**: Use parameterized Cypher queries where possible. For label/relationship type names (which Neo4j doesn't support as parameters), add an explicit allowlist validation instead of regex-based sanitization.
- **Confidence**: Low (current sanitization appears sound but the pattern is fragile)

### Finding 3: Unpinned CDN Dependency (vis-network from unpkg.com)

- **Severity**: HIGH
- **Category**: Supply Chain
- **Location**: `graphify/export.py:428`
- **Description**: The HTML visualization loads `vis-network` from `https://unpkg.com/vis-network/standalone/umd/vis-network.min.js` without a version pin or subresource integrity (SRI) hash. This resolves to whatever the latest version is at the time the HTML is opened.
- **Impact**: If the `vis-network` npm package or unpkg CDN is compromised, any user opening a graphify-generated `graph.html` would execute malicious JavaScript in their browser context. The HTML contains embedded graph data (node labels from source code, file paths, etc.) which could be exfiltrated.
- **Fix**: Pin to a specific version (e.g., `vis-network@9.1.9`) and add an `integrity` attribute with the SHA-384 hash. Consider bundling the JS file locally instead.
- **Confidence**: High

## Medium & Low Severity Findings

### Finding 4: Incomplete SSRF Blocked Hosts List

- **Severity**: MEDIUM
- **Category**: SSRF
- **Location**: `graphify/security.py:19`
- **Description**: `_BLOCKED_HOSTS` only includes Google metadata endpoints but misses the AWS metadata endpoint (`169.254.169.254` -- covered by IP check) and Azure metadata (`metadata.azure.internal`). While the IP-range check covers `169.254.x.x` (link-local), Azure's `metadata.azure.internal` could resolve to a non-link-local address in certain configurations.
- **Impact**: Potential SSRF to Azure metadata in cloud deployments.
- **Fix**: Add `"metadata.azure.internal"` to `_BLOCKED_HOSTS`.
- **Confidence**: Medium

### Finding 5: `sanitize_label` Does Not HTML-Escape

- **Severity**: MEDIUM
- **Category**: XSS
- **Location**: `graphify/security.py:194-205`
- **Description**: `sanitize_label()` strips control characters and caps length but does NOT HTML-escape. The `SECURITY.md` claims "HTML-escapes all node labels" but the function delegates that responsibility to callers. The `to_html()` function in `export.py` does properly use `_html.escape()` for titles (line 380, 397) and has an `esc()` JS function (line 111-113). However, node labels are embedded in JSON (lines 416-418) where `_js_safe()` only escapes `</` sequences -- it does not escape HTML entities within the JSON string values that are later injected into `innerHTML` (line 172).
- **Impact**: If a source file has a function named something like `"><img src=x onerror=alert(1)>`, the label could end up in `innerHTML` assignments in the generated HTML, executing XSS. However, JSON.parse would handle most escaping. The `esc()` helper is used in `showInfo()` which mitigates this for the info panel.
- **Fix**: Audit all `innerHTML` assignments in the HTML template to ensure they use the `esc()` helper consistently. The legend items on line 247 inject `c.label` via template literal without escaping.
- **Confidence**: Medium

### Finding 6: Exception Details Leaked to MCP Clients

- **Severity**: LOW
- **Category**: Information Disclosure
- **Location**: `graphify/serve.py:358-359`
- **Description**: The MCP `call_tool` handler catches all exceptions and returns the full exception message as text: `f"Error executing {name}: {exc}"`. This could leak internal file paths, stack traces, or implementation details to MCP clients.
- **Impact**: Minor information disclosure to connected AI agents. Low risk since MCP runs over local stdio.
- **Fix**: Return generic error messages and log details to stderr instead.
- **Confidence**: High

### Finding 7: `_yaml_str` Incomplete Escaping

- **Severity**: LOW
- **Category**: Injection
- **Location**: `graphify/ingest.py:14-15`
- **Description**: `_yaml_str()` escapes backslash, double-quote, and newlines, but does not escape other YAML-special sequences like `---` (document separator), `: ` (mapping value indicator), or `#` (comment). While the values are always double-quoted (limiting the attack surface), some YAML parsers may still be tripped up by edge cases.
- **Impact**: Malformed YAML frontmatter in ingested files could cause downstream parsing issues. Not a security vulnerability per se, since the YAML is only consumed by graphify's own extractor.
- **Fix**: Use a proper YAML serializer (e.g., `yaml.dump`) for frontmatter generation, or extend escaping to cover all YAML special chars within double-quoted scalars.
- **Confidence**: Low

### Finding 8: SHA-1 Used for Audio File Naming

- **Severity**: LOW
- **Category**: Crypto
- **Location**: `graphify/transcribe.py:59`
- **Description**: `hashlib.sha1(url.encode()).hexdigest()[:12]` is used to derive audio filenames. SHA-1 is considered weak for collision resistance.
- **Impact**: Negligible -- this is only used for cache file naming, not for any security-critical purpose. Collision would only cause one audio file to shadow another.
- **Fix**: Replace with `hashlib.sha256` for consistency with the rest of the codebase (cache.py already uses SHA-256).
- **Confidence**: High (not a real security risk, just hygiene)

## Supply Chain Analysis

**Dependencies** (from `pyproject.toml`):
- **networkx**: Well-maintained, no known vulnerabilities
- **tree-sitter >=0.23.0** + 18 language parsers: Active maintenance, compiled C extensions (potential memory safety issues inherent to C parsers, but tree-sitter is widely audited)
- **Optional**: mcp, neo4j, pypdf, html2text, watchdog, graspologic, python-docx, openpyxl, faster-whisper, yt-dlp, matplotlib

**Observations**:
- No `requirements.txt` or lockfile -- dependency versions are unpinned (except tree-sitter >=0.23.0). This means builds are not reproducible and a compromised upstream could silently affect installs.
- `yt-dlp` is a high-risk dependency (executes network downloads, parses untrusted media metadata) but is only used when explicitly invoked via video transcription.
- `scripts/llm.py` requires `openai` package at runtime -- not declared as a dependency.
- The `unpkg.com` CDN dependency for vis-network (Finding 3) is the most significant supply chain risk.

**CI/CD** (`.github/workflows/ci.yml`):
- Uses pinned action versions (`@v4`, `@v5`) -- good
- Runs on `ubuntu-latest` -- acceptable
- No secrets exposure, no artifact upload, no deployment steps
- No dependency vulnerability scanning (e.g., `pip-audit`, `safety`, Dependabot)
- Workflow permissions are not explicitly restricted (defaults to read/write)

## Code Quality Assessment

**Architecture**: Clean modular design. Each module has a single responsibility (detect, extract, build, cluster, analyze, export, serve). The pipeline is well-structured: detect -> extract -> build -> cluster -> analyze -> report/export.

**Error handling**: Consistent. Functions raise typed exceptions with descriptive messages. The MCP server and CLI both handle errors gracefully with user-friendly messages. Tree-sitter parsing uses `errors="replace"` for robustness.

**Security awareness**: Notably high for a project of this size. The `security.py` module provides SSRF protection, path traversal guards, and label sanitization. There's a dedicated `SECURITY.md` with a threat model. Security tests exist in `test_security.py`.

**Test coverage**: Good breadth -- 25 test files covering most modules. Key security functions are tested. Missing: no tests for Neo4j Cypher escaping, no tests for HTML XSS scenarios in `to_html()`, no fuzzing.

**Documentation**: Comprehensive README, ARCHITECTURE.md, CHANGELOG.md, SECURITY.md. Well-documented functions with docstrings.

## Contribution Opportunities

1. **File**: `graphify/export.py:428`
   - **Issue**: Unpinned CDN dependency without SRI
   - **Fix**: Pin vis-network version and add integrity hash
   - **Effort**: Trivial

2. **File**: `graphify/security.py:19`
   - **Issue**: Missing Azure metadata in blocked hosts
   - **Fix**: Add `"metadata.azure.internal"` to `_BLOCKED_HOSTS`
   - **Effort**: Trivial

3. **File**: `graphify/security.py:50-63`
   - **Issue**: DNS rebinding TOCTOU in SSRF validation
   - **Fix**: Pin DNS resolution and pass resolved IP to fetcher
   - **Effort**: Medium

4. **File**: `graphify/export.py:247`
   - **Issue**: Legend label not HTML-escaped in `innerHTML`
   - **Fix**: Apply `esc()` to legend label template literal
   - **Effort**: Trivial

5. **File**: `.github/workflows/ci.yml`
   - **Issue**: No dependency vulnerability scanning, no explicit permissions
   - **Fix**: Add `pip-audit` step and `permissions: {contents: read}` at workflow level
   - **Effort**: Small

## Draft PRs

### PR 1: Pin vis-network CDN with SRI hash
- **PR Title**: `fix(export): pin vis-network CDN version and add subresource integrity`
- **Branch name**: `fix/pin-visnetwork-sri`
- **Files to modify**: `graphify/export.py`
- **Changes**: Replace `https://unpkg.com/vis-network/standalone/umd/vis-network.min.js` with a pinned version URL and add `integrity="sha384-..."` and `crossorigin="anonymous"` attributes to the script tag.
- **Impact**: Eliminates the supply chain risk of loading arbitrary JavaScript from a CDN in every generated HTML visualization.

### PR 2: Harden SSRF protection
- **PR Title**: `fix(security): add Azure metadata to blocked hosts, mitigate DNS rebinding`
- **Branch name**: `fix/ssrf-hardening`
- **Files to modify**: `graphify/security.py`, `tests/test_security.py`
- **Changes**: Add `"metadata.azure.internal"` to `_BLOCKED_HOSTS`. Refactor `validate_url()` to return resolved addresses, and modify `safe_fetch()` to use the pre-resolved IP for the connection (preventing DNS rebinding TOCTOU).
- **Impact**: Closes the DNS rebinding window and extends cloud metadata protection to Azure environments.

### PR 3: Fix XSS in HTML legend and harden CI
- **PR Title**: `fix(export): escape legend labels in HTML output, add CI permissions`
- **Branch name**: `fix/xss-legend-ci-permissions`
- **Files to modify**: `graphify/export.py`, `.github/workflows/ci.yml`
- **Changes**: In `_html_script()`, apply the `esc()` helper to the legend label interpolation. In CI, add `permissions: {contents: read}` and a `pip-audit` step.
- **Impact**: Prevents XSS via malicious community labels in generated HTML and adds automated dependency vulnerability scanning.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 8 |
| Test Coverage | 7 |
| Contribution Potential | 6 |

## Summary

- **Total findings by severity**: Critical: 0, High: 3, Medium: 2, Low: 3, Info: 0
- **Overall risk level**: **MEDIUM**
- **Top 3 recommendations**:
  1. Pin the vis-network CDN URL with a version and SRI hash to eliminate the supply chain risk in generated HTML files
  2. Harden SSRF protection by mitigating DNS rebinding (resolve-once-then-fetch) and adding Azure metadata to the blocked hosts list
  3. Add `permissions: {contents: read}` to the CI workflow and integrate `pip-audit` for automated dependency vulnerability scanning
