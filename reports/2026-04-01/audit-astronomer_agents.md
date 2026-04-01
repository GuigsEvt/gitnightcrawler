I now have a comprehensive picture of the codebase. Let me produce the audit report.

# Security Audit: astronomer/agents

## Repository Overview

Astronomer Agents is a Claude Code plugin and MCP (Model Context Protocol) server for Apache Airflow integration. It provides an `astro-airflow-mcp` FastMCP server that exposes Airflow REST API operations as MCP tools (DAG management, task inspection, run triggering, admin operations), a CLI (`af`), and a collection of 29 AI skills for data engineering workflows (DAG authoring, warehouse exploration, dbt integration, deployment). The warehouse analysis skill includes a Jupyter kernel manager that connects to Snowflake, PostgreSQL, BigQuery, and SQLAlchemy-compatible databases.

- **Tech stack**: Python 3.10+, FastMCP, httpx, Pydantic, typer, Jupyter client, YAML
- **Build**: hatchling + hatch-vcs, uv for dependency management
- **Maturity**: Growing (v0.1.0, active development, 172+ PRs merged)
- **Categories detected**: ai|actions

## Critical & High Severity Findings

### Finding 1: Default Credentials Auto-Applied for Airflow 2.x

- **Severity**: HIGH
- **Category**: auth, insecure-defaults
- **Location**: `astro-airflow-mcp/src/astro_airflow_mcp/auth.py:139-146`
- **Description**: When the token endpoint returns 404 (Airflow 2.x) and no credentials were provided, the TokenManager silently defaults to `admin:admin` credentials. This fail-open behavior means the MCP server will attempt to authenticate against any Airflow 2.x instance with default admin credentials without user awareness.
- **Impact**: An attacker who controls a service on the expected port (e.g., via DNS rebinding or network positioning) could receive valid basic auth credentials. In production environments where someone forgot to configure credentials, the tool would silently use defaults that may or may not work, masking a configuration error.
- **Fix**: Log a prominent warning (not just INFO level) when defaulting to admin:admin. Consider requiring explicit opt-in (e.g., `--allow-default-credentials` flag) rather than silent fallback. At minimum, only apply defaults when the URL is `localhost`/`127.0.0.1`.
- **Confidence**: Medium (mitigated by local-dev context, but still a security concern)

### Finding 2: Airflow Config Endpoint Exposes Sensitive Values

- **Severity**: HIGH
- **Category**: information-disclosure
- **Location**: `astro-airflow-mcp/src/astro_airflow_mcp/tools/admin.py:113-129`
- **Description**: The `get_airflow_config` MCP tool returns the complete Airflow configuration including all sections. Airflow configuration can contain database connection strings with passwords, SMTP credentials, Fernet keys, secret backend URIs, and other sensitive values. Unlike connections (which have defense-in-depth password filtering), config values are passed through unfiltered.
- **Impact**: An AI agent or MCP client could inadvertently expose database passwords, encryption keys, or other secrets embedded in Airflow configuration to logs, chat history, or third parties.
- **Fix**: Filter known sensitive config keys (e.g., `sql_alchemy_conn`, `fernet_key`, `smtp_password`, `broker_url`, `result_backend`, any key containing `password`, `secret`, `key`, `token`). Apply similar defense-in-depth filtering as done for connections.
- **Confidence**: High

### Finding 3: Airflow Variables Endpoint May Expose Secrets

- **Severity**: HIGH
- **Category**: information-disclosure
- **Location**: `astro-airflow-mcp/src/astro_airflow_mcp/tools/admin.py:56-96`
- **Description**: The `get_variable` and `list_variables` tools return variable values without filtering. Airflow variables commonly store API keys, passwords, and other secrets. While Airflow itself masks variables with keys containing `password`, `secret`, `api_key`, etc., the raw API response may include unmasked values depending on Airflow configuration.
- **Impact**: Secrets stored in Airflow variables could be exposed through MCP tool responses to AI agents, potentially appearing in conversation logs or being sent to third-party systems.
- **Fix**: Add client-side filtering for variable values when the key matches common secret patterns (e.g., contains `password`, `secret`, `api_key`, `token`), similar to the connection password filtering approach.
- **Confidence**: Medium (depends on Airflow server-side masking configuration)

