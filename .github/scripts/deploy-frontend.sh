#!/usr/bin/env bash
# Deploys one released frontend version to the S3 website bucket.
#
# Required environment:
#   VERSION           e.g. 1.3.0 (no leading v)
#   FRONTEND_BUCKET   the public website bucket
#   PLAY_URL          http://<bucket>.s3-website-<region>.amazonaws.com
#   AWS_REGION        region of the bucket
# Optional:
#   ARCHIVE_PATH      pre-downloaded zip (otherwise taken from the release)
#   REPO              owner/name, default lohd4/450-tictactest-mvk
set -euo pipefail

: "${VERSION:?VERSION is required}"
: "${FRONTEND_BUCKET:?FRONTEND_BUCKET is required}"
: "${PLAY_URL:?PLAY_URL is required}"
: "${AWS_REGION:?AWS_REGION is required}"

REPO="${REPO:-lohd4/450-tictactest-mvk}"
archive="${ARCHIVE_PATH:-}"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

note() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

# --- 1. get the artefact from the release -----------------------------------
if [ -z "$archive" ]; then
	note "downloading tictactest-frontend-${VERSION}.zip from release v${VERSION}"
	curl -fsSL -o "$workdir/frontend.zip" \
		"https://github.com/${REPO}/releases/download/v${VERSION}/tictactest-frontend-${VERSION}.zip"
	archive="$workdir/frontend.zip"
fi

site="$workdir/site"
mkdir -p "$site"
unzip -q "$archive" -d "$site"

# The archive must never carry config.js - that belongs to the infrastructure.
# package-frontend.sh already refuses to build such an archive; this is the
# second line of defence, at the moment it would actually do damage.
if [ -f "$site/config.js" ]; then
	echo "::error::the frontend archive contains config.js - refusing to overwrite the infrastructure's configuration"
	exit 1
fi

# --- 2. publish -------------------------------------------------------------
# --delete removes files that no longer exist in the release, as required.
# --exclude config.js is what keeps it from deleting the one file OpenTofu owns:
# without it, --delete would remove config.js on the first deployment, the
# frontend would lose the console URL and the page would load with a dead
# terminal and no backend version. The exclude applies to both sides of the
# sync, so the file is neither uploaded nor deleted.
note "syncing to s3://${FRONTEND_BUCKET}"
aws s3 sync "$site/" "s3://${FRONTEND_BUCKET}/" \
	--region "$AWS_REGION" \
	--delete \
	--exclude 'config.js'

# version.json must not be cached, or the check below (and every visitor) would
# keep seeing the previous release.
aws s3 cp "$site/version.json" "s3://${FRONTEND_BUCKET}/version.json" \
	--region "$AWS_REGION" \
	--cache-control 'no-store' \
	--content-type 'application/json'

# --- 3. verify --------------------------------------------------------------
note "checking that ${PLAY_URL} serves ${VERSION}"
deadline=$(( $(date +%s) + 60 ))
served=""
while [ "$(date +%s)" -lt "$deadline" ]; do
	served=$(curl -fsS --max-time 5 "${PLAY_URL}/version.json" 2>/dev/null \
		| tr -d ' \n\t' | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' || true)
	if [ "$served" = "$VERSION" ]; then
		note "frontend version confirmed: ${served}"
		break
	fi
	sleep 3
done

if [ "$served" != "$VERSION" ]; then
	echo "::error::${PLAY_URL}/version.json reports '${served:-<nothing>}', expected '${VERSION}'"
	exit 1
fi

# The infrastructure's config must still be there after the sync.
if ! curl -fsS --max-time 5 "${PLAY_URL}/config.js" | grep -q 'TICTACTEST_CONFIG'; then
	echo "::error::config.js is missing or broken after the deployment - the console URL is gone"
	exit 1
fi
note "config.js survived the deployment"
