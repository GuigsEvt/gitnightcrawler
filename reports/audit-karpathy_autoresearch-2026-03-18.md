# Audit: karpathy/autoresearch

## Repository Overview

Autoresearch is an autonomous AI research framework by Andrej Karpathy that lets an AI agent (e.g., Claude/Codex) iteratively experiment with LLM pretraining configurations on a single GPU. The agent modifies `train.py`, trains a GPT model for a fixed 5-minute wall-clock budget, evaluates validation bits-per-byte (BPB), and keeps or discards changes — running indefinitely while the human sleeps. The training code is a simplified single-GPU extract of [nanochat](https://github.com/karpathy/nanochat) featuring a GPT with RoPE, sliding window attention, value embeddings, and a Muon+AdamW optimizer.

**Tech stack:** Python 3.10+, PyTorch 2.9.1 (CUDA 12.8), Flash Attention 3 (via `kernels`), custom BPE tokenizer (`rustbpe` + `tiktoken`), `pyarrow` for data loading, `uv` for dependency management. Analysis notebook uses `pandas`/`matplotlib`.

**Maturity:** Early-stage / experimental. ~650 lines of core code across 2 Python files. No tests, no CI, no linting config. Intentionally minimal by design.

## Code Quality Assessment

### Architecture and Organization
The codebase is intentionally small and well-structured for its purpose:
- `prepare.py` (~390 lines): Data download, tokenizer training, dataloader, evaluation — **read-only by design**
- `train.py` (~630 lines): Model definition, optimizer, training loop — **the mutable target**
- `program.md`: Agent instructions / "research org code"
- Clear separation of concerns; single-file model is easy for an AI agent to reason about

**Strengths:**
- Smart dataloader with best-fit packing (zero padding waste)
- Fused compiled optimizer kernels (`@torch.compile`)
- GC management to avoid Python GC stalls during training
- Clean use of `dataclass` for model config

**Weaknesses:**
- All training logic runs at module-level (not wrapped in `main()`), making it non-importable
- `train.py` imports `kernels` and immediately calls CUDA APIs at import time (line 21-24), causing hard crashes on non-NVIDIA systems
- `prepare.py` mixes library code (classes/utilities imported by `train.py`) with script logic — fragile dual-purpose design

### Error Handling Patterns
- Download retry with exponential backoff: **good** (`prepare.py:66-88`)
- NaN/exploding loss fast-fail: **good** (`train.py:570-572`)
- Infinite loop guard for empty training shards: **present** (recent commit `c2450ad`)
- No graceful handling of CUDA OOM — process just crashes
- No signal handling for clean shutdown (e.g., SIGTERM/SIGINT to save checkpoint)
- `pickle.load` on tokenizer file with no validation (`prepare.py:219`)

### Test Coverage
**None.** Zero test files. No test framework configured. No CI pipeline.

### Documentation Quality
- README is excellent: clear purpose, quick start, design rationale, tuning guide for smaller hardware
- `program.md` is well-written agent instructions
- Code comments are sparse but adequate
- No API/function docstrings beyond the top-level module docstrings

### Dependency Health
- PyTorch 2.9.1 pinned to CUDA 12.8 index — reasonable for bleeding-edge GPU work
- `kernels>=0.11.7` — relatively new package for JIT kernel loading
- `rustbpe>=0.1.0` — early-stage Rust BPE implementation
- No lockfile auditing (uv.lock present but no `uv audit` equivalent run)
- All deps are minimum-version pinned (`>=`), except torch which is exact (`==`)

## Security Findings

### Medium: Unsafe Pickle Deserialization
- **File:** `prepare.py:219`
- **Issue:** `pickle.load()` on tokenizer file. If an attacker replaces `~/.cache/autoresearch/tokenizer/tokenizer.pkl`, arbitrary code execution occurs.
- **Mitigation:** The file is locally generated, not downloaded. Risk is local privilege escalation only.
- **Rating:** Medium

### Medium: Unsafe `torch.load` without `weights_only=True`
- **File:** `prepare.py:251`
- **Issue:** `torch.load(f, map_location=device)` defaults to pickle-based loading. Should use `weights_only=True` for tensor-only files.
- **Rating:** Medium

### Low: No TLS Certificate Verification Control
- **File:** `prepare.py:68`
- **Issue:** `requests.get()` uses default cert verification (which is fine), but no certificate pinning for the HuggingFace download URL. Acceptable for this use case.
- **Rating:** Low

### Low: Environment Variable Injection at Module Level
- **File:** `train.py:8-9`
- **Issue:** `os.environ` mutations at import time. Not a security issue per se, but could mask issues in multi-process setups.
- **Rating:** Low / Info

### Info: No Secrets Present
- No hardcoded API keys, tokens, or credentials found.
- `.gitignore` properly excludes `.venv`, `results/`, and generated files.

## Contribution Opportunities

### Bugs

1. **File:** `prepare.py:228-231`
   - **Issue:** `prepend_id` referenced before assignment if `prepend` is `None` and `text` is a `str` — but code path only triggers when `prepend is not None`, so it's not actually reachable. However, the variable is defined inside a conditional that doesn't have an `else`, which is confusing.
   - **Fix:** Move `prepend_id` assignment or restructure the conditional.
   - **Effort:** Trivial
   - **PR-worthy:** Low

2. **File:** `train.py:219-220`
   - **Issue:** `window_size[0]` is always >= 0 (set to `sequence_len` or `sequence_len // 2`), so `window < 0` check in `estimate_flops` is dead code.
   - **Fix:** Remove dead branch or document intent.
   - **Effort:** Trivial
   - **PR-worthy:** Low

### Security Fixes

1. **File:** `prepare.py:251`
   - **Issue:** `torch.load` without `weights_only=True`
   - **Fix:** `torch.load(f, map_location=device, weights_only=True)`
   - **Effort:** Trivial
   - **PR-worthy:** Medium

### Missing Tests

1. **File:** New `test_prepare.py`
   - **Issue:** Zero test coverage on tokenizer encoding/decoding, dataloader packing, BPB calculation.
   - **Fix:** Add unit tests for `Tokenizer.encode()`, `make_dataloader` shape validation, `evaluate_bpb` with mock model.
   - **Effort:** Medium
   - **PR-worthy:** Medium

### Documentation Gaps

1. **File:** `README.md`
   - **Issue:** No documentation on the analysis notebook or how to use it.
   - **Fix:** Add a section explaining the `analysis.ipynb` workflow.
   - **Effort:** Trivial
   - **PR-worthy:** Low

2. **File:** `train.py`
   - **Issue:** The Muon optimizer and polar express orthogonalization are complex algorithms with no references or explanations.
   - **Fix:** Add paper references as comments.
   - **Effort:** Trivial
   - **PR-worthy:** Low

### Code Improvements

1. **File:** `train.py:457-511` (module-level training setup)
   - **Issue:** All setup code runs at import time, making `train.py` non-importable for testing or tooling.
   - **Fix:** Wrap in `if __name__ == "__main__":` or a `main()` function.
   - **Effort:** Small
   - **PR-worthy:** High

2. **File:** `prepare.py:254-337` (dataloader)
   - **Issue:** `make_dataloader` hardcodes `device="cuda"` for GPU buffers (line 299, 303). Cannot run on CPU/MPS.
   - **Fix:** Accept a `device` parameter, default to `"cuda"`.
   - **Effort:** Small
   - **PR-worthy:** Medium

3. **File:** `train.py:543-604` (training loop)
   - **Issue:** No checkpointing. If the process is killed, all progress is lost.
   - **Fix:** Save model/optimizer state periodically or on SIGTERM.
   - **Effort:** Medium
   - **PR-worthy:** High

### Feature Ideas

1. **Checkpoint/Resume Support**
   - Save model state after each experiment so the agent can resume from crashes without re-training.
   - **Effort:** Medium
   - **PR-worthy:** High

2. **SIGINT/SIGTERM Handler**
   - Gracefully stop training and run eval on interrupt, rather than losing the run.
   - **Effort:** Small
   - **PR-worthy:** High

3. **Multi-GPU / FSDP Support**
   - The codebase is explicitly single-GPU. Adding basic DDP/FSDP would expand the user base.
   - **Effort:** Large
   - **PR-worthy:** High (but out of stated scope)

## Draft PRs

### PR 1: `fix: use weights_only=True in torch.load for safe deserialization`
- **Branch:** `fix/torch-load-weights-only`
- **Files:** `prepare.py`
- **Changes:** Line 251: change `torch.load(f, map_location=device)` to `torch.load(f, map_location=device, weights_only=True)`. This prevents potential arbitrary code execution via crafted tensor files, aligning with PyTorch security best practices (warnings emitted since PyTorch 2.4+).
- **Effort:** 5 minutes
- **Impact:** Eliminates a known security anti-pattern. Zero risk of regression since the file only contains a tensor.

### PR 2: `feat: add graceful shutdown with SIGINT/SIGTERM handling`
- **Branch:** `feat/graceful-shutdown`
- **Files:** `train.py`
- **Changes:** Add a signal handler that sets a `should_stop` flag. In the training loop (line 603), check this flag alongside the time budget. On shutdown, still run the final eval and print results, so partial runs aren't wasted. ~15 lines of code.
- **Effort:** 30 minutes
- **Impact:** Prevents lost experiment time when users Ctrl+C or when the agent process is terminated. Critical for the autonomous overnight use case.

### PR 3: `refactor: wrap train.py execution in main() guard`
- **Branch:** `refactor/main-guard`
- **Files:** `train.py`
- **Changes:** Move lines 457-631 (everything after the class/function definitions) into a `def main():` function, called from `if __name__ == "__main__":`. This makes `train.py` safely importable for testing, tooling, or programmatic use without triggering CUDA initialization.
- **Effort:** 15 minutes
- **Impact:** Enables writing tests against model/optimizer code without GPU side effects. Foundational for any future test coverage.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 7 |
| Security | 6 |
| Documentation | 7 |
| Test Coverage | 1 |
| Contribution Potential | 8 |

**Summary:** This is a clean, focused, intentionally minimal research tool. The code quality is high for its purpose — Karpathy's training code is well-engineered with smart dataloader packing, fused optimizer kernels, and GC management. The main gaps are the complete absence of tests, minor security hygiene issues (pickle/torch.load), and the lack of checkpointing for resilience. The codebase offers strong contribution potential given its high visibility and clear, well-scoped improvement opportunities.
