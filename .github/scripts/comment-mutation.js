// Posts (or updates) the PIT mutation-testing PR comment.
// Loaded via require() from the workflow's actions/github-script step, which
// passes in `github`/`context`. Requires env: MUTATION_TOTAL, MUTATION_KILLED, MUTATION_SCORE.
module.exports = async ({ github, context }) => {
  const marker = "<!-- mutation-report -->";
  const total = process.env.MUTATION_TOTAL;
  const killed = process.env.MUTATION_KILLED;
  const score = process.env.MUTATION_SCORE;

  const body = [
    marker,
    "Mutation Testing (PIT)",
    "",
    `Mutations: ${total}`,
    `Killed: ${killed}`,
    `Score: ${score} %`,
    "",
    "Informational only - does not block the PR. Full report: download the `pitest-report` artifact from this run.",
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
};
