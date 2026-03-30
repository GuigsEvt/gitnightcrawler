# Audit: vivekchand/clawmetry

## Repository Overview

ClawMetry is an open-source, real-time observability dashboard for OpenClaw AI agents. It provides a zero-config, read-only monitoring UI that auto-detects OpenClaw workspaces, connects to gateway WebSockets, and optionally ingests OpenTelemetry metrics. The project ships as a single `pip install clawmetry` command with an embedded HTML/CSS/JS frontend inside the Python server -- no build step required.

- **Tech stack**: Python 3.8+, Flask, Waitress (WSGI), SQLite, WebSocket, cryptography (AES-256-GCM for cloud sync)
- **Languages**: Python (~32,300 LOC), embedded HTML/CSS/JS (~8,000 lines within template strings)
- **Frameworks**: Flask (web), Playwright (E2E testing), pytest
- **Maturity**: **Growing** -- v0.12.84, active development (~3-5 releases/month), 400+ PRs, comprehensive CI/CD, but pre-1.0

## Code Quality Assessment

### Architecture and Organization
The single-file design (`dashboard.py` at 25,004 lines) is intentional for portability but creates maintainability challenges. Supporting modules in `clawmetry/` (CLI, sync, proxy, providers, extensions) are well-structured. The project uses a procedural style with 320+ functions, 67 global variables, and no classes in the main file. A Phase 3 refactoring to a `ClawMetryConfig` dataclass is planned. The plugin system (`extensions.py`) is clean and thread-safe.

### Error Handling Patterns
Excellent coverage: 356 try blocks with 367 except handlers. Defensive patterns include corrupted-file backup, disk-full detection, timeout handling for subprocesses, and graceful degradation for optional dependencies. Weakness: ~15 generic `except Exception: pass` blocks that silently swallow errors.

### Test Coverage
~1,475 lines across 5 test files. CI runs on 3 platforms (Linux/macOS/Windows) x 2 Python versions (3.9/3.11). Includes API endpoint tests, proxy budget/loop detection tests, Playwright E2E browser tests, and BrowserStack cloud browser tests. CLI tests are thin (38 lines). No unit tests for the core dashboard logic -- tests are integration-level.

### Documentation Quality
Excellent. README with screenshots, ARCHITECTURE.md with data flow details, comprehensive CHANGELOG (100+ versions), CONTRIBUTING.md, SECURITY.md. 80% docstring coverage (257/320 functions).

### Dependency Health
Minimal production dependencies (flask, waitress, cryptography). No known CVEs in pinned ranges. Version ranges are reasonably bounded (`>=2.0`). Test dependencies (pytest, playwright) properly separated.

## Security Findings

### Critical

**1. XSS via Token Injection in `/auth` Endpoint** -- `dashboard.py:~16099`
Token from `request.args.get('token')` is interpolated directly into a JavaScript string literal without escaping:
```python
return f"""...<script>localStorage.setItem('clawmetry-token', '{token}');...</script>..."""
```
Attack: `/auth?token=');alert(document.cookie);//` executes arbitrary JS. Severity mitigated by localhost-only default binding, but critical if exposed on a network.

### High

**2. Path Traversal in File Access** -- `dashboard.py:~17729`
Uses `os.path.normpath()` instead of `os.path.realpath()` for path validation. Symlinks can bypass the `startswith()` check, potentially allowing reads of arbitrary files.

**3. Missing CSRF Protection** -- All state-changing routes (POST/PUT/DELETE for cron management, alert rules, budget controls) lack CSRF tokens. Exploitable if dashboard is exposed beyond localhost.

**4. Credential Exposure via Query String** -- `dashboard.py:~16052,16079,16091`
Gateway tokens accepted in URL query parameters (`?token=...`), which get logged in browser history, server access logs, and referer headers.

### Medium

**5. Missing Security Headers** -- No `X-Content-Type-Options`, `X-Frame-Options`, `Content-Security-Policy`, or `Strict-Transport-Security` headers set on responses.

**6. No Input Bounds Checking** -- Integer parameters from query strings (e.g., `lines=999999999`) have no upper bounds, risking memory exhaustion.

**7. Fleet API Open by Default** -- `dashboard.py:~372`: When `FLEET_API_KEY` is unset, all fleet requests are allowed without authentication.

### Low

**8. No Rate Limiting** -- All 111+ API endpoints lack rate limiting. Brute-force and DoS possible.

**9. Print-based Logging** -- 167 print statements instead of Python `logging` module. No log level control, no file output, potential for sensitive data in stdout.

**10. Information Disclosure in Error Responses** -- Some error handlers return `str(e)` to clients, leaking implementation details.

### Info

- All SQL queries use parameterized statements (no SQL injection)
- No `eval()`, `exec()`, or `pickle` usage
- All subprocess calls use list-based arguments (no shell injection)
- E2E encryption (AES-256-GCM) for cloud sync is well-implemented
- Default bind to `127.0.0.1` limits attack surface

## Contribution Opportunities

### Bugs

**B1. XSS in `/auth` endpoint**
- File: `dashboard.py:~16099`
- Issue: Unescaped token value interpolated into JS string
- Fix: HTML-escape and JS-escape the token, or use a POST redirect pattern
- Effort: trivial
- PR-worthy: high

**B2. Path traversal via symlinks**
- File: `dashboard.py:~17729`
- Issue: `os.path.normpath()` doesn't resolve symlinks
- Fix: Replace with `os.path.realpath()` in the validation check
- Effort: trivial
- PR-worthy: high

