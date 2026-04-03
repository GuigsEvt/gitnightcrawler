I have all the data needed. Here is the complete security audit report:

---

# Security Audit: vllm-project/vllm

## Repository Overview

vLLM is a high-throughput, memory-efficient inference and serving engine for Large Language Models (LLMs). It provides an OpenAI-compatible API server with support for tensor parallelism, distributed inference across multiple GPUs/nodes, PagedAttention for efficient memory management, and continuous batching. It is one of the most widely deployed open-source LLM serving frameworks.

- **Tech stack**: Python, C++/CUDA (csrc/), FastAPI, gRPC, ZMQ, PyTorch, uvicorn
- **Languages**: Python (~90%), C++/CUDA (~10%)
- **Maturity**: Mature (30k+ GitHub stars, active development, extensive CI)
- **Categories detected**: general, AI/ML inference serving

---

## Critical & High Severity Findings

### C1. Pickle Deserialization over ZMQ TCP Sockets (RCE)
- **Severity**: CRITICAL
- **Category**: Unsafe deserialization
- **Location**: `vllm/distributed/device_communicators/shm_broadcast.py:766,781`
- **Description**: `MessageQueue.recv()` calls `pickle.loads()` on data from ZMQ TCP sockets. When remote readers are configured (PUB/SUB over TCP at line 422), any network host that can connect to the socket can send crafted pickle payloads.
- **Impact**: Remote code execution on any vLLM worker in a multi-node deployment.
- **Fix**: Replace pickle with msgpack/msgspec for ZMQ TCP paths. Keep pickle only for local IPC. Add ZMQ CURVE authentication for TCP sockets.
- **Confidence**: High

### C2. Pickle Deserialization in HTTP Weight Transfer (RCE, gated)
- **Severity**: CRITICAL (mitigated by opt-in flag)
- **Category**: Unsafe deserialization
- **Location**: `vllm/distributed/weight_transfer/ipc_engine.py:85`
- **Description**: `pickle.loads(base64.b64decode(self.ipc_handles_pickled))` deserializes data received via HTTP. Gated behind `VLLM_ALLOW_INSECURE_SERIALIZATION=1` (line 79), but when enabled, deserialized IPC handles include callable `(func, args)` tuples that are invoked at line 191.
- **Impact**: Arbitrary code execution from any HTTP client when the insecure flag is set.
- **Fix**: Replace pickle with structured metadata for IPC handles. Document prominently that this flag must never be used on network-exposed instances.
- **Confidence**: High

### H1. Unauthenticated gRPC Server on 0.0.0.0
- **Severity**: HIGH
- **Category**: Network exposure, missing authentication
- **Location**: `vllm/entrypoints/grpc_server.py:109,111`
- **Description**: gRPC server defaults to `0.0.0.0` binding with `add_insecure_port()`. No TLS, no authentication. Max message size set to unlimited (`-1`) at line 88-89.
- **Impact**: Unauthenticated access to full inference API. DoS via oversized messages.
- **Fix**: Default to `127.0.0.1`. Add TLS via `add_secure_port()`. Set reasonable message size limits.
- **Confidence**: High

### H2. Unauthenticated ZMQ TCP in P2P NCCL Engine
- **Severity**: HIGH
- **Category**: Network exposure, missing authentication
- **Location**: `vllm/distributed/kv_transfer/kv_connector/v1/p2p/p2p_nccl_engine.py:127`
- **Description**: ZMQ ROUTER socket bound to TCP with no authentication. Accepts `NEW` (init NCCL channels), `PUT` (allocate GPU memory), `GET` (exfiltrate tensors) commands from any client.
- **Impact**: GPU memory exhaustion, data exfiltration, unauthorized NCCL communication channel establishment.
- **Fix**: Add shared-secret or mTLS authentication. Restrict binding to cluster-internal interfaces.
- **Confidence**: High

### H3. Unauthenticated ZMQ Event Publisher
- **Severity**: HIGH
- **Category**: Network exposure, data leakage
- **Location**: `vllm/distributed/kv_events.py:288,379,389`
- **Description**: PUB and ROUTER sockets on `tcp://*:5557` with no authentication. ROUTER services replay requests from any client exposing KV cache events.
- **Impact**: Information leakage of request metadata (token IDs, block hashes).
- **Fix**: Restrict to IPC sockets or add ZMQ CURVE authentication. Bind to specific internal interface.
- **Confidence**: High

### H4. Dependency Confusion via UV_INDEX_STRATEGY="unsafe-best-match"
- **Severity**: HIGH
- **Category**: Supply chain
- **Location**: `docker/Dockerfile:134`
- **Description**: The `unsafe-best-match` strategy resolves packages from all indexes preferring highest version. Combined with `--extra-index-url` for PyTorch CUDA indexes, an attacker can publish higher-versioned packages on PyPI with the same name.
- **Impact**: Malicious package installation in Docker builds, arbitrary code execution at build/runtime.
- **Fix**: Use `unsafe-first-match` or scope packages to specific indexes using `uv`'s `--index` with package restrictions.
- **Confidence**: High

