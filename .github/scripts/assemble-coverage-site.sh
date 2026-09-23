#!/usr/bin/env bash
# Builds the gh-pages "site/" directory: the coverage-trend page plus an
# appended row in coverage-history.csv (carried forward from the existing
# gh-pages branch, if any). Requires: COVERAGE_VALUE, GITHUB_SHA.
set -euo pipefail

mkdir -p site
cp docs/coverage-trend/index.html site/index.html

if git ls-remote --exit-code --heads origin gh-pages > /dev/null 2>&1; then
  git fetch origin gh-pages --depth=1
  git show origin/gh-pages:coverage-history.csv > site/coverage-history.csv 2>/dev/null || echo "Datum,Commit,Coverage" > site/coverage-history.csv
else
  echo "Datum,Commit,Coverage" > site/coverage-history.csv
fi

echo "$(date -u +%Y-%m-%d),${GITHUB_SHA::7},${COVERAGE_VALUE}" >> site/coverage-history.csv
