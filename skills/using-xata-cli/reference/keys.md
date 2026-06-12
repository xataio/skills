# API Keys

Manage API keys for authentication.

## Contents

- [User API Keys](#user-api-keys)
- [Organization API Keys](#organization-api-keys)
- [Using API Keys](#using-api-keys)
- [Best Practices](#best-practices)
- [Common Issues](#common-issues)

## User API Keys

Personal API keys tied to your user account.

### List Keys

```bash
xata keys user list
```

**Alias:** `ls`

### Create Key

```bash
xata keys user create --name <name>
```

With an expiry (ISO date; omit for no expiry):

```bash
xata keys user create --name <name> --expiry 2026-12-31
```

### Delete Keys

Deletes one or more keys by ID:

```bash
xata keys user delete <key-id> [<key-id> ...]
```

## Organization API Keys

Shared API keys for organization-level access.

**Alias:** `keys org`

### List Keys

```bash
xata keys org list
```

For a specific org:

```bash
xata keys org list --organization <id>
```

### Create Key

```bash
xata keys org create --name <name>
```

For a specific org, with an expiry:

```bash
xata keys org create --name <name> --organization <id> --expiry 2026-12-31
```

### Delete Keys

```bash
xata keys org delete <key-id> [<key-id> ...]
```

## Using API Keys

### Environment Variable

Set for the CLI and SDKs:

```bash
export XATA_API_KEY=<your-key>
```

When `XATA_API_KEY` is set the CLI uses it automatically (it activates the `__env` profile).

### In a .env File

```
XATA_API_KEY=xau_xxxxxxxxxxxxx
```

### CI/CD Setup

1. Create a dedicated key:

   ```bash
   xata keys user create --name github-actions
   ```

2. Store it as a secret in your CI platform.

3. Use it in workflows:

   ```yaml
   env:
     XATA_API_KEY: ${{ secrets.XATA_API_KEY }}
   ```

## Best Practices

**Use descriptive names:** Name keys after their purpose (e.g. `github-ci`, `production-api`).

**Set an expiry:** For temporary access, pass `--expiry <iso-date>`.

**Rotate regularly:** Delete old keys and create new ones periodically.

**Org keys for shared access:** Use org keys when multiple team members or services need access.

**User keys for personal use:** Use user keys for personal development or single-user scripts.

## Common Issues

**"Invalid API key":** Verify the key is correct and free of whitespace. Regenerate if compromised.

**Key not working in CI:** Ensure `XATA_API_KEY` is set correctly and the secret is configured.

**Cannot find a key ID:** List keys with `xata keys user list` or `xata keys org list`.

**Key expired:** Create a new key. Use `--expiry` to control the lifetime.