### H5. Docker Images Run as Root
- **Severity**: HIGH
- **Category**: Container security
- **Location**: `docker/Dockerfile` (entire file, no `USER` directive)
- **Description**: All Docker image stages including production (`vllm-openai`, `vllm-sagemaker`) run as root.
- **Impact**: Container escape or compromise gives attacker root access.
- **Fix**: Add `RUN useradd -m vllm && USER vllm` for runtime stages.
- **Confidence**: High

### H6. Curl-Pipe-Shell Without Integrity Verification
- **Severity**: HIGH
- **Category**: Supply chain
- **Location**: `docker/Dockerfile:120`, `docker/Dockerfile:543`
- **Description**: `curl -LsSf https://astral.sh/uv/install.sh | sh` and `curl -sS ${GET_PIP_URL} | python` with no checksum verification.
- **Impact**: MITM or domain compromise allows arbitrary code execution during Docker build.
- **Fix**: Pin installer versions and verify checksums before execution.
- **Confidence**: High

### H7. Pickle via TCPStore in Multi-Node Distributed Communication
- **Severity**: HIGH
- **Category**: Unsafe deserialization
- **Location**: `vllm/distributed/utils.py:216,236,264,279`
- **Description**: `StatelessProcessGroup` uses `pickle.loads()` for object exchange via TCPStore. In multi-node setups, TCPStore listens on TCP with no encryption or authentication.
- **Impact**: Remote code execution from any host that can reach the TCPStore port.
- **Fix**: Add HMAC signing to serialized payloads. Use encrypted channels for multi-node communication.
- **Confidence**: High

### H8. WebSocket Authentication Gap for Browser Clients
- **Severity**: HIGH
- **Category**: Authentication bypass
- **Location**: `vllm/entrypoints/openai/realtime/api_router.py:28-50`
- **Description**: WebSocket endpoint at `/v1/realtime` relies on `AuthenticationMiddleware` checking Bearer tokens in headers. Browser WebSocket API does not support custom headers, making browser clients unable to authenticate even when API keys are configured.
- **Impact**: Effectively unauthenticated WebSocket access for browser-based clients.
- **Fix**: Implement token passing via query parameter or WebSocket subprotocol. Validate within the endpoint handler before `websocket.accept()`.
- **Confidence**: High

### H9. Arbitrary Module Loading via Config-Controlled Paths
- **Severity**: HIGH
- **Category**: Code injection
- **Location**: `vllm/distributed/kv_transfer/kv_connector/factory.py:116`, `vllm/config/compilation.py:901`, `vllm/v1/sample/logits_processor/__init__.py:130`
- **Description**: Multiple code paths use `importlib.import_module()` or `__import__()` with module paths from config files or API parameters. The logits processor FQCN path (line 130) is especially dangerous as it may accept values from API callers.
- **Impact**: Arbitrary code execution if attacker controls config values or API parameters.
- **Fix**: Restrict module loading to allowlisted namespaces (e.g., `vllm.*`, `torch.*`). Never accept FQCNs from API request payloads.
- **Confidence**: Medium-High

### H10. Unpinned Third-Party Actions in CI
- **Severity**: HIGH
- **Category**: Supply chain
- **Location**: `.github/workflows/macos-smoke-test.yml:18,21`
- **Description**: `actions/checkout@v6.0.1` pinned to tag (not SHA), `astral-sh/setup-uv@v7` pinned to major version only. Tags are mutable -- upstream compromise allows repointing to malicious commits.
- **Impact**: CI supply chain compromise, secret exfiltration.
- **Fix**: Pin all actions to full SHA hashes.
- **Confidence**: High

---

## Medium & Low Severity Findings

### M1. SSRF via Multimodal Media URL Fetching
- **Severity**: MEDIUM
- **Category**: SSRF
- **Location**: `vllm/connections.py:225-256`, `vllm/multimodal/media/connector.py:286-319`
- **Description**: HTTP URL validation only checks scheme (http/https), not destination IP. No blocking of private ranges (127.0.0.1, 169.254.x.x, 10.x.x.x). `allowed_media_domains` is empty by default. Redirects enabled by default.
- **Impact**: Internal network probing via multimodal API requests.
- **Fix**: Add private IP range blocking. Make `allowed_media_domains` mandatory in production. Disable redirects by default.
- **Confidence**: High

