Now I have all the data needed. Here's the full audit report:

---

# Audit: can1357/oh-my-pi

## Repository Overview

**oh-my-pi** is an AI-powered coding agent for the terminal, forked from `badlogic/pi-mono`. It provides a rich TUI for interacting with multiple LLM providers (Anthropic, OpenAI, Google, AWS Bedrock) with features like agentic git commits, MCP server support, session management, context compaction, web search, code search/grep via native Rust bindings, and extensibility through custom slash commands, skills, hooks, and tools. The project compiles to standalone cross-platform binaries.

**Tech stack**: TypeScript (1,161 files) + Rust (151 files), Bun runtime, N-API native bindings, tree-sitter (22+ grammars), brush-core (embedded bash), SQLite, React (stats dashboard), Puppeteer (web scraping). CI via GitHub Actions with multi-platform builds (Linux x64/arm64, macOS Intel/Apple Silicon, Windows x64).

**Maturity**: **Growing** -- v13.14.2 with 59 commits (fork), 12 contributors, 307 test files, 50 docs files, active development cadence with conventional commits.

## Code Quality Assessment

**Architecture and organization**: Excellent. Clean monorepo with 9 well-separated packages (`coding-agent`, `ai`, `agent`, `tui`, `natives`, `utils`, `stats`, `swarm-extension`, `react-edit-benchmark`) and 3 Rust crates. Clear boundaries between concerns. Workspace-linked dependencies with shared `tsconfig.base.json`. The `AGENTS.md` file (21KB) codifies strict coding standards: no `private`/`protected` (use `#` private fields), no `ReturnType<>`, no inline imports, no `console.log` in coding-agent.

**Error handling**: Good. Centralized logging via `@oh-my-pi/pi-utils` with daily rotation. HTTP errors redact sensitive headers (Authorization, X-API-Key, Cookie). Proper async/await with error propagation. Rust side uses `Result` types consistently.

**Test coverage**: Good breadth. 307 test files across all packages using Bun test runner. Tests cover agent sessions, MCP reconnection, model selection, BM25 search, web scraping, image encoding, provider schemas. No obvious coverage gaps for core functionality. No integration test suite visible.

**Documentation quality**: Strong. 50 internal docs covering architecture internals (provider streaming, MCP lifecycle, TUI runtime, compaction, secrets, etc.). 60KB README with installation, usage, configuration, and extensibility guides. `AGENTS.md` provides comprehensive contributor guidelines. Security policy present.

**Dependency health**: Healthy. Major deps are recent versions (`@anthropic-ai/sdk ^0.78`, `openai ^6.25`, `@google/genai ^1.43`). Lock files are frozen for CI (`--frozen-lockfile`). Rust deps pinned in `Cargo.toml`. No known vulnerable packages detected. 70+ Rust transitive deps is notable but expected for the feature set.

## Security Findings

| # | Finding | Severity | Details |
|---|---------|----------|---------|
| 1 | `noExplicitAny` disabled in biome.json | **Info** | Allows unchecked `any` types, reducing type safety. Justified for AI SDK flexibility but worth monitoring. |
| 2 | Broad file system access | **Low** | Agent can read/write any file accessible to the user. Mitigated by running in user context (by design). |
| 3 | Bash shell execution via brush-core | **Low** | Embedded bash runtime executes user-initiated commands. Proper isolation through brush-core; no injection vectors found. |
| 4 | Puppeteer web scraping | **Low** | Stealth mode enabled. Could expose user to malicious page content. Mitigated by linkedom sandboxing. |
| 5 | OAuth token storage in SQLite | **Low** | Tokens stored at platform-appropriate paths. No encryption at rest, relies on OS-level file permissions. |
| 6 | 13 Rust `unsafe` blocks | **Info** | All in expected locations (FFI, PTY, signal handling). `undocumented_unsafe_blocks = "warn"` enforced. |
| 7 | Secret obfuscation is not encryption | **Info** | Transcript secrets use indexed placeholders or deterministic hashing -- not cryptographic protection. Designed for log safety, not storage security. |

**No critical, high, or medium severity issues found.**

- No hardcoded secrets, API keys, or credentials in source
- No SQL injection (parameterized queries throughout)
- No XSS vectors (no `innerHTML` / `dangerouslySetInnerHTML`)
- No shell injection patterns
- No eval()/Function() constructor usage
- Proper path traversal protection in `path-utils.ts`
- Sensitive HTTP headers properly redacted
- API keys stripped from subprocess environments (Python kernel)
- Security policy with responsible disclosure process

## Contribution Opportunities

### Bugs

No obvious bugs identified in the audit. The recent commit history shows active bug fixing (`setHookWidget`, quota exhaustion detection, mic cursor width).

