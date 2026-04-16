Now I have all the information needed to compile the final report.

# Security Audit: MemPalace/mempalace

## Repository Overview

MemPalace is a local-first AI memory system that stores verbatim conversation transcripts and project data in a searchable "palace" structure (wings, rooms, drawers) backed by ChromaDB for vector search and SQLite for a knowledge graph. It integrates with Claude Code and Codex via MCP server, CLI, and hook scripts. No cloud APIs are required for core operations.

- **Tech stack**: Python 3.9+, ChromaDB (vector store), SQLite (knowledge graph), MCP protocol (JSON-RPC over stdio), shell hooks (bash)
- **Languages**: Python, Bash
- **Frameworks**: None (stdlib-heavy, minimal dependencies)
- **Maturity**: Growing (v3.3.0, Beta status, active development, 85%+ test coverage)
- **Categories**: ai | actions

---

## Critical & High Severity Findings

### HIGH-1: Shell `eval` on Partially Sanitized Input in Save Hook

- **Severity**: HIGH
- **Category**: injection
- **Location**: `hooks/mempal_save_hook.sh:70-83`
- **Description**: The save hook reads JSON from stdin and uses Python to sanitize values, then passes them through `eval` to set shell variables. While the sanitizer (`re.sub(r'[^a-zA-Z0-9_/.\-~]', '', str(s))`) strips most dangerous characters, the allowed characters `/`, `.`, `~` in file paths combined with `eval` create a narrow attack surface. If Python's output were ever malformed (e.g., due to a Python runtime error fallback to stderr redirect `2>/dev/null` silencing), `eval` would execute whatever remains on the line. The `2>/dev/null` suppression of Python errors means a broken Python sanitizer would silently produce empty/malformed output that `eval` processes without warning.
- **Impact**: If an attacker can control the JSON input to the hook (e.g., via a malicious Claude Code plugin or compromised transcript), they could potentially inject shell commands. The `2>/dev/null` suppresses any Python errors that would alert to problems.
- **Fix**: Replace `eval` with explicit variable extraction using `read` or jq:
  ```bash
  SESSION_ID=$(echo "$INPUT" | python3 -c "..." 2>/dev/null | head -1)
  ```
  Or use `jq` with the safe lambda approach and avoid `eval` entirely.
- **Confidence**: medium (the sanitizer is strong, but `eval` is inherently risky)

### HIGH-2: Missing `permissions` Block in CI Workflow

- **Severity**: HIGH
- **Category**: supply-chain / privilege escalation
- **Location**: `.github/workflows/ci.yml` (entire file, no `permissions:` key)
- **Description**: The CI workflow has no explicit `permissions:` block. On repositories with default token permissions set to "Read and write", this grants the `GITHUB_TOKEN` write access to contents, packages, deployments, issues, and PRs across all four jobs (test-linux, test-windows, test-macos, lint).
- **Impact**: A compromised test dependency (e.g., via a supply chain attack on `chromadb` or `pytest`) executing arbitrary code during `pip install` or `pytest` could use the write-scoped token to push malicious commits, create releases, or modify workflow files.
- **Fix**: Add at the top level of `ci.yml`:
  ```yaml
  permissions:
    contents: read
  ```
- **Confidence**: high

---

## Medium & Low Severity Findings

### MEDIUM-1: GitHub Actions Not Pinned to Commit SHAs

- **Severity**: MEDIUM
- **Category**: supply-chain
- **Location**: All workflows — `ci.yml:16-17,26-27,36-37,45-46`, `deploy-docs.yml:26,32,34,49,66`
- **Description**: All GitHub Actions use mutable version tags (`@v4`, `@v6`, `@v2`) instead of immutable commit SHAs. Tags can be force-pushed by action maintainers (or attackers who compromise their repos).
- **Impact**: A compromised action could exfiltrate secrets, modify code, or inject malware into builds.
- **Fix**: Pin all actions to full commit SHAs. Example: `actions/checkout@<sha>`.
- **Confidence**: high

### MEDIUM-2: Third-Party Action from Non-GitHub Organization

- **Severity**: MEDIUM
- **Category**: supply-chain
- **Location**: `.github/workflows/deploy-docs.yml:34`
- **Description**: `oven-sh/setup-bun@v2` is a third-party action from outside the `actions/` org, not pinned to SHA.
- **Impact**: Higher supply-chain risk than first-party actions. Compromise of the `oven-sh` org would affect this workflow.
- **Fix**: Pin to commit SHA: `oven-sh/setup-bun@<sha>`.
- **Confidence**: high

### MEDIUM-3: `chromadb` Dependency Has No Upper Version Bound

