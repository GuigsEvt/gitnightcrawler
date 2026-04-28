# Security Audit: safishamsi/graphify

## Repository Overview

Graphify is a Python CLI tool and AI coding assistant skill that turns any folder of code, docs, papers, images, or videos into a queryable knowledge graph. It uses tree-sitter for AST-based structural extraction across 20+ languages, builds a NetworkX graph with community detection (Leiden algorithm), and exports to HTML (vis.js), JSON, Obsidian vaults, Neo4j Cypher, SVG, and Canvas formats. It integrates with Claude Code, Codex, Gemini CLI, Cursor, Aider, Kiro, and many other AI coding assistants via skill files and hooks. An optional MCP stdio server exposes graph query tools.

- **Tech stack**: Python 3.10+, tree-sitter, NetworkX, vis.js (HTML viz), optional: MCP, Neo4j, pypdf, watchdog, faster-whisper, yt-dlp, matplotlib
- **Maturity**: Growing (v0.4.31, active development, good test coverage, CI on multiple Python versions)
- **Categories detected**: ai|actions|mobile

## Critical & High Severity Findings

### Finding 1: SSRF TOCTOU in DNS Resolution

- **Severity**: MEDIUM-HIGH (downgraded from HIGH due to local-tool context)
- **Category**: SSRF
- **Location**: `graphify/security.py:50-63`
- **Description**: The `validate_url()` function resolves the hostname to check for private/reserved IPs, then the actual HTTP request in `safe_fetch()` resolves DNS again independently. Between the two resolutions, a DNS rebinding attack could return a public IP for validation and a private IP for the actual fetch.
- **Impact**: An attacker controlling DNS for a domain could bypass SSRF protections and reach internal services (e.g., cloud metadata at 169.254.169.254) from the `ingest` command.
- **Fix**: Pin the resolved IP and use it for the actual connection (e.g., set the `Host` header and connect directly to the validated IP), or perform validation at the socket level after connection.
- **Confidence**: Medium -- requires attacker-controlled DNS and user to run `graphify add <malicious-url>`.

### Finding 2: Cypher Injection via f-string Interpolation of Sanitized Labels in Neo4j Push

- **Severity**: MEDIUM-HIGH
- **Category**: Injection
- **Location**: `graphify/export.py:917-918`, `graphify/export.py:927-929`
- **Description**: In `push_to_neo4j()`, the node label type (`ftype`) and relationship type (`rel`) are interpolated directly into Cypher queries via f-strings: `f"MERGE (n:{ftype} ...)"` and `f"MERGE (a)-[r:{rel}]->(b)"`. While `_safe_label()` strips non-alphanumeric chars from `ftype` and `_safe_rel()` does the same for `rel`, the properties are passed via parameters (`$id`, `$props`). However, if `_safe_label` or `_safe_rel` returned an empty string (edge case), the query could be malformed. More critically, the `to_cypher()` file export at line 327 uses `_cypher_escape()` which only escapes `\` and `'` -- it does not handle newlines or other Cypher special chars in string values.
- **Impact**: Malformed Cypher queries if edge cases arise; potential for Cypher injection in exported `.cypher` files if node labels contain crafted content.
- **Fix**: Use parameterized queries consistently (already done for `push_to_neo4j` property values -- extend to label/rel types by using `apoc.merge.node` or validating against a strict allowlist). For `to_cypher()`, escape newlines, tabs, and unicode in `_cypher_escape()`.
- **Confidence**: Medium -- requires crafted graph data reaching Neo4j export.

No findings strictly at CRITICAL severity level.

## Medium & Low Severity Findings

### Finding 3: Incomplete SSRF Blocklist for Cloud Metadata

- **Severity**: MEDIUM
- **Category**: SSRF
- **Location**: `graphify/security.py:19`
- **Description**: `_BLOCKED_HOSTS` only blocks `metadata.google.internal` and `metadata.google.com`. The AWS metadata endpoint at `169.254.169.254` is blocked by the IP range check, but the hostname-based block misses Azure's `metadata.azure.com` and other cloud metadata endpoints that may resolve to non-link-local IPs in some configurations.
- **Impact**: Potential metadata access on Azure or other cloud providers if DNS resolution bypasses the IP check.
- **Fix**: Add `metadata.azure.com`, `169.254.169.254` (as hostname), and consider `metadata.containers.internal` to the blocked hosts set.
- **Confidence**: Low -- IP range checks likely catch most cases.

