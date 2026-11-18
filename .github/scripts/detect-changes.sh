#!/usr/bin/env bash
# Decides what a release has to deploy: backend, frontend, both or nothing.
#
# The comparison is against the PREVIOUS RELEASE TAG, not the previous commit.
# A release is the unit that gets deployed, so "has the backend changed?" can
# only mean "has it changed since the last thing we deployed?". Comparing
# against the previous commit would miss everything that landed on main between
# two releases, and would deploy nothing for a release that bundles ten commits.
#
# This is also why the GitHub Actions `paths:` filter cannot do this job: it
# only looks at the commits contained in the triggering push, and a tag push
# contains no commits at all. It would never fire.
#
# Usage: detect-changes.sh <tag>        e.g. detect-changes.sh v1.3.0
# Writes backend=/frontend=/previous_tag= to $GITHUB_OUTPUT (and stdout).
set -euo pipefail

tag="${1:?usage: detect-changes.sh <tag>}"

emit() {
	echo "$1"
	[ -n "${GITHUB_OUTPUT:-}" ] && echo "$1" >> "$GITHUB_OUTPUT"
	return 0
}

# --- which release came before this one? ------------------------------------
# Only v* tags count; anything else is not a release of ours.
#
# "The newest tag that is not this one" would be wrong: when an OLDER version
# is redeployed on purpose (rollback), that would compare against a release
# made *after* it and invert the result. So walk the tags in version order and
# take the one immediately before this tag.
previous_tag=$(git tag --list 'v*' --sort=version:refname \
	| awk -v current="$tag" '$0 == current { found = 1; exit } { prev = $0 } END { if (found) print prev }')

if [ -z "$previous_tag" ]; then
	# The very first release has nothing to compare against, so everything is
	# new by definition - deploy both halves.
	echo "no previous release tag: first release, deploying everything"
	emit "previous_tag="
	emit "backend=true"
	emit "frontend=true"
	exit 0
fi

echo "comparing $previous_tag..$tag"
changed=$(git diff --name-only "$previous_tag".."$tag")

if [ -z "$changed" ]; then
	echo "no file changes between $previous_tag and $tag"
	emit "previous_tag=$previous_tag"
	emit "backend=false"
	emit "frontend=false"
	exit 0
fi

echo "--- changed files ---"
echo "$changed" | sed 's/^/  /'
echo "---------------------"

backend=false
frontend=false

while IFS= read -r file; do
	[ -n "$file" ] || continue
	case "$file" in
		# --- frontend ---------------------------------------------------
		frontend/*)
			frontend=true ;;
		.github/scripts/package-frontend.sh)
			# Changes how the frontend archive is produced.
			frontend=true ;;

		# --- backend ----------------------------------------------------
		# Only main sources: a test-only change produces a byte-identical jar,
		# so there is nothing to deploy.
		src/main/*)
			backend=true ;;
		build.gradle|settings.gradle|gradle.properties|gradlew|gradlew.bat|gradle/*)
			# Build configuration decides what ends up in the jar.
			backend=true ;;

		# --- both -------------------------------------------------------
		.github/workflows/release.yaml)
			# Produces both artefacts; a change here can alter either one.
			backend=true; frontend=true ;;

		# --- neither ----------------------------------------------------
		# Documentation, tests, the dev container, the infrastructure and the
		# local ops helpers never change a released artefact. Infrastructure in
		# particular is applied with `tofu apply`, deliberately not from here.
		src/test/*|doc/*|docs/*|*.md|.devcontainer/*|infra/*|ops/*|.github/*|.vscode/*|.idea/*|.editorconfig|.gitattributes|.gitignore)
			;;
		*)
			# Unknown path: deploy both rather than silently skipping something.
			echo "  note: '$file' matches no rule - deploying both to be safe"
			backend=true; frontend=true ;;
	esac
done <<< "$changed"

emit "previous_tag=$previous_tag"
emit "backend=$backend"
emit "frontend=$frontend"
