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

### Create Key

```bash
xata keys user create <name>
```

With expiration:

```bash
xata keys user create <name> --expiration 90
```

### Delete Key

```bash
xata keys user delete <key-id>
```

## Organization API Keys

Shared API keys for organization-level access.

**Alias:** `keys org`

### List Keys

```bash
xata keys org list
```

For specific org:

```bash
xata keys org list --organization <id>
```

### Create Key

```bash
xata keys org create <name>
```

For specific org:

```bash
xata keys org create <name> --organization <id>
```

### Delete Key

```bash
xata keys org delete <key-id>
```

## Using API Keys

### Environment Variable

Set for CLI and SDKs:

```bash
export XATA_API_KEY=<your-key>
```

### In .env File

```
XATA_API_KEY=xau_xxxxxxxxxxxxx
```

### CI/CD Setup

1. Create a dedicated key:
   ```bash
   xata keys user create github-actions
   ```

2. Store as secret in CI platform

3. Use in workflows:
   ```yaml
   env:
     XATA_API_KEY: ${{ secrets.XATA_API_KEY }}
   ```

## Best Practices

**Use descriptive names:** Name keys after their purpose (e.g., `github-ci`, `production-api`)

**Set expiration:** For temporary access, use `--expiration` flag

**Rotate regularly:** Delete old keys and create new ones periodically

**Org keys for shared access:** Use org keys when multiple team members or services need access

**User keys for personal use:** Use user keys for personal development or single-user scripts

## Common Issues

**"Invalid API key":** Verify key is correct. Check for extra whitespace. Regenerate if compromised.

**Key not working in CI:** Ensure `XATA_API_KEY` environment variable is set correctly. Check secret configuration.

**Cannot find key ID:** List keys with `xata keys user list` or `xata keys org list` to find the ID.

**Key expired:** Create a new key with `xata keys user create <name>`. Use `--expiration` for temporary keys.
