# Organizations

Manage organizations and team members.

**Alias:** `org`

## List Organizations

```bash
xata org list
```

JSON output:

```bash
xata org list --json
```

## View Organization Details

```bash
xata org describe
```

For specific org:

```bash
xata org describe --organization <id>
```

**Aliases:** `view`, `show`

## Create Organization

```bash
xata org create <name>
```

## Delete Organization

```bash
xata org delete
```

Skip confirmation:

```bash
xata org delete --force
```

Delete specific org:

```bash
xata org delete --organization <id>
```

## Team Members

### List Members

```bash
xata org members list
```

For specific org:

```bash
xata org members list --organization <id>
```

### Invite Member

```bash
xata org members invite <email>
```

With role:

```bash
xata org members invite <email> --role <role>
```

### Remove Member

```bash
xata org members remove <email>
```

## Invitations

### List Pending Invitations

```bash
xata org invitations list
```

### Get Invitation Details

```bash
xata org invitations get <invitation-id>
```

### Create Invitation

```bash
xata org invitations create <email>
```

With role:

```bash
xata org invitations create <email> --role <role>
```

### Cancel Invitation

```bash
xata org invitations delete <invitation-id>
```

### Resend Invitation

```bash
xata org invitations resend <invitation-id>
```

## Common Patterns

### Onboard New Team Member

```bash
# Invite
xata org members invite developer@company.com --role developer

# Check pending invitations
xata org invitations list

# Resend if needed
xata org invitations resend <invitation-id>
```

### Audit Team Access

```bash
# List all members
xata org members list --json | jq '.[] | {email, role}'

# List pending invitations
xata org invitations list
```

### Offboard Team Member

```bash
xata org members remove developer@company.com
```
