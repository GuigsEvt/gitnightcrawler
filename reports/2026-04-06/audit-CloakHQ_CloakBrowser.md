Good, no hardcoded secrets. Now I have all the data needed for the report.

# Security Audit: CloakHQ/CloakBrowser

## Repository Overview

CloakBrowser is an open-source stealth Chromium automation library that wraps Playwright/Puppeteer with a custom-patched Chromium binary containing source-level fingerprint patches to bypass bot detection (reCAPTCHA, Cloudflare Turnstile, DataDome, etc.). It provides Python and Node.js SDKs, a CDP multiplexer server (`cloakserve`), and a Docker image. The project auto-downloads patched Chromium binaries from its own CDN with GitHub Releases as fallback, supports proxy routing with GeoIP-based timezone/locale detection, and human-like input simulation.

- **Tech stack**: Python 3.9+, TypeScript/Node.js 18+, Playwright, Puppeteer, httpx, aiohttp, websockets, Docker
- **Maturity**: Growing (v0.3.20, active development, 48 patches in latest release)
- **Categories detected**: ai|actions

## Critical & High Severity Findings

### Finding 1: PowerShell Command Injection in ZIP Extraction (JS)

- **Severity**: HIGH
- **Category**: injection
- **Location**: `js/src/download.ts:428-432`
- **Description**: The `extractZip` function on Windows constructs a PowerShell command by string-interpolating `archivePath` and `destDir` directly into a command string. If an attacker controls the `CLOAKBROWSER_CACHE_DIR` env var or the download URL resolves to a path containing single quotes or PowerShell escape characters, arbitrary PowerShell commands could be injected.
- **Impact**: Remote code execution on Windows hosts where `CLOAKBROWSER_CACHE_DIR` is attacker-controlled (e.g., in shared CI environments).
- **Fix**: Use separate arguments array with `execFileSync` instead of string interpolation, or use a Node.js-native zip library (e.g., `yauzl`) instead of shelling out.
- **Confidence**: Medium (requires attacker control of env vars or download paths)

### Finding 2: `cloakserve` Binds to `0.0.0.0` Without Authentication

- **Severity**: HIGH
- **Category**: auth
- **Location**: `bin/cloakserve:632`
- **Description**: The CDP multiplexer server binds to all network interfaces (`0.0.0.0`) by default with no authentication. Anyone with network access can connect, launch Chrome processes, proxy arbitrary URLs through configured proxies, and interact with browser sessions (read cookies, DOM, etc.).
- **Impact**: Unauthorized remote browser control, proxy abuse, credential theft from active sessions, resource exhaustion via unbounded Chrome process spawning.
- **Fix**: Bind to `127.0.0.1` by default. Add `--host` CLI flag for explicit opt-in to external binding. Consider adding token-based authentication for non-localhost connections.
- **Confidence**: High

### Finding 3: Checksum Bypass via Environment Variable

- **Severity**: HIGH
- **Category**: supply-chain
- **Location**: `cloakbrowser/download.py:167`, `js/src/download.ts:199`
- **Description**: Setting `CLOAKBROWSER_SKIP_CHECKSUM=true` completely disables SHA-256 verification of downloaded binaries. Combined with `CLOAKBROWSER_DOWNLOAD_URL`, an attacker who can set environment variables can redirect downloads to a malicious server and skip integrity checks.
- **Impact**: Execution of a tampered Chromium binary — full system compromise.
- **Fix**: Remove `CLOAKBROWSER_SKIP_CHECKSUM` or restrict it to development builds only. Document the security implications prominently if kept.
- **Confidence**: High (by design, but the combination of env vars creates a trivial supply-chain attack vector)

### Finding 4: `--no-sandbox` Default Reduces Chrome Security

- **Severity**: HIGH
- **Category**: insecure-default
- **Location**: `cloakbrowser/config.py:50`, `js/src/config.ts:213`
- **Description**: `--no-sandbox` is included in default stealth args for all platforms. This disables Chromium's multi-process sandbox, meaning a renderer exploit can directly access the host system.
- **Impact**: If the browser navigates to a malicious page (common in scraping/automation), a renderer vulnerability becomes a full host compromise instead of being contained.
- **Fix**: Only add `--no-sandbox` when running as root or in Docker. On non-root systems, let the sandbox run. Add a warning in docs about the security tradeoff.
- **Confidence**: High

## Medium & Low Severity Findings

### Finding 5: Proxy Credentials Logged in Debug Output

