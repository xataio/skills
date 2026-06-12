---
name: using-xata-api
description: Use the Xata HTTP API to manage organizations, projects, and branches, authenticate with an API key or OAuth, get a branch connection string, and understand pagination and error conventions. Triggers when calling the Xata API directly (curl, fetch, a Postgres driver, or an SDK), scripting against api.xata.tech, or building an app that programmatically manages Xata.
---

# Using the Xata API

The Xata HTTP API manages organizations, projects, and branches. Every branch is a standard PostgreSQL database, so for queries you connect any Postgres driver with a connection string rather than going through this API.

This skill orients you to the conventions. The source of truth for exact request and response shapes is the OpenAPI spec at `https://api.xata.tech/openapi.json` and the docs at `https://xata.io/docs`. When an operation is not covered here, read those.

## Base URL and auth

- Base URL: `https://api.xata.tech`.
- Authenticate with an API key as a bearer token:

```sh
curl -H "Authorization: Bearer $XATA_API_KEY" https://api.xata.tech/organizations
```

Create API keys in the dashboard or with `xata keys create` (see the `using-xata-cli` skill). OAuth 2.0 is also supported for user-facing apps (Keycloak realm `xata`, with scopes such as `org:read`, `project:read`, `branch:write`).

## Resource model

Organizations contain projects; projects contain branches; each branch is a Postgres database. The id a list call returns is the next path segment, so you walk down the hierarchy.

```
GET  /organizations
GET  /organizations/{organizationID}/projects
GET  /organizations/{organizationID}/projects/{projectID}
GET  /organizations/{organizationID}/projects/{projectID}/branches
GET  /organizations/{organizationID}/projects/{projectID}/branches/{branchID}
GET  /organizations/{organizationID}/projects/{projectID}/branches/{branchID}/credentials
GET  /organizations/{organizationID}/regions
GET  /api-keys
```

Create with `POST` on the collection (e.g. `POST .../projects`, `POST .../branches`), and remove with `DELETE` on the item. Deleting a branch drops its database and is irreversible.

## Connecting to a branch

1. `GET .../branches/{branchID}` returns `connectionString` (and the branch `status`).
2. `GET .../branches/{branchID}/credentials?username=<user>` returns a username and password (the `username` query param is optional and defaults to the branch user).

Substitute the credentials into the connection string and connect with any Postgres driver (`postgres`, `pg`, psql). For connecting from code, see the project's TypeScript/driver examples in the docs.

## Conventions

- **Pagination:** most list endpoints take `first` (0-based offset) and `max` (default and maximum 100). Some endpoints instead use `cursor` and `limit` and return `pagination_metadata: { has_more, next_cursor }`. Loop until `has_more` is false (or fewer than `max` rows come back).
- **Errors:** a non-2xx response returns a JSON body shaped like `{ "message": "...", "code"?, "severity"?, "detail"?, "hint"? }`. Common statuses: `400` validation, `401` authentication, `403` forbidden, `404` not found, `409` conflict.
- **Safety:** `GET` is read-only and safe to retry; `POST`/`PATCH` create or modify; `DELETE` is destructive.

## Finding everything else

This skill covers the common path. The full surface (backups, metrics, logs, postgres-config, GitHub app, members and invitations, regions, IP filtering) lives in the OpenAPI spec at `https://api.xata.tech/openapi.json`. The docs site also exposes a search interface for how-to questions. When you are connected to the Xata MCP server, the popular operations above are additionally available as typed tools, so prefer those over hand-rolling HTTP when they exist.
