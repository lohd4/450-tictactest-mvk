#!/usr/bin/env bash
# Summarizes a PIT mutations.xml report as GitHub Actions outputs
# (total, killed, score). Usage: pitest-summary.sh <path-to-mutations.xml>
set -euo pipefail

xml="${1:?usage: pitest-summary.sh <path-to-mutations.xml>}"

total=$(grep -o '<mutation ' "$xml" | wc -l)
killed=$(grep -o "status='KILLED'" "$xml" | wc -l)

if [ "$total" -eq 0 ]; then
  score="0.0"
else
  scaled=$(( (killed * 1000 + total / 2) / total ))
  score="$((scaled / 10)).$((scaled % 10))"
fi

echo "total=$total" >> "$GITHUB_OUTPUT"
echo "killed=$killed" >> "$GITHUB_OUTPUT"
echo "score=$score" >> "$GITHUB_OUTPUT"
