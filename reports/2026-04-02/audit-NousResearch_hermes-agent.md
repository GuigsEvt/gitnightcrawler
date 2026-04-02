# Security Audit: NousResearch/hermes-agent

**Audit Date**: 2026-04-02
**Commit**: 624ad582 (main)
**Version**: 0.6.0

## Repository Overview

Hermes-agent is a self-improving AI agent framework by Nous Research that creates skills from experience, improves them during use, and runs across multiple platforms. It features a multi-platform messaging gateway (Telegram, Discord, Slack, WhatsApp, Signal, Matrix, Email, SMS, etc.), an OpenAI-compatible REST API, tool execution sandbox, code execution environment, skill marketplace with security scanning, blockchain integrations (Base/Solana), reinforcement learning training pipeline, and MCP server support. The project is a comprehensive AI agent OS with ~400+ Python source files and 400+ test files.

**Tech stack**: Python 3.11+, aiohttp, OpenAI/Anthropic SDKs, python-telegram-bot, discord.py, Node.js (Playwright, WhatsApp bridge), SQLite, Docker, Nix.

**Maturity**: Growing (v0.6.0, active development, good test coverage, supply chain awareness)

**Categories**: ai | actions | blockchain

---

## Critical & High Severity Findings

### FINDING-01: Command Injection via Quick Commands (shell=True)
- **Severity**: HIGH
- **Category**: injection
- **Location**: `cli.py:4040-4046`
- **Description**: The quick commands feature executes user-configured commands with `subprocess.run(exec_cmd, shell=True)`. While the command string comes from the user's own config file (`config.yaml`), if the config can be written to by the agent (via skills or tool calls), this creates a command injection vector where LLM-generated content could be executed as shell commands.
- **Impact**: Arbitrary command execution on the host system if an attacker or prompt injection can modify the quick_commands config.
- **Fix**: Use `subprocess.run(shlex.split(exec_cmd))` instead of `shell=True`, or validate commands against an allowlist.
- **Confidence**: Medium (requires config write access)

### FINDING-02: Webhook Server Binds to 0.0.0.0 by Default
- **Severity**: HIGH
- **Category**: network-exposure
- **Location**: `gateway/platforms/webhook.py:54`
- **Description**: The webhook server defaults to binding on `0.0.0.0` (all interfaces), exposing it to the network. Combined with the `INSECURE_NO_AUTH` secret bypass (line 56), this could allow unauthenticated webhook submissions from any network host.
- **Impact**: Unauthorized agent invocation, potential abuse of agent capabilities (tool execution, messaging) from the network.
- **Fix**: Default to `127.0.0.1`. Require explicit opt-in for `0.0.0.0` binding. Remove or gate `INSECURE_NO_AUTH` behind a `--dev-mode` flag.
- **Confidence**: High

### FINDING-03: API Server Auth Bypass When No Key Configured
- **Severity**: HIGH
- **Category**: auth
- **Location**: `gateway/platforms/api_server.py:361-362`
- **Description**: The API server's `_check_auth()` method returns `None` (allow) when no API key is configured (`if not self._api_key: return None`). This means all endpoints are unauthenticated by default. While the server defaults to `127.0.0.1:8642`, users deploying with a different bind address would be exposed.
- **Impact**: Unauthenticated access to the full agent API, including chat completions and tool execution.
- **Fix**: Log a warning when no key is configured. Consider requiring a key when binding to non-loopback addresses. Add rate limiting regardless of auth.
- **Confidence**: High

### FINDING-04: Red-Teaming Skill Uses `exec()` to Load Code
- **Severity**: HIGH
- **Category**: code-execution
- **Location**: `skills/red-teaming/godmode/scripts/auto_jailbreak.py:55-57`
- **Description**: The auto-jailbreak skill uses `exec(compile(open(path).read(), ...))` to dynamically load sibling scripts. While this is intentional for the red-teaming skill, the pattern is dangerous if skill paths can be manipulated.
- **Impact**: If skill directory paths are controllable (e.g., via symlinks or skill download manipulation), arbitrary code execution is possible.
- **Fix**: Use standard Python imports instead of `exec()`. If dynamic loading is needed, use `importlib`.
- **Confidence**: Medium (intentional design for red-team tooling)

