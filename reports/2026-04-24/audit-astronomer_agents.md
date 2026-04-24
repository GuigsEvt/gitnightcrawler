Report written to `MARKETING_AUDIT.md`. Key findings:

**Top 3 easiest PRs:**
1. **Fix broken CI badge + add root README badges** (10 min, high merge chance) -- the sub-README CI badge points to the old `astronomer/astro-airflow-mcp` repo
2. **Add `py.typed` marker + complete PyPI metadata** (15 min) -- missing authors, license, keywords, classifiers, URLs in pyproject.toml
3. **Add pytest-cov coverage reporting** (20 min) -- only 17% of source files have dedicated tests, but there's no way to even measure it currently

**Biggest gaps:** MCP tools (66 functions, zero tests), 8/13 CLI modules untested, no dependabot, no issue/PR templates, no CHANGELOG. But the codebase itself is very clean -- high quality bar.
