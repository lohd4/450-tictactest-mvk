#!/usr/bin/env bash
# Prints the LINE coverage percentage from a JaCoCo XML report as a
# GitHub Actions output ("value=NN.N"). Usage: jacoco-line-coverage.sh <report.xml>
set -euo pipefail

xml="${1:?usage: jacoco-line-coverage.sh <path-to-jacocoTestReport.xml>}"

entry=$(grep -o '<counter type="LINE" missed="[0-9]*" covered="[0-9]*"/>' "$xml" | tail -n 1)
missed=$(echo "$entry" | sed -E 's/.*missed="([0-9]+)".*/\1/')
covered=$(echo "$entry" | sed -E 's/.*covered="([0-9]+)".*/\1/')
total=$((covered + missed))
scaled=$(( (covered * 1000 + total / 2) / total ))
echo "value=$((scaled / 10)).$((scaled % 10))" >> "$GITHUB_OUTPUT"
