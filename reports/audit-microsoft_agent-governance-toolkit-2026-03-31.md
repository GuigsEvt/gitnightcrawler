# Audit: microsoft/agent-governance-toolkit

## Repository Overview

Microsoft Agent Governance Toolkit is a runtime governance infrastructure for AI agents that governs **what agents do**, not what they say. It provides a policy engine, zero-trust identity (Ed25519), execution sandboxing (4-tier privilege rings), agent SRE (error budgets, circuit breakers), and 12+ framework integrations (LangChain, CrewAI, Dify, LlamaIndex, etc.). Claims 10/10 OWASP Agentic Top 10 coverage with <0.1ms p50 latency and 9,500+ tests.

**Tech stack:** Python (87.7%), TypeScript (8.5%), C# (3.2%). Build: Hatchling (Python), npm, .NET SDK. Frameworks: FastAPI, Pydantic, structlog, cryptography/pynacl, pytest, Jest, xUnit. CI: GitHub Actions (34 workflows) with path-based conditional execution.

**Maturity:** Growing/Mature — v3.0.0, comprehensive docs (437 md files), ADRs, threat model, OWASP compliance mapping, ESRP code signing, SBOM generation. MIT license. Microsoft-backed but public preview.

---

## Code Quality Assessment

### Architecture and Organization
**Rating: Excellent.** Clean monorepo with 13 packages in layered architecture: primitives → infrastructure (trust, messaging) → framework (control-plane, observability) → intelligence (semantic analysis). 14 agent-os modules with clear separation. Path-based CI ensures only affected packages run. Each package independently installable via PyPI/npm/NuGet.

### Error Handling Patterns
**Rating: Good with concerns.** 40+ bare `except Exception` clauses across agent-mesh (transport/websocket.py, providers.py, handshake.py, sandbox.py). Some use `# noqa: BLE001` to suppress linter warnings rather than fixing. Core patterns are sound — specific exception types like `HandshakeError`, `HandshakeTimeoutError` exist. CWE-209 (error info exposure) was addressed per changelog.

### Test Coverage
**Rating: Uneven.** 433 test files, ~3,399+ test functions (agent-os alone). Strong core testing in agent-mesh (68 files) and agent-os (97 files). Critical gaps:
- `agent-sre`: **0 tests** despite 124 source files
- `agent-os-vscode`: **0 tests** (19 TS files)
- `agent-runtime`: **0 tests**
- `agent-lightning`: 2 tests for 7 source files
- Most `agentmesh-integrations`: stub tests only
- No coverage reporting enforced in CI

### Documentation Quality
**Rating: Excellent.** 437 markdown files. 23 tutorials, 6 ADRs, 24 proposals, STRIDE threat model, OWASP compliance matrix, deployment guides (AKS, Container Apps, private endpoints). Every package has README with code examples. Comprehensive docstrings with usage examples. Contributing guide, security policy, benchmarks doc.

### Dependency Health
**Rating: Strong.** All versions use `>=` minimum pinning. Security-critical packages pinned tightly (cryptography>=46.0.5). CVE tracking documented (CVE-2025-27520, CVE-2024-53981, CVE-2024-47874, CVE-2024-5206, CVE-2023-36464). GitHub Actions SHA-pinned. Dependency confusion detection script. SBOM generation. Missing: hash verification in CI requirements.

---

## Security Findings

### Critical
None found.

### High
| Finding | Details |
|---------|---------|
| **Historical shell=True injection (CWE-78)** | MSRC Case 111178 — fixed but reintroduced twice via PRs #357, #362. Mitigated by mandatory maintainer approval. No current instances in production code. |
| **CostGuard kill switch bypass (fixed)** | IEEE 754 NaN/Infinity bypassed budget thresholds. Fixed v2.1.0 PR #272. |

### Medium
| Finding | Details |
|---------|---------|
| **Bare except Exception clauses** | 40+ instances in transport, handshake, sandbox code. Could mask errors in security-critical paths. Files: `providers.py:50`, `websocket.py:89,203,220`, `handshake.py:262`, `sandbox.py:84,123` |
| **innerHTML in VS Code extension** | `MetricsDashboardPanel.ts`, `WorkflowDesignerPanel.ts` use template literals for HTML. VS Code webview context mitigates risk but not ideal. |
| **Thread safety issues (fixed)** | 4 race conditions fixed in v2.1.0: CostGuard breach history, VectorClock, ErrorBudget._events, .NET SDK disposal. |

