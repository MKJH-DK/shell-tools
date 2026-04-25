---
bee_name: shell-tools
bee_version: 1.0.0
queen_template_version: "2.0"
inherits: ../../../../AGENTS.md
---

# AGENTS.md — shell-tools

**Read the Queen's `AGENTS.md` at the vault root FIRST.**
Path: `../../../../AGENTS.md` (four levels up).

All vault-level rules apply. This file extends them with bee-specific
context and overrides.

---

## Bee identity

- **Name**: shell-tools
- **Bucket**: 01-active
- **Status**: active
- **Primary language(s)**: bash, zsh
- **One-line purpose**: Developer shell environment setup and utility tools.

## What this bee does

This bee manages a collection of scripts for setting up a modern Zsh environment, SSH configurations, and Termux-specific layout fixes. It includes an interactive TUI for easy management.

## Bee-specific rules

- **Shell Standard**: Use `bash` for logic/scripts and `zsh` for interactive components.
- **TUI**: All interactive menus must use `fzf` for selection.
- **Dependencies**: Always check for `fzf`, `micro`, and `sgpt` before running related actions.
- **Android/Termux**: Maintain compatibility with Termux filesystem paths and keys.

## Context pointers

- State: `memory/CONTEXT.md`
- Prior learnings: `memory/lessons.jsonl`
- Side observations: `memory/observations.jsonl`
- Issues: use GitHub Issues on this bee's remote.

## Invocation

Use the Queen's wrapper to ensure AGENTS.md (Queen + bee) is loaded
as system prompt:

```bash
# From inside this bee directory:
bash ../../../../02-agents/03-tools/ask.sh claude "your task"
```

## When done with a task

1. Update `memory/CONTEXT.md` (STATUS, NEXT, CHANGED)
2. Append lesson to `memory/lessons.jsonl` if non-trivial
3. Append observations if you noticed something outside task scope
4. Commit (bee has its own git).

---

## Structure (Legacy Reference)

| Path | Contents |
|------|---------|
| `index.sh` | Interactive TUI entry point (Main) |
| `scripts/` | Installation logic, utility scripts, and helpers |
| `memory/` | Bee state and lessons |

## Components (Legacy Reference)

- shell-setup: Zsh + plugins + micro + aliases
- ssh-setup: Key generation and config management
- termux: Custom keyboard layout and environment checks
