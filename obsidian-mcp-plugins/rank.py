"""Weighted ranking of Obsidian MCP candidates. Usage: python3 rank.py scores.csv"""
import csv, sys

# Weights reflect the stated priorities: maintenance + code quality + popularity,
# semantic search as a strong plus, and fit for Karpathy's ingest/query/lint loop.
WEIGHTS = {"wiki_fit": 0.25, "semantic_search": 0.20, "maintenance": 0.20,
           "code_quality": 0.20, "popularity": 0.15}

rows = list(csv.DictReader(open(sys.argv[1])))
for r in rows:
    r["score"] = sum(float(r[k]) * w for k, w in WEIGHTS.items())
rows.sort(key=lambda r: r["score"], reverse=True)
cols = ["popularity", "maintenance", "code_quality", "semantic_search", "wiki_fit"]
print("| # | Candidate | Pop | Maint | Quality | Semantic | Wiki fit | **Score** |")
print("|---|---|---|---|---|---|---|---|")
for i, r in enumerate(rows, 1):
    cells = " | ".join(r[c] for c in cols)
    print(f"| {i} | [{r['candidate']}](https://github.com/{r['repo']}) | {cells} | **{r['score']:.2f}** |")
