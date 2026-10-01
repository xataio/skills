---
name: branching-postgresql-for-agents
description: Creates isolated Xata PostgreSQL branches with realistic data to investigate bugs, build features, and validate changes. Use when a coding task needs database queries or testing without reading or writing the source or production database.
license: Apache-2.0
---

<!-- Adapted from https://github.com/xataio/frontend/blob/ae450a4543835c952b4879908057f8f9d64476d4/apps/website/public/xata-claude-skill/SKILL.md. Modified for harness-neutral use and explicit branch safety checks. -->

# Branching PostgreSQL for Agents

Fix bugs and build features against an isolated database branch with realistic data, then validate the changes on that branch.

## Prerequisites and safety

- Use any coding assistant with shell access. Require an installed, authenticated `xata` CLI and an installed `psql` client. If either is unavailable, stop and tell the user what is missing.
- Require an authenticated `gh` CLI only when the user supplies a GitHub issue or pull request. Read that context before proceeding; if it cannot be read, stop and notify the user. For example, use `gh issue view <issue-url> --comments` or `gh pr view <pr-url> --comments`.
- Never query the source or production database, even for reads. Xata control-plane commands for identifying and branching the source are allowed; SQL connections to it are not.
- Never use an inherited `DATABASE_URL` or other inherited connection settings as the database target. Never read or use `seed.sql`; inspect the isolated branch's actual data instead.
- Do not print connection strings, credentials, or sensitive query results in logs or the final response. Disable shell tracing before handling a connection string.

## 1. Establish the source explicitly

Read the task and relevant application code. Run `xata status` to inspect configured context; it does **not** establish that the current branch is production or the intended source.

Establish the exact organization ID, project ID, source branch ID, and database name from the user's intent and project configuration. Use scoped control-plane commands to resolve branch names when necessary:

```bash
xata branch list --organization <org> --project <project> --json
xata branch describe <source-id> --organization <org> --project <project> --json
```

If any target is missing or ambiguous, stop and ask the user. Do not assume `main`, the currently checked-out branch, or a default database is the correct source. Confirm authorization to create the child branch before creating resources.

## 2. Create and verify the isolated child

Choose a unique task-specific branch name. Replace all placeholders below with the established values. Run each step separately and verify its result before proceeding.

```bash
xata branch create --name <unique-name> --parent-branch <source-id> --organization <org> --project <project> --json
```

Require a successful command and a child object with a nonempty `id`, the requested `name`, and `parentID` equal to the source ID. Retain that returned `id` as `<child-id>` for every subsequent branch command; it must differ from the source ID. If creation fails or the response is missing, malformed, or inconsistent, stop. Do not fall back to an existing branch or blindly retry a creation whose outcome is unknown.

```bash
xata branch wait-ready <child-id> --organization <org> --project <project> --json
```

Require success **and** an actual JSON response whose `id` matches the retained child ID and whose `status.statusType` is `STATUS_TYPE_HEALTHY`. A hibernated branch can produce empty output with exit code zero: that is not readiness. On empty, malformed, mismatched, or unhealthy output, or any command failure, stop before checkout or database access and report the problem.

## 3. Check out and verify the effective context

Creation only checks out automatically when project context already exists. Always check out explicitly:

```bash
xata checkout <child-id> --organization <org> --project <project> --database <database>
xata status
```

Require checkout success, then verify that the effective organization, project, branch, and database reported by `xata status` match the intended organization, project, retained child ID, and database. If status displays a branch name rather than an ID, resolve it with the scoped `branch describe` command and verify its ID. If context is missing, ambiguous, or mismatched, stop; never continue against the source branch.

## 4. Obtain a checked connection string

Capture stdout from this command privately into a fresh variable such as `child_url`; check its exit status separately. Do not display the value:

```bash
xata branch url <child-id> --organization <org> --project <project> --database <database>
```

This command prints a raw connection string, even with global JSON output defaults. It can return empty output when readiness validation fails. Require success and a nonempty, valid `postgresql://` or `postgres://` URL with an explicit host and the intended database before using it. Reject malformed output, embedded extra lines, or a different database. Stop on failure; do not reuse an earlier URL or fall back to inherited connection settings.

Never nest the URL command inside `psql`: an empty URL can make libpq use default connection settings. Only after all checks above pass, use the captured child URL explicitly, for example:

```bash
psql -X --dbname="$child_url" --set=ON_ERROR_STOP=1 -c 'SELECT current_database();'
```

Require a successful connection and the intended database in the result before investigating. On failure, stop; do not try a source or production URL.

## 5. Investigate, fix, and validate

Use application code and queries against the verified child to reproduce the bug or explore the feature with realistic data. Select only the data needed for the task. Make the code changes, then run targeted queries and tests against that same child to validate the result.

Before running an application, test suite, or migration, explicitly configure its database connection to use the verified child URL and verify it cannot use inherited production settings or load `seed.sql`. If the target cannot be established, stop. Keep any task-required database writes confined to the child; never apply them to the source or production database.

Report what changed, the child branch name and ID, the checks performed, and any remaining failures, without credentials or sensitive data. Leave the branch available for review; this workflow does not archive or delete branches.

License: [Apache-2.0](LICENSE.txt).