### Security Fixes

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `packages/ai/src/auth-storage.ts` | OAuth tokens stored unencrypted in SQLite | Add optional encryption-at-rest using OS keychain (macOS Keychain, libsecret) | large | high |
| 2 | `biome.json:12` | `noExplicitAny: "off"` allows type-unsafe patterns | Enable as `warn` and incrementally fix violations | medium | medium |

### Missing Tests

| # | File/Area | Issue | Fix | Effort | PR-worthy |
|---|-----------|-------|-----|--------|-----------|
| 1 | `packages/coding-agent/src/secrets/` | Secret obfuscation edge cases (nested secrets, unicode, very long values) | Add fuzz-style test cases for obfuscation/deobfuscation roundtrips | small | high |
| 2 | `crates/pi-natives/` | No Rust-side unit tests visible | Add `#[cfg(test)]` modules for core native functions (grep, AST, clipboard) | medium | high |
| 3 | `packages/coding-agent/src/tools/path-utils.ts` | Path traversal protection not explicitly tested | Add tests for `../`, symlink, and edge-case path inputs | small | high |
| 4 | End-to-end integration tests | No E2E test suite for full agent workflows | Add integration tests for session lifecycle, tool execution, compaction | large | medium |

### Documentation Gaps

| # | File/Area | Issue | Fix | Effort | PR-worthy |
|---|-----------|-------|-----|--------|-----------|
| 1 | `CONTRIBUTING.md` | Missing contributor guide (setup, PR process, code style) | Create `CONTRIBUTING.md` referencing `AGENTS.md` standards | small | high |
| 2 | `docs/` | No architecture overview diagram | Add high-level diagram showing package relationships and data flow | small | medium |

### Code Improvements

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `Cargo.toml` | 70+ Rust dependencies; build times could be improved | Audit and trim unused features, consider feature flags for optional grammars | medium | medium |
| 2 | `packages/coding-agent/` | Large package (likely 100+ source files) | Consider splitting tool implementations into a separate `tools` package | large | low |

### Feature Ideas

| # | Idea | Impact | Effort | PR-worthy |
|---|------|--------|--------|-----------|
| 1 | Rate limiting for web scraping requests | Prevents abuse and improves reliability | small | medium |
| 2 | Telemetry opt-in with privacy-preserving usage stats | Helps maintainers prioritize features | large | low |

## Draft PRs

### PR 1: Add unit tests for path traversal protection

- **PR Title**: `test(tools): add path-utils security test suite`
- **Branch**: `test/path-utils-security`
- **Files**: `packages/coding-agent/test/tools/path-utils.test.ts` (new)
- **Changes**: Add comprehensive test cases for `expandPath()`, `resolveToCwd()`, and `normalizePathLikeInput()` covering `../` traversal, symlink resolution, null bytes, unicode paths, Windows-style paths, and tilde expansion edge cases. Ensures path validation logic is regression-protected.
- **Effort**: 2-3 hours
- **Impact**: Prevents future regressions in security-critical path handling code. High-value, low-risk contribution.

### PR 2: Add Rust-side unit tests for native bindings

- **PR Title**: `test(natives): add unit tests for core Rust modules`
- **Branch**: `test/rust-native-tests`
- **Files**: `crates/pi-natives/src/grep.rs`, `crates/pi-natives/src/ast.rs`, `crates/pi-natives/src/clipboard.rs` (add `#[cfg(test)]` modules)
- **Changes**: Add `#[cfg(test)] mod tests` blocks to the primary Rust modules with tests for grep pattern matching, AST parsing correctness across language grammars, and clipboard read/write roundtrips. Use `cargo test` integration in CI.
- **Effort**: 1-2 days
- **Impact**: The Rust native layer is the performance-critical foundation. Unit tests catch regressions before they reach JS consumers.

### PR 3: Create CONTRIBUTING.md

- **PR Title**: `docs: add CONTRIBUTING.md with setup and PR guidelines`
- **Branch**: `docs/contributing-guide`
- **Files**: `CONTRIBUTING.md` (new)
- **Changes**: Create contributor guide covering: prerequisites (Bun, Rust toolchain, system deps), local development setup (`bun install`, `cargo build`), running tests, code style references to `AGENTS.md` and `biome.json`, PR checklist, and link to `SECURITY.md` for vulnerability reports. Keep concise and actionable.
- **Effort**: 1-2 hours
- **Impact**: Lowers barrier for new contributors. The project has 12 contributors but no explicit contribution guide.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 8 |
| Documentation | 7 |
| Test Coverage | 6 |
| Contribution Potential | 7 |

**Overall**: This is a well-engineered, actively maintained project with strong security practices, excellent architecture, and comprehensive internal documentation. The main gaps are in test coverage (no Rust tests, no E2E suite) and contributor onboarding. No critical or high-severity security issues were found.