### FINDING-05: Command Injection in Supply Chain Audit Workflow
- **Severity**: HIGH
- **Category**: injection
- **Location**: `.github/workflows/supply-chain-audit.yml:177-186`
- **Description**: The supply chain audit workflow constructs a `$BODY` variable from git diff output (`$PTH_FILES`, `$B64_EXEC_HITS`, etc.) and interpolates it into a `gh pr comment` command via double-quoted shell string. An attacker could craft PR filenames containing shell metacharacters (e.g., backticks, `$()`) that would be executed when the comment is posted.
- **Impact**: Command injection in CI context with `pull-requests: write` permission. An attacker could post arbitrary PR comments or potentially exfiltrate the GITHUB_TOKEN.
- **Fix**: Write the comment body to a file and use `gh pr comment --body-file /tmp/comment.md` instead of inline interpolation.
- **Confidence**: High

### FINDING-06: GitHub Actions Not Pinned to SHA Hashes
- **Severity**: HIGH
- **Category**: supply-chain
- **Location**: `.github/workflows/*.yml` (all 6 workflow files, 21 unpinned actions)
- **Description**: All GitHub Actions use tag-based references (e.g., `actions/checkout@v4`, `docker/build-push-action@v6`) instead of SHA-pinned references. **Critically**, `nix.yml` lines 30-31 use `DeterminateSystems/nix-installer-action@main` and `DeterminateSystems/magic-nix-cache-action@main` -- pinned to a moving branch target, meaning every push to those repos changes what code runs in CI.
- **Impact**: Supply chain compromise of the build/deploy pipeline, potential credential theft from CI secrets (DOCKERHUB_USERNAME, DOCKERHUB_TOKEN).
- **Fix**: Pin all actions to full SHA hashes (e.g., `actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11`). Highest priority: the `@main` refs in `nix.yml`.
- **Confidence**: High

### FINDING-07: Docker Image Runs as Root
- **Severity**: HIGH
- **Category**: container-security
- **Location**: `Dockerfile:1-26`
- **Description**: The Dockerfile does not create or switch to a non-root user. The container runs all processes as root, which violates container security best practices.
- **Impact**: If the container is compromised (e.g., through code execution tools), the attacker has root access within the container, increasing the blast radius.
- **Fix**: Add `RUN useradd -m hermes` and `USER hermes` before the ENTRYPOINT.
- **Confidence**: High

### FINDING-08: No Rate Limiting on API Server Endpoints
- **Severity**: HIGH
- **Category**: availability
- **Location**: `gateway/platforms/api_server.py` (all POST endpoints)
- **Description**: The API server has zero rate limiting. Each request spawns an AIAgent making LLM API calls. An attacker with a valid key (or when no key is configured) can exhaust LLM credits or cause DoS. The webhook adapter has rate limiting (30/min per route), but the API server does not.
- **Impact**: LLM credit exhaustion, denial of service, resource abuse.
- **Fix**: Add rate-limiting middleware or per-IP/per-key token bucket. At minimum, limit concurrent agent executions.
- **Confidence**: High

### FINDING-09: Non-Interactive Mode Auto-Approves All Dangerous Commands
- **Severity**: HIGH
- **Category**: auth
- **Location**: `tools/approval.py:544-545`
- **Description**: When neither `HERMES_INTERACTIVE` nor `HERMES_GATEWAY_SESSION` is set (batch runner, cron jobs, programmatic usage), ALL dangerous commands are auto-approved without any user confirmation.
- **Impact**: In batch/cron/automation contexts, the agent can execute any destructive command (`rm -rf /`, `curl | bash`, etc.) without approval.
- **Fix**: Deny dangerous commands by default in non-interactive mode. Require explicit opt-in via config for auto-approval.
- **Confidence**: High

### FINDING-10: Missing Permissions in CI Workflows
- **Severity**: MEDIUM (upgraded context: HIGH for docker-publish)
- **Category**: actions-security
- **Location**: `.github/workflows/docker-publish.yml`, `.github/workflows/tests.yml`, `.github/workflows/nix.yml`
- **Description**: Three workflow files do not specify top-level `permissions:`, defaulting to the repository's default token permissions (often `write-all`). The docker-publish workflow has access to `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets.
- **Impact**: A compromised action could use overly broad permissions to modify repository contents, create releases, or exfiltrate secrets.
- **Fix**: Add explicit `permissions: contents: read` (or minimal required) to all workflows.
- **Confidence**: High

---

## Medium & Low Severity Findings

