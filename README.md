# dotfiles

Personal AI agent skills — portable instruction packages for Kiro, Claude Code, Copilot, Cursor, and any tool supporting the [Agent Skills](https://agentskills.io/) open standard.

## Skills

| Skill | Description |
|-------|-------------|
| [terraform-skill](./skills/terraform-skill/) | Terraform/OpenTofu best practices — modules, testing, CI/CD, state management, and failure mode diagnosis |

## Installation

### Option 1: Using the `skills` CLI (recommended)

Install a specific skill into your project:

```bash
# Install for Kiro CLI
npx skills add mapangil/dotfiles --skill terraform-skill --agent kiro-cli

# Install globally (available in all projects)
npx skills add mapangil/dotfiles --skill terraform-skill --agent kiro-cli --global

# Install for multiple agents at once
npx skills add mapangil/dotfiles --skill terraform-skill --agent kiro-cli --agent claude-code --agent cursor
```

### Option 2: Kiro IDE — Clone into workspace `.kiro/skills/`

Copy the skill folder into your project's `.kiro/skills/` directory:

```bash
# From your project root
mkdir -p .kiro/skills
cp -r /path/to/dotfiles/skills/terraform-skill .kiro/skills/
```

Or add as a git submodule:

```bash
git submodule add https://github.com/mapangil/dotfiles.git .dotfiles
ln -s ../.dotfiles/skills/terraform-skill .kiro/skills/terraform-skill
```

### Option 3: Global installation (all Kiro workspaces)

Install once, available everywhere:

```bash
# Copy to your global Kiro skills directory
cp -r /path/to/dotfiles/skills/terraform-skill ~/.kiro/skills/

# Or symlink (stays in sync when you git pull)
ln -s /path/to/dotfiles/skills/terraform-skill ~/.kiro/skills/terraform-skill
```

## How It Works With Kiro IDE

Once installed, skills integrate with Kiro in two ways:

1. **Auto-activation** — When you ask Kiro something related to Terraform (e.g., "create a VPC module"), it automatically detects and loads the skill based on the description field.

2. **Slash command** — Type `/terraform-skill` in the Kiro chat to explicitly invoke it.

### Integration Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  YOUR PROJECT                                                │
│                                                             │
│  .kiro/                                                     │
│  ├── steering/          ← project rules (always loaded)     │
│  └── skills/                                                │
│      └── terraform-skill/   ← THIS REPO'S SKILL            │
│          ├── SKILL.md       (loaded on demand)              │
│          └── references/    (loaded when needed)            │
│                                                             │
│  OR globally:                                               │
│                                                             │
│  ~/.kiro/skills/                                            │
│  └── terraform-skill/       ← available in ALL projects    │
└─────────────────────────────────────────────────────────────┘
```

### Priority Order

1. **Workspace skills** (`.kiro/skills/`) override global skills
2. **Global skills** (`~/.kiro/skills/`) are available as fallback
3. Skills are loaded on-demand (only ~100 tokens until activated)

## Creating Your Own Skills

Each skill is a folder with a `SKILL.md` file:

```
skills/
└── my-new-skill/
    ├── SKILL.md           # Required: YAML frontmatter + instructions
    ├── scripts/           # Optional: executable scripts
    ├── references/        # Optional: reference docs (progressive disclosure)
    └── assets/            # Optional: templates, data files
```

The `SKILL.md` frontmatter:

```yaml
---
name: my-new-skill
description: "What it does. Use when [trigger conditions]."
---

# Instructions go here in Markdown...
```

## License

MIT
