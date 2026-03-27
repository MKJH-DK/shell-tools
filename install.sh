#!/usr/bin/env bash
# shell-tools — top-level installer
# Usage: ./install.sh [shell|ssh|askall|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [shell|ssh|askall|all]"
    echo ""
    echo "  shell   — Install zsh, starship, atuin, fzf, zoxide, eza, ripgrep, bat, tmux"
    echo "  ssh     — Bootstrap SSH config across devices (Termux, WSL, Linux)"
    echo "  askall  — Install askall CLI (multi-AI prompt tool)"
    echo "  all     — Run all of the above"
    exit 1
}

run_shell() {
    echo "[shell-tools] Running shell-setup..."
    bash "$SCRIPT_DIR/shell-setup/install.sh"
}

run_ssh() {
    echo "[shell-tools] Running ssh-setup..."
    bash "$SCRIPT_DIR/ssh-setup/ssh-bootstrap.sh"
}

run_askall() {
    echo "[shell-tools] Installing askall..."
    bash "$SCRIPT_DIR/scripts/askall-install.sh"
}

case "${1:-}" in
    shell)  run_shell ;;
    ssh)    run_ssh ;;
    askall) run_askall ;;
    all)
        run_shell
        run_ssh
        run_askall
        ;;
    *)
        usage
        ;;
esac