### FINDING-11: SMS Webhook Server Binds to 0.0.0.0
- **Severity**: MEDIUM
- **Category**: network-exposure
- **Location**: `gateway/platforms/sms.py:107`
- **Description**: The SMS platform webhook binds to `0.0.0.0` without configurable bind address.
- **Impact**: Network-exposed webhook endpoint.
- **Fix**: Make bind address configurable, default to `127.0.0.1`.
- **Confidence**: High

### FINDING-12: Telegram Webhook Binds to 0.0.0.0
- **Severity**: MEDIUM
- **Category**: network-exposure
- **Location**: `gateway/platforms/telegram.py:583`
- **Description**: Telegram webhook mode binds to `0.0.0.0`.
- **Impact**: Network-exposed webhook. Telegram validates via webhook secret, so risk is lower.
- **Fix**: Make bind address configurable.
- **Confidence**: High

### FINDING-13: CORS Wildcard Origin Support
- **Severity**: MEDIUM
- **Category**: web-security
- **Location**: `gateway/platforms/api_server.py:325-328`
- **Description**: The API server supports `"*"` as a CORS origin, which allows any website to make cross-origin requests to the API.
- **Impact**: Combined with missing auth (FINDING-03), any website could interact with the agent API.
- **Fix**: Warn when wildcard CORS is configured. Document the security implications.
- **Confidence**: High

### FINDING-14: Git Dependencies in RL Optional Group
- **Severity**: MEDIUM
- **Category**: supply-chain
- **Location**: `pyproject.toml:68-69`
- **Description**: The `rl` optional dependency group uses git+https references (`atroposlib`, `tinker`) without pinning to specific commits. These repos could be modified to include malicious code.
- **Impact**: Supply chain compromise for users installing RL dependencies.
- **Fix**: Pin to specific commit hashes (e.g., `git+https://github.com/...@abc123`).
- **Confidence**: High

### FINDING-15: env_passthrough Bypasses Secret Filtering
- **Severity**: MEDIUM
- **Category**: credential-exposure
- **Location**: `tools/code_execution_tool.py:440-448`
- **Description**: The `env_passthrough` mechanism allows skills to declare environment variables that should be passed through to the sandbox, bypassing the secret name filtering. A malicious skill could declare passthrough for sensitive variables.
- **Impact**: Credential leakage to LLM-generated code in the sandbox.
- **Fix**: The skills_guard already scans for exfiltration patterns. Consider also validating passthrough declarations against the secret substring list and requiring user confirmation.
- **Confidence**: Medium

### FINDING-16: Code Execution Sandbox Lacks OS-Level Isolation
- **Severity**: MEDIUM
- **Category**: sandboxing
- **Location**: `tools/code_execution_tool.py:346-658`
- **Description**: The `execute_code` tool runs LLM-generated Python code in a child process with the same OS user privileges as the parent. While it filters secret env vars and redacts output, the child can read arbitrary files from disk (including `~/.hermes/.env`), make direct network requests, and access `PYTHONPATH` including the hermes-agent root.
- **Impact**: LLM-generated code could exfiltrate secrets from disk or make outbound network requests. `preexec_fn=os.setsid` only creates a process group, not isolation.
- **Fix**: Run sandbox in a separate user, network namespace, or container. Consider using seccomp or Linux namespaces.
- **Confidence**: High

### FINDING-17: shell=True in Docker Environment
- **Severity**: MEDIUM
- **Category**: injection
- **Location**: `tools/environments/docker.py:517,526`
- **Description**: Docker environment management uses `shell=True` for stop and cleanup commands.
- **Impact**: If container names or parameters are controllable, command injection is possible.
- **Fix**: Use array form for subprocess calls.
- **Confidence**: Medium

### FINDING-18: Persisted --insecure Flag Permanently Disables TLS Verification
- **Severity**: MEDIUM
- **Category**: crypto
- **Location**: `hermes_cli/auth.py:1137-1161, 1454-1457`
- **Description**: The `--insecure` flag disables TLS certificate verification for all OAuth flows. Worse, this setting is persisted in auth state via `tls.insecure`, meaning a one-time `--insecure` flag permanently downgrades security for that provider session without the user realizing.
- **Impact**: Permanent MITM vulnerability for OAuth token exchanges if the insecure flag is set once.
- **Fix**: Do not persist `insecure=True` in auth state. Require it to be passed explicitly each time.
- **Confidence**: High

