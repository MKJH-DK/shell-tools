# AGENTS.md — shell-tools

Developer shell environment tools. Merged from shell-setup + ssh-setup + askall (2026-03-27).

## Structure

| Path | Contents |
|------|---------|
| `shell-setup/` | Full zsh environment setup, multi-platform scripts |
| `ssh-setup/` | SSH bootstrap (ssh-bootstrap.sh + ssh-bootstrap.toml) |
| `scripts/askall` | Multi-AI CLI dispatcher (bash) |
| `scripts/askall-config` | Default askall config |
| `scripts/askall-install.sh` | Installs askall to PATH |
| `install.sh` | Top-level installer: `./install.sh [shell|ssh|askall|all]` |

## Notes

- shell-setup supports: Termux, Arch, Debian, Fedora, macOS, WSL, Alpine, Void
- ssh-setup: shared SSH config lives in vault, private keys stay per-device
- askall: auto-detects installed AI CLIs (claude, gemini, sgpt, codex)
