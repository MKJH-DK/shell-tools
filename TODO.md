# Project Roadmap: shell-tools

## Core Infrastructure & Environment
- [ ] **Dynamic Env Management**: Implement `setenv` function to manage variables in `~/.config/zsh/local.zsh`.
- [ ] **SSH Automation**: Script for key generation (ED25519) and `~/.ssh/config` templating.
- [ ] **Modular Zsh**: Refactor `interactive-void.zsh` into `~/.config/zsh/conf.d/*.zsh`.
- [ ] **Quick-Edit Menu**: TUI shortcuts for `sudoers`, `ssh config`, `zshrc` and `local.zsh`.
- [ ] **Local Config Sync**: Encrypted backup/restore of personal config layer to `/storage/shared`.
- [ ] **Package Mirror Helper**: Tool to switch to fastest mirrors (Termux/Arch focus).

## Shell Enhancements
- [x] **Tab Completion Upgrade**: Integrate `fzf-tab` for visual completion.
- [x] **Project Jumper (`pj`)**: `fzf`-based directory switcher filtered for `.git` repos.
- [x] **Command Analytics**: "Top 10 most used commands" report in System Info.
- [x] **Ephemeral Snippets**: Temporary command buffer for session-specific tasks.
- [x] **Fast Top 3**: completion suggestions for common commands.

## AI & Smart Tools
- [ ] **AI Pipe (`fix`)**: Send last failed command output to AI for troubleshooting.
- [ ] **Context-Aware AI**: Integration of project-specific context into `sgpt` calls.
- [ ] **AI CLI Installer Hub**: System-aware installers for `codex`, `gemini`, `claude`, `sgpt`, and related AI CLIs.
- [ ] **AI CLI Doctor**: Status checker for installed AI CLIs, versions, PATH visibility, and required env var names without exposing secret values.
- [ ] **Provider Profiles**: Shared provider/model profiles for ShellGPT and other OpenAI-compatible CLIs.
- [ ] **AI CLI Shortcuts**: Standard aliases such as `cx`, `gm`, `cl`, `ask`, `ai-status`, and `ai-install`.
- [ ] **Cross-CLI Skills Sync**: Manage reusable skills/templates for Codex (`SKILL.md`), Claude (`SKILL.md`), and Gemini CLI extensions (`gemini-extension.json`/`GEMINI.md`).
- [ ] **AI Skills Installer**: Add `ai-skills install <codex|claude|gemini> <skill>` and `ai-skills sync` for installing shared project skills into each CLI's expected location.

## Android & Termux Specifics
- [ ] **Touch/Quick Fix**: ZLE widget to open current buffer in `micro` for easier mobile editing.
- [ ] **Dashboard**: Minimalist welcome screen with battery, disk, and update status.
- [ ] **Share-to-Termux**: Handlers for Android's "Share" intent (yt-dlp, file movement).
- [ ] **Arch Infra Helpers**: Specialized scripts for Arch Linux ARM/Termux environments.

## Maintenance
- [ ] **Fast Install Path**: Streamlined one-liner for fresh environments.
- [ ] **Infrastructure Repo Helpers**: Shortcuts and automation for repo management.
