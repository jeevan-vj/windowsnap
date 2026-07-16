# Codex Multi-Agent Issue-to-PR Workflow

This runbook describes how to ask Codex to process multiple GitHub issues with
isolated subagents, test-driven development (TDD), independent review, draft
pull requests, and controlled merges.

The workflow is designed for changes that should be implemented in parallel
without modifying or cleaning the primary local workspace.

## Outcomes

For every selected issue, the workflow should produce:

- an isolated working directory and `codex/` branch;
- tests written before the production implementation;
- an implementation checked against every acceptance criterion;
- a full relevant test run and release build;
- a self-reviewed commit pushed to GitHub;
- a draft pull request linked to the issue;
- an issue comment containing the PR and verification status;
- an independent review by an agent that did not author the change;
- fixes and regression tests for every blocking review finding;
- a merge only after independent approval.

## Important operating rules

1. **Preserve the primary workspace.** Agents must not edit, reset, stash, or
   clean the user's current checkout. Existing uncommitted files belong to the
   user.
2. **Use isolated clones.** Give each implementation and review agent its own
   directory below `/private/tmp`.
3. **One branch per issue.** Use names such as
   `codex/issue-42-short-description`.
4. **Tests first.** The agent must demonstrate a meaningful red phase before
   implementing the green phase.
5. **Do not trust the PR description.** A separate reviewer must inspect the
   actual diff and rerun tests.
6. **Do not merge draft work.** Authoring agents open draft PRs and never merge
   their own changes.
7. **Do not overclaim.** Hardware, TCC permission, notarization, VoiceOver, and
   other manual-only checks remain explicitly unchecked until a person performs
   them.
8. **Respect dependencies.** Do not start dependent issues from an unmerged
   branch unless a stacked-PR strategy was explicitly requested.
9. **Stop on security or data-loss findings.** Convert every blocker into a
   regression test, fix it, and request a fresh independent review.
10. **Never work around platform or approval limits.** Record the exact branch,
    commit, tests, remaining steps, and retry time so the run can resume safely.

## Recommended concurrency model

When four concurrent agent slots are available, use:

- one coordinator (the primary Codex agent); and
- up to three implementation or review subagents.

Do not fill every slot merely because it is available. Only parallelize issues
that do not depend on each other's unmerged changes.

Example dependency plan:

```text
Wave 1: #14, #15, #17       independent
Wave 2: #16 after #17       updates depend on release pipeline
        #18                 independent product decision
Wave 3: #19 after #18       config follows deployment decision
Wave 4: #20 after #14/#15/#16
```

## Preflight checklist

Before launching agents, the coordinator should:

- identify the repository as `owner/repository`;
- read every GitHub issue in scope;
- search for duplicate or overlapping open issues;
- inspect the local Git remote and default branch;
- record the current dirty-worktree state without changing it;
- identify issue dependencies and product decisions;
- confirm whether the user authorizes draft PR creation and merging;
- confirm the required merge method (squash is recommended here);
- verify that Git push and the GitHub connector are available;
- create a visible plan with one step per wave.

## Copy-paste orchestrator prompt

Use this prompt to start a complete run:

```text
Process GitHub issues #ISSUES in OWNER/REPOSITORY using multiple subagents.

Act as the coordinator. First inspect the issues, current PRs, dependencies,
and repository state. Preserve my current local workspace and all uncommitted
changes.

For each independent issue:
1. Create a subagent in an isolated clone under /private/tmp.
2. Create a codex/issue-N-description branch from the latest appropriate base.
3. Follow TDD: add meaningful failing tests first, then implement.
4. Implement every acceptance criterion that can be automated.
5. Run focused tests, the full test suite, a release build, and diff checks.
6. Self-review, commit, push, and open a DRAFT PR linked with Closes #N.
7. Comment on the issue with the PR, tests, achieved criteria, and manual checks.
8. Do not merge from the implementation agent.

After each draft PR is ready, assign a different subagent to independently
review the actual diff and rerun verification. If it finds a blocker, convert
the finding into a failing regression test, fix it, and re-review with a fresh
agent. Only mark ready and squash-merge after independent approval.

Run dependency-safe issues in waves. After every merge, start dependent work
from the updated main branch. Continue until all issues are completed or a real
external/platform blocker prevents progress. Report progress regularly and do
not work around approval, credential, or usage-limit failures.
```

Replace `#ISSUES` with a list such as `#14, #15, #17`.

## Implementation-agent contract

The coordinator can use the following task text for each implementation agent:

```text
Implement GitHub issue #N in OWNER/REPOSITORY end-to-end with TDD.

Work only in an isolated clone at /private/tmp/PROJECT-issue-N. Clone the latest
appropriate remote base and create branch codex/issue-N-short-name. Never touch
the user's primary workspace.

Read the complete issue before editing. Add focused failing tests first and
record the red result. Implement the acceptance criteria, then run focused
tests, the full suite, a release build, and git diff --check. Review your own
diff for regressions and security/privacy problems.

Commit intentionally, push the branch, and open a DRAFT PR with Closes #N. The
PR must contain a summary, red/green TDD evidence, exact commands/results, and
an acceptance-criteria checklist. Comment on issue #N with the PR link and
status. Leave manual-only criteria unchecked. Do not merge.
```

Add issue-specific risks to the end of this contract. For example, a clipboard
agent should be told to test migration, corruption recovery, file permissions,
in-memory clearing, privacy markers, and content-log redaction.

## Independent-review contract

Never assign the authoring agent to approve its own PR. Use a fresh clone and a
fresh agent:

