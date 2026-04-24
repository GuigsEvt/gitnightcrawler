# Security Audit: safishamsi/graphify

## Repository Overview

Graphify is a Python CLI tool and Claude Code skill that turns folders of code, documents, papers, images, and videos into a queryable knowledge graph. It uses tree-sitter for AST-based structural extraction across 20+ languages, NetworkX for graph construction/clustering, and optionally serves the graph via an MCP stdio server or exports to HTML (vis.js), Obsidian vaults, Neo4j Cypher, GraphML, and SVG. It supports URL ingestion (tweets, arXiv, web pages, PDFs, YouTube), file watching, git hook integration, and incremental updates.

- **Tech stack**: Python 3.10+, tree-sitter, NetworkX, optional deps (mcp, neo4j, pypdf, watchdog, faster-whisper, yt-dlp, matplotlib)
- **Maturity**: Growing (v0.4.31, active development, good test coverage for a project this size)
- **Categories detected**: ai|actions|mobile

## Critical & High Severity Findings

### Finding 1: SSRF TOCTOU Race in DNS Resolution

- **Severity**: MEDIUM-HIGH (downgraded from HIGH due to local-tool context)
- **Category**: SSRF
- **Location**: `graphify/security.py:50-63`
- **Description**: `validate_url()` resolves the hostname via `socket.getaddrinfo()` and checks if the IP is private/reserved, then later `safe_fetch()` makes a separate HTTP request. Between validation and fetch, the DNS record could change (DNS rebinding attack). An attacker-controlled DNS server could return a public IP during validation, then a private IP (e.g., `169.254.169.254`) during the actual fetch.
- **Impact**: SSRF to internal services/cloud metadata endpoints in environments where graphify's `ingest` command is exposed to untrusted URL input.
- **Fix**: Resolve DNS once and connect to the validated IP directly, or use a custom socket factory that pins the resolved address. Alternatively, re-validate the IP at the socket level after connection.
- **Confidence**: Medium -- exploitability depends on the deployment context; as a local CLI tool the attack surface is narrow.

### Finding 2: DNS Resolution Failure Silently Bypasses SSRF Check

- **Severity**: MEDIUM
- **Category**: SSRF
- **Location**: `graphify/security.py:61-62`
- **Description**: When `socket.getaddrinfo()` raises `socket.gaierror`, the exception is silently caught with `pass`, and the URL is returned as valid. The comment says "DNS failure will surface later during fetch," but this means a hostname that fails initial resolution (e.g., due to a transient error) bypasses the private-IP check entirely. If DNS later resolves during the actual fetch, no IP validation occurs.
- **Impact**: Potential SSRF bypass if DNS resolution is unreliable or adversarially manipulated.
- **Fix**: Fail closed -- raise `ValueError` on DNS resolution failure instead of passing through.
- **Confidence**: Medium

No other critical/high severity findings identified.

## Medium & Low Severity Findings

### Finding 3: Unpinned CDN Dependency (vis-network)

- **Severity**: MEDIUM
- **Category**: Supply chain
- **Location**: `graphify/export.py:438`
- **Description**: The HTML visualization loads vis-network from `https://unpkg.com/vis-network/standalone/umd/vis-network.min.js` without a version pin or SRI (Subresource Integrity) hash. If unpkg or the vis-network package is compromised, all generated HTML files will execute malicious JavaScript.
- **Impact**: XSS/code execution in any browser that opens a graphify-generated HTML file.
- **Fix**: Pin the version (e.g., `vis-network@9.1.9`) and add an `integrity` attribute with the expected SHA hash.
- **Confidence**: High

### Finding 4: Legend innerHTML Injection (Residual XSS Surface)

- **Severity**: LOW
- **Category**: XSS
- **Location**: `graphify/export.py:247-249`
- **Description**: The legend `innerHTML` assignment uses `c.color` without escaping: `style="background:${c.color}"`. The color values come from the hardcoded `COMMUNITY_COLORS` array, so this is not currently exploitable. However, `c.label` is server-side HTML-escaped at line 418 (`_html.escape(sanitize_label(...))`), and `c.count` is an integer -- both safe. The `esc()` helper is not applied to legend items, but the data is pre-escaped server-side.
- **Impact**: No current impact -- defense in depth only.
- **Fix**: Apply the client-side `esc()` helper to `c.label` in the legend template for consistency, or add a comment documenting that server-side escaping handles it.
- **Confidence**: Low (not currently exploitable)

