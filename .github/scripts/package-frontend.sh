#!/usr/bin/env bash
# Packages frontend/ as the release archive tictactest-frontend-<version>.zip.
#
# Two rules decide what goes in:
#
#   version.json  IS written here, from the release version, so the deployed
#                 frontend can report which release it came from without anyone
#                 maintaining a number by hand.
#
#   config.js     is NOT included. It holds the address of the web console,
#                 which only the infrastructure knows, and it differs per
#                 environment. Terraform writes it into the bucket once; the
#                 frontend deployment syncs with --exclude config.js so it
#                 survives. Shipping it here would overwrite the real one with
#                 a developer's localhost settings on the next deployment.
#
# Usage: package-frontend.sh <version> [output-dir]
set -euo pipefail

version="${1:?usage: package-frontend.sh <version> [output-dir]}"
outdir="${2:-build/frontend}"

repo_root=$(git rev-parse --show-toplevel)
src="$repo_root/frontend"
[ -d "$src" ] || { echo "::error::no frontend/ directory at $src"; exit 1; }

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

cp -r "$src/." "$staging/"

# Defensive: config.js is gitignored, but a local checkout may still have one.
rm -f "$staging/config.js" "$staging/config.sample.js"

cat > "$staging/version.json" <<EOF
{
  "version": "${version}",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$(git rev-parse HEAD)"
}
EOF

mkdir -p "$repo_root/$outdir"
archive="$repo_root/$outdir/tictactest-frontend-${version}.zip"
rm -f "$archive"

# zip(1) on CI; jar(1) as the fallback so the archive can also be produced on a
# developer machine without zip installed (Java is a hard requirement anyway).
# Both write a plain zip - "--no-manifest" keeps jar from adding META-INF.
if command -v zip >/dev/null 2>&1; then
	(cd "$staging" && zip -qr "$archive" .)
elif command -v jar >/dev/null 2>&1; then
	(cd "$staging" && jar --create --no-manifest --file "$archive" .)
else
	echo "::error::neither zip nor jar available to build the frontend archive"
	exit 1
fi

echo "built $archive"
unzip -l "$archive"

# A frontend that cannot find its entry point is not deployable.
unzip -l "$archive" | grep -q 'index.html' || { echo "::error::index.html missing from archive"; exit 1; }
unzip -l "$archive" | grep -q 'version.json' || { echo "::error::version.json missing from archive"; exit 1; }
if unzip -l "$archive" | grep -q 'config.js'; then
	echo "::error::config.js must not be in the frontend archive - it belongs to the infrastructure"
	exit 1
fi