## Medium & Low Severity Findings

### Finding 4: Arbitrary Code Execution via Kernel

- **Severity**: MEDIUM
- **Category**: code-execution
- **Location**: `skills/analyzing-data/scripts/kernel.py:198-250`, `cli.py:122-154`
- **Description**: The `exec` CLI command and `KernelManager.execute()` allow arbitrary Python code execution in a Jupyter kernel. The code argument is passed directly from CLI input or the AI agent without sanitization.
- **Impact**: This is by design (data analysis kernel), but there's no sandboxing, allowlisting, or resource limits beyond a 30-minute idle timeout. The kernel runs with the user's full privileges.
- **Fix**: This is an accepted risk for the tool's purpose, but consider: (1) documenting the security implications prominently, (2) adding an `--isolated` flag that restricts filesystem access, (3) running the kernel in a container for production use.
- **Confidence**: Low (by design, but worth noting)

### Finding 5: Package Installation Without Verification

- **Severity**: MEDIUM
- **Category**: supply-chain
- **Location**: `skills/analyzing-data/scripts/kernel.py:276-302`
- **Description**: The `install_packages` method passes user-provided package names directly to `uv pip install` without any allowlisting or verification. The `install` CLI command accepts arbitrary package specs.
- **Impact**: A prompt-injected AI agent could be tricked into installing malicious packages. Packages with typosquatted names or malicious post-install scripts could compromise the system.
- **Fix**: Consider maintaining an allowlist of approved packages, or at minimum log all package installations prominently and require explicit user confirmation.
- **Confidence**: Medium

### Finding 6: Subprocess Execution in CLI Wrapper

- **Severity**: MEDIUM
- **Category**: injection
- **Location**: `astro-airflow-mcp/src/astro_airflow_mcp/discovery/astro_cli.py:156-192`
- **Description**: The `AstroCli._run_command()` method constructs subprocess commands with parameters like `deployment_id`, `workspace_id`, and `token_name`. While these are passed as list arguments (preventing shell injection), some values come from parsed CLI output (`_parse_table_output`) which could be manipulated if the `astro` CLI binary is compromised.
- **Impact**: Low risk since arguments are passed as a list (not shell string), but the astro CLI path is resolved via `shutil.which()` which trusts PATH.
- **Fix**: The current implementation using list-based subprocess calls is already safe against injection. The `nosec B603` annotations are appropriate. No immediate action needed.
- **Confidence**: Low

### Finding 7: Telemetry Data Sent to External Endpoint

- **Severity**: LOW
- **Category**: privacy
- **Location**: `astro-airflow-mcp/src/astro_airflow_mcp/telemetry.py:128-184`
- **Description**: Telemetry events are sent to `https://api.astronomer.io/v1alpha1/telemetry` via a detached subprocess. The telemetry URL can be overridden via `AF_TELEMETRY_API_URL` environment variable. While the data is anonymized (UUID-based), it includes OS version, architecture, Python version, and agent detection.
- **Impact**: Telemetry is opt-out (enabled by default). The override URL could be used to redirect telemetry to a malicious endpoint if the environment is compromised.
- **Fix**: Telemetry is already properly disableable via `AF_TELEMETRY_DISABLED=true` or config file. Consider making it opt-in for new installations, and document the data collected more prominently.
- **Confidence**: Low

### Finding 8: SSL Verification Can Be Disabled

- **Severity**: LOW
- **Category**: crypto, insecure-defaults
- **Location**: `astro-airflow-mcp/src/astro_airflow_mcp/__main__.py:116-121`
- **Description**: The `--no-verify-ssl` flag and `AIRFLOW_VERIFY_SSL=false` environment variable allow disabling SSL certificate verification for all Airflow API communications.
- **Impact**: When SSL verification is disabled, the tool is vulnerable to man-in-the-middle attacks. Credentials (basic auth or bearer tokens) could be intercepted.
- **Fix**: Already has appropriate implementation (opt-in to disable, logged when active). Consider adding a warning at each request when SSL verification is off, not just at startup.
- **Confidence**: Low (standard feature, properly implemented)

