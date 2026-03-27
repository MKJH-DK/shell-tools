#!/usr/bin/env bash
# index.sh - Nano-style Shell Setup
set -u # Undlad set -e i menuen for at undgå at read timeouts dræber scriptet

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Styling Constants ─────────────────────────────────────
REV='\033[7m'      # Reverse video (Black on White)
NORM='\033[0m'     # Reset
BOLD='\033[1m'
CLR='\033[2J'      # Clear screen
HOME_CSR='\033[H'  # Move cursor to top left

# ── UI Components ────────────────────────────────────────

draw_nano_screen() {
  local title="$1"
  local -n _opts=$2
  local selected=$3
  local h w
  
  # Get terminal dimensions safely
  if command -v tput >/dev/null 2>&1; then
    h=$(tput lines)
    w=$(tput cols)
  else
    h=$(stty size | cut -d' ' -f1)
    w=$(stty size | cut -d' ' -f2)
  fi
  [[ -z "$h" ]] && h=24
  [[ -z "$w" ]] && w=80

  # 1. Clear & Top Bar
  printf "${CLR}${HOME_CSR}"
  
  # Header: Truncate to fit width
  local header_text="  GNU nano setup 1.0  |  $title"
  printf "${REV}%-${w}.${w}s${NORM}\n" "$header_text"
  
  echo ""
  
  # Calculate column widths based on screen width
  # Label gets ~40% space, min 15, max 30
  local lbl_w=$(( w * 40 / 100 ))
  [[ $lbl_w -lt 15 ]] && lbl_w=15
  [[ $lbl_w -gt 30 ]] && lbl_w=30
  
  # Description gets the rest (minus margins: 1 space left, 1 gap, 1 right = 3)
  local dsc_w=$(( w - lbl_w - 3 ))
  [[ $dsc_w -lt 0 ]] && dsc_w=0

  # 2. Options List
  for i in "${!_opts[@]}"; do
    IFS='|' read -r label desc <<< "${_opts[$i]}"
    [[ -z "${desc:-}" ]] && desc=""
    
    # Truncate strings to fit allocated width
    local clean_lbl="${label:0:$lbl_w}"
    local clean_dsc="${desc:0:$dsc_w}"
    
    if [[ "$i" -eq "$selected" ]]; then
      # Selected: Reverse Video
      printf "${REV} %-*s %-*s ${NORM}\n" "$lbl_w" "$clean_lbl" "$dsc_w" "$clean_dsc"
    else
      # Normal
      printf " %-*s ${BOLD}%-*s${NORM}\n" "$lbl_w" "$clean_lbl" "$dsc_w" "$clean_dsc"
    fi
  done
  
  # 3. Footer (Stick to bottom)
  printf "\033[%d;1H" "$((h-1))" # Move to second to last line (safer on some terms)
  local footer="^X Exit  ^M Select  ↑/↓ Nav"
  printf "${REV}%-${w}.${w}s${NORM}" "$footer" # No newline at very end to prevent scroll
}

# ── Input Loop ───────────────────────────────────────────

menu_loop() {
  local title="$1"; shift
  local options=("$@")
  local selected=0
  local count="${#options[@]}"
  
  # Hide cursor
  printf "\033[?25l"
  trap 'printf "\033[?25h"; exit 0' INT TERM EXIT

  while true; do
    draw_nano_screen "$title" options "$selected"
    
    # Read key (Standard bash read)
    IFS= read -rsn1 key
    
    # Handle Escape Sequences
    if [[ "$key" == $'\e' ]]; then
       # Read next chars with timeout
       read -rsn2 -t 0.01 seq 2>/dev/null || true
       if [[ "$seq" == "[A" || "$seq" == "OA" ]]; then key="UP"; fi
       if [[ "$seq" == "[B" || "$seq" == "OB" ]]; then key="DOWN"; fi
    fi
    
    case "$key" in
      UP|k|K)
        ((selected--))
        [[ $selected -lt 0 ]] && selected=$((count - 1))
        ;;
      DOWN|j|J)
        ((selected++))
        [[ $selected -ge $count ]] && selected=0
        ;;
      "") # Enter
        printf "\033[?25h"
        return "$selected"
        ;;
      q|x|X) # Quit/Exit
        printf "\033[?25h"
        return 255
        ;;
    esac
  done
}

# ── Actions ──────────────────────────────────────────────

run_action() {
  local cmd="$1"
  local script_path="$SCRIPT_DIR/$cmd"
  
  clear
  printf "${REV} Executing: %s ${NORM}\n\n" "$cmd"
  
  if [[ -f "$script_path" ]]; then
    chmod +x "$script_path"
    bash "$script_path"
  else
    echo "Script not found."
  fi
  
  echo ""
  printf "${REV} Press Enter to continue ${NORM}"
  read -r
}

# ── Menus ────────────────────────────────────────────────

menu_install() {
  while true; do
    local opts=(
      "Full Setup|Install everything"
      "ShellGPT Setup|AI CLI tools only"
      "Micro Editor|Config only"
      "Termux Keys|Fix keyboard"
      "Reset History|Clear & Seed Zsh"
      "Back|Return to Main"
    )
    menu_loop "Install Menu" "${opts[@]}"
    case $? in
      0) run_action "install.sh" ;;
      1) run_action "setup-shellgpt.sh" ;;
      2) run_action "setup-micro-minimal.sh" ;;
      3) run_action "setup-termux-keys-layout.sh" ;;
      4) run_action "reset-zsh-history.sh" ;;
      5|255) return ;;
    esac
  done
}

menu_ai() {
  if command -v askall-config >/dev/null 2>&1; then
    clear
    askall-config
  else
    clear
    echo "askall-config not installed."
    echo ""
    echo "Install from: ~/vault/04-repos/01-active/askall/"
    echo "  cd ~/vault/04-repos/01-active/askall && ./install.sh"
    echo ""
    printf "${REV} Press Enter to continue ${NORM}"
    read -r
  fi
}

# ── Main ─────────────────────────────────────────────────

main() {
  while true; do
    local opts=(
      "Installations|Run setup scripts"
      "AI Configuration|Models & API keys"
      "System Info|View details"
      "Exit|Quit Setup"
    )
    menu_loop "Main Menu" "${opts[@]}"
    case $? in
      0) menu_install ;;
      1) menu_ai ;;
      2) 
         clear
         echo "System: $(uname -a)"
         read -r 
         ;;
      3|255)
         clear
         exit 0
         ;;
    esac
  done
}

main "$@"
