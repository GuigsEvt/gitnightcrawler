Report written to `MARKETING_AUDIT.md`. Key findings:

**Top 3 quick wins:**
1. **3 skills missing from README** + 2 skills with wrong filename casing (`skill.md` vs `SKILL.md`) -- combined into one PR, 15 min, high merge likelihood
2. **Zero badges in README** -- 5 min, high merge likelihood
3. **CONTRIBUTING.md has wrong clone command** (missing `--recurse-submodules`) and outdated project structure -- 10 min, high merge likelihood

**Notable bug:** `managing-astro-deployments` and `troubleshooting-astro-deployments` use lowercase `skill.md` while all 21 other skills use `SKILL.md`. On Linux (case-sensitive), these may not be auto-discovered by the plugin.
