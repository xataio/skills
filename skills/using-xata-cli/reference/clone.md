# Database Cloning

Clone databases with optional anonymization.

## Contents

- [Overview](#overview)
- [Generate Configuration](#generate-configuration)
- [Start Clone](#start-clone)
- [Validate Clone](#validate-clone)
- [Configuration File Format](#configuration-file-format)
- [Common Patterns](#common-patterns)
- [Common Issues](#common-issues)

## Overview

Xata clone allows you to:
- Copy database structure and data between branches
- Anonymize sensitive data during copy
- Generate anonymization configs with AI assistance

## Generate Configuration

Interactive mode:

```bash
xata clone config
```

AI-assisted mode (generates anonymization rules automatically):

```bash
xata clone config --mode ai
```

This creates a configuration file defining:
- Tables to include/exclude
- Columns to anonymize
- Anonymization strategies (fake data, masking, etc.)

## Start Clone

```bash
xata clone start \
  --source <source-branch> \
  --target <target-branch> \
  --config <config-file>
```

### Options

| Option       | Description                           |
| ------------ | ------------------------------------- |
| `--source`   | Source branch to clone from           |
| `--target`   | Target branch to clone to             |
| `--config`   | Path to configuration file            |
| `--copy-roles` | Also copy database roles            |

### Example

```bash
xata clone start \
  --source production \
  --target staging \
  --config anonymize.json \
  --copy-roles
```

## Validate Clone

Stream and validate data during clone:

```bash
xata clone stream --validate
```

## Configuration File Format

Example `anonymize.json`:

```json
{
  "tables": {
    "users": {
      "columns": {
        "email": { "strategy": "fake_email" },
        "phone": { "strategy": "mask", "keep_last": 4 },
        "name": { "strategy": "fake_name" }
      }
    },
    "audit_logs": {
      "exclude": true
    }
  }
}
```

### Anonymization Strategies

| Strategy      | Description                              |
| ------------- | ---------------------------------------- |
| `fake_email`  | Generate fake email address              |
| `fake_name`   | Generate fake name                       |
| `fake_phone`  | Generate fake phone number               |
| `mask`        | Mask characters (e.g., `****1234`)       |
| `null`        | Replace with NULL                        |
| `constant`    | Replace with constant value              |

## Common Patterns

### Production to Staging

```bash
# Generate anonymization config
xata clone config --mode ai

# Review and edit config
# ... edit anonymize.json ...

# Clone with anonymization
xata clone start \
  --source production \
  --target staging \
  --config anonymize.json
```

### Development Copy (No Anonymization)

```bash
xata clone start \
  --source staging \
  --target dev-feature
```

## Common Issues

**Clone stuck:** Check progress with `xata clone stream`

**Data mismatch:** Validate with `xata clone stream --validate`

**Missing tables:** Check config file for `"exclude": true` on tables

**Invalid anonymization strategy:** Verify strategy name matches supported options (fake_email, fake_name, mask, null, constant)

**Source branch not found:** Verify branch name with `xata branch list`. Check project context with `xata status`.

**Target branch already exists:** Delete existing branch first or use a different name
