// Posts (or updates) the coverage-gate PR comment.
// Runs via actions/github-script's script-path, so `github`/`context` are
// ambient globals. Requires env: COVERAGE_MAIN, COVERAGE_BRANCH, COVERAGE_DIFF, COVERAGE_RESULT.
const marker = "<!-- coverage-gate-report -->";
const main = process.env.COVERAGE_MAIN;
const branch = process.env.COVERAGE_BRANCH;
const diff = process.env.COVERAGE_DIFF;
const result = process.env.COVERAGE_RESULT;

const body = [
  marker,
  "Test Coverage",
  "",
  `main: ${main} %`,
  `PR: ${branch} %`,
  `Change: ${diff} percentage points`,
  "",
  result === "PASS"
    ? "PASS - Coverage gate passed"
    : "FAIL - Coverage gate failed",
].join("\n");

const { data: comments } = await github.rest.issues.listComments({
  owner: context.repo.owner,
  repo: context.repo.repo,
  issue_number: context.issue.number,
});
const existing = comments.find((c) => c.body && c.body.includes(marker));

if (existing) {
  await github.rest.issues.updateComment({
    owner: context.repo.owner,
    repo: context.repo.repo,
    comment_id: existing.id,
    body,
  });
} else {
  await github.rest.issues.createComment({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
    body,
  });
}
