Report complete at `marketing-audit-report.md`. Key findings across all 8 repos:

**Highest-impact repos** (stars vs missing basics):
- **MemPalace** (46.5K stars) -- missing CODE_OF_CONDUCT, issue templates, i18n PRs merge instantly
- **graphify** (27.4K stars) -- no CONTRIBUTING.md, stale SECURITY.md version
- **nanobot** (39.7K stars) -- no CI badge, no coverage reporting despite having pytest-cov

**Fastest wins** (under 5 minutes each):
1. hermes-webui: fix duplicate alt attribute (2 min)
2. graphify: fix SECURITY.md version string (2 min)
3. bitrouter: add .gitattributes for language detection (5 min)
4. hermes-webui: add CI badge (5 min)
5. moltis: add CODE_OF_CONDUCT.md (5 min)

**Biggest gaps found**:
- GenericAgent has zero CI, zero packaging, 42% community health
- 6 of 8 repos missing CODE_OF_CONDUCT.md
- 5 of 8 repos have no "good first issue" labels on any issues
- graphify maintainer cherry-picks instead of merging -- proceed with caution there
