Now I have a comprehensive picture. Let me produce the report.

# Marketing Audit: shankar0123/certctl

## Quick Overview

**certctl** is a self-hosted certificate lifecycle management platform written in Go. It automates TLS certificate issuance, renewal, and deployment across 12+ CA issuers (ACME, Vault PKI, DigiCert, step-ca, etc.) and 15+ deployment targets (NGINX, HAProxy, IIS, K8s, etc.). It includes a React/TypeScript web dashboard, an agent binary, an MCP server for AI integration, a CLI, Helm charts, and Docker Compose environments. Positioned as a free alternative to enterprise CLM platforms ($100K+/yr).

- **Tech stack**: Go 1.25.9, PostgreSQL, React + TypeScript + Vite + Tailwind, Docker, Helm
- **License**: BSL 1.1
- **Activity**: Extremely active -- 287 commits in 2025, 224 in March, 63 so far in April. Single maintainer (shankar0123).
- **Test coverage**: 149 test files (Go) + frontend tests. CI has coverage thresholds enforced.
- **CI**: GitHub Actions (Go build/test/lint/govulncheck, frontend build/typecheck/test, Helm lint)

---

## Quick Win PRs

### 1. Documentation Improvements

| Item | Details |
|------|---------|
| **Missing CONTRIBUTING.md** | No contributing guide exists. Maintainers of active projects typically welcome this. Include: fork/clone flow, how to run tests locally, PR conventions, coding style. |
| **Missing SECURITY.md** | No security policy. For a security-focused tool this is a glaring gap. Add responsible disclosure instructions, supported versions. |
| **Missing CODEOWNERS** | `.github/CODEOWNERS` not present. Simple addition for a solo maintainer. |
| **No CI badge for build status** | README has license/report/release/stars badges but no CI status badge. Easy to add. |
| **README Quick Start is a link** | The Quick Start section just links to `docs/quickstart.md`. Adding a minimal 3-command inline snippet (docker compose up, open browser) would improve first-impression DX. |

### 2. Code Quality

| Item | Details |
|------|---------|
| **50+ unchecked errors (errcheck)** | `.golangci.yml` explicitly documents this: "errcheck (50 issues)". Each fix is a small, safe PR. |
| **13 dead assignments (ineffassign)** | Also documented in `.golangci.yml` comments. Low-risk removals. |
| **25 missing HTTP contexts (noctx)** | `http.Get` calls without `context.Context`. Each is a 2-line fix. |
| **Missing response body closes (bodyclose)** | Documented as disabled linter. Fix with `defer resp.Body.Close()`. |
| **23 gosec warnings** | Mostly in test/stub code but worth triaging -- some may be real. |
| **Lint suppressions cleanup** | Many staticcheck rules suppressed (ST1005, ST1003, S1009, etc.) -- incrementally fixing these would be welcomed. |

### 3. Tests

| Item | Details |
|------|---------|
| **No tests for `cmd/cli/main.go`** | CLI entry point has no test file. |
| **No tests for `cmd/mcp-server/main.go`** | MCP server entry point untested. |
| **Missing `internal/crypto/` edge cases** | Only `encryption_test.go` exists; key rotation, invalid key handling could be tested. |
| **No fuzz tests except revocation** | Only `revocation_fuzz_test.go` exists. Certificate parsing, validation, and policy enforcement are good fuzz targets. |

### 4. CI/CD

| Item | Details |
|------|---------|
| **No Dependabot / Renovate config** | Go modules and npm dependencies have no automated update mechanism. |
| **No CI status badge in README** | Easy addition: `[![CI](https://github.com/shankar0123/certctl/actions/workflows/ci.yml/badge.svg)](...)` |
| **No Docker image build/push in CI** | `release.yml` exists but there's no container registry push workflow. |
| **Coverage report not posted to PR** | Coverage is calculated but not reported back as a PR comment or Codecov upload. |

### 5. DX Improvements

| Item | Details |
|------|---------|
| **`docker-compose` vs `docker compose`** | Makefile uses `docker-compose` (V1 legacy). Should be `docker compose` (V2). |
| **No `.env.example` documentation** | `.env.example` exists at root and `deploy/` but no README mention of required env vars. |
| **`bin/` not in `.gitignore` for agent/server** | `bin/` is ignored but individual binary names aren't -- fine, but `coverage.html` is in `.gitignore` while `coverage.out` is listed twice. Minor cleanup. |
| **Makefile `docker-compose` deprecation** | Docker Compose V1 (`docker-compose`) is EOL. 6 references in Makefile need updating to `docker compose`. |

---

## Draft PRs

### PR #1: Add CONTRIBUTING.md and SECURITY.md

- **PR Title**: `docs: add CONTRIBUTING.md and SECURITY.md`
- **Branch**: `docs/community-files`
- **Files to change**: Create `CONTRIBUTING.md`, `SECURITY.md`, `.github/CODEOWNERS`
- **Changes**:
  - `CONTRIBUTING.md`: Fork instructions, `make test` / `make lint` prereqs, PR checklist, conventional commit style, link to `.golangci.yml`
  - `SECURITY.md`: Responsible disclosure email, supported versions (master), response timeline
  - `CODEOWNERS`: `* @shankar0123`
- **Effort**: 30 minutes
- **Merge likelihood**: **High** -- every active project benefits from these, and GitHub surfaces them in the UI automatically. Zero risk of breakage.

### PR #2: Add CI status badge to README

- **PR Title**: `docs: add CI workflow status badge to README`
- **Branch**: `docs/ci-badge`
- **Files to change**: `README.md`
- **Changes**: Add `[![CI](https://github.com/shankar0123/certctl/actions/workflows/ci.yml/badge.svg)](https://github.com/shankar0123/certctl/actions/workflows/ci.yml)` to the badge row after the existing badges (line ~9).
- **Effort**: 5 minutes
- **Merge likelihood**: **High** -- trivial, no-risk, visually useful.

### PR #3: Fix Makefile docker-compose V1 deprecation

- **PR Title**: `fix: replace deprecated docker-compose with docker compose in Makefile`
- **Branch**: `fix/docker-compose-v2`
- **Files to change**: `Makefile`
- **Changes**: Replace all 6 occurrences of `docker-compose` with `docker compose` (lines 123, 125, 130, 132, 137, 139, 141, 143, 148, 150). Docker Compose V1 (`docker-compose` binary) has been EOL since July 2023.
- **Effort**: 10 minutes
- **Merge likelihood**: **High** -- Docker Compose V1 is officially deprecated and removed from Docker Desktop. The hyphenated form fails on fresh Docker installs. Clear, non-controversial fix.

---

## Notes

- **Solo maintainer** -- shankar0123 is the only committer. Very high commit velocity (287 in 2025). This means PRs need to be small and self-contained to get reviewed quickly.
- **No open PRs or issues visible** from git history -- check GitHub for PR backlog before submitting.
- **BSL 1.1 license** -- contributions are accepted but the license is not OSI-approved open source. Worth being aware of.
- **Linter debt is well-documented** -- the `.golangci.yml` comments explicitly list disabled linters with issue counts. This is an invitation to fix them incrementally. Each linter category (errcheck, ineffassign, noctx, bodyclose) could be its own PR.
- **Best approach**: Start with PR #1 or #2 (zero-risk docs), then move to PR #3 (Makefile fix), then tackle individual linter categories one at a time. Keep PRs small -- this maintainer ships fast and will likely review quickly.
