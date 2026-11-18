#!/usr/bin/env bash
# Populates ops/local/.runtime/ from a published GitHub release - and from
# nothing else. The point of the exercise is to run the ARTEFACT, so this
# script never builds anything: if an asset is missing from the release, it
# fails rather than falling back to a local build.
#
#   usage: ./fetch-release.sh [vX.Y.Z]      (default: the latest release)
set -euo pipefail

REPO="${TICTACTEST_REPO:-lohd4/450-tictactest-mvk}"

# ttyd is not in any distro repo we use, so it is pinned by version AND digest -
# the same values the EC2 instance installs (see infra/). An unpinned download
# would mean a different terminal on every machine and every instance rebuild.
TTYD_VERSION="1.7.7"
TTYD_SHA256="8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55"
TTYD_URL="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64"

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
runtime="$here/.runtime"
tag="${1:-}"

note() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- which release? ----------------------------------------------------------
api="https://api.github.com/repos/${REPO}/releases"
if [ -z "$tag" ]; then
	tag=$(curl -fsSL "${api}/latest" | grep -oE '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
	[ -n "$tag" ] || die "could not determine the latest release of ${REPO}"
fi
version="${tag#v}"
note "release ${tag} (version ${version})"

base="https://github.com/${REPO}/releases/download/${tag}"
mkdir -p "$runtime/bin" "$runtime/app" "$runtime/www"

# --- backend: the jar --------------------------------------------------------
note "downloading tictactest-${version}.jar"
curl -fsSL -o "$runtime/app/tictactest.jar" "${base}/tictactest-${version}.jar" \
	|| die "no jar in release ${tag}"

if curl -fsSL -o "$runtime/app/tictactest.jar.sha256" "${base}/tictactest-${version}.jar.sha256" 2>/dev/null; then
	# The checksum file names the versioned jar; we saved it unversioned.
	expected=$(awk '{print $1}' "$runtime/app/tictactest.jar.sha256")
	actual=$(sha256sum "$runtime/app/tictactest.jar" | awk '{print $1}')
	[ "$expected" = "$actual" ] || die "jar checksum mismatch: expected $expected, got $actual"
	note "jar checksum OK"
fi

# The version endpoint reads this file. It is derived from the release, so it
# cannot drift from what is actually running.
printf '%s\n' "$version" > "$runtime/app/version.txt"

# --- frontend ----------------------------------------------------------------
note "downloading tictactest-frontend-${version}.zip"
if curl -fsSL -o "$runtime/frontend.zip" "${base}/tictactest-frontend-${version}.zip" 2>/dev/null; then
	rm -rf "$runtime/www"; mkdir -p "$runtime/www"
	unzip -q "$runtime/frontend.zip" -d "$runtime/www"
	rm -f "$runtime/frontend.zip"
	note "frontend archive unpacked"
else
	die "no frontend archive in release ${tag} - releases from before Auftrag 1 do not have one.
       Use a newer release, or for a quick local check copy the working tree:
         rm -rf '$runtime/www' && cp -r '$here/../../frontend' '$runtime/www'"
fi

# --- config.js: owned by the environment, not by the release -----------------
# In the cloud OpenTofu writes this into the bucket. Locally we write it here.
# Either way it is NOT part of the frontend archive, which is why a frontend
# deployment can never overwrite it.
cat > "$runtime/www/config.js" <<EOF
window.TICTACTEST_CONFIG = {
	consoleUrl: 'http://localhost:8080/',
	versionUrl: 'http://localhost:8080/version'
};
EOF
note "config.js written (local environment)"

# --- ttyd --------------------------------------------------------------------
if [ ! -x "$runtime/bin/ttyd" ]; then
	note "downloading ttyd ${TTYD_VERSION}"
	curl -fsSL -o "$runtime/bin/ttyd" "$TTYD_URL"
	actual=$(sha256sum "$runtime/bin/ttyd" | awk '{print $1}')
	if [ "$actual" != "$TTYD_SHA256" ]; then
		rm -f "$runtime/bin/ttyd"
		die "ttyd checksum mismatch: expected $TTYD_SHA256, got $actual"
	fi
	chmod +x "$runtime/bin/ttyd"
	note "ttyd checksum OK"
else
	note "ttyd already present"
fi

note "ready - run: docker compose up -d"