### Low
| Finding | Details |
|---------|---------|
| **No hash verification in CI deps** | `requirements/ci-lint.txt` lacks `--require-hashes`. Supply chain risk for CI environment. |
| **Loose PyYAML pinning** | `pyyaml>=6.0` is very broad. Tighter pinning recommended. |
| **Example API key in VS Code extension** | `extension.ts` contains `sk-EXAMPLE-NOT-A-REAL-KEY-replace-with-your-own` — clearly placeholder but could be cleaner. |

### Info
| Finding | Details |
|---------|---------|
| **No hardcoded secrets** | All .env files are .example only with placeholder values. |
| **yaml.safe_load enforced** | Copilot instructions and compliance scanner check for unsafe yaml.load. |
| **Pickle/marshal blocked** | DANGEROUS_IMPORTS blocklist in secure_codegen.py and sandbox.py. |
| **CORS strict by default** | Hardcoded GitHub-only origins with URL validation. |

---

## Contribution Opportunities

### Bugs

1. **File:** `packages/agent-mesh/src/agentmesh/transport/websocket.py:89,203,220`
   **Issue:** Bare `except Exception` in WebSocket transport can silently swallow connection errors
   **Fix:** Catch specific `ConnectionError`, `asyncio.TimeoutError`, `websockets.exceptions.WebSocketException`
   **Effort:** small
   **PR-worthy:** high

2. **File:** `packages/agent-mesh/src/agentmesh/marketplace/sandbox.py:84,123`
   **Issue:** Broad exception handling in plugin sandbox could mask security-relevant failures
   **Fix:** Catch `ImportError`, `subprocess.TimeoutExpired`, `json.JSONDecodeError` specifically
   **Effort:** small
   **PR-worthy:** high

### Security Fixes

3. **File:** `requirements/ci-lint.txt`
   **Issue:** No hash verification for CI dependencies
   **Fix:** Add `--require-hashes` and generate hashes with `pip-compile --generate-hashes`
   **Effort:** small
   **PR-worthy:** medium

4. **File:** `packages/agent-os-vscode/src/webviews/metricsDashboard/MetricsDashboardPanel.ts`, `WorkflowDesignerPanel.ts`
   **Issue:** Template literal HTML injection risk in webview panels
   **Fix:** Use a sanitization library or CSP nonce-based approach for dynamic content
   **Effort:** medium
   **PR-worthy:** medium

### Missing Tests

5. **File:** `packages/agent-sre/` (entire package)
   **Issue:** 124 Python source files with zero test coverage — SRE functionality (SLOs, error budgets, circuit breakers, chaos engineering) is untested
   **Fix:** Add pytest suite covering core SRE primitives: SLO enforcement, error budget calculations, circuit breaker state transitions, chaos injection
   **Effort:** large
   **PR-worthy:** high

6. **File:** `packages/agent-os-vscode/` (entire package)
   **Issue:** VS Code extension (19 TS files) has no automated tests
   **Fix:** Add Jest tests for webview panels, command handlers, configuration management
   **Effort:** medium
   **PR-worthy:** medium

7. **File:** `packages/agent-marketplace/` (5 tests for 17 source files)
   **Issue:** Low test coverage for marketplace trust tiers, plugin lifecycle, installer security
   **Fix:** Add tests for trust scoring edge cases, malicious plugin detection, signing verification
   **Effort:** medium
   **PR-worthy:** high

### Documentation Gaps

8. **File:** `packages/agentmesh-integrations/nostr-wot/`, `a2a-protocol/`
   **Issue:** Minimal READMEs with no usage examples
   **Fix:** Add quick-start code examples, configuration guide, integration architecture
   **Effort:** small
   **PR-worthy:** low

9. **File:** CI configuration (no `.coveragerc` or coverage threshold)
   **Issue:** No coverage reporting or minimum threshold enforcement in CI
   **Fix:** Add `pytest-cov` threshold to CI, publish coverage badge
   **Effort:** small
   **PR-worthy:** medium

### Code Improvements

10. **File:** `packages/agent-marketplace/src/agent_marketplace/signing.py` + `packages/agent-mesh/src/agentmesh/marketplace/signing.py`
    **Issue:** Marketplace signing/manifest logic duplicated between two packages
    **Fix:** Consolidate into shared module or have agent-marketplace depend on agent-mesh
    **Effort:** medium
    **PR-worthy:** medium

