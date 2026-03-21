Here is the complete audit report:

---

# Audit: can1357/oh-my-pi

## Repository Overview

Oh-my-pi is an AI-powered coding agent for the terminal, forked from [badlogic/pi-mono](https://github.com/badlogic/pi-mono) by Mario Zechner. It provides an interactive CLI (`omp`) that integrates multiple LLM providers (Anthropic, OpenAI, Google GenAI, AWS Bedrock) to assist with code editing, git operations, file management, web search, and more. The agent features session management with compaction, an extension/plugin system, MCP (Model Context Protocol) server support, an AI-powered commit tool, and native Rust performance bindings for text/grep/image operations. It is a monorepo with 10 TypeScript/Bun packages and 3 Rust crates.

**Tech stack**: TypeScript (Bun runtime), Rust (nightly 2024 edition, NAPI bindings), tree-sitter, ast-grep, tokio. Multi-platform: Linux, macOS, Windows.

**Maturity**: **Growing** -- v13.14.0, active development with frequent commits, comprehensive CI/CD, 50+ docs, 308 test files, published to npm. Not yet "mature" due to gaps in test coverage for several large modules and some security hardening areas.

---

## Code Quality Assessment

### Architecture and Organization
**Strong.** Clean monorepo with well-separated concerns:
- `packages/ai` -- LLM provider abstraction layer
- `packages/agent` -- Generic agent runtime with state management
- `packages/coding-agent` -- Main CLI application (largest package, 1000+ files)
- `packages/tui` -- Terminal UI with differential rendering
- `packages/natives` -- JS bridge to Rust NAPI bindings
- `packages/utils` -- Shared utilities
- `crates/pi-natives` -- Rust performance-critical operations (grep, text, image, PTY, shell)

Strict coding standards enforced via `AGENTS.md`: no `any` types, ES native `#private` fields, no inline imports, prompts in static `.md` files with Handlebars.

### Error Handling Patterns
**Good.** Bash executor has proper timeout/abort/cleanup handling. API key validation fails safely. OAuth uses loopback redirect enforcement. Extension loader silently continues on file access errors (minor concern). Comprehensive `AbortSignal` usage throughout.

### Test Coverage
**Moderate.** 308 test files (~69,800 lines), but concentrated in `coding-agent` and `ai` packages. High-quality tests exist for bash execution, schema normalization, skill URL resolution, and session compaction. However, ~29 tool implementations (including large ones like `browser.ts` 51KB, `fetch.ts` 40KB, `python.ts` 37KB) have no dedicated tests. No code coverage tooling configured. No snapshot tests.

### Documentation Quality
**Very good.** 50+ architecture docs in `docs/`, comprehensive README with table of contents, `AGENTS.md` with strict development guidelines, `CHANGELOG.md`. Internal docs cover secrets, MCP, LSP, compaction, hooks, extensions, and environment variables.

### Dependency Health
**Good.** Bun v1.3.7+ required. Rust nightly pinned via `rust-toolchain.toml`. Vendored brush-core/brush-builtins for shell implementation. Biome for formatting/linting. Clippy with strict deny-on-correctness and deny-on-suspicious. 30+ tree-sitter parsers bundled. No lock file audit tool configured in CI.

---

## Security Findings

### Critical
None found.

### High
1. **SSRF in MCP HTTP Transport** -- `packages/coding-agent/src/mcp/transports/http.ts` uses `fetch(this.config.url)` with no private IP range validation or scheme restriction. If MCP config is user-influenced, this could reach internal services (e.g., AWS metadata at `169.254.169.254`).

2. **Extension System Lacks Sandboxing** -- `packages/coding-agent/src/extensibility/extensions/loader.ts:257` uses `await import(resolvedPath)` with no sandboxing, no code signing, no capability-based permissions. Extensions run with full process access.

### Medium
3. **No Symlink Validation in Path Resolution** -- `packages/coding-agent/src/tools/path-utils.ts` normalizes paths but does not validate against symlink escapes. A crafted symlink could bypass directory boundaries.

4. **Write Tool Missing Directory Restrictions** -- `packages/coding-agent/src/tools/write.ts` has no protection against writing to system directories (`/etc`, `/usr/bin`) or `.gitignore`-listed files.

5. **MCP Server Trust Model** -- No server signature verification, no capability-based permissions, no request/response filtering between client and MCP servers.

### Low
6. **Clippy Cast Allowances** -- `Cargo.toml` allows `cast_possible_truncation`, `cast_sign_loss`, `cast_possible_wrap`. While pragmatic for a NAPI binding crate, these could mask numeric bugs.

7. **Silent Extension Load Failures** -- `loader.ts:379,389` silently continues on file access errors, which could mask tampered extension directories.

### Info
8. **No Dependency Audit in CI** -- No `npm audit` or `cargo audit` step in `.github/workflows/ci.yml`.
9. **Unsafe Rust Blocks** -- 3 unsafe blocks in `crates/pi-natives/src/shell.rs` (UTF-8 unchecked, raw FD conversion). All are justified and safe given their context.
10. **Secret Obfuscation System** -- Well-designed with indexed placeholders, two modes (obfuscate/replace), environment variable auto-detection, and per-project `secrets.yml`.

---

## Contribution Opportunities

### Bugs

1. **Silent Extension Load Errors**
   - File: `packages/coding-agent/src/extensibility/extensions/loader.ts:379-389`
   - Issue: File access errors during extension discovery are silently swallowed
   - Fix: Log warnings when extension files fail to load
   - Effort: trivial
   - PR-worthy: medium

### Security Fixes

2. **Add URL Validation to MCP HTTP Transport**
   - File: `packages/coding-agent/src/mcp/transports/http.ts:76,192,342,356,399,452`
   - Issue: No private IP range or scheme validation on MCP server URLs
   - Fix: Add a `validateUrl()` function that rejects private IPs (10.x, 172.16-31.x, 192.168.x, 169.254.x, 127.x) and non-http(s) schemes
   - Effort: small
   - PR-worthy: high

3. **Add Symlink Validation to Path Utils**
   - File: `packages/coding-agent/src/tools/path-utils.ts:106-112`
   - Issue: `resolveToCwd()` does not check for symlink escapes
   - Fix: Add `fs.promises.realpath()` comparison after resolution
   - Effort: small
   - PR-worthy: high

4. **Add Dependency Audit to CI**
   - File: `.github/workflows/ci.yml`
   - Issue: No `npm audit` or `cargo audit` step
   - Fix: Add audit jobs to CI pipeline
   - Effort: trivial
   - PR-worthy: medium

### Missing Tests

5. **Tests for `browser.ts`**
   - File: `packages/coding-agent/src/tools/browser.ts` (51KB, 0 tests)
   - Issue: Large browser automation module with no test coverage
   - Fix: Add unit tests for URL validation, content extraction, and error handling
   - Effort: medium
   - PR-worthy: high

6. **Tests for `fetch.ts`**
   - File: `packages/coding-agent/src/tools/fetch.ts` (40KB, 0 tests)
   - Issue: Network request tool with no test coverage
   - Fix: Add tests for URL handling, response parsing, timeout behavior
   - Effort: medium
   - PR-worthy: high

7. **Tests for `path-utils.ts`**
   - File: `packages/coding-agent/src/tools/path-utils.ts` (16KB, 0 tests)
   - Issue: Security-critical path resolution with no dedicated tests
   - Fix: Add tests for traversal attempts, symlinks, Unicode normalization, tilde expansion
   - Effort: small
   - PR-worthy: high

8. **Tests for `python.ts`**
   - File: `packages/coding-agent/src/tools/python.ts` (37KB, 0 tests)
   - Issue: Python execution environment with no test coverage
   - Fix: Add tests for kernel lifecycle, output capture, error handling
   - Effort: medium
   - PR-worthy: medium

### Documentation Gaps

9. **Extension Security Documentation**
   - File: `docs/` (new file: `docs/extension-security.md`)
   - Issue: No documentation on extension trust model or security implications
   - Fix: Document that extensions have full process access and should only be loaded from trusted sources
   - Effort: trivial
   - PR-worthy: medium

### Code Improvements

10. **Add Code Coverage Reporting**
    - File: `package.json`, `.github/workflows/ci.yml`
    - Issue: No coverage tooling configured
    - Fix: Configure Bun's built-in coverage or c8, add CI upload step
    - Effort: small
    - PR-worthy: medium

11. **Restrict Clippy Cast Allowances**
    - File: `Cargo.toml:45-49`
    - Issue: All cast lints allowed globally rather than per-site
    - Fix: Change to warn, add explicit `#[allow]` at specific cast sites with justification
    - Effort: medium
    - PR-worthy: low

### Feature Ideas

12. **MCP Server Capability Permissions**
    - File: `packages/coding-agent/src/mcp/manager.ts`
    - Issue: All MCP server tools are available to the LLM with no per-server restrictions
    - Fix: Add capability-based permission config per MCP server
    - Effort: large
    - PR-worthy: high

13. **Extension Sandboxing**
    - File: `packages/coding-agent/src/extensibility/extensions/loader.ts`
    - Issue: Extensions run unsandboxed in the main process
    - Fix: Run extensions in isolated Bun workers with an API bridge
    - Effort: large
    - PR-worthy: high

---

## Draft PRs

### PR 1: SSRF Protection for MCP HTTP Transport

- **PR Title**: `fix(mcp): add URL validation to prevent SSRF in HTTP transport`
- **Branch**: `fix/mcp-ssrf-validation`
- **Files**: `packages/coding-agent/src/mcp/transports/http.ts`
- **Changes**: Add a `validateMcpUrl(url: string)` function that:
  1. Parses URL and rejects non-http(s) schemes
  2. Resolves hostname to IP and rejects private ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 127.0.0.0/8, ::1)
  3. Call this validation before every `fetch()` call in the transport
  4. Add a `--allow-private-mcp` flag for legitimate local development use
  5. Add tests for the validation function