### FINDING-19: No SSRF Protection on User-Controlled Base URLs
- **Severity**: MEDIUM
- **Category**: ssrf
- **Location**: `hermes_cli/auth.py:1175-1295`, `agent/credential_pool.py:770-796`
- **Description**: Several functions construct URLs from user/config-controlled base URLs (`portal_base_url`, `inference_base_url`, custom provider `base_url`) and make HTTP requests including Bearer token headers without URL validation. An attacker who modifies `config.yaml` could redirect token exchange requests to a malicious server.
- **Impact**: OAuth token and API key theft via config manipulation.
- **Fix**: Validate URL schemes (require HTTPS for non-localhost). Document trust model for config file access.
- **Confidence**: Medium (requires config write access)

### FINDING-20: MCP OAuth Callback Missing State Validation
- **Severity**: MEDIUM
- **Category**: auth
- **Location**: `tools/mcp_oauth.py:130-191`
- **Description**: The OAuth callback handler captures the `state` parameter but does not validate it against the state sent in the authorization request. Validation is delegated to the MCP SDK's `OAuthClientProvider`, but if the SDK doesn't validate, this is a CSRF vector. Mitigated by localhost binding.
- **Impact**: Potential CSRF on OAuth flow if MCP SDK doesn't validate state.
- **Fix**: Add explicit state validation in the callback handler or verify SDK handles it.
- **Confidence**: Medium

### FINDING-21: Non-Constant-Time API Key Comparison
- **Severity**: LOW
- **Category**: crypto
- **Location**: `gateway/platforms/api_server.py:367`
- **Description**: API key comparison uses `==` (`if token == self._api_key`) which is vulnerable to timing side-channel attacks. The webhook adapter correctly uses `hmac.compare_digest()` for signature validation.
- **Impact**: Theoretical timing attack to recover the API key character by character.
- **Fix**: Replace with `hmac.compare_digest(token, self._api_key)`.
- **Confidence**: High

### FINDING-22: Session ID Predictability in API Server
- **Severity**: LOW
- **Category**: auth
- **Location**: `gateway/platforms/api_server.py:502-514`
- **Description**: `X-Hermes-Session-Id` header lets callers specify any session ID to load conversation history. Session IDs use format `YYYYMMDD_HHMMSS_<8 hex chars>` which is partially guessable (timestamp + 32 bits entropy).
- **Impact**: Conversation history leakage if IDs can be enumerated. Mitigated by API key and local-only binding.
- **Fix**: Use `uuid4` for session IDs or validate session ownership.
- **Confidence**: Medium

### FINDING-23: shell=True in Transcription Tools
- **Severity**: LOW
- **Category**: injection
- **Location**: `tools/transcription_tools.py:362`
- **Description**: Audio transcription tool uses `subprocess.run(command, shell=True)` for ffmpeg invocation.
- **Impact**: If file paths contain shell metacharacters, command injection may be possible.
- **Fix**: Use array form for the subprocess call.
- **Confidence**: Low

### FINDING-24: SQLite ResponseStore Without Parameterized Queries Check
- **Severity**: LOW
- **Category**: injection
- **Location**: `gateway/platforms/api_server.py:68-80`
- **Description**: ResponseStore uses SQLite for persistence. While the code appears to use parameterized queries (standard practice with Python sqlite3), the store initializes with PRAGMA settings. No SQL injection found but worth noting for ongoing review.
- **Impact**: Minimal if parameterized queries are used consistently.
- **Fix**: Audit all SQL queries in the module for parameterized usage.
- **Confidence**: Low

### FINDING-25: Blockchain RPC URL Injection via Environment Variable
- **Severity**: MEDIUM
- **Category**: injection
- **Location**: `optional-skills/blockchain/base/scripts/base_client.py:31-34`, `optional-skills/blockchain/solana/scripts/solana_client.py:31-34`
- **Description**: `RPC_URL` is loaded directly from env vars (`BASE_RPC_URL`/`SOLANA_RPC_URL`) with no scheme validation. A misconfigured or malicious env var could redirect all RPC traffic to an attacker-controlled endpoint over HTTP (no TLS).
- **Impact**: Man-in-the-middle on blockchain queries; fake balances/transactions displayed to user. Impact limited since both clients are strictly read-only (no signing or transactions).
- **Fix**: Validate URL scheme is `https://` before use.
- **Confidence**: High

