Now I have the complete codebase. Let me produce the security audit report.

# Security Audit: karpathy/autoresearch

## Repository Overview

Autoresearch is an experimental project by Andrej Karpathy that gives an AI coding agent a small but real LLM training setup and lets it experiment autonomously. The agent modifies `train.py`, runs 5-minute training experiments on a single GPU, evaluates with a fixed BPB metric, and keeps or discards changes in a loop. The project is intentionally minimal: two Python files (`train.py`, `prepare.py`), a markdown agent prompt (`program.md`), and standard PyTorch dependencies. It's a research prototype / educational tool, not a production service.

- **Tech stack**: Python 3.10+, PyTorch 2.9.1, uv package manager, BPE tokenizer (rustbpe/tiktoken)
- **Languages**: Python
- **Frameworks**: PyTorch (single-GPU), Flash Attention 3 via `kernels` package
- **Maturity**: Early-stage research prototype
- **Categories detected**: AI

## Critical & High Severity Findings

### Finding 1: Unsafe Pickle Deserialization of Tokenizer

- **Severity**: HIGH
- **Category**: Unsafe deserialization
- **Location**: `prepare.py:218-219`
- **Description**: The tokenizer is serialized/deserialized using `pickle.dump` / `pickle.load`. Pickle deserialization can execute arbitrary code if the `.pkl` file is tampered with. The tokenizer file lives at `~/.cache/autoresearch/tokenizer/tokenizer.pkl` and is loaded every time `train.py` runs via `Tokenizer.from_directory()`.
- **Impact**: If an attacker can write to the user's cache directory (e.g., via a supply chain attack, shared filesystem, or symlink attack), they can craft a malicious pickle file that executes arbitrary code when `train.py` is run. Given the autonomous agent loop runs indefinitely, this could provide persistent code execution.
- **Fix**: Replace pickle serialization with a safe format. tiktoken's `Encoding` can be reconstructed from its `mergeable_ranks` and `special_tokens` dicts — serialize those as JSON instead. Alternatively, use `torch.load(..., weights_only=True)` patterns or restrict to safe loaders.
- **Confidence**: Medium (requires local filesystem write access to exploit)

### Finding 2: Unsafe `torch.load` Without `weights_only=True`

- **Severity**: HIGH
- **Category**: Unsafe deserialization
- **Location**: `prepare.py:251`
- **Description**: `torch.load(f, map_location=device)` is called without `weights_only=True`. `torch.load` uses pickle under the hood and can execute arbitrary code from a crafted `.pt` file. The file loaded is `~/.cache/autoresearch/tokenizer/token_bytes.pt`.
- **Impact**: Same as Finding 1 — arbitrary code execution if the cached file is tampered with. PyTorch itself now warns about this and recommends `weights_only=True` for all `torch.load` calls.
- **Fix**: Change to `torch.load(f, map_location=device, weights_only=True)`. The loaded object is a simple `torch.tensor` of int32, so `weights_only=True` will work without issues.
- **Confidence**: Medium

### Finding 3: Shell Command Injection via Autonomous Agent Loop

- **Severity**: HIGH
- **Category**: Injection / agent safety
- **Location**: `program.md:99-100`
- **Description**: The `program.md` instructs the AI agent to run `uv run train.py > run.log 2>&1` and then parse output with `grep` and `tail`. The agent is instructed to modify `train.py` freely, then execute it. Since `train.py` is a Python script with full system access, a compromised or hallucinating agent could write malicious code into `train.py` (e.g., `os.system("rm -rf /")`, data exfiltration, reverse shells) and the autonomous loop would execute it.
- **Impact**: The entire design assumes the AI agent is trusted with arbitrary code execution on the host. Any prompt injection in the agent's context (via crafted data, model outputs, or the training logs themselves) could lead to arbitrary command execution. This is an inherent architectural risk of autonomous code-generation-and-execution loops.
- **Fix**: This is a fundamental design choice. Mitigations include: (1) run inside a sandboxed container (Docker/VM) with no network access, (2) restrict filesystem access to the project directory, (3) use seccomp/AppArmor profiles, (4) add a static analysis check on `train.py` diffs before execution (e.g., reject `os.system`, `subprocess`, `import socket`, etc.), (5) run as an unprivileged user.
- **Confidence**: High (by design, but still a security risk)

## Medium & Low Severity Findings

### Finding 4: HTTP Downloads Without Integrity Verification

