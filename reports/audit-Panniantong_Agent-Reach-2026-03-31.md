# Audit: Panniantong/Agent-Reach

## Repository Overview

Agent Reach is a Python CLI tool and library that gives AI agents read/search access to 17+ internet platforms (Twitter/X, YouTube, Reddit, GitHub, Bilibili, XiaoHongShu, Douyin, WeChat, Weibo, LinkedIn, V2EX, Xueqiu, RSS, and more). It positions itself as a "scaffolding" tool — an installer, diagnostics engine, and config manager — rather than a wrapper. After installation, agents call upstream tools (bird, yt-dlp, mcporter, gh, etc.) directly. The project supports integration with Claude Code, OpenClaw, Cursor, and other agent frameworks via SKILL.md registration.

**Tech stack:** Python 3.10+, argparse CLI, PyYAML config, Rich terminal output, loguru logging, requests HTTP, yt-dlp, feedparser, playwright (optional), browser-cookie3 (optional). CI via GitHub Actions (pytest on 3.10–3.13).

**Maturity:** Growing. v1.0.0 released 2025-02-24, now at v1.3.0 (2026-03-12). 17 channels, 9 test files, bilingual docs. Active development with regular PRs.

---

## Code Quality Assessment

**Architecture and organization:** Clean plugin architecture. Each channel is a single file in `channels/` inheriting from `Channel` ABC with `can_handle()`, `check()` contract. Core is thin (43 lines), CLI is the workhorse (1707 lines). Config, doctor, cookie extraction are well-separated modules. Tier system (0/1/2) for channel complexity is a smart design choice.

**Error handling patterns:** Mixed. Subprocess calls consistently use list-style args (no `shell=True`), timeouts are applied everywhere, and GitHub API retry with backoff is well-implemented. However, there are 15+ `except Exception:` broad catches that could mask real issues. Some `except: pass` patterns silently swallow errors.

**Test coverage:** 9 test files covering CLI parsing, config YAML read/write with permissions, doctor formatting, channel contracts, Twitter cookie parsing, XHS formatter, and GitHub retry logic. Tests use mocking and parametrization well. Missing: integration tests for actual channel `check()` calls, cookie_extract module, MCP server, uninstall flow, and several channel implementations.

**Documentation quality:** Strong. Bilingual README (Chinese + English), CONTRIBUTING.md, CHANGELOG.md, 5 docs in `docs/`, setup guides per platform in `guides/`, SKILL.md with usage examples. CLAUDE.md provides project context.

**Dependency health:** Excellent. `constraints.txt` pins versions. `pyproject.toml` specifies minimums. Optional dependency groups (`browser`, `cookies`, `dev`). CI enforces constraints.

---

## Security Findings

| Finding | Severity | Details |
|---------|----------|---------|
| No hardcoded secrets | Info | All credentials via config/env, `.env.example` is template only |
| Config file permissions enforced (0o600) | Info | Good practice in `config.py:56-59` |
| All subprocess calls use list args | Info | No `shell=True`, no command injection vectors |
| `yaml.safe_load()` used consistently | Info | No unsafe deserialization |
| No `eval()`/`exec()`/`pickle` usage | Info | No dynamic code execution |
| SSL verification enabled (no `verify=False`) | Info | Default `requests` behavior preserved |
| Input validation gaps on cookie/proxy values | Medium | `cli.py:1089-1093` — no length checks, no character validation on cookie tokens; `cli.py:970` — proxy URL format not validated |
| Broad exception handling | Medium | 15+ `except Exception:` or `except: pass` patterns across channels and cookie_extract could mask security-relevant errors |
| Credentials stored as plaintext YAML | Low | `~/.agent-reach/config.yaml` — mitigated by 0o600 permissions, but no OS keyring integration |
| Doctor security check for world-readable config | Info | `doctor.py` warns if config is world-readable |
| No `--break-system-packages` guard | Low | `cli.py:668` — pip install with `--break-system-packages` could interfere with system Python on some distros |

---

