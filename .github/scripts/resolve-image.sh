#!/usr/bin/env bash
# Picks which tictactest-dev image tag to use for the CI container.
# Tries, in order: the current branch's own image, the default branch's
# image, then "latest". Requires: REPO_OWNER, BRANCH_REF, DEFAULT_BRANCH.
set -euo pipefail

owner=$(echo "$REPO_OWNER" | tr '[:upper:]' '[:lower:]')
repo="ghcr.io/$owner/tictactest-dev"
slug=$(echo "$BRANCH_REF" | sed 's#[^a-zA-Z0-9._-]#-#g')

for tag in "$slug" "$DEFAULT_BRANCH" latest; do
  if docker manifest inspect "$repo:$tag" >/dev/null 2>&1; then
    echo "image=$repo:$tag" >> "$GITHUB_OUTPUT"
    echo "Using $repo:$tag"
    exit 0
  fi
done

echo "::error::No dev container image in GHCR yet. Run the 'Dev container image' workflow (Actions tab -> Run workflow), or push a change under .devcontainer/."
exit 1