- **Effort**: 2-3 hours
- **Impact**: Prevents SSRF attacks via crafted MCP server configurations. Critical for users who add third-party MCP servers.

### PR 2: Path Traversal Hardening with Symlink Validation

- **PR Title**: `fix(tools): add symlink validation to path resolution`
- **Branch**: `fix/symlink-path-validation`
- **Files**: `packages/coding-agent/src/tools/path-utils.ts`, `packages/coding-agent/test/tools/path-utils.test.ts` (new)
- **Changes**:
  1. In `resolveToCwd()` and `resolveReadPath()`, add `fs.realpathSync()` comparison to detect symlink escapes outside the working directory
  2. Create a comprehensive test suite for `path-utils.ts` covering: relative paths, absolute paths, `../` traversal, symlink following, Unicode normalization, tilde expansion, macOS NFD handling
  3. Add configurable boundary enforcement (warn vs. deny)
- **Effort**: 3-4 hours
- **Impact**: Prevents path traversal via symlinks in read/write/edit tools. Security-critical for multi-user environments.

### PR 3: Test Coverage for Untested High-Risk Tools

- **PR Title**: `test(tools): add tests for browser, fetch, and path-utils`
- **Branch**: `feat/tool-test-coverage`
- **Files**:
  - `packages/coding-agent/test/tools/browser.test.ts` (new)
  - `packages/coding-agent/test/tools/fetch.test.ts` (new)
  - `packages/coding-agent/test/tools/path-utils.test.ts` (new)
- **Changes**:
  1. `browser.test.ts`: Test URL validation, content extraction from HTML, error handling for unreachable URLs, timeout behavior, readability integration
  2. `fetch.test.ts`: Test HTTP method handling, response parsing (JSON/text/binary), redirect following, timeout enforcement, header injection prevention
  3. `path-utils.test.ts`: Test normalization, traversal prevention, Unicode handling, edge cases
  4. Use existing test utilities from `test/utilities.ts`
- **Effort**: 6-8 hours
- **Impact**: Covers ~128KB of untested code in the three highest-risk tool modules. Prevents regressions in network and file operations.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 6 |
| Documentation | 8 |
| Test Coverage | 5 |
| Contribution Potential | 8 |

**Summary**: This is a well-architected, actively maintained project with strict coding standards, comprehensive documentation, and a strong extension system. The main areas for improvement are: (1) security hardening around MCP transport URLs and extension loading, (2) test coverage for large tool modules (browser, fetch, python, path-utils), and (3) adding dependency auditing to CI. The codebase is clean, follows consistent patterns, and is highly approachable for contributors.