## Contribution Opportunities

### Bugs

1. **File:** `agent_reach/cli.py:668-669`
   **Issue:** `--break-system-packages` flag passed unconditionally to pip, which can break system Python on managed distros (Debian 12+, Ubuntu 23.04+).
   **Fix:** Detect if running in a venv first; only add flag outside venv, or prefer `--user` install.
   **Effort:** small
   **PR-worthy:** medium

2. **File:** `agent_reach/channels/xueqiu.py`
   **Issue:** Xueqiu channel makes HTTP requests with a hardcoded User-Agent but the session cookies may expire without warning, causing silent failures.
   **Fix:** Add cookie expiry detection in `check()` and return `"warn"` status with re-auth instructions.
   **Effort:** small
   **PR-worthy:** medium

### Security Fixes

3. **File:** `agent_reach/cli.py:1082-1095`, `agent_reach/cli.py:970`
   **Issue:** Cookie values and proxy URLs accepted without validation — no length limits, no character restrictions, no URL format check.
   **Fix:** Add regex validation for cookie tokens (alphanumeric + limited chars, max 256 chars), use `urllib.parse.urlparse()` for proxy URLs.
   **Effort:** small
   **PR-worthy:** high

4. **File:** Multiple channels + `cookie_extract.py`
   **Issue:** Broad `except Exception:` catches can hide security-relevant errors (auth failures, permission issues, credential leaks in error messages).
   **Fix:** Replace with specific exception types (`subprocess.CalledProcessError`, `json.JSONDecodeError`, `FileNotFoundError`, etc.). Log suppressed exceptions at debug level.
   **Effort:** medium
   **PR-worthy:** medium

### Missing Tests

5. **File:** `tests/` (new file: `test_cookie_extract.py`)
   **Issue:** `cookie_extract.py` (220 lines) has zero test coverage — handles sensitive browser cookie extraction.
   **Fix:** Add tests for `extract_all()` with mocked `browser_cookie3`, platform spec matching, credential sync, permission checks.
   **Effort:** medium
   **PR-worthy:** high

6. **File:** `tests/` (new file: `test_mcp_server.py`)
   **Issue:** MCP server integration (`mcp_server.py`) is untested.
   **Fix:** Add tests for `get_status` tool response format, error handling when doctor fails.
   **Effort:** small
   **PR-worthy:** medium

7. **File:** `tests/`
   **Issue:** Channel `check()` methods for bilibili, douyin, wechat, weibo, linkedin, xiaoyuzhou have no dedicated tests.
   **Fix:** Add parametrized tests with mocked subprocess calls for each channel's check logic.
   **Effort:** medium
   **PR-worthy:** medium

### Documentation Gaps

8. **File:** `docs/` (new: `security.md`)
   **Issue:** No security documentation — users don't know the threat model (plaintext creds, cookie risks, dedicated account recommendations).
   **Fix:** Add security doc covering: credential storage model, file permissions, dedicated account policy, cookie rotation.
   **Effort:** small
   **PR-worthy:** medium

9. **File:** `CONTRIBUTING.md`
   **Issue:** No instructions for adding a new channel — the plugin architecture is clean but undocumented for contributors.
   **Fix:** Add "Adding a New Channel" section with base class contract, tier assignment, test requirements, doctor integration.
   **Effort:** small
   **PR-worthy:** high

### Code Improvements

10. **File:** `agent_reach/cli.py` (1707 lines)
    **Issue:** CLI module is a monolith — handles install, configure, doctor, skill, format, update check, cookie parsing all in one file.
    **Fix:** Extract into submodules: `cli/install.py`, `cli/configure.py`, `cli/skill.py`, `cli/update.py`. Keep `cli/__init__.py` as thin dispatcher.
    **Effort:** large
    **PR-worthy:** medium

11. **File:** `agent_reach/config.py:30-42`
    **Issue:** `to_dict()` masks sensitive values with string matching (`token`, `key`, `secret`, `password`, `proxy`, `cookie`). This is fragile — new config keys could leak.
    **Fix:** Use an explicit allowlist of non-sensitive keys instead of a denylist of sensitive patterns.
    **Effort:** small
    **PR-worthy:** medium

