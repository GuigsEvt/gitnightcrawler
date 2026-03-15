#!/usr/bin/env python3
"""
gitnightcrawler - Discovery Script
Finds trending AI/MCP/Crypto repos + marketing-farm repos on GitHub.
"""

import json
import math
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / "config.json").read_text())

JSON_FIELDS = "fullName,description,stargazersCount,forksCount,openIssuesCount,language,license,createdAt,pushedAt,updatedAt,url,watchersCount"


def gh_search(query, topics=None, sort="stars", limit=20, min_stars=None, max_stars=None, updated_after=None):
    """Search repos using gh search repos CLI."""
    cmd = [
        "gh", "search", "repos",
        "--sort", sort,
        "--limit", str(limit),
        "--json", JSON_FIELDS,
    ]
    # Build stars filter
    if min_stars is not None and max_stars is not None:
        cmd.extend(["--stars", f"{min_stars}..{max_stars}"])
    elif min_stars is not None:
        cmd.extend(["--stars", f">={min_stars}"])
    elif max_stars is not None:
        cmd.extend(["--stars", f"<={max_stars}"])

    if updated_after:
        cmd.extend(["--updated", f">={updated_after}"])
    if topics:
        for t in topics:
            cmd.extend(["--topic", t])
    if query:
        cmd.append(query)

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        q_str = query or ",".join(topics or [])
        if "rate limit" in result.stderr.lower():
            print(f"  [rate-limit] Waiting 60s...", file=sys.stderr)
            time.sleep(60)
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"  [error] retry failed '{q_str}': {result.stderr.strip()}", file=sys.stderr)
                return []
        else:
            print(f"  [error] search '{q_str}': {result.stderr.strip()}", file=sys.stderr)
            return []
    # Pace requests to stay under 30/min search API limit
    time.sleep(2.5)
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return []


def compute_momentum(repo, is_marketing=False):
    """Compute momentum score from repo metadata."""
    now = datetime.now(timezone.utc)

    created = datetime.fromisoformat(repo["createdAt"].replace("Z", "+00:00"))
    pushed = datetime.fromisoformat(repo["pushedAt"].replace("Z", "+00:00"))

    age_days = max((now - created).days, 1)
    days_since_push = (now - pushed).days

    stars = repo.get("stargazersCount", 0)
    forks = repo.get("forksCount", 0)
    open_issues = repo.get("openIssuesCount", 0)
    language = repo.get("language") or ""

    velocity = stars / age_days
    recency_boost = max(0, 10 - days_since_push) / 10

    score = 0.0

    if is_marketing:
        # Marketing score: favor small active repos where PRs land easy
        # Low star count = less competition for PRs
        score += recency_boost * 30  # active = good
        score += min(open_issues * 2, 30)  # issues = easy targets
        score += min(velocity * 5, 20)  # some traction
        if stars < 500:
            score += 15  # sweet spot: visible but not crowded
        if age_days < 180:
            score += 10  # new projects accept more PRs
        # Language preference
        if language in CONFIG["preferred_languages"]:
            score *= CONFIG["language_boost"]
        # Penalty for inactive
        if days_since_push > 14:
            score *= 0.3
    else:
        # Main momentum score
        score += min(velocity * 10, 50)
        score += recency_boost * 20
        score += math.log10(max(stars, 1)) * 5

        # Young repo boost
        if age_days < 90:
            score += 15
        elif age_days < 180:
            score += 8

        # Fork engagement
        if stars > 0:
            score += min((forks / stars) * 20, 10)

        # Open issues = contribution opportunity (boosted)
        score += min(open_issues * 1.0, 25)

        # Language preference
        if language in CONFIG["preferred_languages"]:
            score *= CONFIG["language_boost"]

        # Penalties
        if days_since_push > 30:
            score *= 0.3
        if age_days > 365 and velocity < 1:
            score *= 0.5

    return {
        "momentum_score": round(score, 2),
        "stars_per_day": round(velocity, 2),
        "recency_boost": round(recency_boost, 2),
        "age_days": age_days,
        "days_since_push": days_since_push,
    }


def repo_to_entry(repo, momentum):
    return {
        "full_name": repo["fullName"],
        "description": (repo.get("description") or "")[:140],
        "url": repo["url"],
        "stars": repo.get("stargazersCount", 0),
        "forks": repo.get("forksCount", 0),
        "open_issues": repo.get("openIssuesCount", 0),
        "language": repo.get("language"),
        "license": (repo.get("license") or {}).get("key"),
        "created_at": repo.get("createdAt"),
        "pushed_at": repo.get("pushedAt"),
        "momentum": momentum,
    }


def is_excluded(repo):
    """Filter out non-code repos, awesome lists, archived, mega-repos, too young."""
    name = repo["fullName"].lower()
    if any(kw in name for kw in ["awesome-", "awesome_"]):
        return True
    if not repo.get("language"):
        return True
    return False


def passes_age_filter(repo):
    created = datetime.fromisoformat(repo["createdAt"].replace("Z", "+00:00"))
    age_days = (datetime.now(timezone.utc) - created).days
    return age_days >= CONFIG["min_age_days"]


def passes_star_filter(repo, min_s=None, max_s=None):
    stars = repo.get("stargazersCount", 0)
    if min_s and stars < min_s:
        return False
    if max_s and stars > max_s:
        return False
    return True