### Finding 9: Connection `extra` Field May Contain Secrets

- **Severity**: LOW
- **Category**: information-disclosure
- **Location**: `astro-airflow-mcp/src/astro_airflow_mcp/utils.py:8-31`
- **Description**: The `filter_connection_passwords` function allowlists specific fields but includes the `extra` field. Airflow connection `extra` JSON often contains sensitive data like AWS access keys, GCP service account keys, or API tokens.
- **Impact**: Secrets stored in connection `extra` fields are exposed through the `list_connections` MCP tool.
- **Fix**: Either exclude the `extra` field from the response, or parse and filter known sensitive keys within the `extra` JSON (e.g., `aws_access_key_id`, `aws_secret_access_key`, `private_key`, `keyfile_dict`).
- **Confidence**: Medium

### Finding 10: Credential Embedding in Generated Code

- **Severity**: LOW
- **Category**: information-disclosure
- **Location**: `skills/analyzing-data/scripts/connectors.py:224-228`, `connectors.py:334-335`
- **Description**: The `to_python_prelude()` methods in connectors can embed plaintext passwords directly into generated Python code when no environment variable reference is configured (e.g., `password={self.password!r}`). This code is executed in the Jupyter kernel.
- **Impact**: Credentials may appear in kernel history, Jupyter logs, or process memory.
- **Fix**: Always use environment variable indirection for secrets. When no env var is configured, inject the password via environment variable at kernel start time rather than embedding it in code.
- **Confidence**: Medium

## Supply Chain Analysis

**Dependencies** (astro-airflow-mcp):
- `fastmcp>=0.1.0` - Relatively new MCP framework; growing ecosystem
- `httpx>=0.27.0` - Well-maintained HTTP client
- `pydantic>=2.0.0` - Mature, well-audited data validation
- `pyyaml>=6.0` - Uses `safe_load` throughout (good)
- `typer>=0.12.0` - Well-maintained CLI framework
- `filelock>=3.0.0` - Simple, well-maintained
- `packaging>=21.0` - Standard Python packaging utilities

**Dev dependencies**:
- `bandit[toml]>=1.7.0` - Security scanner is included (positive)
- `ruff>=0.1.0` - Modern linter with security rules enabled
- `pytest-httpx>=0.30.0` - HTTP mocking for tests

**Assessment**: Dependencies are well-chosen, actively maintained, and from reputable sources. No known vulnerabilities in the specified versions. The use of `yaml.safe_load` throughout prevents YAML deserialization attacks. The git submodule (`vendor/dbt-agent-skills`) introduces external dependency but is pinned to a specific commit.

## Code Quality Assessment

**Architecture**: Well-organized with clear separation of concerns. The adapter pattern for Airflow 2.x/3.x compatibility is clean. MCP tools are properly grouped by domain. The plugin system uses Claude Code's standard plugin format.

**Error handling**: Consistent pattern of try/except with string error returns in MCP tools. The `ReadOnlyError` pattern for write protection is well-implemented. Proper fallback chains for authentication.

**Test coverage**: Good - 25+ unit test files for the MCP server, 12 test files for analyzing-data scripts. Integration tests against real Airflow 2.x and 3.x instances. Multiple CI workflows with matrix testing across Python versions.

**Documentation**: Comprehensive - CLAUDE.md, AGENTS.md, README, SECURITY.md, CONTRIBUTING.md, CODE_OF_CONDUCT.md. Each skill has its own SKILL.md with frontmatter.

## Contribution Opportunities

1. **File**: `astro-airflow-mcp/src/astro_airflow_mcp/tools/admin.py:113-129`
   **Issue**: Config endpoint exposes sensitive values without filtering
   **Fix**: Add sensitive key filtering similar to connection password filtering
   **Effort**: Small

