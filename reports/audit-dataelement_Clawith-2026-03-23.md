# Audit: dataelement/Clawith

## Repository Overview

Clawith is an open-source multi-agent collaboration platform that gives AI agents persistent identities, long-term memory, and private workspaces, then orchestrates them as a team within an organization. It features an autonomous "Aware" system with trigger-based scheduling, a social "Plaza" feed, multi-tenant RBAC, channel integrations (Slack, Discord, Feishu, DingTalk, Teams), sandboxed code execution via Docker containers, and runtime tool/skill discovery. Built by DataElem Inc. under Apache 2.0.

**Tech stack:** Python 3.12 / FastAPI / SQLAlchemy 2.0 (async) / PostgreSQL / Redis / Alembic | React 19 / TypeScript / Vite / Zustand / TanStack Query | Docker Compose / nginx  
**Maturity:** Early-to-growing. Active development, 18 migration files, no tests, no CI/CD.

---

## Code Quality Assessment

### Architecture and Organization
Clean separation: `backend/app/{api,services,models,core}` + `frontend/src/{pages,components,services,stores}`. Backend follows FastAPI conventions with Pydantic schemas, async SQLAlchemy, and dependency injection. Frontend uses Zustand for state, a single `api.ts` client, and i18n. ~135 Python files, ~34 frontend source files.

### Error Handling
- Backend has global exception middleware with logging
- Frontend has ErrorBoundary component and proper API error parsing
- Stack traces logged in production (information disclosure risk)
- Alembic migration failures are non-blocking (warn-and-continue)

### Test Coverage
**Zero tests.** No `test_*.py`, `*_test.py`, `*.test.ts`, `*.spec.ts` files exist anywhere. `pyproject.toml` has a `dev` extra with pytest but no test directory.

### Documentation Quality
Good README with quick-start, Docker instructions, architecture overview, and multi-language translations (EN/ZH/JA/KO/ES). No API docs, no contributing guide, no inline architecture docs.

### Dependency Health
- 38 Python deps, 8 frontend deps -- all mainstream, well-maintained
- No lockfile for Python (supply chain risk) -- only `package-lock.json` for frontend
- Unusual `shadowsocks-libev` in backend Dockerfile
- No `npm audit` or `pip-audit` in any workflow

---

## Security Findings

### Critical

**1. Command Injection in File Upload Processing**  
File: `backend/app/api/upload.py:45-106`  
User-supplied `file_path` is interpolated directly into a Python code string passed to `subprocess.run()`. A crafted filename like `'; import os; os.system("cmd"); #.pdf` executes arbitrary code. Affects PDF, DOCX, and Excel extraction paths.

**2. Hardcoded Default Secrets**  
File: `backend/app/config.py:52,62`  
`SECRET_KEY = "change-me-in-production"` and `JWT_SECRET_KEY = "change-me-jwt-secret"`. If not overridden via env vars, enables JWT forgery and session hijacking. Same defaults in `docker-compose.yml:41-42`.

**3. API Keys Stored in Plaintext**  
File: `backend/app/api/enterprise.py:122` (`# TODO: encrypt`)  
LLM provider API keys (OpenAI, Anthropic, etc.) and channel secrets (Feishu, WeChat) stored unencrypted in the database despite having `pycryptodome` as a dependency.

### High

**4. Docker Socket Mounted to Backend**  
File: `docker-compose.yml:51`  
`/var/run/docker.sock` gives the backend container full Docker API access -- a container escape / privilege escalation vector.

**5. Token Leaked in Download URL**  
File: `frontend/src/services/api.ts:261-264`  
JWT token passed as query parameter for file downloads, exposing it in browser history, server logs, and proxy logs.

**6. XSS in Markdown Renderer**  
File: `frontend/src/components/MarkdownRenderer.tsx:182`  
Custom markdown-to-HTML renderer uses `dangerouslySetInnerHTML` with incomplete sanitization. Link URLs injected without validation. No DOMPurify.

**7. CORS Wildcard in Docker**  
File: `docker-compose.yml:43`  
`CORS_ORIGINS: '["*"]'` allows any origin. Combined with credential-bearing requests, this is exploitable.

### Medium

**8. No Rate Limiting on Auth Endpoints**  
File: `backend/app/api/auth.py`  
Login, registration, and password endpoints have no rate limiting or CAPTCHA -- brute-force vulnerable.

**9. Weak Password Policy**  
File: `backend/app/schemas/schemas.py:14`  
Minimum password length is 6 characters. Should be 12+.

**10. No Security Headers in nginx**  
File: `frontend/nginx.conf`  
Missing CSP, X-Frame-Options, X-Content-Type-Options, HSTS, Referrer-Policy.

**11. 24-Hour JWT with No Refresh/Revocation**  
File: `backend/app/config.py`  
Long-lived tokens with no rotation, blacklist, or logout mechanism.

### Low / Info

**12. `dangerouslySetInnerHTML` in Login**  
File: `frontend/src/pages/Login.tsx:90` -- Currently renders static i18n string, low risk but bad pattern.

**13. Hardcoded DB credentials** `clawith:clawith` in `setup.sh`, `alembic.ini`, `docker-compose.yml` -- acceptable for dev, risky if unchanged.

**14. No CI/CD pipeline** -- No `.github/workflows/`, no automated security scanning, linting, or testing.

**15. `shadowsocks-libev` in Dockerfile** -- Unusual dependency in `backend/Dockerfile:26`, unclear purpose.

---

## Contribution Opportunities

### Bugs

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 1 | `backend/app/api/upload.py:45-106` | Command injection via filename in subprocess | Use pdfplumber/python-docx/openpyxl directly (already in deps) instead of subprocess with string interpolation | small | high |
| 2 | `frontend/src/services/api.ts:261-264` | JWT token in download URL query param | Use Authorization header or POST-based download with token in body | small | high |

