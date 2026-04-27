#!/usr/bin/env bash
# index.sh - Interactive Setup TUI using fzf
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Styling Constants ─────────────────────────────────────
REV='\033[7m'
NORM='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'

# ── Helpers ───────────────────────────────────────────────

log_header() {
  clear
  printf "${REV} %-78s ${NORM}\n" "  shell-tools 1.0  |  $1"
  echo ""
}

run_action() {
  local label="$1"
  local cmd="$2"
  local script_path="$SCRIPT_DIR/$cmd"
  
  clear
  printf "${REV} Executing: %s ${NORM}\n\n" "$label"
  
  if [[ -f "$script_path" ]]; then
    chmod +x "$script_path"
    bash "$script_path"
  elif [[ "$cmd" == "exit" ]]; then
    exit 0
  else
    echo "Script not found: $script_path"
  fi
  
  echo ""
  printf "${REV} Press Enter to continue ${NORM}"
  read -r
}

# ── Menus using fzf ──────────────────────────────────────

main_menu() {
  while true; do
    log_header "Main Menu"
    
    local choice
    choice=$(printf "1. Installations\n2. Config & Maintenance\n3. AI Tools\n4. System Info\n5. Exit" | fzf --height 14% --layout=reverse --border --header="Select an option:")

    case "$choice" in
      "1. Installations") install_menu ;;
      "2. Config & Maintenance") config_menu ;;
      "3. AI Tools") ai_menu ;;
      "4. System Info")
         clear
         header "System Information"
         echo "OS: $(uname -s)"
         echo "Kernel: $(uname -r)"
         echo "Architecture: $(uname -m)"
         echo "Hostname: $(hostname)"
         echo ""
         header "Top Commands"
         if [[ -r "${HISTFILE:-$HOME/.zsh_history}" ]]; then
           awk '
             {
               line=$0
               sub(/^: [0-9]+:[0-9]+;/, "", line)
               gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
               if (line == "") next
               split(line, parts, /[[:space:]]+/)
               count[parts[1]]++
             }
             END {
               for (cmd in count) print count[cmd], cmd
             }
           ' "${HISTFILE:-$HOME/.zsh_history}" 2>/dev/null | sort -rn | head -n 10
         else
           echo "No zsh history found."
         fi
         echo ""
         printf "${REV} Press Enter to continue ${NORM}"
         read -r 
         ;;
      "5. Exit"|*)
         clear
         exit 0
         ;;
    esac
  done
}

ai_menu() {
  while true; do
    log_header "AI Tools"

    local options=(
      "AI Fix Last Failure|scripts/ai-fix"
      "ShellGPT Setup|scripts/setup-shellgpt.sh"
      "Back|back"
    )

    local fzf_input=""
    for opt in "${options[@]}"; do
      fzf_input+="${opt%%|*}\n"
    done

    local selected
    selected=$(printf "$fzf_input" | fzf --height 14% --layout=reverse --border --header="Select AI tool:")

    [[ -z "$selected" || "$selected" == "Back" ]] && return

    for opt in "${options[@]}"; do
      if [[ "${opt%%|*}" == "$selected" ]]; then
        run_action "$selected" "${opt#*|}"
        break
      fi
    done
  done
}

config_menu() {
  while true; do
    log_header "Config & Maintenance"

    local options=(
      "Quick Edit Configs|scripts/quick-edit"
      "Environment Check|scripts/env-check"
      "Update shell-tools|scripts/tool-update"
      "SSH Setup|scripts/ssh-setup"
      "Config Sync|scripts/config-sync"
      "Mirror Helper|scripts/mirror-helper"
      "Reset History|scripts/reset-zsh-history.sh"
      "Back|back"
    )

    local fzf_input=""
    for opt in "${options[@]}"; do
      fzf_input+="${opt%%|*}\n"
    done

    local selected
    selected=$(printf "$fzf_input" | fzf --height 18% --layout=reverse --border --header="Select tool:")

    [[ -z "$selected" || "$selected" == "Back" ]] && return

    for opt in "${options[@]}"; do
      if [[ "${opt%%|*}" == "$selected" ]]; then
        run_action "$selected" "${opt#*|}"
        break
      fi
    done
  done
}

install_menu() {
  while true; do
    log_header "Installations"
    
    local options=(
      "Full Setup|scripts/install.sh"
      "ShellGPT Setup|scripts/setup-shellgpt.sh"
      "Micro Editor|scripts/setup-micro-minimal.sh"
      "Termux Keys|scripts/setup-termux-keys-layout.sh"
      "Reset History|scripts/reset-zsh-history.sh"
      "Back|back"
    )

    local fzf_input=""
    for opt in "${options[@]}"; do
      fzf_input+="${opt%%|*}\n"
    done

    local selected
    selected=$(printf "$fzf_input" | fzf --height 15% --layout=reverse --border --header="Select setup script:")

    [[ -z "$selected" || "$selected" == "Back" ]] && return

    # Find the corresponding command
    for opt in "${options[@]}"; do
      if [[ "${opt%%|*}" == "$selected" ]]; then
        run_action "$selected" "${opt#*|}"
        break
      fi
    done
  done
}

header() {
  printf "${BOLD}${CYAN}── %s ──${NORM}\n" "$*"
}

# ── Start ────────────────────────────────────────────────

if ! command -v fzf >/dev/null 2>&1; then
  echo "Error: fzf is not installed. Please install it first."
  exit 1
fi

main_menu "$@"