### M2. Permissive CORS Defaults (Wildcard Everything)
- **Severity**: MEDIUM
- **Category**: Misconfiguration
- **Location**: `vllm/entrypoints/openai/cli_args.py:236-241`
- **Description**: Default CORS: `allowed_origins=["*"]`, `allowed_methods=["*"]`, `allowed_headers=["*"]`.
- **Impact**: Any website can make cross-origin API requests.
- **Fix**: Default to deny-all; require explicit opt-in. Warn when wildcard used with auth enabled.
- **Confidence**: High

### M3. Error Responses Leak Internal Details
- **Severity**: MEDIUM
- **Category**: Information disclosure
- **Location**: `vllm/entrypoints/utils.py:349`, `vllm/entrypoints/openai/server_utils.py:372-382`
- **Description**: `str(exc)` passed directly to client in JSON error responses. `sanitize_message` only strips memory addresses, not file paths, class names, or internal state.
- **Impact**: Internal architecture, file paths, and configuration details leaked to clients.
- **Fix**: Return generic messages for 5xx errors; log details server-side only.
- **Confidence**: High

### M4. Shared Memory Without Access Control
- **Severity**: MEDIUM
- **Category**: Local privilege escalation
- **Location**: `vllm/distributed/device_communicators/shm_broadcast.py:274-276`
- **Description**: POSIX shared memory segments use default permissions. Any same-user process can attach and corrupt data, including poisoning pickle payloads.
- **Impact**: Code execution via pickle poisoning in shared memory.
- **Fix**: Use restrictive permissions (0600). Add HMAC integrity checks before deserialization.
- **Confidence**: Medium

### M5. No Rate Limiting on Any Endpoint
- **Severity**: MEDIUM
- **Category**: Denial of service
- **Location**: `vllm/entrypoints/openai/api_server.py` (build_app function)
- **Description**: No rate limiting middleware. Server relies entirely on external infrastructure.
- **Impact**: Resource exhaustion from unlimited requests.
- **Fix**: Add optional rate limiting middleware configurable via CLI.
- **Confidence**: High

### M6. Unbounded WebSocket Audio Buffer
- **Severity**: MEDIUM
- **Category**: Denial of service
- **Location**: `vllm/entrypoints/openai/realtime/connection.py:47,114-134`
- **Description**: `audio_queue` has no `maxsize`. Cumulative buffered data is not tracked.
- **Impact**: Unbounded memory growth from malicious clients sending many small chunks.
- **Fix**: Set `maxsize` on queue and track cumulative bytes per connection.
- **Confidence**: High

### M7. Unpinned Runtime Dependencies
- **Severity**: MEDIUM
- **Category**: Supply chain
- **Location**: `requirements/common.txt`
- **Description**: Multiple dependencies with no version constraints: `regex`, `cachetools`, `numpy`, `pillow`, `msgspec`, `pyyaml`, `cloudpickle`, `mcp`.
- **Impact**: Compromised package release automatically pulled into builds.
- **Fix**: Add upper bounds or pin versions for critical dependencies.
- **Confidence**: Medium

### L1. Authentication Bypass on Non-/v1 Routes
- **Severity**: LOW
- **Category**: Authentication gap
- **Location**: `vllm/entrypoints/openai/server_utils.py:80`
- **Description**: Auth only enforced for `/v1` prefix. Routes outside this prefix (health, metrics, future additions) bypass auth.
- **Fix**: Use whitelist approach (skip known public routes) instead of prefix-based exclusion.
- **Confidence**: Medium

### L2. Fallback IP 0.0.0.0 in Network Utils
- **Severity**: LOW
- **Category**: Silent security degradation
- **Location**: `vllm/utils/network_utils.py:67-72`
- **Description**: `get_ip()` falls back to `0.0.0.0` on failure, silently binding all services to all interfaces.
- **Fix**: Raise error instead of falling back. Require explicit `VLLM_HOST_IP`.
- **Confidence**: High

### L3. X-Request-Id Header Reflection Without Validation
- **Severity**: LOW
- **Category**: Input validation
- **Location**: `vllm/entrypoints/openai/server_utils.py:110-111`
- **Description**: Client-provided `X-Request-Id` reflected without length/format validation.
- **Fix**: Validate format (max 128 chars, alphanumeric + hyphens).
- **Confidence**: Low

---

## Supply Chain Analysis

| Area | Assessment |
|------|------------|
| **Dependency pinning** | Runtime deps (`requirements/common.txt`) use minimum bounds only; test deps (`requirements/test.txt`) are properly pinned. Docker builds use `UV_INDEX_STRATEGY=unsafe-best-match` creating dependency confusion risk. |
| **CI actions** | Most workflows pin to SHA hashes (good), but `macos-smoke-test.yml` uses tag-based pinning. |
| **Docker builds** | Curl-pipe-shell pattern for `uv` and `pip` installers without checksum verification. Third-party PPA (`deadsnakes`) added. |
| **Plugin system** | Entry points (`vllm.general_plugins`, `vllm.logitsprocs`) load any pip-installed package -- inherent to the model but increases supply chain surface. |
| **Key dependencies** | PyTorch, transformers, numpy, fastapi, uvicorn -- all well-maintained. `cloudpickle` and `msgspec` are less mainstream but actively developed. |