### FINDING-26: Debian Base Image Not Pinned to Digest
- **Severity**: LOW
- **Category**: supply-chain
- **Location**: `Dockerfile:1`
- **Description**: The Dockerfile uses `debian:13.4` (tag) instead of a SHA256 digest.
- **Impact**: Tag can be overwritten upstream, though Debian official images are generally trustworthy.
- **Fix**: Use `debian:13.4@sha256:<digest>` for deterministic builds.
- **Confidence**: Low

---

## Supply Chain Analysis

### Dependencies

**Python (pyproject.toml)**:
- Core dependencies are well-pinned with upper bounds (e.g., `openai>=2.21.0,<3`)
- CVE awareness noted in comments (`requests>=2.33.0` cites CVE-2026-25645, `PyJWT` cites CVE-2026-32597)
- Git-based dependencies (`atroposlib`, `tinker`) lack commit pinning
- Total: ~30 direct dependencies, all from well-known packages

**Node.js (package.json)**:
- Used primarily for browser tools (Playwright) and WhatsApp bridge
- Standard packages from npm

**Supply Chain Audit Workflow**:
- The project has a dedicated `supply-chain-audit.yml` workflow that scans PRs for:
  - `.pth` files (Python auto-execute)
  - base64+exec combos
  - Credential exfiltration patterns
  - Subprocess with encoded commands
  - marshal/pickle deserialization
- This is excellent and rare for open-source projects

**Skills Guard**:
- Comprehensive regex-based static analysis scanner for externally-sourced skills
- 80+ threat patterns covering exfiltration, injection, destructive operations, persistence, network, and obfuscation
- Trust-level based install policy (builtin > trusted > community)
- This is a strong defense against malicious skills

### Dockerfile Concerns
- Base image `debian:13.4` is Debian **testing** (trixie), not a stable release -- testing receives less security scrutiny than stable
- Container runs as root (see FINDING-07)
- `npm install --no-audit` suppresses vulnerability warnings during build
- `.dockerignore` exists but doesn't exclude `tests/`, `__pycache__/`, `logs/`

### Missing CI Security Tooling
- No `pip-audit` or `npm audit` step in CI to catch known CVEs in the dependency tree
- Supply chain workflow does not flag when new packages are added to `pyproject.toml` or `package.json`
- No `--require-hashes` for pip install integrity verification

### Health Assessment
- Core dependencies well-pinned with upper bounds and CVE-aware comments
- Git-based dependencies (`atroposlib`, `tinker`, `yc-bench`) lack commit pinning
- Verify low-profile npm packages (`parallel-web`, `@askjo/camoufox-browser`) are not typosquats
- Good version pinning discipline overall

---

## Code Quality Assessment

### Architecture and Organization
- Well-structured modular architecture with clear separation of concerns
- Gateway pattern cleanly abstracts 15+ messaging platforms
- Tool system with sandbox isolation and RPC-based communication
- Skills marketplace with security scanning pipeline
- Clean entry points: CLI, agent runner, ACP server, gateway

### Error Handling
- Consistent use of try/except with logging
- Graceful fallbacks (e.g., SQLite falls back to :memory: if disk fails)
- Timeout handling in subprocess calls
- Process group killing for runaway child processes

### Test Coverage
- 404 test files covering unit, integration, and e2e tests
- CI runs tests with empty API keys to prevent accidental real API calls
- Parallel test execution with pytest-xdist
- Dedicated test categories (tools, gateway, cron, etc.)

### Documentation
- Comprehensive .env.example with inline documentation
- Platform-specific SKILL.md files
- ADDING_A_PLATFORM.md guide for gateway extensions
- Release notes for each version
- Docusaurus documentation site

### Security-Positive Patterns
- YAML parsing uses CSafeLoader/SafeLoader (no unsafe_load)
- No pickle usage found
- Code execution sandbox filters secret env vars and redacts output
- Skills guard scans downloaded skills for 80+ threat patterns
- Supply chain audit workflow for PRs
- Secret redaction in model context (`agent.redact.redact_sensitive_text`)
- ANSI stripping to prevent terminal injection

---

## Contribution Opportunities

### 1. Pin GitHub Actions to SHA Hashes
- **File**: `.github/workflows/*.yml` (all 6 files)
- **Issue**: Actions use tags instead of SHA hashes
- **Fix**: Replace tag references with SHA-pinned versions
- **Effort**: Trivial

### 2. Add Non-Root User to Dockerfile
- **File**: `Dockerfile:22-25`
- **Issue**: Container runs as root
- **Fix**: Add `RUN useradd -m hermes && USER hermes`
- **Effort**: Small