- **Severity**: MEDIUM
- **Category**: information-disclosure
- **Location**: `bin/cloakserve:159-163`, `cloakbrowser/browser.py:111`
- **Description**: When a Chrome process is already running for a seed, `cloakserve` logs the proxy URL (which may contain credentials) at WARNING level. Debug logging in `browser.py` could also leak proxy args.
- **Impact**: Proxy credentials exposed in log files or console output.
- **Fix**: Redact credentials from proxy URLs before logging. Use a helper like `proxy_url.replace(parsed.password, '***')`.
- **Confidence**: Medium

### Finding 6: Unbounded Chrome Process Spawning in `cloakserve`

- **Severity**: MEDIUM
- **Category**: denial-of-service
- **Location**: `bin/cloakserve:133-242`
- **Description**: `ChromePool` has no limit on the number of Chrome processes it will spawn. Each unique `fingerprint` query parameter creates a new Chrome process. An attacker can exhaust memory/CPU by sending requests with random seed values.
- **Impact**: Denial of service on the host machine.
- **Fix**: Add a `--max-processes` flag with a sensible default (e.g., 50). Return HTTP 503 when the limit is reached.
- **Confidence**: High

### Finding 7: Status Endpoint Exposes Internal Process Details

- **Severity**: MEDIUM
- **Category**: information-disclosure
- **Location**: `bin/cloakserve:343-362`
- **Description**: The `GET /` endpoint returns PIDs, internal CDP ports, proxy URLs (potentially with credentials), timezone, locale, and connection counts for all running Chrome processes with no authentication.
- **Impact**: Information leakage useful for reconnaissance or proxy credential theft.
- **Fix**: Require authentication for the status endpoint, or return only aggregate stats (process count, uptime).
- **Confidence**: High

### Finding 8: Symlink Traversal Protection is Incomplete (Tar Extraction)

- **Severity**: MEDIUM
- **Category**: path-traversal
- **Location**: `cloakbrowser/download.py:319-323`
- **Description**: The Python tar extraction allows symlinks as long as they don't contain `..` or absolute paths. However, a multi-step symlink chain (e.g., symlink `a -> b`, then `b -> ../../../etc/passwd`) could still escape the extraction directory. The check splits on `/` rather than resolving the final target.
- **Impact**: Potential path traversal during binary extraction if the download server is compromised.
- **Fix**: Resolve the full symlink target path against `dest_dir` and verify containment, similar to the regular file check.
- **Confidence**: Medium

### Finding 9: `random.randint` Used for Fingerprint Seed (Python)

- **Severity**: LOW
- **Category**: crypto
- **Location**: `cloakbrowser/config.py:46`, `js/src/config.ts:209`
- **Description**: The fingerprint seed is generated using `random.randint` (Python) and `Math.random` (JS) — both non-cryptographic PRNGs. The seed space is only 90,000 values (10000-99999).
- **Impact**: Fingerprints are somewhat predictable. A detection service observing multiple sessions could correlate them by seed collision probability (~1/90000). Not critical since fingerprint evasion is the goal, not cryptographic secrecy.
- **Fix**: Expand seed range to at least 2^32 or use `secrets.randbelow` / `crypto.getRandomValues`. Low priority.
- **Confidence**: Low

### Finding 10: Docker Image Runs as Root

- **Severity**: LOW
- **Category**: insecure-default
- **Location**: `Dockerfile:1-51`
- **Description**: The Dockerfile has no `USER` directive. The container runs all processes (including Chrome) as root.
- **Impact**: If Chrome is exploited, the attacker has root in the container. Combined with `--no-sandbox`, this removes all isolation layers.
- **Fix**: Add a non-root user and switch to it before `ENTRYPOINT`: `RUN useradd -m cloakuser` / `USER cloakuser`.
- **Confidence**: High

### Finding 11: Dockerfile Uses Piped Curl for NodeSource Setup

- **Severity**: LOW
- **Category**: supply-chain
- **Location**: `Dockerfile:14`
- **Description**: `curl -fsSL https://deb.nodesource.com/setup_20.x | bash -` pipes a remote script directly into bash during Docker build. If the NodeSource CDN is compromised, malicious code executes during image build.
- **Fix**: Pin to a specific known-good hash, use the official Node.js Docker image as a build stage, or use `apt` with the NodeSource signing key verified separately.
- **Confidence**: Low (standard practice, but worth noting)

## Supply Chain Analysis

**Dependencies (Python)**:
- `playwright>=1.40` — well-maintained by Microsoft
- `httpx>=0.24` — well-maintained async HTTP client
- Optional: `geoip2>=4.0`, `patchright>=1.40`, `aiohttp>=3.9`, `websockets>=12.0` — all healthy

**Dependencies (JavaScript)**:
- `tar: ^7.0.0` — sole runtime dependency, well-maintained
- Peer deps: `playwright-core`, `puppeteer-core`, `mmdb-lib` — all healthy and optional