- **Severity**: MEDIUM
- **Category**: Supply chain / data integrity
- **Location**: `prepare.py:57-88`
- **Description**: Data shards are downloaded from HuggingFace over HTTPS but no checksum or hash verification is performed. The `download_single_shard` function writes the response directly to disk after downloading.
- **Impact**: If the HuggingFace CDN is compromised, or if a MITM attack occurs (e.g., corporate proxy with TLS interception), corrupted or malicious training data could be served. While training data corruption is lower severity than code execution, poisoned training data could affect model behavior.
- **Fix**: Add SHA-256 checksum verification for downloaded shards. HuggingFace datasets API provides file checksums that could be verified after download.
- **Confidence**: Low (HTTPS provides transport security, but no at-rest integrity guarantee)

### Finding 5: Dynamic Kernel Loading from Remote Repository

- **Severity**: MEDIUM
- **Category**: Supply chain
- **Location**: `train.py:20-24`
- **Description**: Flash Attention 3 kernels are loaded dynamically at runtime via `get_kernel("varunneal/flash-attention-3")` or `get_kernel("kernels-community/flash-attn3")`. The `kernels` package fetches and compiles CUDA kernels from GitHub repositories at runtime. If either repository is compromised, malicious CUDA code would be compiled and executed.
- **Impact**: Arbitrary code execution via compromised upstream kernel repository. The `kernels-community` repo is community-maintained and has a larger attack surface.
- **Confidence**: Medium (depends on the `kernels` package's caching and verification behavior)

### Finding 6: No TLS Certificate Verification Configuration

- **Severity**: LOW
- **Category**: Network security
- **Location**: `prepare.py:68`
- **Description**: `requests.get(url, stream=True, timeout=30)` uses default TLS settings. While this is generally fine (certifi is used by default), there's no explicit `verify=True` to guard against accidental disabling.
- **Impact**: Minimal — default behavior is secure. Noted for completeness.
- **Confidence**: Low

### Finding 7: Hardcoded Seed May Reduce Experiment Diversity

- **Severity**: LOW (Info)
- **Category**: Logic
- **Location**: `train.py:458-459`
- **Description**: `torch.manual_seed(42)` and `torch.cuda.manual_seed(42)` are set once at startup. Since the autonomous agent loop restarts the entire script per experiment, every run starts with the same seed. This is actually correct for reproducibility but worth noting that experiment differences come only from code changes, not randomness.
- **Impact**: None — this is intentional design. Different code produces different results even with the same seed.
- **Confidence**: Low (informational)

### Finding 8: Temporary File Race Condition

- **Severity**: LOW
- **Category**: File handling
- **Location**: `prepare.py:70-75`
- **Description**: The download function writes to a `.tmp` file and renames it. While `os.rename` is atomic on the same filesystem, there's a window between creation and rename where another process could interfere. Additionally, the temp file naming is predictable (`filepath + ".tmp"`).
- **Impact**: Very low — only relevant in multi-process download scenarios where two processes download the same shard simultaneously. The worst case is a corrupted file that would cause a parquet read error.
- **Confidence**: Low

## Supply Chain Analysis

### Dependencies (`pyproject.toml`)

| Package | Version | Risk |
|---------|---------|------|
| `torch` | ==2.9.1 | Pinned, from custom PyTorch CUDA 12.8 index. Well-maintained. |
| `kernels` | >=0.11.7 | **Medium risk** — dynamically fetches and compiles CUDA kernels from GitHub repos at runtime. Relatively new package. |
| `numpy` | >=2.2.6 | Low risk, well-maintained |
| `matplotlib` | >=3.10.8 | Low risk, well-maintained |
| `pandas` | >=2.3.3 | Low risk, well-maintained |
| `pyarrow` | >=21.0.0 | Low risk, well-maintained |
| `requests` | >=2.32.0 | Low risk, well-maintained |
| `rustbpe` | >=0.1.0 | **Low-medium risk** — small package, Rust-based BPE tokenizer. Less widely audited. |
| `tiktoken` | >=0.11.0 | Low risk, OpenAI-maintained |

- **Custom index**: PyTorch is pulled from `https://download.pytorch.org/whl/cu128` — this is the official PyTorch index, safe.
- **Lock file**: `uv.lock` is present (443KB), ensuring reproducible builds.
- **Notable**: No `requirements.txt` — only `pyproject.toml` + `uv.lock`. This is good practice.

## Code Quality Assessment

### Architecture and Organization
- Excellent for a research prototype. Two Python files with clear separation: `prepare.py` (data/eval, read-only) and `train.py` (model/training, mutable).
- Clean, well-structured code following PyTorch conventions.
- Good use of `@dataclass` for model configuration.
- `torch.compile` used correctly with `dynamic=False, fullgraph=True`.

### Error Handling
- Minimal but appropriate for a research script. Download retries with exponential backoff (`prepare.py:66-88`).
- NaN/explosion detection in training loop (`train.py:570-572`).
- No exception handling in the training loop itself — a crash fails fast, which is correct for this use case.

### Test Coverage
- **No tests**. Zero test files in the repository. This is expected for a research prototype but limits confidence in correctness.

### Documentation Quality
- Excellent README with clear quick start, design rationale, and platform guidance.
- `program.md` is a well-structured agent prompt with clear rules and constraints.
- Inline code comments are sparse but the code is readable.

## Contribution Opportunities

1. **File**: `prepare.py:218-219` and `prepare.py:251`
   - **Issue**: Unsafe pickle and torch.load deserialization
   - **Fix**: Use JSON for tokenizer serialization, add `weights_only=True` to `torch.load`
   - **Effort**: Small

2. **File**: `prepare.py:57-88`
   - **Issue**: No checksum verification for downloaded data shards
   - **Fix**: Add SHA-256 hash verification after download
   - **Effort**: Small

3. **File**: `program.md:99`
   - **Issue**: No sandboxing guidance for autonomous execution
   - **Fix**: Add a "Security" section recommending Docker/container execution and listing dangerous patterns to reject
   - **Effort**: Trivial

4. **File**: `train.py:20-24`
   - **Issue**: Dynamic kernel loading from mutable GitHub repos
   - **Fix**: Pin specific commit hashes for kernel repos, or vendor the kernels
   - **Effort**: Medium

5. **File**: (new) `tests/test_prepare.py`
   - **Issue**: No test coverage
   - **Fix**: Add unit tests for tokenizer roundtrip, dataloader, BPB evaluation
   - **Effort**: Medium

## Draft PRs

### PR 1: `fix(security): use safe deserialization for tokenizer and token_bytes`

- **Branch**: `fix/safe-deserialization`
- **Files to modify**: `prepare.py`
- **Changes**:
  - Replace `pickle.dump(enc, f)` with JSON serialization of `mergeable_ranks` and `special_tokens`
  - Replace `pickle.load(f)` in `Tokenizer.from_directory()` with JSON load + `tiktoken.Encoding()` reconstruction
  - Add `weights_only=True` to `torch.load()` call at line 251
  - Update `.gitignore` if needed for new file extensions
- **Impact**: Eliminates two arbitrary code execution vectors via deserialization. The `weights_only=True` fix is a one-character change with zero risk. The pickle-to-JSON migration requires slightly more work but is straightforward since the tokenizer data is just dicts of bytes-to-int mappings.

### PR 2: `feat(security): add download integrity verification`

- **Branch**: `feat/download-checksums`
- **Files to modify**: `prepare.py`
- **Changes**:
  - After downloading each shard, compute SHA-256 hash of the file
  - Add a function to fetch expected checksums from HuggingFace dataset API
  - Verify hash matches before renaming `.tmp` to final path
  - Log warning if checksum unavailable (graceful degradation)
- **Impact**: Prevents training on corrupted or tampered data. Adds defense-in-depth beyond HTTPS transport security.

### PR 3: `docs(security): add sandboxing recommendations for autonomous mode`

- **Branch**: `docs/sandboxing`
- **Files to modify**: `README.md`, `program.md`
- **Changes**:
  - Add "Security Considerations" section to README explaining risks of autonomous code execution
  - Provide example Dockerfile for sandboxed execution
  - Add to `program.md` a list of banned patterns (e.g., `os.system`, `subprocess`, `socket`, `eval`, `exec`) that the agent should never write into `train.py`
  - Recommend running with `--network=none` in Docker to prevent data exfiltration
- **Impact**: Reduces risk of the most dangerous attack vector (arbitrary code execution via agent) without changing the core design.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 4 |
| Documentation | 8 |
| Test Coverage | 1 |
| Contribution Potential | 7 |

## Summary

- **Total findings by severity**: Critical: 0, High: 3, Medium: 2, Low: 3, Info: 0
- **Overall risk level**: **MEDIUM**
- **Top 3 recommendations**:
  1. **Fix unsafe deserialization** — Add `weights_only=True` to `torch.load` and replace pickle with JSON for the tokenizer. These are the most concrete, exploitable vulnerabilities.
  2. **Add sandboxing guidance** — The autonomous execution loop is the biggest architectural risk. Documenting and recommending containerized execution significantly reduces blast radius.
  3. **Pin kernel repository versions** — The dynamic `get_kernel()` calls load code from mutable GitHub repos. Pinning to specific commits prevents supply chain attacks via upstream changes.
