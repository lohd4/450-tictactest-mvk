#!/usr/bin/env bash
# Pushes the Terraform outputs into the places that need them:
#
#   1. GitHub Actions *Variables* - what deploy.yaml reads (vars.*)
#   2. the play link in README.md
#
# The outputs are the interface between the infrastructure and everything else,
# and this script is what keeps that interface from being copied by hand. Run it
# after every `terraform apply` that changed an address or an identifier -
# in particular after a destroy/apply cycle, where the Elastic IP, both bucket
# names and the instance ID are all new.
#
# NOT handled here on purpose: the three AWS credentials. They are Secrets, not
# Variables, they come from the Learner Lab rather than from Terraform, and they
# must never pass through a script that could log them. Set them with
# `gh secret set AWS_ACCESS_KEY_ID` (etc.), which prompts for the value instead
# of taking it from the command line or the environment.
#
#   usage: ops/sync-github-env.sh [--dry-run]
set -euo pipefail

dry_run=false
case "${1:-}" in
	--dry-run) dry_run=true ;;
	"") ;;
	*) echo "usage: $(basename "$0") [--dry-run]" >&2; exit 2 ;;
esac

repo_root=$(git rev-parse --show-toplevel)
infra="$repo_root/infra"
readme="$repo_root/README.md"

note() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v terraform >/dev/null 2>&1 || die "terraform not found in PATH"
[ -d "$infra" ] || die "no infra/ directory at $infra"

# --- read the outputs -------------------------------------------------------
# One `terraform output -raw` per value instead of parsing the JSON blob: no jq
# dependency, and a missing output fails loudly instead of yielding "null".
out() {
	terraform -chdir="$infra" output -raw "$1" 2>/dev/null \
		|| die "output '$1' is not available - has 'terraform apply' run in $infra?"
}

note "reading Terraform outputs"
AWS_REGION=$(out aws_region)
INSTANCE_ID=$(out instance_id)
ARTIFACTS_BUCKET=$(out artifacts_bucket)
FRONTEND_BUCKET=$(out frontend_bucket)
VERSION_URL=$(out version_url)
PLAY_URL=$(out play_url)

# None of these are secret - they are public addresses and identifiers (see
# docs/deployment.md section 2.2), so printing them here is fine and makes the
# --dry-run useful.
cat <<SUMMARY

  AWS_REGION        $AWS_REGION
  INSTANCE_ID       $INSTANCE_ID
  ARTIFACTS_BUCKET  $ARTIFACTS_BUCKET
  FRONTEND_BUCKET   $FRONTEND_BUCKET
  VERSION_URL       $VERSION_URL
  PLAY_URL          $PLAY_URL

SUMMARY

# --- 1. GitHub Actions Variables --------------------------------------------
gh_usable() {
	command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

if [ "$dry_run" = true ]; then
	note "--dry-run: not touching GitHub or README.md"
elif ! gh_usable; then
	# Not fatal: the README update below is still worth doing, and the values
	# are printed above so they can be pasted into
	# Settings -> Secrets and variables -> Actions -> Variables.
	printf '\033[1;33mSKIPPED:\033[0m gh is missing or not logged in - set the six Variables above by hand\n'
	printf '          (install: winget install GitHub.cli, then: gh auth login)\n'
else
	note "setting GitHub Actions variables"
	for pair in \
		"AWS_REGION=$AWS_REGION" \
		"INSTANCE_ID=$INSTANCE_ID" \
		"ARTIFACTS_BUCKET=$ARTIFACTS_BUCKET" \
		"FRONTEND_BUCKET=$FRONTEND_BUCKET" \
		"VERSION_URL=$VERSION_URL" \
		"PLAY_URL=$PLAY_URL"
	do
		name="${pair%%=*}"
		value="${pair#*=}"
		gh variable set "$name" --body "$value"
		echo "    $name"
	done
fi

# --- 2. the play link in README.md ------------------------------------------
# Rewritten between markers so the script is idempotent and cannot eat anything
# else in the README.
start='<!-- play-url:start -->'
end='<!-- play-url:end -->'

grep -qF "$start" "$readme" || die "marker '$start' missing from README.md"
grep -qF "$end" "$readme"   || die "marker '$end' missing from README.md"

block="> ### ▶ [Jetzt spielen]($PLAY_URL)
>
> Web-Konsole: <$VERSION_URL> meldet die laufende Backend-Version."

if [ "$dry_run" = true ]; then
	note "README.md would become:"
	printf '%s\n' "$block" | sed 's/^/    /'
else
	tmp=$(mktemp)
	awk -v start="$start" -v end="$end" -v block="$block" '
		$0 == start { print; print block; skip = 1; next }
		$0 == end   { print; skip = 0; next }
		!skip       { print }
	' "$readme" > "$tmp"
	mv "$tmp" "$readme"
	note "README.md updated - commit the change"
fi

note "done"
