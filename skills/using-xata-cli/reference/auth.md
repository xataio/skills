# Authentication

Manage Xata authentication and user profiles.

`xata auth` subcommands accept a `--profile <name>` flag. This is the only group where `--profile` is available; for all other commands the active profile (set by `xata auth switch`) is used.

## Login

Device flow authentication (opens browser):

```bash
xata auth login
```

Log in to a specific profile:

```bash
xata auth login --profile work
```

Force a new login even if already authenticated:

```bash
xata auth login --force
```

For a custom (self-hosted) environment, `login` also accepts `--issuer`, `--api-base-url`, `--client-id`, and `--client-secret`.

## Check Status

```bash
xata auth status
```

Shows the active account and authentication state. Check a specific profile with `--profile <name>`.

## Multiple Profiles

Xata CLI supports multiple authenticated profiles for different accounts or environments.

### List Profiles

```bash
xata auth list
```

**Alias:** `ls`

### Switch the Active Profile

```bash
xata auth switch <profile-name>
```

This sets which profile every other command uses (there is no per-command `--profile` flag outside the `auth` group).

## Logout

```bash
xata auth logout
```

Logout from a specific profile:

```bash
xata auth logout --profile work
```

## Token Management

### Print Access Token

For scripts or CI/CD:

```bash
xata auth access-token
```

Use `--profile <name>` to target a specific profile.

### Print/Refresh the Refresh Token

```bash
xata auth refresh-token
```

## CI/CD Authentication

For CI environments, use an API key instead of the device flow:

1. Create an API key: `xata keys user create --name ci-key`
2. Export it: `export XATA_API_KEY=<key>`
3. Commands pick up the key automatically (it activates the `__env` profile).

## Common Issues

**"You are logged out":** Run `xata auth login`.

**Wrong account:** Check `xata auth status`, then `xata auth switch <profile>` (or log in to a new profile).

**Token expired:** Run `xata auth login` again.
