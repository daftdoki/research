#!/usr/bin/env bash
# usage: metrics.sh owner/repo ...  -> TSV of activity/quality signals
since=$(date -u -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)
printf "repo\tstars\tforks\tpushed\tarchived\tlicense\tlang\topen_issues\tcommits90d\tcontributors\tlatest_release\trelease_date\tci_workflows\ttest_files\n"
for r in "$@"; do
  j=$(gh api repos/$r 2>/dev/null) || { echo -e "$r\tERR"; continue; }
  base=$(echo "$j" | jq -r '[.stargazers_count,.forks_count,.pushed_at[0:10],.archived,(.license.spdx_id//"-"),.language,.open_issues_count]|@tsv')
  br=$(echo "$j" | jq -r .default_branch)
  c90=$(gh api "repos/$r/commits?since=$since&per_page=100" --paginate --jq 'length' 2>/dev/null | paste -sd+ | bc)
  contrib=$(gh api "repos/$r/contributors?per_page=100&anon=0" --jq 'length' 2>/dev/null)
  rel=$(gh api repos/$r/releases/latest --jq '[.tag_name,.published_at[0:10]]|@tsv' 2>/dev/null || echo -e "-\t-")
  tree=$(gh api "repos/$r/git/trees/$br?recursive=1" --jq '.tree[].path' 2>/dev/null)
  ci=$(echo "$tree" | grep -c '^\.github/workflows/')
  tests=$(echo "$tree" | grep -Ei '(^|/)(tests?|__tests__|spec)/|\.(test|spec)\.[jt]sx?$|_test\.(py|go|rs)$|test_[^/]*\.py$' | grep -vc node_modules)
  echo -e "$r\t$base\t${c90:-0}\t$contrib\t$rel\t$ci\t$tests"
done