def discover():
    """Main discovery flow."""
    print(f"[gitnightcrawler] Discovery started at {datetime.now().isoformat()}")

    lookback = (datetime.now(timezone.utc) - timedelta(days=CONFIG["lookback_days"])).strftime("%Y-%m-%d")
    min_stars = CONFIG["min_stars"]
    max_stars = CONFIG["max_stars"]

    seen = set()
    candidates = []
    marketing_candidates = []

    def collect(repos, bucket):
        for r in repos:
            name = r["fullName"]
            if name not in seen:
                seen.add(name)
                bucket.append(r)

    # ── MAIN DISCOVERY ──────────────────────────────────────────────
    print("\n[Phase 1] Main queries...")
    for query in CONFIG["search_queries"]:
        print(f"  -> {query}")
        repos = gh_search(query, sort="stars", limit=15,
                          min_stars=min_stars, max_stars=max_stars,
                          updated_after=lookback)
        collect(repos, candidates)

    print("\n[Phase 2] Topic search...")
    topic_groups = [
        ["llm"], ["ai-agent"], ["mcp"], ["mcp-server"],
        ["rag"], ["defi"], ["crypto-trading"], ["blockchain-ai"],
        ["model-context-protocol"], ["ai-agents"],
    ]
    for topics in topic_groups:
        print(f"  -> topic:{','.join(topics)}")
        repos = gh_search(None, topics=topics, sort="updated", limit=15,
                          min_stars=min_stars, max_stars=max_stars,
                          updated_after=lookback)
        collect(repos, candidates)

    print("\n[Phase 3] Hot new repos (< 30 days)...")
    recent = (datetime.now(timezone.utc) - timedelta(days=30)).strftime("%Y-%m-%d")
    for query in ["AI agent", "MCP", "LLM", "crypto AI", "DeFi bot"]:
        print(f"  -> new: {query}")
        repos = gh_search(query, sort="stars", limit=10,
                          min_stars=20, max_stars=max_stars,
                          updated_after=recent)
        collect(repos, candidates)

    # ── MARKETING FARM DISCOVERY ────────────────────────────────────
    print("\n[Phase 4] Marketing farm repos...")
    mkt_min = CONFIG["marketing_min_stars"]
    mkt_max = CONFIG["marketing_max_stars"]
    for query in CONFIG["marketing_queries"]:
        print(f"  -> mkt: {query}")
        repos = gh_search(query, sort="updated", limit=10,
                          min_stars=mkt_min, max_stars=mkt_max,
                          updated_after=lookback)
        collect(repos, marketing_candidates)

    # ── SCORE & RANK ────────────────────────────────────────────────
    print(f"\n[Discovery] {len(candidates)} main + {len(marketing_candidates)} marketing candidates")
    print("[Scoring] Computing momentum...")

    # Score main repos
    scored_main = []
    for repo in candidates:
        if is_excluded(repo) or not passes_age_filter(repo):
            continue
        if not passes_star_filter(repo, min_stars, max_stars):
            continue
        m = compute_momentum(repo)
        scored_main.append(repo_to_entry(repo, m))
    scored_main.sort(key=lambda x: x["momentum"]["momentum_score"], reverse=True)
    top_main = scored_main[:CONFIG["max_repos_per_night"]]

    # Score marketing repos
    scored_mkt = []
    for repo in marketing_candidates:
        if is_excluded(repo) or not passes_age_filter(repo):
            continue
        if not passes_star_filter(repo, mkt_min, mkt_max):
            continue
        m = compute_momentum(repo, is_marketing=True)
        scored_mkt.append(repo_to_entry(repo, m))
    scored_mkt.sort(key=lambda x: x["momentum"]["momentum_score"], reverse=True)
    top_mkt = scored_mkt[:CONFIG["max_marketing_repos"]]

    # ── REPORT ──────────────────────────────────────────────────────
    report = {
        "run_date": datetime.now(timezone.utc).isoformat(),
        "total_main_candidates": len(candidates),
        "total_marketing_candidates": len(marketing_candidates),
        "scored_main": len(scored_main),
        "scored_marketing": len(scored_mkt),
        "top_repos": top_main,
        "marketing_repos": top_mkt,
    }

    report_dir = ROOT / CONFIG["report_dir"]
    report_dir.mkdir(exist_ok=True)
    date_str = datetime.now().strftime("%Y-%m-%d")
    report_path = report_dir / f"discovery-{date_str}.json"
    report_path.write_text(json.dumps(report, indent=2))

    # Print
    print(f"\n{'='*70}")
    print(f"  TOP {len(top_main)} REPOS — {date_str}")
    print(f"{'='*70}")
    for i, r in enumerate(top_main, 1):
        m = r["momentum"]
        print(f"\n  #{i} [score: {m['momentum_score']}] {r['full_name']}")
        print(f"     {r['description']}")
        print(f"     Stars: {r['stars']:,} | Forks: {r['forks']:,} | Issues: {r['open_issues']} | Lang: {r['language']}")
        print(f"     Velocity: {m['stars_per_day']} s/d | Age: {m['age_days']}d | Push: {m['days_since_push']}d ago")
        print(f"     {r['url']}")

    print(f"\n{'='*70}")
    print(f"  MARKETING FARM — {len(top_mkt)} repos")
    print(f"{'='*70}")
    for i, r in enumerate(top_mkt, 1):
        m = r["momentum"]
        print(f"\n  #{i} [score: {m['momentum_score']}] {r['full_name']}")
        print(f"     {r['description']}")
        print(f"     Stars: {r['stars']:,} | Issues: {r['open_issues']} | Lang: {r['language']}")
        print(f"     {r['url']}")

    print(f"\n[Report] {report_path}")
    return report


if __name__ == "__main__":
    discover()