### Finding 4: HTML Visualization Loads vis.js from Unpinned CDN

- **Severity**: MEDIUM
- **Category**: Supply chain
- **Location**: `graphify/export.py:438`
- **Description**: The generated HTML file loads `<script src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js">` without a pinned version or Subresource Integrity (SRI) hash. This means the latest version is fetched every time, and a compromise of the unpkg CDN or the vis-network npm package could inject malicious code.
- **Impact**: XSS or data exfiltration when users open the generated `graph.html` file in a browser.
- **Fix**: Pin to a specific version (e.g., `vis-network@9.1.9`) and add an `integrity` attribute with the SHA-384 hash.
- **Confidence**: High -- this is a well-known supply chain risk pattern.

### Finding 5: Git Hook Shell Script Could Be Hijacked via Symlinked `.git` Directory

- **Severity**: LOW
- **Category**: Logic
- **Location**: `graphify/hooks.py:129-136`
- **Description**: `_git_root()` walks up directories looking for a `.git` directory. If a malicious `.git` symlink exists higher in the path, hooks could be installed in an unexpected location. The `_hooks_dir()` function also trusts `core.hooksPath` from git config without path validation.
- **Impact**: A crafted repository could cause hooks to be written to an attacker-controlled directory.
- **Fix**: Resolve symlinks and validate that the hooks directory is within the repository root, or use `git rev-parse --git-dir` directly.
- **Confidence**: Low -- requires a pre-existing malicious repo structure.

### Finding 6: YAML Frontmatter Injection Edge Case

- **Severity**: LOW
- **Category**: Injection
- **Location**: `graphify/ingest.py:14-15`
- **Description**: `_yaml_str()` escapes backslashes, double quotes, and newlines, but does not escape the YAML `---` delimiter sequence. If a webpage title contains `---` on its own line, the generated markdown frontmatter could be malformed, potentially allowing metadata injection in downstream YAML parsers.
- **Impact**: Malformed frontmatter in ingested files; unlikely to cause code execution but could corrupt graph metadata.
- **Fix**: Also strip or escape `---` sequences in `_yaml_str()`, or use a proper YAML serializer.
- **Confidence**: Low.

### Finding 7: Unbounded `depth` Parameter in MCP Server

- **Severity**: LOW
- **Category**: DoS
- **Location**: `graphify/serve.py:240`
- **Description**: The `depth` parameter in `query_graph` is capped at 6 (`min(int(...), 6)`), which is good, but for large graphs this could still result in a BFS/DFS traversal touching thousands of nodes. The token_budget truncation mitigates output size but not computation time.
- **Impact**: Temporary performance degradation on very large graphs.
- **Fix**: Consider adding a node-count cap to BFS/DFS traversal (e.g., stop after visiting 500 nodes).
- **Confidence**: Low -- stdio server is local-only.

### Finding 8: Exception Details Leaked in MCP Tool Responses

- **Severity**: INFO
- **Category**: Information disclosure
- **Location**: `graphify/serve.py:359`
- **Description**: `except Exception as exc: return [TextContent(text=f"Error executing {name}: {exc}")]` exposes internal exception messages to the MCP client. While the client is typically a local AI assistant, this could leak filesystem paths or internal state.
- **Impact**: Minor information disclosure.
- **Fix**: Return a generic error message and log details to stderr.
- **Confidence**: High.

## Supply Chain Analysis

- **Dependencies**: All runtime dependencies are well-known, actively maintained packages (networkx, tree-sitter grammars). No pinned versions in `pyproject.toml` -- uses `>=` constraints only.
- **Optional deps**: `mcp`, `neo4j`, `pypdf`, `html2text`, `watchdog`, `graspologic`, `faster-whisper`, `yt-dlp` -- all reputable packages.
- **vis-network CDN**: Unpinned, no SRI hash (Finding 4).
- **No lock file**: No `requirements.txt` or `pip.lock` for reproducible builds. The `pyproject.toml` uses minimum version constraints only.
- **CI**: Uses `actions/checkout@v4` and `actions/setup-python@v5` -- pinned to major versions, which is acceptable. No third-party actions with security concerns.
- **No known CVEs** in direct dependencies based on current versions.

## Code Quality Assessment