### 3. Default Webhook/API Servers to 127.0.0.1
- **File**: `gateway/platforms/webhook.py:54`, `gateway/platforms/sms.py:107`
- **Issue**: Servers bind to 0.0.0.0 by default
- **Fix**: Change defaults to `127.0.0.1`, add explicit opt-in for network exposure
- **Effort**: Small

### 4. Add Permissions to All CI Workflows
- **File**: `.github/workflows/docker-publish.yml`, `tests.yml`, `nix.yml`
- **Issue**: Missing top-level permissions declarations
- **Fix**: Add `permissions: contents: read` (minimum required)
- **Effort**: Trivial

### 5. Pin Git Dependencies to Commit Hashes
- **File**: `pyproject.toml:68-69`
- **Issue**: Git dependencies not pinned to commits
- **Fix**: Add `@<commit-hash>` to git URLs
- **Effort**: Trivial

---

## Draft PRs

### PR 1: Harden CI/CD Workflow Permissions and Action Pinning

- **PR Title**: `fix(ci): pin actions to SHA hashes and add explicit permissions`
- **Branch**: `fix/ci-supply-chain-hardening`
- **Files to modify**: All 6 files in `.github/workflows/`
- **Changes**:
  - Pin all `uses:` actions to full SHA hashes instead of tags
  - Add `permissions: contents: read` to `docker-publish.yml`, `tests.yml`, `nix.yml`, `docs-site-checks.yml`
  - Add job-level permission escalation only where needed (e.g., `packages: write` for docker push)
- **Impact**: Prevents supply chain attacks via compromised upstream actions and limits blast radius of compromised CI jobs

### PR 2: Harden Network Defaults for Webhook and API Servers

- **PR Title**: `fix(gateway): default webhook/SMS servers to localhost binding`
- **Branch**: `fix/localhost-default-binding`
- **Files to modify**: `gateway/platforms/webhook.py`, `gateway/platforms/sms.py`
- **Changes**:
  - Change `DEFAULT_HOST = "0.0.0.0"` to `DEFAULT_HOST = "127.0.0.1"` in webhook.py
  - Change SMS webhook bind from `"0.0.0.0"` to configurable with `127.0.0.1` default
  - Gate `INSECURE_NO_AUTH` behind environment variable check (`HERMES_DEV_MODE=1`)
  - Log warning when binding to non-loopback address
- **Impact**: Prevents accidental network exposure of webhook endpoints to untrusted networks

### PR 3: Add Non-Root User to Docker Image

- **PR Title**: `fix(docker): run container as non-root user`
- **Branch**: `fix/docker-nonroot-user`
- **Files to modify**: `Dockerfile`, `docker/entrypoint.sh`
- **Changes**:
  - Add `RUN groupadd -r hermes && useradd -r -g hermes -m hermes`
  - Add `RUN chown -R hermes:hermes /opt/hermes /opt/data`
  - Add `USER hermes` before ENTRYPOINT
  - Update entrypoint.sh to handle permissions if needed
  - Pin base image to SHA256 digest
- **Impact**: Reduces blast radius of container compromise; follows Docker security best practices

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 7 |
| Test Coverage | 8 |
| Contribution Potential | 7 |

---

## Summary

- **Total findings by severity**: Critical: 0, High: 10, Medium: 11, Low: 5, Info: 0
- **Overall risk level**: **MEDIUM**

### Top 3 Recommendations

1. **Harden CI/CD pipeline**: Pin all GitHub Actions to SHA hashes and add explicit `permissions` blocks to all workflows. This is the highest-impact, lowest-effort improvement.

2. **Default servers to localhost**: Change webhook, SMS, and other server defaults from `0.0.0.0` to `127.0.0.1` and gate `INSECURE_NO_AUTH` behind a dev-mode flag. Network exposure without authentication is a significant risk.

3. **Add non-root Docker user**: The container running as root is a common but impactful security gap. Adding a dedicated user limits container escape impact.

### Notable Strengths

The project demonstrates unusually strong security awareness for an open-source AI agent:
- **Skills Guard**: 80+ regex patterns scanning external skills for threats
- **Supply Chain Audit**: Dedicated CI workflow scanning PRs for attack patterns
- **Sandbox Isolation**: Code execution tool filters secrets from env, uses RPC for tool access, and redacts sensitive output
- **YAML Safety**: Consistent use of SafeLoader
- **CVE Tracking**: Dependencies pinned with CVE references in comments
