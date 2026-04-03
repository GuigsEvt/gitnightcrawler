

All four analysis agents have completed. Let me now compile the full report.

# Security Audit: microsoft/agent-governance-toolkit

## Repository Overview

Microsoft's Agent Governance Toolkit is a comprehensive framework for governing AI agents at scale. It provides policy engines, trust/identity management (Ed25519-based IATP), execution sandboxing, prompt injection detection, plugin marketplace with signature verification, compliance frameworks, and multi-framework integrations (LangChain, AutoGen, Semantic Kernel, MCP). The toolkit is a monorepo with ~12 packages spanning Python, TypeScript, .NET, and Go.

- **Tech stack**: Python (FastAPI, Pydantic), TypeScript (Express, Node.js), .NET (C#), Go, Docker
- **Languages**: Python (~60%), TypeScript (~25%), C# (~10%), Go (~5%)
- **Maturity**: Growing (v3.0.x, active development, comprehensive docs but some rough edges)
- **Categories detected**: ai, actions, crypto-primitives

---

## Critical & High Severity Findings

### C1. Signature Verification Bypass via Simulation Fallback
- **Severity**: CRITICAL
- **Category**: crypto / auth bypass
- **Location**: `packages/agent-mesh/packages/langchain-agentmesh/langchain_agentmesh/identity.py:133-135`
- **Description**: When the `cryptography` library is not installed, `verify_signature()` unconditionally returns `True`. An attacker who controls the environment (e.g., removes the package) gets a complete authentication bypass.
- **Impact**: Full identity fabrication. Any agent can claim any DID and trust score. All trust handshakes become meaningless.
- **Fix**: Return `False` and log a critical warning in simulation mode, or make `cryptography` a hard dependency. Never return `True` without actual verification.
- **Confidence**: HIGH

### C2. Deterministic "Private Key" in Simulation Fallback
- **Severity**: CRITICAL
- **Category**: crypto
- **Location**: `packages/agent-mesh/packages/langchain-agentmesh/langchain_agentmesh/identity.py:83-87`, also `packages/agentmesh-integrations/dify/identity.py:121-124`
- **Description**: Without `cryptography`, the "private key" is `SHA256(did:key)` where the DID is public. Signing is `SHA256(private_key:data)` -- trivially reproducible by anyone.
- **Impact**: Zero cryptographic security. Any actor with knowledge of the DID can forge signatures.
- **Fix**: Remove the simulation codepath entirely or make `cryptography` a hard dependency.
- **Confidence**: HIGH

### C3. No Lock Files Committed Anywhere
- **Severity**: CRITICAL
- **Category**: supply-chain
- **Location**: Repository-wide (10 `package.json`, 39 `pyproject.toml` files)
- **Description**: No `package-lock.json`, `poetry.lock`, `uv.lock`, or equivalent exists. Builds are non-reproducible.
- **Impact**: A compromised dependency version could be silently pulled at install time. Classic supply chain attack vector.
- **Fix**: Generate and commit lock files for all packages. Use `npm ci` (requires lockfile) and `pip-compile` or `uv lock` for Python.
- **Confidence**: HIGH

### H1. Hypervisor REST API Has No Authentication
- **Severity**: HIGH
- **Category**: auth
- **Location**: `packages/agent-hypervisor/src/hypervisor/api/server.py:115-306`
- **Description**: The FastAPI application has zero authentication or authorization middleware. All endpoints (create/terminate sessions, kill agents, access audit logs) are open.
- **Impact**: Anyone with network access can create/terminate sessions, kill agent processes, and read audit logs.
- **Fix**: Add authentication middleware (API key, JWT, or mTLS) for all non-health endpoints.
- **Confidence**: HIGH

### H2. Command Injection in deploy.js
- **Severity**: HIGH
- **Category**: injection
- **Location**: `packages/agent-os/extensions/copilot/deploy.js:150-165`
- **Description**: `execSync()` uses string interpolation with unsanitized environment variables (`AZURE_APP_NAME`, `DOCKER_TAG`).
- **Impact**: Arbitrary shell command execution via crafted environment variables.
- **Fix**: Use `execFileSync` with argument arrays instead of string interpolation.
- **Confidence**: HIGH

### H3. Webhook Signature Bypass in Copilot Extension
- **Severity**: HIGH
- **Category**: auth / crypto
- **Location**: `packages/agent-os/extensions/copilot/src/index.ts:247-257`
- **Description**: Non-constant-time string comparison for HMAC. Verification skipped entirely when `GITHUB_WEBHOOK_SECRET` is unset OR when the signature header is missing.
- **Impact**: Spoofed webhook events accepted; timing attack against HMAC comparison.
- **Fix**: Use `crypto.timingSafeEqual()`. Reject requests missing the signature header when a secret is configured.
- **Confidence**: HIGH

### H4. Plugin Sandbox Bypass via `compile()` Builtin
- **Severity**: HIGH
- **Category**: sandbox escape
- **Location**: `packages/agent-mesh/src/agentmesh/marketplace/sandbox.py:111`
- **Description**: The sandbox strips `exec`, `eval`, `breakpoint` from builtins but NOT `compile`. A plugin can use `compile()` + reflection tricks to execute arbitrary code.
- **Impact**: Malicious plugin code execution within the sandbox subprocess.
- **Fix**: Add `compile` to the `_STRIP` list. Also consider stripping `type`, `getattr`, `setattr`.
- **Confidence**: MEDIUM

### H5. Transitive Dependencies Skip Signature Verification
- **Severity**: HIGH
- **Category**: supply-chain
- **Location**: `packages/agent-marketplace/src/agent_marketplace/installer.py:183`
- **Description**: Recursive dependency installation calls `self.install(dep_name, dep_version, verify=False)`. All transitive dependencies bypass signature verification.
- **Impact**: A signed plugin can declare an unsigned/malicious dependency which gets installed without verification.
- **Fix**: Change `verify=False` to `verify=True` for dependency installation.
- **Confidence**: HIGH

### H6. XSS via innerHTML in VS Code Webviews
- **Severity**: HIGH
- **Category**: injection / XSS
- **Location**: `packages/agent-os-vscode/src/webviews/onboarding/OnboardingPanel.ts:473-505`, `workflowDesigner/WorkflowDesignerPanel.ts:952-1149`, `policyEditor/PolicyEditorPanel.ts:1027-1032`
- **Description**: Multiple webviews use `innerHTML` with unescaped template literals interpolating user-visible strings from configuration/policy files.
- **Impact**: Malicious workspace configurations could inject arbitrary HTML/JS into VS Code webviews with access to `acquireVsCodeApi()`.
- **Fix**: Use DOM APIs (`createElement`, `textContent`) instead of `innerHTML` for dynamic content.
- **Confidence**: MEDIUM

### H7. Unauthenticated Policy Modification Endpoint
- **Severity**: HIGH
- **Category**: auth
- **Location**: `packages/agent-os/extensions/copilot/src/index.ts:387-395`
- **Description**: POST `/api/policy` allows any unauthenticated request to modify active governance policies. `/api/audit` exposes audit logs without authentication.
- **Impact**: An attacker can disable all governance protections by overwriting policies.
- **Fix**: Add authentication middleware to sensitive endpoints.
- **Confidence**: HIGH

### H8. GITHUB_TOKEN Used as LLM API Key Fallback
- **Severity**: HIGH
- **Category**: secrets exposure
- **Location**: `.github/actions/ai-agent-runner/action.yml:197`
- **Description**: The composite action sends `GITHUB_TOKEN` to `AI_MODEL_ENDPOINT` (configurable). If the endpoint is overridden to a malicious URL, the token leaks.
- **Impact**: GITHUB_TOKEN with write permissions exfiltrated to attacker-controlled endpoint.
- **Fix**: Never send `GITHUB_TOKEN` to non-GitHub endpoints. Require a separate `AI_MODEL_API_KEY`. Validate endpoint URL domain.
- **Confidence**: MEDIUM

### H9. LLM-Generated Content Committed to Repository
- **Severity**: HIGH
- **Category**: injection
- **Location**: `.github/workflows/ai-spec-drafter.yml:69-123`
- **Description**: Triggers on `issues: labeled` with `contents: write` + `pull-requests: write`. LLM-generated content from issue title/body is committed directly to a branch and a PR is created. Prompt injection via issue content could push malicious content.
- **Impact**: Attacker-influenced content committed to the repository via LLM prompt injection relay.
- **Fix**: Restrict `needs-spec` label to maintainers. Add content validation before committing. Add CODEOWNERS for `docs/specs/`.
- **Confidence**: HIGH

### H10. Docker Containers Run as Root
- **Severity**: HIGH
- **Category**: container security
- **Location**: `packages/agent-os/modules/iatp/Dockerfile`, `services/cloud-board/Dockerfile`, `modules/caas/Dockerfile`, and 4 more
- **Description**: Seven production Dockerfiles never switch to a non-root `USER`. The IATP sidecar (handling inter-agent trust) is particularly concerning.
- **Impact**: Container escape vulnerabilities are amplified when running as root.
- **Fix**: Add `USER` directives to all production Dockerfiles.
- **Confidence**: HIGH

---

## Medium & Low Severity Findings

### Medium

| # | Category | Location | Description | Confidence |
|---|----------|----------|-------------|------------|
| M1 | Path traversal | `extensions/mcp-server/src/services/agent-manager.ts:144,225` | User-supplied IDs used in `path.join` without validation | HIGH |
| M2 | Path traversal | `extensions/mcp-server/src/services/approval-workflow.ts:120,129` | Same pattern as M1 | HIGH |
| M3 | Path traversal | `agent-marketplace/src/agent_marketplace/installer.py:110-111` | Plugin name used directly in path join | MEDIUM |
| M4 | Prompt injection bypass | `agent-os/src/agent_os/prompt_injection.py:409-420` | Allowlist uses substring matching; embed allowlisted string to bypass all detection | HIGH |
| M5 | Timing side-channel | `agent-compliance/src/agent_compliance/integrity.py:256` | Hash comparison uses `==` instead of `hmac.compare_digest` | MEDIUM |
| M6 | Timing side-channel | `agent-os/src/agent_os/memory_guard.py:250` | Same non-constant-time comparison for memory integrity | MEDIUM |
| M7 | Insecure default | `agent-os/modules/control-plane/src/agent_control_plane/agent_hibernation.py:62` | Hibernation state stored in world-readable `/tmp` | HIGH |
| M8 | Env leak | `agent-os/src/agent_os/sandbox_provider.py:90-96` | Subprocess sandbox passes `env=None`, inheriting all parent secrets | HIGH |
| M9 | CORS | `agent-hypervisor/src/hypervisor/api/server.py:128-134` | Wildcard methods/headers with `allow_credentials=True` | MEDIUM |
| M10 | Secrets exposure | `extensions/chrome/injected.js:188-192` | `postMessage({...}, '*')` broadcasts agent data to all origins | HIGH |
| M11 | Missing headers | `agent-mesh/services/api/src/index.ts:1-31` | No CORS, no security headers, no body size limits | HIGH |
| M12 | Prompt injection relay | `.github/actions/ai-agent-runner/action.yml:372-386` | Untrusted PR titles/bodies passed to LLM, output posted as bot comment | HIGH |
| M13 | Supply chain | `spell-check.yml:32` | `npm install --global cspell@8` without exact pin or integrity hash | HIGH |
| M14 | Dependency conflict | Multiple `pyproject.toml` files | `cryptography` version constraints are mutually exclusive within agent-os | HIGH |
| M15 | Fail-open | `extensions/chrome/src/shared/api.ts:115-124` | Code review returns `overallSafe: true` on API failure | HIGH |

### Low

| # | Category | Location | Description |
|---|----------|----------|-------------|
| L1 | Memory exhaustion | `agent-os/src/agent_os/prompt_injection.py:336,639` | Unbounded `_audit_log` list grows forever |
| L2 | Memory exhaustion | `agent-mesh/services/api/src/middleware/rateLimit.ts:10-36` | Rate limiter `store` Map never cleans up expired IPs |
| L3 | Deprecated API | `agent-mesh/src/agentmesh/trust/handshake.py:32+` | `datetime.utcnow()` used throughout; deprecated since Python 3.12 |
| L4 | Info disclosure | `agentmesh/marketplace/sandbox.py:234-238` | stderr from sandbox subprocess included in exception messages |
| L5 | Potential ReDoS | `agent-mesh/packages/mcp-proxy/src/sanitizer.ts:32` | Nested repetition in command injection regex |
| L6 | Permissions | `scorecard.yml:11` | `permissions: read-all` broader than necessary |
| L7 | Inconsistency | Multiple workflow files | Different SHAs for same `github/codeql-action` across workflows |

---

## Supply Chain Analysis

### Dependency Health

**Critical Issues:**
- **No lock files** anywhere in the repository (10 `package.json`, 39 `pyproject.toml`)
- **Unpinned `cryptography`** in 4 production `pyproject.toml` files (zero version constraint)
- **Conflicting `cryptography` constraints**: agent-os iatp wants `>=46.0.5,<47.0` but dev caps at `<46.0` -- mutually exclusive
- **`langchain-core` conflict**: agent-mesh requires `>=1.2.11,<2.0` but langchain-agentmesh integration caps at `<1.0`

**Positive Practices:**
- Docker base images pinned with SHA256 digests (excellent)
- Multi-stage Docker builds used in several packages
- `scripts/check_dependency_confusion.py` provides typosquatting protection
- `scripts/generate_sbom.py` for CycloneDX SBOM generation
- All GitHub Actions third-party dependencies are SHA-pinned
- Dependabot configured with comprehensive ecosystem coverage

**Notable Dependencies:**
- `crypto-js@4.2.0` in mcp-proxy (consider native Node.js crypto instead)
- `.npmrc` sets `legacy-peer-deps=true` globally, masking peer dependency conflicts

---

## Code Quality Assessment

**Architecture**: Well-organized monorepo with clear package boundaries. Each package has its own `pyproject.toml`/`package.json`, README, and test suite. The IATP (Inter-Agent Trust Protocol) and policy engine are well-designed with ADRs documenting key decisions.

**Error Handling**: Mixed. Some packages (prompt injection detector, memory guard) implement fail-closed correctly. Others (Chrome extension code review, webhook verification) fail-open silently. The simulation fallbacks in crypto code are the most dangerous pattern.

**Test Coverage**: Comprehensive test suites exist across packages with unit tests, integration tests, fuzz tests (ClusterFuzzLite), and property-based testing. However, several security-critical paths (simulation fallbacks, sandbox bypass vectors) appear undertested.

**Documentation**: Excellent. 27 tutorials, ADRs, threat model, OWASP compliance docs, deployment guides, testing guide. The security documentation (`SECURITY.md`, `THREAT_MODEL.md`, `OWASP-COMPLIANCE.md`) is thorough.

---

## Contribution Opportunities

| Rank | File | Issue | Fix | Effort |
|------|------|-------|-----|--------|
| 1 | `packages/agent-mesh/packages/langchain-agentmesh/langchain_agentmesh/identity.py:133` | Simulation mode returns `True` for all signature verification | Change to `return False` + log critical warning | Trivial |
| 2 | `packages/agent-marketplace/src/agent_marketplace/installer.py:183` | Transitive deps skip signature verification (`verify=False`) | Change to `verify=True` | Trivial |
| 3 | `packages/agent-compliance/src/agent_compliance/integrity.py:256` | Non-constant-time hash comparison | Replace `==` with `hmac.compare_digest()` | Trivial |
| 4 | `packages/agent-os/extensions/copilot/src/index.ts:247-257` | Webhook HMAC bypass (non-constant-time + conditional skip) | Use `crypto.timingSafeEqual()`, require signature when secret is set | Small |
| 5 | `packages/agent-mesh/src/agentmesh/marketplace/sandbox.py:111` | `compile` not stripped from sandbox builtins | Add `compile` to `_STRIP` list | Trivial |

---

## Draft PRs

### PR 1: fix(identity): reject signatures in simulation mode instead of accepting all
- **Branch**: `fix/simulation-mode-signature-bypass`
- **Files**: `packages/agent-mesh/packages/langchain-agentmesh/langchain_agentmesh/identity.py`, `packages/agentmesh-integrations/dify/identity.py`
- **Changes**: Change `verify_signature()` simulation fallback from `return True` to `return False` with a `logging.critical()` warning. Change deterministic key derivation to raise `RuntimeError("cryptography package required for signing")`. Update corresponding tests.
- **Impact**: Closes a complete authentication bypass. Currently any agent can forge any identity when `cryptography` is not installed.

### PR 2: fix(marketplace): verify signatures for transitive plugin dependencies
- **Branch**: `fix/transitive-dep-signature-verification`
- **Files**: `packages/agent-marketplace/src/agent_marketplace/installer.py`, `packages/agent-mesh/src/agentmesh/marketplace/_marketplace_impl.py`
- **Changes**: Change `verify=False` to `verify=True` in the recursive `self.install()` call for dependencies. Add test case that installs a signed plugin with an unsigned dependency and verifies it fails.
- **Impact**: Closes a supply chain attack vector where a signed plugin can declare unsigned malicious dependencies.

### PR 3: fix(copilot): use constant-time comparison for webhook signatures and require verification
- **Branch**: `fix/webhook-signature-verification`
- **Files**: `packages/agent-os/extensions/copilot/src/index.ts`
- **Changes**: Replace `!==` with `crypto.timingSafeEqual()` for HMAC comparison. Change verification logic to reject requests missing signature header when `GITHUB_WEBHOOK_SECRET` is configured. Add authentication middleware to `/api/policy` and `/api/audit` endpoints.
- **Impact**: Prevents webhook spoofing and unauthorized policy modification.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 4 |
| Documentation | 9 |
| Test Coverage | 6 |
| Contribution Potential | 9 |

---

## Summary

- **Total findings by severity**: Critical: 3, High: 10, Medium: 15, Low: 7, Info: 0
- **Overall risk level**: **HIGH**

**Top 3 Recommendations:**
1. **Eliminate simulation mode crypto fallbacks** -- The `return True` signature verification bypass (C1) and deterministic key derivation (C2) completely undermine the trust architecture. Make `cryptography` a hard dependency or refuse to operate without it.
2. **Generate and commit lock files** -- The absence of any lock files across the entire monorepo (C3) is the biggest supply chain risk. Use `npm ci` + `package-lock.json` and `pip-compile` / `uv lock` for reproducible builds.
3. **Add authentication to API endpoints** -- The hypervisor (H1) and copilot extension (H7) expose critical operations (session management, policy modification, audit logs) without any authentication. Add API key or JWT middleware at minimum.
