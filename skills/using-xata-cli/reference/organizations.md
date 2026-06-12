# Organizations

Manage organizations, members, and invitations.

**Alias:** `org` (so `xata org ...` works everywhere `xata organization ...` does).

## Contents

- [List Organizations](#list-organizations)
- [View Organization Details](#view-organization-details)
- [Create Organization](#create-organization)
- [Delete Organization](#delete-organization)
- [Members](#members)
- [Invitations](#invitations)
- [Common Patterns](#common-patterns)
- [Common Issues](#common-issues)

## List Organizations

```bash
xata org list
```

**Alias:** `ls`. JSON output with `--json`.

## View Organization Details

```bash
xata org describe
```

For a specific org (positional or `--organization`):

```bash
xata org describe <name>
xata org describe --organization <id>
```

**Aliases:** `view`, `show`

## Create Organization

```bash
xata org create
```

Pass `--name <name>` to skip the prompt.

## Delete Organization

```bash
xata org delete
```

Skip confirmation:

```bash
xata org delete --yes
```

Delete a specific org:

```bash
xata org delete --organization <id>
```

## Members

### List Members

```bash
xata org members list
```

**Alias:** `ls`. Use `--organization <id>` for a specific org.

### Invite a Member

```bash
xata org members invite --email <email>
```

**Alias:** `add`. There is no role flag; sent invitations are managed under `xata org invitations`.

### Remove a Member

Members are removed by user ID:

```bash
xata org members remove <user-id>
```

**Aliases:** `delete`, `rm`. Skip confirmation with `--force`.

## Invitations

```bash
# List pending invitations (alias: ls)
xata org invitations list

# Show one invitation (alias: show)
xata org invitations get <invitation-id>

# Create/send an invitation (aliases: add, invite)
xata org invitations create --email <email>

# Cancel an invitation (aliases: rm, remove)
xata org invitations delete <invitation-id>

# Resend an invitation
xata org invitations resend <invitation-id>
```

## Common Patterns

### Onboard a New Team Member

```bash
# Send the invite
xata org members invite --email developer@company.com

# Check pending invitations
xata org invitations list

# Resend if needed
xata org invitations resend <invitation-id>
```

### Audit Team Access

```bash
xata org members list --json | jq '.[]'
xata org invitations list
```

### Offboard a Team Member

```bash
# Find the user ID from the members list, then remove
xata org members list
xata org members remove <user-id> --force
```

## Common Issues

**"Organization not found":** Check the ID with `xata org list`. Use `--organization <id>` to specify.

**Invitation not received:** Check the spam folder, then `xata org invitations resend <invitation-id>`.

**Cannot remove member:** Verify you have admin permissions and that you are not removing the last admin.

**Wrong organization context:** Use `--organization <id>`, or switch the active account with `xata auth switch <profile>`.
