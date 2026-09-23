#!/usr/bin/env bash
# Combines docker/metadata-action's tag list with the release-version tag
# (only present on a run that's publishing a new release), producing the
# final multi-line tag list for docker/build-push-action.
# Requires: META_TAGS. Optional (both or neither): RELEASE_OWNER, RELEASE_VERSION.
set -euo pipefail

tags="$META_TAGS"
if [ -n "${RELEASE_VERSION:-}" ]; then
  tags="$tags
ghcr.io/${RELEASE_OWNER}/tictactest-dev:${RELEASE_VERSION}"
fi

{
  echo "list<<TAGS_EOF"
  echo "$tags"
  echo "TAGS_EOF"
} >> "$GITHUB_OUTPUT"
