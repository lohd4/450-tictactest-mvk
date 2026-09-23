#!/usr/bin/env bash
# Bumps the dev container's patch version and writes the new value back into
# the version file (the working-tree change is what the caller turns into a
# release pull request). Usage: next-devcontainer-version.sh <path-to-VERSION>
set -euo pipefail

version_file="${1:?usage: next-devcontainer-version.sh <path-to-VERSION-file>}"

old_version=$(<"$version_file")
if [[ ! "$old_version" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "::error::${version_file} does not contain a vMAJOR.MINOR.PATCH version (got '${old_version}')"
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
new_version="v${major}.${minor}.$((patch + 1))"

echo "$new_version" > "$version_file"

owner=$(echo "${GITHUB_REPOSITORY_OWNER}" | tr '[:upper:]' '[:lower:]')

echo "old_version=$old_version" >> "$GITHUB_OUTPUT"
echo "new_version=$new_version" >> "$GITHUB_OUTPUT"
echo "owner=$owner" >> "$GITHUB_OUTPUT"