### Finding 5: Neo4j Cypher f-string with Sanitized but Unparameterized Labels

- **Severity**: LOW
- **Category**: Injection
- **Location**: `graphify/export.py:917-918, 927-929`
- **Description**: `push_to_neo4j()` uses f-strings to embed `ftype` and `rel` into Cypher queries: `f"MERGE (n:{ftype} ...)"`. Both values are sanitized (`_safe_label` strips non-alphanumeric, `_safe_rel` strips non-alphanumeric), and all data values use parameterized queries (`$id`, `$props`, `$src`, `$tgt`). The sanitization is correct, but f-string Cypher is a code smell.
- **Impact**: None with current sanitization. If sanitization is accidentally weakened, Cypher injection becomes possible.
- **Fix**: Add a comment documenting the sanitization contract, or use APOC procedures that accept label names as parameters.
- **Confidence**: Low (not currently exploitable)

### Finding 6: `to_cypher()` Uses String Escaping Instead of Parameterization

- **Severity**: LOW
- **Category**: Injection
- **Location**: `graphify/export.py:320-339`
- **Description**: `to_cypher()` generates Cypher as a text file using `_cypher_escape()` (backslash/single-quote escaping). This is for offline import, not direct execution, but the escaping only handles `\` and `'` -- it doesn't escape unicode control characters or null bytes that could affect some Neo4j parsers.
- **Impact**: Minimal -- this generates a `.cypher` file for manual import, not direct database execution.
- **Fix**: Also strip/escape control characters in `_cypher_escape()`.
- **Confidence**: Low

### Finding 7: `save_query_result` Node Names Not Sanitized in YAML

- **Severity**: LOW
- **Category**: Injection
- **Location**: `graphify/ingest.py:266`
- **Description**: `source_nodes` list items are embedded in YAML frontmatter as `["{n}"]` without escaping via `_yaml_str()`. If a node name contains `"`, it could break the YAML structure.
- **Impact**: Malformed YAML frontmatter in saved query results. Not a security issue per se, but could cause parsing errors.
- **Fix**: Apply `_yaml_str()` to each node name: `f'"{_yaml_str(n)}"'`.
- **Confidence**: High

### Finding 8: SHA-1 Used for URL Hashing in Transcribe

- **Severity**: INFO
- **Category**: Crypto
- **Location**: `graphify/transcribe.py:59`
- **Description**: `hashlib.sha1(url.encode()).hexdigest()[:12]` is used for generating cache filenames from URLs. SHA-1 is cryptographically broken for collision resistance, but here it's only used as a filename deduplication key, not for security purposes.
- **Impact**: None -- collision in 12-char hex prefix could overwrite a cached file, but this is a usability issue not a security one.
- **Fix**: Consider using SHA-256 for consistency with the rest of the codebase (e.g., `cache.py` uses SHA-256).
- **Confidence**: High (not a vulnerability)

## Supply Chain Analysis

**Dependencies (core)**:
- `networkx` -- well-maintained, widely used
- `tree-sitter>=0.23.0` + 20 language grammars -- actively maintained by the tree-sitter org
- `setuptools>=68` -- standard build backend

**Optional dependencies**:
- `mcp` -- MCP SDK, relatively new but from Anthropic
- `neo4j` -- official Neo4j Python driver
- `pypdf`, `html2text` -- well-established
- `watchdog` -- well-maintained filesystem watcher
- `graspologic` -- Microsoft Research graph statistics library
- `faster-whisper`, `yt-dlp` -- active community projects
- `python-docx`, `openpyxl` -- widely used Office format libraries
- `matplotlib` -- standard plotting library

**Assessment**: Dependencies are healthy and well-maintained. No known CVEs in the pinned versions. The `vis-network` CDN dependency (unpinned, no SRI) is the main supply chain concern.

**CI/CD** (`ci.yml`):
- Uses pinned action versions (`actions/checkout@v4`, `actions/setup-python@v5`) -- good
- No secrets exposure in workflow
- No command injection vectors (no `${{ github.event... }}` in `run:` blocks)
- Workflow triggers are appropriately scoped

## Code Quality Assessment

**Architecture**: Well-organized pipeline architecture (detect -> extract -> build -> cluster -> analyze -> report -> export). Each module has a single responsibility. The `security.py` module centralizes all security-sensitive operations.

**Error handling**: Consistent try/except patterns with graceful degradation. Optional dependencies handled via ImportError. The `errors="replace"` pattern for encoding is used throughout.