2. **File**: `astro-airflow-mcp/src/astro_airflow_mcp/utils.py:19-31`
   **Issue**: Connection `extra` field may contain secrets (AWS keys, etc.)
   **Fix**: Filter or redact known sensitive keys in `extra` JSON
   **Effort**: Small

3. **File**: `astro-airflow-mcp/src/astro_airflow_mcp/auth.py:139-146`
   **Issue**: Silent default to admin:admin credentials
   **Fix**: Restrict to localhost-only or require explicit opt-in
   **Effort**: Small

4. **File**: `skills/analyzing-data/scripts/connectors.py:224-228`
   **Issue**: Passwords embedded in generated Python code
   **Fix**: Always use env var indirection for credentials in generated code
   **Effort**: Medium

5. **File**: `astro-airflow-mcp/src/astro_airflow_mcp/tools/admin.py:56-96`
   **Issue**: Variables endpoint may expose secrets
   **Fix**: Add client-side value masking for sensitive variable keys
   **Effort**: Small

## Draft PRs

### PR 1: Filter sensitive values from Airflow config endpoint

- **PR Title**: `fix: filter sensitive values from get_airflow_config response`
- **Branch name**: `fix/filter-config-secrets`
- **Files to modify**: `astro-airflow-mcp/src/astro_airflow_mcp/tools/admin.py`, `astro-airflow-mcp/src/astro_airflow_mcp/utils.py`
- **Changes**: Add a `filter_config_secrets()` utility function that redacts values for known sensitive config keys (`sql_alchemy_conn`, `fernet_key`, `broker_url`, `result_backend`, `smtp_password`, `celery_result_backend`, and any key containing `password`, `secret`, `key`, `token`). Apply it in `_get_config_impl()` before returning.
- **Impact**: Prevents inadvertent exposure of database credentials, encryption keys, and other secrets through the MCP config tool. Defense-in-depth layer complementing Airflow's own `expose_config` setting.

### PR 2: Filter secrets from connection extra field

- **PR Title**: `fix: redact sensitive keys in connection extra field`
- **Branch name**: `fix/filter-connection-extra`
- **Files to modify**: `astro-airflow-mcp/src/astro_airflow_mcp/utils.py`
- **Changes**: Enhance `filter_connection_passwords()` to parse the `extra` JSON field and redact known sensitive keys (`aws_secret_access_key`, `private_key`, `keyfile_dict`, `password`, `token`, `secret`). If parsing fails, replace the entire extra field with `"***FILTERED***"`.
- **Impact**: Prevents leakage of cloud provider credentials and API keys stored in Airflow connection extras.

### PR 3: Restrict default credentials to localhost only

- **PR Title**: `fix: restrict default admin credentials to localhost connections`
- **Branch name**: `fix/localhost-only-default-creds`
- **Files to modify**: `astro-airflow-mcp/src/astro_airflow_mcp/auth.py`
- **Changes**: In the `_fetch_token` 404 handler (line 139-146), check if `self.airflow_url` points to localhost/127.0.0.1 before applying default admin:admin credentials. For non-local URLs, log a WARNING and leave credentials as None, forcing the user to provide explicit credentials.
- **Impact**: Prevents accidental use of default credentials against remote Airflow instances, reducing risk of credential exposure over the network.

## Scores (1-10)

| Category | Score |
|----------|-------|
| Code Quality | 8 |
| Security | 7 |
| Documentation | 9 |
| Test Coverage | 7 |
| Contribution Potential | 7 |

## Summary

- **Total findings by severity**: Critical: 0, High: 3, Medium: 3, Low: 4, Info: 0
- **Overall risk level**: **MEDIUM**

**Top 3 recommendations**:
1. **Filter sensitive config values** - The `get_airflow_config` tool returns raw Airflow configuration which commonly contains database passwords and encryption keys. Add defense-in-depth filtering.
2. **Redact connection extras** - Connection `extra` fields frequently contain cloud provider credentials. Extend the existing password filtering to cover this field.
3. **Restrict default credential scope** - The automatic admin:admin fallback should be limited to localhost connections to prevent credential exposure over the network.