### Security Fixes

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 3 | `backend/app/config.py:52,62` | Hardcoded secrets with no startup validation | Add startup check that raises if secrets are default values in production | trivial | high |
| 4 | `backend/app/api/enterprise.py:122` | Plaintext API key storage | Implement Fernet encryption using `cryptography` (already a dep via python-jose) | medium | high |
| 5 | `frontend/src/components/MarkdownRenderer.tsx:182` | XSS via custom markdown renderer | Add `dompurify` dependency and sanitize HTML before rendering | small | high |
| 6 | `frontend/nginx.conf` | Missing security headers | Add CSP, X-Frame-Options, HSTS, X-Content-Type-Options | trivial | medium |
| 7 | `backend/app/api/auth.py` | No rate limiting | Add slowapi or custom rate limiter on login/register endpoints | small | high |
| 8 | `docker-compose.yml:43` | CORS wildcard | Change default to specific origins, document override | trivial | medium |

### Missing Tests

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 9 | `backend/` (entire) | Zero test coverage | Add pytest fixtures, test auth flow, permissions, file access, API endpoints | large | high |
| 10 | `frontend/` (entire) | Zero test coverage | Add vitest + testing-library, test API client, auth flow, markdown renderer | large | high |

### Documentation Gaps

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 11 | Root | No CONTRIBUTING.md | Add contribution guide with setup, testing, PR process | small | medium |
| 12 | Root | No API documentation | Add OpenAPI schema export or Swagger UI route | trivial | medium |
| 13 | Root | No security policy | Add SECURITY.md with vulnerability reporting process | trivial | medium |

### Code Improvements

| # | File | Issue | Fix | Effort | PR-worthy |
|---|------|-------|-----|--------|-----------|
| 14 | `backend/app/services/agent_tools.py:1401` | `__import__` inline usage | Replace with standard `from urllib.parse import quote` | trivial | low |
| 15 | `backend/pyproject.toml` | No pinned dependency lock | Add `pip-compile` or `uv lock` output for reproducible builds | small | medium |
| 16 | `backend/Dockerfile:26` | Unexplained `shadowsocks-libev` install | Remove if unused or document purpose | trivial | low |

### Feature Ideas

| # | Description | Effort | PR-worthy |
|---|-------------|--------|-----------|
| 17 | Add GitHub Actions CI with linting (ruff), type checking, and security scanning (pip-audit, npm audit) | medium | high |
| 18 | Implement refresh token rotation with short-lived access tokens | medium | high |
| 19 | Add OpenTelemetry tracing for agent execution observability | large | medium |

---

## Draft PRs

### PR 1: Fix critical command injection in file upload

- **PR Title:** `fix(upload): replace subprocess command injection with direct library calls`
- **Branch:** `fix/upload-command-injection`
- **Files:** `backend/app/api/upload.py`
- **Changes:** Remove all `subprocess.run(["python3", "-c", f"...{file_path}..."])` patterns (lines 45-106). Replace PDF extraction with direct `pdfplumber.open(file_path)`, DOCX extraction with `docx.Document(file_path)`, and Excel extraction with `openpyxl.load_workbook(file_path)`. All three libraries are already in `pyproject.toml` dependencies. No new deps needed.
- **Effort:** 1-2 hours
- **Impact:** Eliminates the most severe vulnerability -- arbitrary code execution via crafted filenames. Currently exploitable by any authenticated user who can upload files.

### PR 2: Encrypt API keys at rest in database

- **PR Title:** `fix(security): encrypt LLM API keys and channel secrets at rest`
- **Branch:** `fix/encrypt-api-keys`
- **Files:** `backend/app/config.py` (add ENCRYPTION_KEY setting), `backend/app/core/security.py` (add encrypt/decrypt helpers), `backend/app/api/enterprise.py` (encrypt on save, decrypt on use), `backend/app/models/llm.py`, `backend/app/models/channel_config.py`, `backend/alembic/versions/` (new migration to re-encrypt existing keys)
- **Changes:** Implement Fernet symmetric encryption from `cryptography` library. Add `ENCRYPTION_KEY` to config with startup validation. Create `encrypt_value()`/`decrypt_value()` helpers. Wrap all API key write paths with encryption and read paths with decryption. Add migration to encrypt existing plaintext keys.
- **Effort:** 4-6 hours
- **Impact:** Protects all LLM provider API keys and channel secrets from database compromise. Currently ~every configured provider key is exposed in plaintext.

### PR 3: Add startup secret validation and security defaults

- **PR Title:** `fix(config): validate secrets on startup, reject defaults in production`
- **Branch:** `fix/security-defaults`
- **Files:** `backend/app/config.py` (add validator), `backend/app/main.py` (add startup check), `docker-compose.yml` (remove wildcard CORS), `frontend/nginx.conf` (add security headers), `frontend/src/components/MarkdownRenderer.tsx` (add DOMPurify), `frontend/package.json` (add dompurify dep)
- **Changes:** Add a Pydantic `model_validator` that raises on startup if `SECRET_KEY` or `JWT_SECRET_KEY` contain "change-me" when `DEBUG=false`. Change docker-compose CORS default to localhost origins. Add `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and basic CSP to nginx. Add `dompurify` to frontend and sanitize markdown HTML output.
- **Effort:** 2-3 hours
- **Impact:** Prevents the most common deployment misconfiguration (default secrets) and hardens the frontend against XSS. Low-effort, high-value security baseline.

---

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 6 |
| Security | 3 |
| Documentation | 5 |
| Test Coverage | 1 |
| Contribution Potential | 9 |