**Test coverage**: Good coverage of security-critical paths (`test_security.py` covers URL validation, path traversal, label sanitization, fetch guards). Tests exist for extraction, clustering, validation, serving, and more. 14 test files total.

**Documentation**: Excellent -- `SECURITY.md` documents the threat model comprehensively, `ARCHITECTURE.md` explains the pipeline, and the code has clear docstrings. The `SECURITY.md` threat surface table is notably thorough for a project this size.

**Security awareness**: The codebase shows strong security consciousness:
- No `shell=True` anywhere
- No `eval`/`exec`
- Sensitive file detection and skipping
- `followlinks=False` by default in `os.walk`
- SSRF protections with redirect re-validation
- XSS protections with multi-layer escaping
- Path traversal guards
- `</script>` sequence escaping in JSON embeddings

## Contribution Opportunities

1. **File**: `graphify/security.py:61-62`
   - **Issue**: DNS resolution failure silently bypasses private-IP check
   - **Fix**: Raise `ValueError` on `socket.gaierror` instead of `pass`
   - **Effort**: Trivial

2. **File**: `graphify/export.py:438`
   - **Issue**: Unpinned vis-network CDN without SRI hash
   - **Fix**: Pin version and add `integrity` attribute
   - **Effort**: Trivial

3. **File**: `graphify/ingest.py:266`
   - **Issue**: `source_nodes` not YAML-escaped in frontmatter
   - **Fix**: Wrap with `_yaml_str()`
   - **Effort**: Trivial

4. **File**: `graphify/security.py:50-63`
   - **Issue**: TOCTOU between DNS validation and HTTP fetch
   - **Fix**: Pin resolved IP and connect directly, or use a custom resolver
   - **Effort**: Small

5. **File**: `graphify/export.py:315-317`
   - **Issue**: `_cypher_escape` doesn't handle control characters
   - **Fix**: Add control character stripping
   - **Effort**: Trivial

## Draft PRs

### PR 1: Close DNS resolution failure bypass in SSRF validation

- **PR Title**: `fix: fail closed on DNS resolution error in validate_url()`
- **Branch name**: `fix/ssrf-dns-fail-closed`
- **Files to modify**: `graphify/security.py`, `tests/test_security.py`
- **Changes**: In `validate_url()`, replace `except socket.gaierror: pass` with raising a `ValueError` that blocks the URL. Add test case for DNS failure behavior.
- **Impact**: Eliminates a path where SSRF validation can be bypassed when DNS resolution fails transiently.

### PR 2: Pin vis-network CDN version and add SRI hash

- **PR Title**: `fix: pin vis-network version and add subresource integrity hash`
- **Branch name**: `fix/vis-network-sri`
- **Files to modify**: `graphify/export.py`
- **Changes**: Change the unpkg URL to include a specific version (e.g., `vis-network@9.1.9`) and add `integrity="sha384-..."` and `crossorigin="anonymous"` attributes to the script tag.
- **Impact**: Prevents supply chain attacks via CDN compromise from affecting generated HTML files.

### PR 3: Fix YAML injection in source_nodes frontmatter

- **PR Title**: `fix: escape source_nodes in query result YAML frontmatter`
- **Branch name**: `fix/yaml-source-nodes-escape`
- **Files to modify**: `graphify/ingest.py`, `tests/test_ingest.py`
- **Changes**: Apply `_yaml_str()` to each node name in the `source_nodes` list at line 266. Add test with node names containing double quotes and newlines.
- **Impact**: Prevents malformed YAML output when node names contain special characters.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 9 |
| Test Coverage | 7 |
| Contribution Potential | 6 |

## Summary

- **Total findings by severity**: Critical: 0, High: 0, Medium: 3, Low: 4, Info: 1
- **Overall risk level**: **LOW**
- **Top 3 recommendations**:
  1. Fail closed on DNS resolution errors in `validate_url()` to prevent SSRF bypass
  2. Pin the vis-network CDN version and add SRI integrity hash to prevent supply chain attacks on generated HTML
  3. Escape `source_nodes` in YAML frontmatter to prevent injection

This is a well-secured codebase for its category. The maintainer has clearly thought about the threat model (as evidenced by the thorough `SECURITY.md`) and implemented defense-in-depth across SSRF, XSS, path traversal, and injection vectors. The findings are mostly hardening opportunities rather than exploitable vulnerabilities, given that graphify operates as a local development tool.