- **Architecture**: Clean separation of concerns -- detect, extract, build, cluster, analyze, report, export pipeline. Each module has a single responsibility.
- **Error handling**: Generally good. Graceful degradation for missing optional dependencies. Tree-sitter parsing uses `errors="replace"` throughout. Some broad `except Exception: pass` patterns in watch.py could mask real errors.
- **Test coverage**: 28 test files covering all major modules. Tests for security functions (SSRF, path traversal, sanitization). Good fixture-based testing.
- **Documentation**: Comprehensive README, ARCHITECTURE.md, SECURITY.md, CHANGELOG.md. Security model is well-documented with threat surface table.
- **Code organization**: The `__main__.py` at ~1400 lines is oversized -- CLI argument parsing, install logic for 15+ platforms, and command handlers are all in one file.

## Contribution Opportunities

1. **File**: `graphify/export.py:438` -- **Issue**: Unpinned CDN script tag. **Fix**: Pin vis-network version + add SRI hash. **Effort**: Trivial.

2. **File**: `graphify/security.py:50-63` -- **Issue**: TOCTOU DNS rebinding in SSRF validation. **Fix**: Pin resolved IP for the actual connection. **Effort**: Medium.

3. **File**: `graphify/export.py:315-317` -- **Issue**: `_cypher_escape()` incomplete (no newline/tab/unicode handling). **Fix**: Extend escaping to cover all Cypher special chars. **Effort**: Trivial.

4. **File**: `graphify/__main__.py` -- **Issue**: Monolithic 1400-line CLI file. **Fix**: Extract platform install logic and command handlers into separate modules. **Effort**: Medium.

5. **File**: `graphify/security.py:19` -- **Issue**: Incomplete cloud metadata blocklist. **Fix**: Add Azure, AWS hostname, and other cloud metadata endpoints. **Effort**: Trivial.

## Draft PRs

### PR 1: Pin vis-network CDN and add SRI hash

- **PR Title**: `fix: pin vis-network CDN version and add subresource integrity hash`
- **Branch name**: `fix/pin-visnetwork-sri`
- **Files to modify**: `graphify/export.py`
- **Changes**: Replace `https://unpkg.com/vis-network/standalone/umd/vis-network.min.js` with a version-pinned URL (e.g., `https://unpkg.com/vis-network@9.1.9/standalone/umd/vis-network.min.js`) and add `integrity="sha384-..."` and `crossorigin="anonymous"` attributes to the script tag.
- **Impact**: Prevents supply chain attacks via CDN compromise. Zero risk of breaking existing functionality.

### PR 2: Harden Cypher escaping for Neo4j export

- **PR Title**: `fix: escape newlines and tabs in Cypher string literals`
- **Branch name**: `fix/cypher-escape-hardening`
- **Files to modify**: `graphify/export.py`
- **Changes**: Extend `_cypher_escape()` to also escape `\n`, `\r`, `\t`, and null bytes. Add test cases in `tests/test_export.py` for edge-case node labels containing these characters.
- **Impact**: Prevents malformed Cypher output when graph data contains newlines or control characters in labels/relations.

### PR 3: Expand cloud metadata blocklist in SSRF protection

- **PR Title**: `fix: add Azure and additional cloud metadata endpoints to SSRF blocklist`
- **Branch name**: `fix/ssrf-metadata-blocklist`
- **Files to modify**: `graphify/security.py`, `tests/test_security.py`
- **Changes**: Add `"metadata.azure.com"`, `"169.254.169.254"`, `"metadata.containers.internal"` to `_BLOCKED_HOSTS`. Add test cases for these hosts.
- **Impact**: Closes a gap in SSRF protection for Azure and container environments.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 7 |
| Documentation | 8 |
| Test Coverage | 7 |
| Contribution Potential | 6 |

## Summary

- **Total findings by severity**: Critical: 0, High: 0, Medium-High: 2, Medium: 2, Low: 3, Info: 1
- **Overall risk level**: **LOW-MEDIUM**
- **Top 3 recommendations**:
  1. Pin the vis-network CDN URL to a specific version with an SRI hash to prevent supply chain compromise via the generated HTML visualization
  2. Extend `_cypher_escape()` to handle newlines, tabs, and null bytes for safer Neo4j Cypher export
  3. Expand the cloud metadata hostname blocklist in SSRF validation to cover Azure and container environments

The project demonstrates strong security awareness -- a dedicated `security.py` module, SSRF protection with redirect validation, HTML escaping in visualizations, label sanitization, path traversal guards, and a well-documented threat model in SECURITY.md. The findings are primarily edge cases and defense-in-depth improvements rather than exploitable vulnerabilities in typical usage (local development tool).