### Feature Ideas

12. **File:** `agent_reach/config.py`
    **Issue:** Credentials stored as plaintext YAML. On macOS, could use Keychain; on Linux, could use `secretstorage`.
    **Fix:** Add optional keyring backend via `keyring` library for sensitive values, keep YAML for non-sensitive config.
    **Effort:** large
    **PR-worthy:** low (nice-to-have)

13. **File:** `agent_reach/cli.py`
    **Issue:** No `agent-reach list` or `agent-reach channels` command to show available channels with their current status inline.
    **Fix:** Add `list` subcommand that shows channels table with tier, status, and backend info.
    **Effort:** small
    **PR-worthy:** medium

---

## Draft PRs

### PR 1: Input Validation for Credentials

- **PR Title:** `fix(security): add input validation for cookie and proxy values`
- **Branch:** `fix/credential-input-validation`
- **Files:** `agent_reach/cli.py`
- **Changes:**
  - Add `_validate_cookie_token(value: str) -> str` that enforces max length (256), alphanumeric + `_-` chars only, raises `ValueError` on invalid input
  - Add `_validate_proxy_url(value: str) -> str` using `urllib.parse.urlparse()` to verify scheme (http/https/socks5), host, port
  - Apply validators in `_cmd_configure()` before calling `config.set()`
  - Add corresponding tests in `tests/test_cli.py`
- **Effort:** 1-2 hours
- **Impact:** Prevents malformed credential injection. Medium severity security fix that protects against unexpected behavior when users paste malformed values.

### PR 2: Cookie Extract Test Coverage

- **PR Title:** `test: add test coverage for cookie_extract module`
- **Branch:** `feat/test-cookie-extract`
- **Files:** `tests/test_cookie_extract.py` (new), `agent_reach/cookie_extract.py` (minor refactor for testability if needed)
- **Changes:**
  - Test `extract_all()` with mocked `browser_cookie3.chrome()`, `browser_cookie3.firefox()`, etc.
  - Test platform spec matching (correct domains, correct cookie names extracted)
  - Test credential sync to `~/.config/bird/credentials.env` and `session.json`
  - Test file permission enforcement (0o600)
  - Test graceful handling of missing browsers, empty cookie jars, locked profiles
  - Test `PLATFORM_SPECS` structure validity
- **Effort:** 2-3 hours
- **Impact:** The cookie_extract module handles the most sensitive data in the project (browser cookies) and currently has zero tests. This is the highest-impact test gap.

### PR 3: Add "New Channel" Contributor Guide

- **PR Title:** `docs: add channel contribution guide to CONTRIBUTING.md`
- **Branch:** `docs/channel-contribution-guide`
- **Files:** `CONTRIBUTING.md`
- **Changes:**
  - Add "Adding a New Channel" section with:
    - Channel base class contract (`can_handle`, `check`, tier assignment)
    - File naming convention (`channels/<platform>.py`)
    - Registration in `channels/__init__.py`
    - Required test file (`tests/test_<platform>_channel.py`)
    - Doctor integration (tier classification, status messages)
    - SKILL.md update with trigger keywords and examples
    - CHANGELOG entry format
  - Include a minimal channel template (copy-paste starter)
- **Effort:** 1 hour
- **Impact:** Lowers the barrier for new contributors. The channel plugin system is the project's core extension mechanism — making it easy to add channels directly drives growth.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 7 |
| Documentation | 8 |
| Test Coverage | 5 |
| Contribution Potential | 8 |

**Summary:** Well-architected project with clean plugin system, good security practices (file permissions, no shell injection, safe deserialization), and strong bilingual documentation. Main gaps are test coverage (especially for cookie_extract and MCP server), the monolithic CLI module, input validation for credential values, and broad exception handling. High contribution potential due to the pluggable channel architecture — adding new platforms is straightforward.