```text
Independently review PR #N in OWNER/REPOSITORY as a strict code reviewer.

Use a fresh isolated clone at /private/tmp/PROJECT-review-N. Fetch main and the
exact PR head. Do not trust the PR description. Inspect the full diff against
the linked issue and every acceptance criterion.

Look for correctness, regression, concurrency, security, privacy, migration,
data-loss, lifecycle, API-availability, release, and test-coverage problems as
appropriate. Run focused tests, the full suite, a release build, and additional
safe checks relevant to the change.

Do not edit or merge. Report findings ordered by severity with exact file/line
evidence, test results, remaining manual checks, and either APPROVE or REQUEST
CHANGES. Explicitly say APPROVE only when there is no merge blocker.
```

## Review-fix loop

When a review requests changes:

1. Send the findings back to the implementation agent.
2. Require a failing regression test for each reproducible blocker.
3. Fix every blocker; do not merely update the PR description.
4. Rerun the complete verification set.
5. Push the new head and update the PR/issue.
6. Use a fresh reviewer or a new review turn against the exact new head SHA.
7. Repeat until approved.

Copy-paste fix prompt:

```text
PR #N received CHANGES REQUESTED. Fix every finding on the existing isolated
branch. Add failing regression tests first for each reproducible issue, then
implement the fixes. Run focused tests, the full suite, release build, relevant
security/static checks, and diff checks. Push the new head, update the PR and
issue, and do not merge. Report the exact head SHA and verification evidence so
a different agent can re-review it.
```

## Merge procedure

The coordinator, not the implementation agent, performs merges:

1. Confirm the PR head SHA has not changed since the approved review.
2. Confirm required CI checks are successful.
3. Confirm the PR is mergeable and has no unresolved review blockers.
4. Mark the draft PR ready for review.
5. Squash-merge using the reviewed head SHA.
6. Confirm the linked issue closed or update it with the merge result.
7. Refresh `main` before launching dependent agents.
8. Re-check remaining PRs for conflicts introduced by the merge.

Never merge when:

- the reviewer returned `REQUEST CHANGES`;
- a data-loss, privacy, release-integrity, or security concern is unresolved;
- the reviewed head SHA differs from the current PR head;
- tests are failing or missing;
- the PR claims manual checks that were not performed.

## Progress reporting format

Ask agents to report at safe boundaries rather than waiting silently:

```text
Issue/PR:
Branch and head SHA:
Stage: red | green | build | review | published
Tests added:
Focused tests:
Full tests:
Release build:
Findings/blockers:
PR/issue links:
Manual checks remaining:
```

The coordinator should give the user a short update at least once per major
stage: red tests, green implementation, draft PR, review result, fix cycle, and
merge.

## Resume after interruption

Use this prompt after a usage limit, approval failure, lost session, or other
interruption:

```text
Resume the multi-agent GitHub workflow for OWNER/REPOSITORY.

First inspect current GitHub issues, open PRs, PR head SHAs, CI state, and the
isolated directories under /private/tmp. Do not redo completed work and do not
touch my primary dirty workspace.

For each in-progress item, determine whether it is:
- implemented but awaiting independent review;
- approved but awaiting merge;
- changes requested;
- partially edited but uncommitted;
- blocked by a dependency or external/platform limit.

Continue from the latest verified boundary. Re-run tests before trusting partial
work. Never publish an incomplete branch, bypass an approval failure, or claim
manual criteria were completed. Continue dependency waves until all scoped
issues are reviewed and merged or a genuine blocker remains.
```

Before ending a blocked run, record:

- repository, issue, PR, branch, and exact head SHA;
- isolated directory path;
- committed versus uncommitted state;
- tests already run and their results;
- review findings still open;
- files or steps remaining;
- external approval/credential/usage-limit message and retry time.

## Manual invocation examples

Start three independent issues:

```text
Use the multi-agent issue-to-PR workflow in
docs/CODEX_MULTI_AGENT_WORKFLOW.md. Process issues #14, #15, and #17 in
parallel. Create draft PRs, independently review them, but stop before merging.
```

Review and merge existing PRs:

```text
Use docs/CODEX_MULTI_AGENT_WORKFLOW.md. Independently review PRs #21, #22, and
#23 in parallel. Fix blockers with regression tests. Mark ready and squash-merge
only PRs that receive independent approval. Then update their issues.
```

Continue dependency waves:

```text
Use docs/CODEX_MULTI_AGENT_WORKFLOW.md and resume from current GitHub state.
After approved PRs merge, start the next dependency-safe issues from updated
main. Continue implementation, independent review, fix cycles, and squash
merges until all scoped issues are complete.
```

Work on one issue with two-agent separation:

```text
Use docs/CODEX_MULTI_AGENT_WORKFLOW.md for issue #18. One agent implements with
TDD and opens a draft PR. A different agent independently reviews it. Fix all
blockers, but leave the approved PR unmerged for my manual review.
```

## Suggested issue and PR templates

Every implementation issue should contain:

- summary and user value;
- current behavior and evidence;
- in-scope and out-of-scope work;
- dependencies and product decisions;
- security/privacy requirements;
- suggested files;
- individually testable acceptance criteria;
- required automated and manual verification.

Every PR should contain:

- `Closes #N`;
- implementation summary;
- red-phase evidence;
- green-phase commands and results;
- acceptance checklist;
- known warnings or limitations;
- manual verification still required;
- dependency and merge-order notes.

## Final completion audit

After the final merge, ask a fresh agent or the coordinator to verify:

- every scoped issue is closed or correctly updated;
- no draft or superseded PR remains unintentionally open;
- the default branch contains every intended merge;
- repository-wide tests pass from a fresh clone;
- a release build succeeds;
- release/security/privacy policy tests pass;
- documentation matches shipped behavior;
- no credentials, generated caches, or temporary artifacts were committed;
- manual-only release and macOS permission checks are clearly handed off.