- **Severity**: MEDIUM
- **Category**: supply-chain
- **Location**: `pyproject.toml:28`
- **Description**: `chromadb>=0.5.0` allows any future major version. ChromaDB has had breaking API changes between majors. A malicious or buggy release could be pulled in automatically.
- **Impact**: Build breakage or, in a supply-chain attack scenario, code execution during install (via setup.py/pyproject hooks).
- **Fix**: Add upper bound: `chromadb>=0.5.0,<2`.
- **Confidence**: medium

### MEDIUM-4: `yaml.dump()` Without Explicit SafeDumper

- **Severity**: MEDIUM
- **Category**: unsafe serialization
- **Location**: `mempalace/room_detector_local.py:296`
- **Description**: `yaml.dump(config, f, ...)` is called without `Dumper=yaml.SafeDumper`. While the `config` dict currently contains only safe string/list types, if the data ever includes custom Python objects, this could lead to arbitrary code execution on `yaml.load()`.
- **Impact**: Low currently (data is constructed from safe primitives), but a future code change could introduce risk.
- **Fix**: Add `Dumper=yaml.SafeDumper` to the `yaml.dump()` call.
- **Confidence**: low (defense-in-depth)

### LOW-1: Bare `except` in Hook Shell Script

- **Severity**: LOW
- **Category**: error handling
- **Location**: `hooks/mempal_save_hook.sh:111` (Python block at lines 98-114)
- **Description**: `except:` without specifying exception type catches all exceptions including `KeyboardInterrupt` and `SystemExit`, silently swallowing errors.
- **Impact**: Debugging difficulty; unexpected behavior if the Python process receives signals.
- **Fix**: Use `except (json.JSONDecodeError, KeyError, TypeError):` instead.
- **Confidence**: high

### LOW-2: Export Path Not Validated Against User Input

- **Severity**: LOW
- **Category**: path traversal
- **Location**: `mempalace/exporter.py:51,90-92`
- **Description**: `export_palace()` creates directories based on wing/room names from ChromaDB metadata. While `_safe_path_component()` sanitizes names, the `output_dir` parameter itself is not validated for symlink or path traversal attacks.
- **Impact**: If `output_dir` is user-controlled and points to a symlink, files could be written to unintended locations. Mitigated by the fact that wing/room names are sanitized before use as path components.
- **Fix**: Resolve `output_dir` and verify it's not a symlink: `os.path.realpath(output_dir)`.
- **Confidence**: low

### LOW-3: Pre-commit Hook Not SHA-Pinned

- **Severity**: LOW
- **Category**: supply-chain
- **Location**: `.pre-commit-config.yaml:2-6`
- **Description**: `astral-sh/ruff-pre-commit` is pinned to tag `v0.4.10` rather than a commit SHA.
- **Impact**: Tag could be force-pushed. Affects developer machines running `pre-commit install`.
- **Fix**: Pin to commit SHA alongside the version tag comment.
- **Confidence**: medium

### INFO-1: Outbound Network Call to Wikipedia (Opt-in)

- **Severity**: INFO
- **Category**: privacy
- **Location**: `mempalace/entity_registry.py:176-264`
- **Description**: `_wikipedia_lookup()` makes HTTPS requests to Wikipedia for entity disambiguation. This is gated behind `allow_network=True` and documented with privacy warnings.
- **Impact**: Could leak entity names to Wikipedia servers. Correctly designed as opt-in.
- **Fix**: None required — design is appropriate.
- **Confidence**: high

### INFO-2: Comprehensive Query Sanitization for Prompt Contamination

- **Severity**: INFO (positive finding)
- **Category**: prompt injection defense
- **Location**: `mempalace/query_sanitizer.py:39-188`
- **Description**: The project has a 4-stage pipeline to strip system prompt contamination from search queries, preventing retrieval degradation from 89.8% to 1.0% R@10.
- **Impact**: Strong defense against prompt injection affecting search quality.
- **Confidence**: high

---

## Supply Chain Analysis

| Dependency | Version | Health | Notes |
|-----------|---------|--------|-------|
| `chromadb` | `>=0.5.0` (no upper) | Active, well-maintained | No upper bound is a risk |
| `pyyaml` | `>=6.0,<7` | Mature, stable | Properly bounded |
| `hatchling` | build-system | Active | Standard build backend |
| `pytest` | `>=7.0` (dev) | Mature | Dev-only |
| `pytest-cov` | `>=4.0` (dev) | Mature | Dev-only |
| `ruff` | `>=0.4.0` (dev) | Active | Dev-only |
| `psutil` | `>=5.9` (dev) | Mature | Dev-only |
| `autocorrect` | `>=2.0` (optional) | Small project | Optional extra |

- Dependabot is configured for both pip and GitHub Actions (`.github/dependabot.yml`)
- Minimal dependency surface (2 runtime deps) reduces supply-chain attack area
- No suspicious or unmaintained dependencies detected

---

## Code Quality Assessment

