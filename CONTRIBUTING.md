# Contributing to Xata Skills

This guide covers how to create effective skills for this repository. The guidelines are based on [Anthropic's skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

## Packaging

This repository is an [Agent Plugins 1.0.0](https://agent-plugins.org/) package:

- Skills live exactly one level under `skills/`, as `skills/<name>/SKILL.md`. Clients do not search deeper.
- `plugin.json` has a closed schema — only `$schema`, `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, and `extensions`. Client-specific settings go under a reverse-domain key in `extensions`, never as new top-level fields.
- MCP servers are declared only in `mcp.json`, whose `$schema` version must match `plugin.json` — a mismatch makes clients drop MCP entirely. Never commit credentials in `headers` or `env`; they are visible package data.
- Bump `version` in `plugin.json` when you add, remove, or materially change a skill or server.

## Quick Start

1. Create a new directory under `skills/` with a descriptive name (prefer gerund form, e.g., `managing-postgresql`)
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`)
3. Keep SKILL.md under 500 lines - use `reference/` subdirectory for detailed content
4. Follow progressive disclosure: SKILL.md provides overview, reference files provide depth
5. Include practical examples and concise explanations (Claude already knows the basics)

## Skill Structure

```
skills/
└── my-skill/
    ├── SKILL.md              # Main instructions (loaded when triggered)
    ├── reference/            # Detailed content (loaded as needed)
    │   ├── topic-a.md
    │   └── topic-b.md
    └── scripts/              # Utility scripts (executed, not loaded)
        └── helper.py
```

### YAML Frontmatter

Every `SKILL.md` must include:

```yaml
---
name: my-skill-name
description: What the skill does and when to use it. Use when...
---
```

**Name requirements:**
- Maximum 64 characters
- Lowercase letters, numbers, and hyphens only
- Cannot start or end with a hyphen, or contain consecutive hyphens
- Must match the skill's directory name

**Description requirements:**
- Non-empty, maximum 1024 characters
- Write in third person ("Processes files..." not "I can help you...")
- Include both what the skill does AND when to use it
- Be specific with key terms for discovery

## Core Principles

### 1. Concise is Key

The context window is a shared resource. Only add context Claude doesn't already have.

**Good** (~50 tokens):
```markdown
## Extract PDF text

Use pdfplumber for text extraction:

```python
import pdfplumber
with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
```

**Bad** (~150 tokens):
```markdown
## Extract PDF text

PDF (Portable Document Format) files are a common file format that contains
text, images, and other content. To extract text from a PDF, you'll need to
use a library. There are many libraries available...
```

### 2. Set Appropriate Degrees of Freedom

Match specificity to the task's fragility:

| Freedom Level | When to Use | Example |
|--------------|-------------|---------|
| **High** | Multiple approaches valid | Code review guidelines |
| **Medium** | Preferred pattern exists | Template with parameters |
| **Low** | Operations are fragile | Exact migration commands |

### 3. Use Progressive Disclosure

SKILL.md is the overview; reference files provide depth. Claude loads additional files only when needed.

```markdown
# My Skill

## Quick start
[Essential content here]

## Advanced features
**Topic A**: See [reference/topic-a.md](reference/topic-a.md)
**Topic B**: See [reference/topic-b.md](reference/topic-b.md)
```

**Important:** Keep references one level deep from SKILL.md. Avoid nested references.

## Naming Conventions

Use **gerund form** (verb + -ing) for skill names:

**Good:**
- `processing-pdfs`
- `managing-databases`
- `testing-code`

**Avoid:**
- Vague names: `helper`, `utils`, `tools`
- Overly generic: `documents`, `data`

## Writing Effective Descriptions

The description is critical for skill discovery. Include:
1. What the skill does
2. When to use it (triggers)

**Good:**
```yaml
description: Diagnoses PostgreSQL performance issues including slow queries, high CPU, and connection problems. Use when troubleshooting database performance or investigating PostgreSQL errors.
```

**Bad:**
```yaml
description: Helps with databases
```

## Content Guidelines

### Use Workflows for Complex Tasks

Provide checklists for multi-step operations:

```markdown
## Investigation workflow

Copy this checklist:

```
- [ ] Step 1: Identify the issue
- [ ] Step 2: Gather diagnostics
- [ ] Step 3: Analyze results
- [ ] Step 4: Apply fix
- [ ] Step 5: Verify resolution
```

**Step 1: Identify the issue**
[Details...]
```

### Implement Feedback Loops

For quality-critical tasks, include validation steps:

```markdown
1. Make changes
2. **Validate immediately**: Run validation script
3. If validation fails, fix and re-validate
4. Only proceed when validation passes
```

### Avoid Time-Sensitive Information

Don't include dates that will become outdated. Use "old patterns" sections instead:

```markdown
## Current method
Use the v2 API endpoint.

## Old patterns
<details>
<summary>Legacy v1 API (deprecated)</summary>
[Historical context...]
</details>
```

### Use Consistent Terminology

Pick one term and use it throughout:
- Always "API endpoint" (not mixing with "URL", "route", "path")
- Always "field" (not mixing with "box", "element", "control")

## Patterns

### Template Pattern

Provide output templates with appropriate strictness:

```markdown
## Report structure

Use this template:

```markdown
# [Title]

## Summary
[Overview]

## Findings
- Finding 1
- Finding 2

## Recommendations
1. Recommendation 1
2. Recommendation 2
```
```

### Examples Pattern

Show input/output pairs for clarity:

```markdown
## Example 1
Input: [description]
Output: [expected result]

## Example 2
Input: [description]
Output: [expected result]
```

### Conditional Workflow Pattern

Guide through decision points:

```markdown
1. Determine the task type:
   - **Creating new?** → Follow "Creation workflow"
   - **Editing existing?** → Follow "Editing workflow"

2. Creation workflow:
   [steps...]

3. Editing workflow:
   [steps...]
```

## Reference Files

For files longer than 100 lines, include a table of contents:

```markdown
# Reference

## Contents
- Section A
- Section B
- Section C

## Section A
...
```

## Utility Scripts

Pre-made scripts are more reliable than generated code. When including scripts:

1. List required packages in SKILL.md
2. Document usage clearly
3. Make execution intent clear:
   - "Run `script.py` to process data" (execute)
   - "See `script.py` for the algorithm" (read as reference)

### Error Handling

Scripts should handle errors explicitly, not punt to Claude:

**Good:**
```python
try:
    result = process(data)
except FileNotFoundError:
    print(f"File not found, creating default")
    result = create_default()
```

**Bad:**
```python
result = open(path).read()  # Just fails
```

## Anti-Patterns to Avoid

1. **Windows-style paths**: Always use forward slashes (`reference/guide.md`)
2. **Too many options**: Provide a default, mention alternatives only when necessary
3. **Deeply nested references**: Keep one level deep from SKILL.md
4. **Voodoo constants**: Document why values were chosen
5. **Assuming tools installed**: Be explicit about dependencies

## Testing

Before submitting:

1. Test with real usage scenarios
2. Verify Claude can navigate the file structure
3. Check that descriptions trigger skill discovery correctly
4. Ensure SKILL.md stays under 500 lines

## Checklist

- [ ] Name uses gerund form and lowercase-hyphenated format
- [ ] Description includes what AND when (triggers)
- [ ] Description written in third person
- [ ] SKILL.md body under 500 lines
- [ ] Additional details in separate reference files
- [ ] No time-sensitive information
- [ ] Consistent terminology throughout
- [ ] Concrete examples (not abstract)
- [ ] File references one level deep
- [ ] Workflows have clear steps
- [ ] All file paths use forward slashes
