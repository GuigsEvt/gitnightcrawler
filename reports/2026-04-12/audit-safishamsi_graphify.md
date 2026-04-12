I now have a comprehensive understanding of the codebase. Let me produce the security audit report.

# Security Audit: safishamsi/graphify

## Repository Overview

Graphify is a Python CLI tool and AI coding assistant skill that turns any folder of code, docs, papers, images, or videos into a queryable knowledge graph. It uses tree-sitter for deterministic AST extraction, NetworkX for graph construction, Leiden/Louvain for community detection, and outputs interactive HTML visualizations, JSON graphs, Obsidian vaults, Neo4j Cypher, and markdown reports. It integrates with Claude Code, Codex, OpenCode, Cursor, Gemini CLI, and other AI coding tools as a skill/plugin.

- **Tech stack**: Python 3.10+, NetworkX, tree-sitter, optional deps (MCP, Neo4j, pypdf, watchdog, faster-whisper, yt-dlp, graspologic)
- **Maturity**: Growing (v0.4.2, active development, good test coverage)
- **Categories detected**: ai|actions|mobile

## Critical & High Severity Findings

### Finding 1: Neo4j Cypher Injection via Dynamic Node Labels

- **Severity**: HIGH
- **Category**: injection
- **Location**: `graphify/export.py:893-898`
- **Description**: The `push_to_neo4j` function constructs Cypher queries using f-strings with `_safe_label()` to sanitize Neo4j node labels. While `_safe_label()` strips non-alphanumeric chars, the relationship type in `_safe_rel()` at line 874 and the f-string query at line 905 (`f"MERGE (a)-[r:{rel}]->(b)"`) inject the relationship type directly into the Cypher query without parameterization. If `data.get("relation")` contains crafted content like `RELATED_TO]->(b) DELETE b//`, after `_safe_rel` transforms it to `RELATED_TO____B__DELETE_B__`, it would be safe. However, the node label at line 895 (`f"MERGE (n:{ftype} {{id: $id}})"`) uses `_safe_label` which only strips non-`[A-Za-z0-9_]` -- this is adequate but the pattern of string interpolation in Cypher is inherently fragile.
- **Impact**: In practice, `_safe_label` and `_safe_rel` strip dangerous characters, limiting exploitability. However, the pattern is fragile and could break if sanitization regresses.
- **Fix**: Use parameterized queries exclusively. For dynamic labels/relationship types (which Cypher doesn't support as parameters), validate against an allowlist instead of regex stripping.
- **Confidence**: medium

### Finding 2: SSRF via DNS Rebinding (TOCTOU in validate_url)

- **Severity**: HIGH
- **Category**: ssrf
- **Location**: `graphify/security.py:50-63`
- **Description**: `validate_url()` resolves the hostname via `socket.getaddrinfo()` to check for private IPs, then `safe_fetch()` opens a new connection that resolves the hostname again. An attacker controlling DNS could return a public IP during validation but a private/metadata IP during the actual fetch (DNS rebinding attack).
- **Impact**: Could bypass SSRF protections to reach cloud metadata endpoints (169.254.169.254) or internal services. Only exploitable if the attacker controls the DNS for the target hostname and the user explicitly passes that URL to `graphify ingest`.
- **Fix**: Pin the resolved IP from validation and use it for the actual connection, or use `socket.create_connection` with the pre-resolved address. Alternatively, validate the IP at the socket level after connection.
- **Confidence**: medium (requires user to `ingest` an attacker-controlled URL)

### Finding 3: Missing AWS Metadata Endpoint in SSRF Blocklist

- **Severity**: HIGH
- **Category**: ssrf
- **Location**: `graphify/security.py:19`
- **Description**: `_BLOCKED_HOSTS` only contains Google Cloud metadata endpoints (`metadata.google.internal`, `metadata.google.com`). The AWS metadata endpoint (`169.254.169.254`) is blocked by the private IP check, but the hostname-based block misses AWS-specific hostnames. More critically, Azure IMDS (`169.254.169.254` with header `Metadata: true`) and other cloud providers' metadata endpoints aren't explicitly listed.
- **Impact**: The private IP range check at lines 54-58 does cover 169.254.x.x via `is_link_local`, so this is mitigated. The hostname blocklist is defense-in-depth but incomplete.
- **Fix**: Add `169.254.169.254` to `_BLOCKED_HOSTS` for defense-in-depth, along with Azure and other cloud metadata hostnames.
- **Confidence**: low (the IP-based check already covers this)

## Medium & Low Severity Findings

### Finding 4: `sanitize_label` Does Not HTML-Escape

- **Severity**: MEDIUM
- **Category**: xss
- **Location**: `graphify/security.py:188-197`
- **Description**: `sanitize_label()` strips control characters and caps length but does not HTML-escape. The docstring explicitly states "For direct HTML injection, wrap the result with html.escape()." The `to_html()` function in `export.py` does use `_html.escape()` for `title` attributes (line 367, 384, 407), and the JavaScript `esc()` helper escapes innerHTML. However, node labels are injected directly into `vis_nodes[].label` (line 356) without HTML escaping -- vis.js renders these as text nodes not innerHTML, so this is safe by the library's behavior, but it's fragile.
- **Fix**: Document clearly that vis.js `label` property is text-safe. For `title` attributes (tooltip), ensure `_html.escape()` is always applied (which it is).
- **Confidence**: low

### Finding 5: `--break-system-packages` Flag in Skill Install Script

- **Severity**: MEDIUM
- **Category**: supply-chain
- **Location**: `graphify/skill.md:75`
- **Description**: The install step in `skill.md` includes `--break-system-packages` as a fallback: `pip install graphifyy -q --break-system-packages`. This bypasses PEP 668 protections that prevent pip from modifying system-managed Python installations.
- **Impact**: Could corrupt system Python installation on managed systems (Debian 12+, Ubuntu 23.04+).
- **Fix**: Remove `--break-system-packages` fallback. Recommend `pipx install graphifyy` instead, or guide users to create a venv.
- **Confidence**: high

### Finding 6: Skill.md Instructs Agents to Execute Arbitrary Python Code

- **Severity**: MEDIUM
- **Category**: prompt-injection
- **Location**: `graphify/skill.md` (all skill-*.md variants)
- **Description**: The skill files instruct AI coding agents to run multi-line Python code blocks directly via bash. While this is the intended design (the agent runs graphify's pipeline), the pattern means any modification to the skill file by a malicious actor could inject arbitrary code that the AI agent would execute.
- **Impact**: If a user installs a tampered version of graphify, the skill file could instruct the AI agent to execute malicious code. This is inherent to the skill/agent paradigm but worth noting.
- **Fix**: Pin skill file checksums in the version stamp. Add integrity verification in `_check_skill_version()`.
- **Confidence**: medium

### Finding 7: DNS Lookup Failure Silently Passes Validation

- **Severity**: LOW
- **Category**: ssrf
- **Location**: `graphify/security.py:61-62`
- **Description**: When `socket.getaddrinfo()` raises `socket.gaierror` (DNS failure), the code silently passes with `pass`. This means a URL with an unresolvable hostname passes validation -- the fetch will fail later, but the validation doesn't block it.
- **Impact**: Minimal -- the fetch will fail with a connection error. No security bypass.
- **Fix**: Consider raising `ValueError` on DNS failure to fail fast.
- **Confidence**: low

### Finding 8: No Rate Limiting on `ingest` URL Fetches

- **Severity**: LOW
- **Category**: abuse
- **Location**: `graphify/ingest.py:184-235`
- **Description**: The `ingest()` function has no rate limiting. An automated caller could use it to make many rapid outbound requests.
- **Impact**: Could be used for light abuse, but graphify is a local CLI tool, and the user must explicitly provide each URL.
- **Fix**: Add optional rate limiting or batch limits.
- **Confidence**: low

### Finding 9: SHA-1 Used for yt-dlp Download Caching

- **Severity**: LOW
- **Category**: crypto
- **Location**: `graphify/transcribe.py:59`
- **Description**: `hashlib.sha1()` is used to generate cache filenames for downloaded audio. SHA-1 is cryptographically broken for collision resistance.
- **Impact**: Minimal -- this is only used for cache key generation, not security. Two different URLs producing the same SHA-1 prefix (12 chars) would overwrite cached files, which is a correctness issue, not a security one.
- **Fix**: Use SHA-256 for consistency with the rest of the codebase (cache.py uses SHA-256).
- **Confidence**: high

## Supply Chain Analysis

**Dependencies** (from `pyproject.toml`):
- **networkx**: Well-maintained, no known critical CVEs. Core dependency.
- **tree-sitter** + language grammars (20 packages): Actively maintained by the tree-sitter org. Low risk.
- **Optional deps**: mcp, neo4j, pypdf, html2text, watchdog, graspologic, python-docx, openpyxl, faster-whisper, yt-dlp -- all mainstream packages.

**Observations**:
- No `requirements.txt` or lock file -- dependency versions are unpinned beyond `tree-sitter>=0.23.0`. This allows supply chain attacks via dependency confusion or malicious updates.
- The package is named `graphifyy` (double y) on PyPI -- unusual naming that could lead to typosquatting confusion with a potential `graphify` package.
- No dependency pinning in CI (`ci.yml` uses `pip install -e ".[mcp,pdf,watch]"` without pins).

## Code Quality Assessment

**Architecture**: Well-organized modular design. Clear separation of concerns: detect -> extract -> build -> cluster -> analyze -> report -> export. Each module has a single responsibility.

**Error handling**: Consistent use of try/except with informative error messages. Graceful degradation for optional dependencies (ImportError handling throughout). JSON decode errors handled explicitly.

**Test coverage**: 28 test files covering all major modules including a dedicated `test_security.py`. Tests cover URL validation, path traversal, label sanitization, and fetch guards.

**Documentation**: Excellent -- SECURITY.md documents the threat model explicitly, ARCHITECTURE.md describes the pipeline, and skill files provide comprehensive usage instructions. Multiple language translations of README.

## Contribution Opportunities

1. **File**: `graphify/security.py:50-63`
   - **Issue**: TOCTOU DNS rebinding vulnerability in SSRF validation
   - **Fix**: Pin resolved IP and connect using the validated address
   - **Effort**: medium

2. **File**: `graphify/skill.md:75` (and all skill-*.md variants)
   - **Issue**: `--break-system-packages` pip flag in install instructions
   - **Fix**: Replace with `pipx install graphifyy` recommendation
   - **Effort**: trivial

3. **File**: `graphify/transcribe.py:59`
   - **Issue**: SHA-1 used for cache keys instead of SHA-256
   - **Fix**: Replace `hashlib.sha1` with `hashlib.sha256`
   - **Effort**: trivial

4. **File**: `pyproject.toml:13-36`
   - **Issue**: No dependency version pinning or lock file
   - **Fix**: Add upper bounds to dependency versions and/or add a lock file
   - **Effort**: small

5. **File**: `graphify/export.py:882-910`
   - **Issue**: Cypher query construction uses string interpolation for labels/relationship types
   - **Fix**: Validate against an allowlist, add integration tests
   - **Effort**: small

## Draft PRs

### PR 1
- **PR Title**: `fix: replace SHA-1 with SHA-256 for audio cache keys`
- **Branch name**: `fix/sha256-audio-cache`
- **Files to modify**: `graphify/transcribe.py`
- **Changes**: Replace `hashlib.sha1(url.encode()).hexdigest()[:12]` with `hashlib.sha256(url.encode()).hexdigest()[:12]` at line 59. This aligns with `cache.py` which already uses SHA-256.
- **Impact**: Eliminates use of a cryptographically broken hash function. Cache keys become collision-resistant.

### PR 2
- **PR Title**: `fix: remove --break-system-packages from install instructions`
- **Branch name**: `fix/remove-break-system-packages`
- **Files to modify**: `graphify/skill.md`, `graphify/skill-codex.md`, `graphify/skill-opencode.md`, `graphify/skill-aider.md`, `graphify/skill-copilot.md`, `graphify/skill-claw.md`, `graphify/skill-droid.md`, `graphify/skill-trae.md`, `graphify/skill-windows.md`
- **Changes**: Remove `--break-system-packages` fallback from pip install commands. Add `pipx install graphifyy` as the primary install method with `pip install --user graphifyy` as fallback.
- **Impact**: Prevents system Python corruption on PEP 668 systems. Follows Python packaging best practices.

### PR 3
- **PR Title**: `fix: add AWS/Azure metadata hosts to SSRF blocklist`
- **Branch name**: `fix/ssrf-blocklist-expansion`
- **Files to modify**: `graphify/security.py`, `tests/test_security.py`
- **Changes**: Add `169.254.169.254` and Azure IMDS hostname to `_BLOCKED_HOSTS`. Add corresponding test cases. While the IP range check already blocks these, explicit hostname blocking provides defense-in-depth.
- **Impact**: Hardens SSRF protection for cloud deployments.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 9 |
| Test Coverage | 7 |
| Contribution Potential | 6 |

## Summary

- **Total findings by severity**: Critical: 0, High: 3, Medium: 3, Low: 3, Info: 0
- **Overall risk level**: **MEDIUM**
- **Top 3 recommendations**:
  1. Address DNS rebinding TOCTOU in `validate_url()` by pinning the resolved IP for subsequent connections
  2. Remove `--break-system-packages` from skill install instructions and recommend `pipx`
  3. Replace SHA-1 with SHA-256 in `transcribe.py` for consistency and correctness

The codebase demonstrates strong security awareness -- it has a dedicated `security.py` module, a threat model in `SECURITY.md`, SSRF protections with redirect re-validation, path traversal guards, label sanitization, and security-specific tests. The findings are primarily hardening opportunities rather than exploitable vulnerabilities. The project's attack surface is limited by its nature as a local CLI tool where the user explicitly provides all inputs.