11. **File:** Multiple `except Exception` across `packages/agent-mesh/src/agentmesh/observability/tracing.py:138,165,331,350`
    **Issue:** Observability code silently catches all exceptions — could hide instrumentation failures
    **Fix:** Catch specific OTEL exceptions, log at warning level minimum
    **Effort:** trivial
    **PR-worthy:** medium

### Feature Ideas

12. **Coverage gate in CI**
    **Issue:** No minimum test coverage threshold enforced
    **Fix:** Add `--cov-fail-under=80` to pytest CI step, add coverage badge to README
    **Effort:** trivial
    **PR-worthy:** high

13. **Dead code detection**
    **Issue:** No automated dead code scanning
    **Fix:** Add `vulture` to CI lint step
    **Effort:** trivial
    **PR-worthy:** low

---

## Draft PRs

### PR 1: Narrow exception handling in security-critical paths

- **PR Title:** `fix: replace bare except Exception with specific exception types in transport and sandbox`
- **Branch:** `fix/narrow-exception-handling`
- **Files:**
  - `packages/agent-mesh/src/agentmesh/transport/websocket.py`
  - `packages/agent-mesh/src/agentmesh/marketplace/sandbox.py`
  - `packages/agent-mesh/src/agentmesh/trust/handshake.py`
  - `packages/agent-mesh/src/agentmesh/providers.py`
  - `packages/agent-mesh/src/agentmesh/observability/tracing.py`
- **Changes:** Replace ~15 bare `except Exception` clauses with specific types: `ConnectionError`, `asyncio.TimeoutError`, `websockets.exceptions.*` for transport; `ImportError`, `subprocess.TimeoutExpired`, `json.JSONDecodeError` for sandbox; specific handshake/crypto errors for trust layer. Ensure all caught exceptions are logged with context.
- **Effort:** 2-3 hours
- **Impact:** Prevents silent failure masking in security-critical WebSocket transport, plugin sandboxing, and trust handshake paths. Improves debuggability and aligns with flake8-bugbear BLE001 rule already configured.

### PR 2: Add test suite for agent-sre package

- **PR Title:** `test: add comprehensive test suite for agent-sre package`
- **Branch:** `test/agent-sre-coverage`
- **Files:**
  - `packages/agent-sre/tests/` (new directory, ~10-15 test files)
  - `packages/agent-sre/tests/conftest.py`
  - `.github/workflows/ci.yml` (add agent-sre to test matrix if not present)
- **Changes:** Create pytest suite covering: SLO definition and enforcement, error budget calculation and depletion, circuit breaker open/half-open/closed transitions, signing module (Ed25519 signatures), chaos engineering injection, progressive delivery gates. Include both happy-path and edge-case tests (NaN inputs, concurrent access, budget exhaustion).
- **Effort:** 1-2 days
- **Impact:** 124 source files currently untested. SRE functionality (circuit breakers, error budgets) is production-critical — bugs here cause cascading failures. Highest-impact test gap in the repo.

### PR 3: Enforce coverage threshold and reporting in CI

- **PR Title:** `ci: add test coverage threshold and reporting`
- **Branch:** `ci/coverage-gate`
- **Files:**
  - `.github/workflows/ci.yml` (add `--cov-fail-under=70` to pytest steps)
  - `pyproject.toml` files for each package (add `[tool.coverage.run]` config)
  - `README.md` (add coverage badge)
- **Changes:** Configure pytest-cov with `--cov-fail-under=70` as initial threshold. Add `.coveragerc` or `[tool.coverage]` sections to each package's pyproject.toml with source paths and omit patterns. Generate coverage XML for CI artifact upload. Add Codecov or similar badge to root README.
- **Effort:** 2-3 hours
- **Impact:** Currently no coverage tracking means regressions go undetected. A coverage gate prevents merging PRs that reduce test coverage, establishing a quality floor across all packages.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 8 |
| Documentation | 9 |
| Test Coverage | 5 |
| Contribution Potential | 8 |

**Summary:** Impressively well-engineered for a growing project. The architecture, security posture, and documentation are production-grade. The main weakness is uneven test coverage — core packages (agent-mesh, agent-os) are well-tested but agent-sre (124 files, 0 tests) and the VS Code extension are completely untested. The 40+ bare exception catches in security-critical paths are the most actionable code quality issue.