### Security Fixes

**S1. Add CSRF protection to state-changing routes**
- File: `dashboard.py` (all POST/PUT/DELETE routes)
- Issue: No CSRF validation
- Fix: Generate CSRF token per session, validate on state-changing requests
- Effort: medium
- PR-worthy: high

**S2. Add security headers via `@app.after_request`**
- File: `dashboard.py`
- Issue: Missing standard security headers
- Fix: Add `after_request` handler setting CSP, X-Frame-Options, X-Content-Type-Options
- Effort: trivial
- PR-worthy: medium

**S3. Move token auth to POST body / Authorization header only**
- File: `dashboard.py:~16052,16079,16091`
- Issue: Token in query string gets logged everywhere
- Fix: Accept token only via `Authorization: Bearer` header or POST body
- Effort: small
- PR-worthy: medium

### Missing Tests

**T1. Unit tests for core dashboard functions**
- File: `tests/` (new file)
- Issue: No unit tests for metrics parsing, session detection, auto-discovery logic
- Fix: Add `test_dashboard.py` with mocked filesystem
- Effort: medium
- PR-worthy: medium

**T2. Security-focused test cases**
- File: `tests/test_api.py`
- Issue: No tests for path traversal, XSS, auth bypass
- Fix: Add negative test cases for security boundaries
- Effort: small
- PR-worthy: high

### Documentation Gaps

**D1. API authentication documentation**
- File: `ARCHITECTURE.md` or `docs/`
- Issue: Auth flow (token detection, fleet keys) not documented for users exposing dashboard
- Fix: Add security hardening section
- Effort: small
- PR-worthy: low

### Code Improvements

**C1. Replace print logging with Python `logging` module**
- File: `dashboard.py` (167 print statements)
- Issue: No log levels, no file output, no structured logging
- Fix: Initialize `logging.getLogger("clawmetry")` and replace print calls
- Effort: medium
- PR-worthy: medium

**C2. Add input bounds checking on query parameters**
- File: `dashboard.py:~16937,17750`
- Issue: Unbounded integer parameters from user input
- Fix: `min(max(int(val), 1), 10000)` pattern
- Effort: trivial
- PR-worthy: low

**C3. Reduce bare `except Exception: pass` blocks**
- File: `dashboard.py` (15+ instances)
- Issue: Silently swallowed errors make debugging impossible
- Fix: At minimum log the exception; use specific exception types
- Effort: small
- PR-worthy: low

### Feature Ideas

**F1. Rate limiting on API endpoints**
- File: `dashboard.py`
- Issue: No rate limiting; DoS and brute-force possible
- Fix: Add Flask-Limiter or simple in-memory rate limiter
- Effort: small
- PR-worthy: medium

**F2. Structured JSON logging mode**
- File: `dashboard.py`
- Issue: Log output not machine-parseable
- Fix: Add `--json-logs` flag for structured output
- Effort: medium
- PR-worthy: low

## Draft PRs

### PR 1: Fix XSS and path traversal vulnerabilities

- **PR Title**: `fix: sanitize token input in /auth and use realpath for file access`
- **Branch**: `fix/xss-and-path-traversal`
- **Files**: `dashboard.py`
- **Changes**:
  1. At ~line 16099: Escape the token value using `html.escape()` and replace single quotes before interpolating into JS. Better: use a POST-redirect pattern where the token is sent via form POST, stored server-side, and redirected.
  2. At ~line 17729: Replace `os.path.normpath()` with `os.path.realpath()` for both the workspace base and the requested path before the `startswith()` check.
  3. Add test cases in `tests/test_api.py` for XSS payloads and path traversal attempts.
- **Effort**: 1-2 hours
- **Impact**: Fixes the two most exploitable vulnerabilities. Critical for any deployment beyond localhost.

### PR 2: Add security headers and CSRF protection

- **PR Title**: `feat: add security headers and CSRF token validation`
- **Branch**: `feat/security-headers-csrf`
- **Files**: `dashboard.py`
- **Changes**:
  1. Add `@app.after_request` handler setting `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Content-Security-Policy` (with appropriate `script-src` for inline JS).
  2. Generate a per-session CSRF token stored in a secure cookie. Validate it on all POST/PUT/DELETE routes.
  3. Update the embedded frontend JS to include the CSRF token in fetch requests.
- **Effort**: 4-6 hours
- **Impact**: Hardens the application against clickjacking, MIME sniffing, and cross-site request forgery. Required for any network-exposed deployment.

### PR 3: Replace print logging with Python logging module

- **PR Title**: `refactor: migrate from print statements to Python logging module`
- **Branch**: `refactor/structured-logging`
- **Files**: `dashboard.py`
- **Changes**:
  1. Initialize `logger = logging.getLogger("clawmetry")` at module level with a `StreamHandler`.
  2. Replace 167 `print()` calls with appropriate `logger.info/warning/error/debug` calls.
  3. Add `--log-level` CLI flag (default: INFO) and `--log-file` option.
  4. Ensure no sensitive data (tokens, keys) appears in log messages.
- **Effort**: 3-4 hours
- **Impact**: Enables proper log management, debugging, and integration with log aggregation systems. Prevents accidental sensitive data exposure in stdout.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 5 |
| Documentation | 9 |
| Test Coverage | 6 |
| Contribution Potential | 8 |
