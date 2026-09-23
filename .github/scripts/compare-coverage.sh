#!/usr/bin/env bash
# Compares branch coverage against main, writes the job summary table, and
# fails the step if branch coverage regressed. Requires: COVERAGE_MAIN, COVERAGE_BRANCH.
set -euo pipefail

main="$COVERAGE_MAIN"
branch="$COVERAGE_BRANCH"

diff=$(awk -v m="$main" -v b="$branch" 'BEGIN { printf "%.1f", b - m }')
pass=$(awk -v m="$main" -v b="$branch" 'BEGIN { print (b >= m) ? "1" : "0" }')
sign=$(awk -v d="$diff" 'BEGIN { print (d >= 0) ? "+" : "" }')
result="FAIL"
[ "$pass" = "1" ] && result="PASS"

{
  echo "## Test Coverage Gate"
  echo ""
  echo "| main | branch | Diff | Result |"
  echo "|------|--------|------|--------|"
  echo "| ${main} % | ${branch} % | ${sign}${diff} pp | ${result} |"
} >> "$GITHUB_STEP_SUMMARY"

echo "main=$main" >> "$GITHUB_OUTPUT"
echo "branch=$branch" >> "$GITHUB_OUTPUT"
echo "diff=${sign}${diff}" >> "$GITHUB_OUTPUT"
echo "result=$result" >> "$GITHUB_OUTPUT"

if [ "$result" = "FAIL" ]; then
  echo "::error::Branch coverage (${branch}%) is lower than main (${main}%)."
  exit 1
fi