No known CVEs detected in pinned dependency versions at time of review.

---

## Code Quality Assessment

| Area | Assessment |
|------|------------|
| **Architecture** | Well-structured modular design. Clean separation between entrypoints, engine, distributed, and model layers. |
| **Error handling** | Generally good with typed exceptions. Some catch-all `Exception` handlers leak details to clients. |
| **Test coverage** | Extensive test suite under `tests/`. Comprehensive CI with Buildkite. Multiple hardware-specific test configurations. |
| **Documentation** | Good contributor docs. AGENTS.md is thoughtful. API docs auto-generated. Security documentation is sparse. |
| **Code style** | Enforced via pre-commit (ruff, mypy). Consistent conventions. |

---

## Contribution Opportunities

| # | File | Issue | Fix | Effort |
|---|------|-------|-----|--------|
| 1 | `vllm/connections.py:225-256` | No SSRF protection on media URL fetching | Add private IP range blocking utility | Small |
| 2 | `vllm/entrypoints/grpc_server.py:109-111` | gRPC defaults to 0.0.0.0 insecure | Default to 127.0.0.1, add TLS option, set message limits | Medium |
| 3 | `docker/Dockerfile:134` | `UV_INDEX_STRATEGY=unsafe-best-match` | Switch to `unsafe-first-match` | Trivial |
| 4 | `vllm/entrypoints/openai/server_utils.py:372-382` | Error responses leak internals | Return generic 5xx messages, log details server-side | Small |
| 5 | `docker/Dockerfile:120` | Curl-pipe-shell without verification | Pin uv version, verify checksum | Small |

---

## Draft PRs

### PR 1: fix(docker): prevent dependency confusion via index strategy
- **Branch**: `fix/docker-index-strategy`
- **Files**: `docker/Dockerfile`
- **Changes**: Replace `UV_INDEX_STRATEGY="unsafe-best-match"` with `"unsafe-first-match"` at line 134. This ensures packages from the primary index are preferred over higher versions from extra indexes, preventing dependency confusion attacks where an attacker publishes a higher-versioned package on PyPI.
- **Impact**: Closes a supply chain attack vector affecting all Docker-based deployments.

### PR 2: fix(server): add SSRF protection for media URL fetching
- **Branch**: `fix/ssrf-media-url-protection`
- **Files**: `vllm/connections.py`, `vllm/multimodal/media/connector.py`
- **Changes**: Add a `_validate_url_target()` method to `HTTPConnection` that resolves the URL hostname and blocks requests to private/reserved IP ranges (RFC 1918, link-local, loopback, metadata endpoints like 169.254.169.254). Apply this check before all outbound HTTP requests in `get_response()` and `get_async_response()`. Also check redirect targets.
- **Impact**: Prevents SSRF attacks via multimodal media URLs probing internal infrastructure.

### PR 3: fix(grpc): default to localhost and set message size limits
- **Branch**: `fix/grpc-security-defaults`
- **Files**: `vllm/entrypoints/grpc_server.py`
- **Changes**: Change default host from `0.0.0.0` to `127.0.0.1` at line 109. Set `grpc.max_receive_message_length` to a reasonable limit (e.g., 100MB) instead of unlimited (-1). Add `--grpc-enable-tls`, `--grpc-tls-cert`, `--grpc-tls-key` CLI options for secure port binding.
- **Impact**: Prevents accidental exposure of unauthenticated gRPC to all network interfaces and mitigates DoS via oversized messages.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 4 |
| Documentation | 7 |
| Test Coverage | 8 |
| Contribution Potential | 7 |

---

## Summary

- **Total findings by severity**: Critical: 2, High: 8, Medium: 7, Low: 3 -- **Total: 20**
- **Overall risk level**: **HIGH**

### Top 3 Recommendations

1. **Eliminate pickle deserialization over network sockets** -- The combination of `pickle.loads()` with unauthenticated TCP-bound ZMQ/TCPStore sockets (C1, H7) is the most critical attack surface. In multi-node deployments, any host on the network can achieve remote code execution. Replace with msgpack + HMAC signing for network paths.

2. **Fix supply chain attack vectors in Docker builds** -- `UV_INDEX_STRATEGY=unsafe-best-match` (H4) enables dependency confusion, and curl-pipe-shell without checksums (H6) enables build-time compromise. These are trivial-to-small fixes with high impact.

3. **Secure distributed network services** -- gRPC (H1), ZMQ P2P NCCL (H2), and ZMQ event publisher (H3) all bind to 0.0.0.0 without authentication. Default to localhost, add authentication mechanisms, and document the security model for multi-node deployments.
