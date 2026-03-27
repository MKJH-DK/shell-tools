# shell-tools

Developer environment setup tools. Merged from shell-setup + ssh-setup + askall (2026-03-27).

## Tools

| Tool | Path | Purpose |
|------|------|---------|
| shell-setup | `shell-setup/` | Opinionated zsh environment (Termux, Arch, Debian, Fedora, macOS, WSL, Alpine, Void) |
| ssh-setup | `ssh-setup/` | Cross-device SSH bootstrap with shared vault config |
| askall | `scripts/askall` | Send a prompt to multiple AI CLIs in parallel and compare responses |

## Install

```bash
# Install everything
./install.sh all

# Install individual tools
./install.sh shell
./install.sh ssh
./install.sh askall
```

## shell-setup

Installs: zsh, starship, atuin, fzf, zoxide, eza, ripgrep, bat, tmux, direnv, plus CLI wrappers.

```bash
./shell-setup/install.sh
```

## ssh-setup

Bootstraps SSH config across devices. Shared config lives in the vault; private keys stay local.

```bash
./ssh-setup/ssh-bootstrap.sh [--dry-run]
```

## askall

Sends the same prompt to claude, gemini, and sgpt in parallel.

```bash
./scripts/askall "Your question here"
# Install to PATH:
./scripts/askall-install.sh
```
