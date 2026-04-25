# shell-tools

Developer environment setup tools. Merged from shell-setup + ssh-setup (2026-03-27).

## Tools

| Tool | Path | Purpose |
|------|------|---------|
| Main Entry | `index.sh` | Interactive TUI for all tools |
| Scripts | `scripts/` | Installation and utility logic |

## Install

```bash
# Run the interactive TUI
./index.sh

# Or run individual scripts directly
./scripts/install.sh all
./scripts/setup-shellgpt.sh
```

## Features

- **Shell Setup**: Opinionated Zsh environment with plugins and modern CLI tools.
- **SSH Setup**: Cross-device SSH bootstrap with shared configuration.
- **Termux Support**: Custom keyboard layouts and environment checks for Android.
- **AI Integration**: Wrapper scripts for AI CLI tools like ShellGPT.
