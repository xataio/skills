# Authentication

Manage Xata authentication and user profiles.

## Login

Device flow authentication (opens browser):

```bash
xata auth login
```

With a specific profile:

```bash
xata auth login --profile work
```

## Check Status

```bash
xata auth status
```

Output shows current profile, user email, and token expiration.

## Multiple Profiles

Xata CLI supports multiple authenticated profiles for different accounts or environments.

### List Profiles

```bash
xata auth list
```

### Switch Profile

```bash
xata auth switch <profile-name>
```

### Use Profile for Single Command

```bash
xata branch list --profile work
```

## Logout

```bash
xata auth logout
```

Logout from specific profile:

```bash
xata auth logout --profile work
```

## Token Management

### Get Access Token

For scripts or CI/CD:

```bash
xata auth access-token
```

### Refresh Token

```bash
xata auth refresh-token
```

## CI/CD Authentication

For CI environments, use API keys instead of device flow:

1. Create an API key: `xata keys user create ci-key`
2. Set environment variable: `XATA_API_KEY=<key>`
3. Commands will use the API key automatically

## Common Issues

**"Not authenticated"**: Run `xata auth login`

**Wrong account**: Check `xata auth status`, then `xata auth switch <profile>` or login with different profile

**Token expired**: Run `xata auth refresh-token` or `xata auth login` again
