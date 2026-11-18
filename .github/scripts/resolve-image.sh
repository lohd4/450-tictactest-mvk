#!/usr/bin/env bash
# Picks which tictactest-dev image tag to use for the CI container.
# Tries, in order: the current branch's own image, the default branch's
# image, then "latest". Requires: REPO_OWNER, BRANCH_REF, DEFAULT_BRANCH.
#
# Every probe reports why it failed. Swallowing those errors once cost a full
# debugging round: deleting the "untagged" package versions in GHCR had removed
# the child manifests an image index points at, so the tag still resolved but
# `docker manifest inspect` returned "manifest unknown" - which was reported as
# the flatly wrong "No dev container image in GHCR yet".
set -euo pipefail

owner=$(echo "$REPO_OWNER" | tr '[:upper:]' '[:lower:]')
repo="ghcr.io/$owner/tictactest-dev"
slug=$(echo "$BRANCH_REF" | sed 's#[^a-zA-Z0-9._-]#-#g')

reasons=""
for tag in "$slug" "$DEFAULT_BRANCH" latest; do
	# 2>&1 >/dev/null captures stderr only: stdout (the manifest) is discarded.
	if error=$(docker manifest inspect "$repo:$tag" 2>&1 >/dev/null); then
		echo "image=$repo:$tag" >> "$GITHUB_OUTPUT"
		echo "Using $repo:$tag"
		exit 0
	fi
	error=${error//$'\n'/ }
	echo "  $repo:$tag unavailable: ${error:-unknown error}"
	reasons+="  - ${tag}: ${error:-unknown error}"$'\n'
done

# A note on the second case below: GHCR lists the platform manifest and the
# buildx attestation manifest of a multi-arch image as separate *untagged*
# versions. Deleting those guts the tagged index - the tag still resolves, but
# its children 404 - and the image can only be restored by rebuilding it.
echo "::error::No usable dev container image at ${repo}. Tried ${slug}, ${DEFAULT_BRANCH}, latest:
${reasons}If these say 'manifest unknown', the image was either never built or its untagged
child manifests were deleted from the package. Either way, rebuild it: Actions tab ->
'Dev container image' -> Run workflow (or push a change under .devcontainer/)."
exit 1
