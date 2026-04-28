Report written to `MARKETING_AUDIT.md`. Here's the summary:

### Top Targets by ROI (merge speed x visibility)

| Rank | Repo | Stars | Merge Speed | Best Quick Win |
|------|------|-------|-------------|----------------|
| 1 | **heygen-com/hyperframes** | 12K | 11-17 min | README badges, issue templates |
| 2 | **MemPalace/mempalace** | 50K | Same-day | README badges, MCP tool docs |
| 3 | **HKUDS/nanobot** | 41K | Same-day | CI coverage reporting, README ToC |
| 4 | **astronomer/agents** | 345 | 11 min-2 days | Missing SKILL.md files, badges |
| 5 | **nesquena/hermes-webui** | 4.6K | Same-day | PR template (explicitly flagged as missing) |
| 6 | **moltis-org/moltis** | 2.6K | 10-36 min | Screenshots, troubleshooting docs |
| 7 | **bitrouter/bitrouter** | 77 | Same-day | Dockerfile, provider YAMLs |
| 8 | **safishamsi/graphify** | 36K | **AVOID** | 0/30 PRs merged via GitHub flow |

### Universal pattern across all 8 repos
Every single repo is missing **README badges**. This is the easiest possible first PR (15 minutes, zero risk, universally appreciated).

### Avoid
**safishamsi/graphify** -- despite 36K stars, the maintainer has merged 0 of the last 30 closed PRs through GitHub's merge flow. They push directly to main. Your PR will likely sit open indefinitely.
