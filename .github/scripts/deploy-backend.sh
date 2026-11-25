#!/usr/bin/env bash
# Deploys one released backend version to the running EC2 instance.
#
# The instance is NOT recreated and Terraform is not involved. All this does is
# put a jar into the artefact bucket, tell the instance which version it should
# be running, and verify that it is.
#
# Required environment:
#   VERSION            e.g. 1.3.0 (no leading v)
#   ARTIFACTS_BUCKET   private bucket the instance pulls from
#   INSTANCE_ID        target EC2 instance
#   VERSION_URL        http://<ip>/version
#   AWS_REGION         region of all of the above
# Optional:
#   JAR_PATH           pre-downloaded jar (otherwise taken from the release)
#   REPO               owner/name, default lohd4/450-tictactest-mvk
set -euo pipefail

: "${VERSION:?VERSION is required}"
: "${ARTIFACTS_BUCKET:?ARTIFACTS_BUCKET is required}"
: "${INSTANCE_ID:?INSTANCE_ID is required}"
: "${VERSION_URL:?VERSION_URL is required}"
: "${AWS_REGION:?AWS_REGION is required}"

REPO="${REPO:-lohd4/450-tictactest-mvk}"
jar="${JAR_PATH:-}"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

note() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

# --- 1. get the artefact from the release -----------------------------------
# Deployed is what was released. Nothing is rebuilt here - that is the whole
# point of deploying from a release rather than from a branch.
if [ -z "$jar" ]; then
	note "downloading tictactest-${VERSION}.jar from release v${VERSION}"
	base="https://github.com/${REPO}/releases/download/v${VERSION}"
	curl -fsSL -o "$workdir/tictactest-${VERSION}.jar" "${base}/tictactest-${VERSION}.jar"
	curl -fsSL -o "$workdir/tictactest-${VERSION}.jar.sha256" "${base}/tictactest-${VERSION}.jar.sha256" || true
	jar="$workdir/tictactest-${VERSION}.jar"
fi

# --- 2. put it where the instance can reach it ------------------------------
note "uploading to s3://${ARTIFACTS_BUCKET}/backend/"
aws s3 cp "$jar" "s3://${ARTIFACTS_BUCKET}/backend/tictactest-${VERSION}.jar" --region "$AWS_REGION"
if [ -f "${jar}.sha256" ]; then
	aws s3 cp "${jar}.sha256" "s3://${ARTIFACTS_BUCKET}/backend/tictactest-${VERSION}.jar.sha256" --region "$AWS_REGION"
fi

# --- 3. tell the instance which version it runs -----------------------------
# Over SSM, not SSH: no key material has to exist in GitHub, access is
# controlled by IAM, and every command is logged in CloudTrail. The downside is
# that it depends on the SSM agent being healthy - if it is wedged, SSH would
# still work, which is why the security group can be opened for debugging.
#
# Writing /etc/tictactest/version is what makes the choice survive a reboot:
# the systemd unit reads that file at start time.
note "instructing ${INSTANCE_ID} to switch to ${VERSION}"
command_id=$(aws ssm send-command \
	--region "$AWS_REGION" \
	--instance-ids "$INSTANCE_ID" \
	--document-name "AWS-RunShellScript" \
	--comment "deploy tictactest ${VERSION}" \
	--parameters "commands=[
		'set -euxo pipefail',
		'printf \"%s\\n\" \"${VERSION}\" > /etc/tictactest/version',
		'/usr/local/bin/tictactest-fetch',
		'systemctl restart tictactest.service',
		'systemctl is-active tictactest.service'
	]" \
	--query 'Command.CommandId' --output text)

note "SSM command ${command_id} sent, waiting"
if ! aws ssm wait command-executed \
		--region "$AWS_REGION" \
		--command-id "$command_id" \
		--instance-id "$INSTANCE_ID" 2>/dev/null; then
	echo "::error::SSM command did not succeed"
	aws ssm get-command-invocation --region "$AWS_REGION" \
		--command-id "$command_id" --instance-id "$INSTANCE_ID" \
		--query '{Status:Status,Stdout:StandardOutputContent,Stderr:StandardErrorContent}' \
		--output text || true
	exit 1
fi
note "SSM command finished"

# --- 4. verify what is actually running -------------------------------------
# A green SSM command only proves the commands ran, not that the right version
# is serving traffic. The version endpoint is the real check, and the deploy
# fails if it does not report the expected version in time.
note "waiting for ${VERSION_URL} to report ${VERSION}"
deadline=$(( $(date +%s) + 120 ))
reported=""
while [ "$(date +%s)" -lt "$deadline" ]; do
	reported=$(curl -fsS --max-time 5 "$VERSION_URL" 2>/dev/null | tr -d '[:space:]' || true)
	if [ "$reported" = "$VERSION" ]; then
		note "running version confirmed: ${reported}"
		exit 0
	fi
	sleep 5
done

echo "::error::after 120s ${VERSION_URL} reports '${reported:-<nothing>}', expected '${VERSION}'"
exit 1