**Binary supply chain**: The primary risk is the patched Chromium binary itself, downloaded from `cloakbrowser.dev` or GitHub Releases. Mitigations in place:
- SHA-256 checksum verification (but bypassable via env var)
- GitHub attestations via Sigstore/cosign
- Dual download sources (CDN + GitHub)
- Dependabot configured for GitHub Actions (but not for pip/npm dependencies)

**Missing**: Dependabot is only configured for `github-actions`, not for `pip` or `npm` ecosystems.

## Code Quality Assessment

- **Architecture**: Clean separation between Python and JS wrappers mirroring the same API. Well-organized modules (config, download, browser, geoip, human).
- **Error handling**: Generally good — graceful fallbacks for network failures, clear error messages, atomic file operations for downloads.
- **Test coverage**: Good unit test coverage for config, args, proxy parsing, geoip, and stealth checks. Integration tests marked as `slow` for live detection sites. Missing: no tests for `cloakserve` server handlers, no security-focused tests.
- **Documentation**: Comprehensive README, docstrings on all public functions, changelog maintained. Good inline comments explaining stealth rationale.
- **CI/CD**: Pinned action versions with SHA hashes (excellent practice). Tests run on PR and push. OIDC trusted publishing for PyPI and npm.

## Contribution Opportunities

1. **File**: `bin/cloakserve:632` (line 632)
   - **Issue**: Server binds to `0.0.0.0` with no auth
   - **Fix**: Default to `127.0.0.1`, add `--host` flag, add optional token auth
   - **Effort**: small

2. **File**: `Dockerfile:1-51`
   - **Issue**: Runs as root, no USER directive
   - **Fix**: Add non-root user, adjust permissions
   - **Effort**: trivial

3. **File**: `js/src/download.ts:421-436`
   - **Issue**: PowerShell command injection in zip extraction
   - **Fix**: Use argument array or native zip library
   - **Effort**: small

4. **File**: `.github/dependabot.yml`
   - **Issue**: Only covers GitHub Actions, not pip/npm
   - **Fix**: Add `pip` and `npm` ecosystems
   - **Effort**: trivial

5. **File**: `bin/cloakserve:84-266`
   - **Issue**: No process limit in ChromePool
   - **Fix**: Add `--max-processes` with HTTP 503 when exceeded
   - **Effort**: small

## Draft PRs

### PR 1: `fix(cloakserve): bind to localhost by default and add --host flag`
- **Branch**: `fix/cloakserve-localhost-binding`
- **Files to modify**: `bin/cloakserve`
- **Changes**:
  - Change `web.run_app(app, host="0.0.0.0", ...)` to `web.run_app(app, host="127.0.0.1", ...)`
  - Add `--host=` to `parse_cli_args` with default `127.0.0.1`
  - Update help text and logger output
- **Impact**: Prevents unauthorized remote access to the CDP multiplexer. Docker users can pass `--host=0.0.0.0` explicitly.

### PR 2: `fix(docker): run as non-root user`
- **Branch**: `fix/docker-nonroot`
- **Files to modify**: `Dockerfile`
- **Changes**:
  - Add `RUN groupadd -r cloakuser && useradd -r -g cloakuser -m cloakuser` after package installation
  - Add `USER cloakuser` before `ENTRYPOINT`
  - Adjust file permissions for cache directory
- **Impact**: Adds defense-in-depth layer. If Chrome is exploited, attacker is non-root in container.

### PR 3: `fix(download): prevent command injection in Windows zip extraction`
- **Branch**: `fix/zip-extraction-injection`
- **Files to modify**: `js/src/download.ts`
- **Changes**:
  - Replace PowerShell string interpolation with properly escaped arguments or switch to a Node.js native zip library (e.g., `yauzl` or `node:zlib` + `fflate`)
  - Add test case for paths containing special characters
- **Impact**: Eliminates potential RCE on Windows when cache paths contain special characters.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 5 |
| Documentation | 8 |
| Test Coverage | 6 |
| Contribution Potential | 7 |

## Summary

- **Total findings by severity**: Critical: 0, High: 4, Medium: 4, Low: 3, Info: 0
- **Overall risk level**: **MEDIUM** (HIGH findings exist but require specific conditions — env var control or network access)
- **Top 3 recommendations**:
  1. **Bind `cloakserve` to `127.0.0.1` by default** — the current `0.0.0.0` binding with no auth is the most exploitable issue in a real deployment
  2. **Add non-root Docker user** — trivial fix that significantly improves container security posture
  3. **Add process limits and rate limiting to `cloakserve`** — prevents DoS and resource exhaustion in production use
