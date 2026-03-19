# Marketing Audit: giantswarm/muster

## Quick Overview

Muster is a universal control plane and meta-MCP (Model Context Protocol) server aggregator for platform engineers and AI agents. It manages multiple backend MCP servers, provides intelligent tool discovery/filtering, includes an MCP-native workflow engine, and exposes its own functionality through MCP tools. Think of it as a "router + orchestrator" for AI agent tooling.

- **Tech stack**: Go 1.25/1.26, Cobra CLI, Kubernetes (controller-runtime, CRDs), Helm, MCP protocol (mcp-go), OAuth/SSO, Valkey caching, GoReleaser
- **Activity level**: ~50 commits since Jan 2025, ~4-5/week. Dominated by one primary developer (Timo Derstappen, 43/50 commits). PR turnaround appears fast (auto-release on merge). Active SSO/OAuth hardening phase. Current version: v0.1.75.

---

## Quick Win PRs

### 1. Documentation Improvements

**CRITICAL FINDING: 8 broken internal links in README.md**

The README references these docs that don't exist:
- `docs/getting-started/quick-start.md`
- `docs/getting-started/platform-setup.md`
- `docs/how-to/troubleshooting.md`
- `docs/how-to/ai-troubleshooting.md`
- `docs/how-to/cursor-advanced-setup.md`
- `docs/reference/api.md`
- `docs/reference/crds.md`
- `docs/explanation/problem-statement.md`

**Missing CODE_OF_CONDUCT.md** - Standard for open-source projects, especially under a company org.

**Badge gaps in README**:
- No CI status badge (they have GitHub Actions CI)
- No license badge (Apache 2.0)
- No release/version badge
- GoDoc badge points to `godoc.org` (deprecated) instead of `pkg.go.dev`

### 2. Code Quality

**Missing `doc.go` files** (project convention requires them):
- `internal/agent/commands/`
- `internal/services/aggregator/`
- `internal/services/mcpserver/`

**No `.golangci.yml` config file** - CI references golangci-lint but there's no config file in the repo. This means default settings only, and contributors can't see what rules apply.

**TODO/FIXME comments** (7 instances across codebase):
- `internal/api/workflow.go:122`
- `internal/aggregator/event_handler.go:322`
- `internal/services/mcpserver/service.go:632`
- `internal/workflow/execution_tracker.go:119`
- `internal/services/instance.go:686`

### 3. Tests

**Missing test coverage**:
- `internal/template/` - Has `context.go` and `engine.go` but ZERO test files. This is the only internal package with no tests at all.

**No codecov integration** - Tests run with `-cover` flag but no coverage reporting/tracking tool configured.

### 4. CI/CD

**Missing from CI**:
- No CI status badge in README despite having `.github/workflows/ci.yaml`
- No codecov/coveralls integration for coverage tracking
- No dependency license scanning

### 5. DX Improvements

**No `docker-compose.yaml`** - Would be useful for local development with Valkey, OAuth mock, etc.

**GoDoc badge outdated** - Points to deprecated `godoc.org` instead of `pkg.go.dev`

---

## Draft PRs

### PR #1: Fix broken documentation links in README

- **PR Title**: `docs: fix 8 broken internal links in README`
- **Branch**: `docs/fix-broken-readme-links`
- **Files to change**: `README.md`
- **Changes**: Either create stub files for the 8 missing docs, or remove/update the broken links in README. Creating stubs with `# TODO` headers is the safer approach since it makes the structure explicit while marking what's needed.
- **Effort**: 15-30 minutes
- **Merge likelihood**: **HIGH** - Broken links are objectively wrong, easy to verify, and maintainers will appreciate the cleanup. Zero risk of breaking anything.

### PR #2: Update badges and add CI status badge

- **PR Title**: `docs: update GoDoc badge to pkg.go.dev and add CI status badge`
- **Branch**: `docs/update-readme-badges`
- **Files to change**: `README.md` (badge section at top)
- **Changes**:
  - Replace `godoc.org` badge with `pkg.go.dev` equivalent: `[![Go Reference](https://pkg.go.dev/badge/github.com/giantswarm/muster.svg)](https://pkg.go.dev/github.com/giantswarm/muster)`
  - Add CI badge: `[![CI](https://github.com/giantswarm/muster/actions/workflows/ci.yaml/badge.svg)](https://github.com/giantswarm/muster/actions/workflows/ci.yaml)`
  - Add license badge: `[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)`
- **Effort**: 10 minutes
- **Merge likelihood**: **HIGH** - godoc.org is officially deprecated, pkg.go.dev is the standard. CI badge is standard practice. Pure cosmetic improvement.

### PR #3: Add missing doc.go files for 3 packages

- **PR Title**: `docs: add missing doc.go for agent/commands, services/aggregator, services/mcpserver`
- **Branch**: `docs/add-missing-docgo`
- **Files to change** (create):
  - `internal/agent/commands/doc.go`
  - `internal/services/aggregator/doc.go`
  - `internal/services/mcpserver/doc.go`
- **Changes**: Add package-level documentation following the existing `doc.go` pattern used in all other packages. Each file is ~5-10 lines with a package comment describing the package's purpose.
- **Effort**: 15 minutes
- **Merge likelihood**: **HIGH** - Project's own CLAUDE.md states "Every package must have a `doc.go`". This enforces their own documented convention.

---

## Notes

- **Single maintainer risk**: 43/50 recent commits from one person. PRs may sit if they're busy. Keep PRs small and obvious.
- **Giant Swarm org**: This is a company-backed project, not a hobby repo. They have standardized tooling (devctl, architect-orb, renovate). Respect their patterns.
- **Auto-generated files**: Many files prefixed with `zz_generated` - don't touch these.
- **Best approach**: Start with PR #1 (broken links) - it's the most obviously valuable and requires no code changes. Open an issue first referencing the broken links, then submit the PR.
- **PR template exists**: Follow `.github/pull_request_template.md` format when submitting.
- **DCO required**: All commits need `Signed-off-by` line (Developer Certificate of Origin). Use `git commit -s`.