**Architecture**: Clean separation of concerns — MCP server, CLI, backends, search, knowledge graph are well-isolated modules. Pluggable backend interface (`backends/base.py`) enables future storage swaps.

**Error handling**: Consistently good. JSON parsing wrapped in try/except, file operations handle `OSError`, subprocess calls have timeouts. The WAL (write-ahead log) provides an audit trail for all write operations.

**Input validation**: Excellent. Three-tier sanitization (`sanitize_name`, `sanitize_kg_value`, `sanitize_content`) covers all entry points. Path traversal blocked at multiple layers. Null bytes rejected universally.

**File permissions**: Exemplary. All sensitive files created with `0o600`, directories with `0o700`. Atomic file creation via `os.open(O_CREAT | O_WRONLY, 0o600)` avoids TOCTOU races.

**Test coverage**: 85%+ threshold enforced in CI, with dedicated security tests (path traversal, injection, prompt contamination). Multi-platform CI (Linux, macOS, Windows).

**Documentation**: Thorough CLAUDE.md with architecture, conventions, and setup. SECURITY.md with vulnerability reporting. Good inline comments in security-sensitive code.

---

## Contribution Opportunities

| # | File | Issue | Fix | Effort |
|---|------|-------|-----|--------|
| 1 | `.github/workflows/ci.yml` | Missing `permissions: contents: read` | Add 2-line permissions block | trivial |
| 2 | All `.github/workflows/*.yml` | Actions pinned to tags not SHAs | Look up and replace with commit SHAs | small |
| 3 | `hooks/mempal_save_hook.sh:70` | `eval` on sanitized input | Replace with `read`-based variable extraction | small |
| 4 | `mempalace/room_detector_local.py:296` | `yaml.dump` without SafeDumper | Add `Dumper=yaml.SafeDumper` | trivial |
| 5 | `pyproject.toml:28` | `chromadb` unbounded version range | Add `<2` upper bound | trivial |

---

## Draft PRs

### PR 1: Add least-privilege permissions to CI workflow

- **PR Title**: `fix(ci): add explicit read-only permissions to CI workflow`
- **Branch**: `fix/ci-permissions`
- **Files**: `.github/workflows/ci.yml`
- **Changes**: Add `permissions: contents: read` at the top level of the workflow, below the `on:` block. This restricts the GITHUB_TOKEN to read-only access for all CI jobs, preventing a compromised dependency from abusing write permissions during test execution.
- **Impact**: Eliminates privilege escalation risk from supply-chain attacks targeting test dependencies.

### PR 2: Pin GitHub Actions to commit SHAs

- **PR Title**: `fix(ci): pin all GitHub Actions to immutable commit SHAs`
- **Branch**: `fix/pin-action-shas`
- **Files**: `.github/workflows/ci.yml`, `.github/workflows/deploy-docs.yml`, `.github/workflows/version-guard.yml`
- **Changes**: Replace all version tag references (`@v4`, `@v6`, `@v2`, `@v3`, `@v5`) with their corresponding full commit SHAs. Add version comments for readability (e.g., `actions/checkout@abc123 # v6`).
- **Impact**: Prevents tag-based supply-chain attacks on all CI/CD pipelines.

### PR 3: Replace eval with safe variable extraction in save hook

- **PR Title**: `fix(hooks): replace eval with safe variable extraction in save hook`
- **Branch**: `fix/hook-eval-removal`
- **Files**: `hooks/mempal_save_hook.sh`
- **Changes**: Replace the `eval $(python3 ...)` pattern with direct variable assignment using command substitution or `read` from Python output. This eliminates the `eval` call entirely while preserving the existing sanitization logic. Example approach: have Python output values one per line, then `read` each into a variable.
- **Impact**: Removes the last remaining `eval` usage in the codebase, eliminating a class of injection risk in the hook pipeline.

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

- **Total findings by severity**: Critical: 0, High: 2, Medium: 4, Low: 3, Info: 2
- **Overall risk level**: **MEDIUM**

### Top 3 Recommendations

1. **Add `permissions: contents: read` to `ci.yml`** — trivial fix that eliminates the highest-impact supply-chain risk vector
2. **Pin all GitHub Actions to commit SHAs** — prevents mutable tag attacks across all three workflows
3. **Replace `eval` in `mempal_save_hook.sh`** — removes the only `eval` usage in the codebase, closing a narrow but real injection vector

### Overall Assessment

MemPalace demonstrates strong security engineering for a project of its size. The local-first, zero-API architecture eliminates entire categories of risk. Input validation is thorough and consistent across all entry points. File permissions are strict. SQL queries are properly parameterized. The primary gaps are in CI/CD hardening (workflow permissions, action pinning) and a single `eval` usage in a shell hook — all fixable with small, low-risk PRs.
