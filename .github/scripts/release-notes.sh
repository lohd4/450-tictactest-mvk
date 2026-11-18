#!/usr/bin/env bash
# Builds the GitHub release body for one version, in the format required by the
# release assignment: tag, commit, changes, artefact. The "changes" section is
# taken verbatim from the matching CHANGELOG.md section, so the release notes and
# the changelog can never drift apart.
# Usage: release-notes.sh <version-without-v> <tag>
set -euo pipefail

version="$1"
tag="$2"
commit=$(git rev-parse HEAD)

# Everything between "## <version> - <date>" and the next "## " heading.
changes=$(awk -v v="$version" '
  $0 ~ "^## " v "( |$|-)" { found = 1; next }
  found && /^## / { exit }
  found { print }
' CHANGELOG.md)

if [ -z "$(echo "$changes" | tr -d '[:space:]')" ]; then
  echo "::error::CHANGELOG.md has no section for version $version - update the changelog before tagging." >&2
  exit 1
fi

cat <<EOF
**Release:** TicTacTest $tag

| | |
| --- | --- |
| **Tag** | \`$tag\` |
| **Commit** | \`$commit\` |
| **Artefakt** | \`tictactest-$version.jar\` |

## Änderungen
$changes

## Download und Start

Das Jar unter *Assets* herunterladen und starten - es muss **nicht** aus dem
Quellcode gebaut werden:

\`\`\`bash
java -jar tictactest-$version.jar
\`\`\`

Version des heruntergeladenen Jars prüfen:

\`\`\`bash
java -jar tictactest-$version.jar --version
\`\`\`

Integrität prüfen (optional, gegen \`tictactest-$version.jar.sha256\`):

\`\`\`bash
sha256sum -c tictactest-$version.jar.sha256
\`\`\`
EOF
