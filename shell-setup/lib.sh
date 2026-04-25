#!/usr/bin/env zsh

# Centralized logging
log() { echo -e "\e[32m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

# OS Detection
get_os() {
    if [[ -f /etc/alpine-release ]]; then echo "alpine";
    elif [[ -f /etc/debian_version ]]; then echo "debian";
    elif [[ -f /etc/fedora-release ]]; then echo "fedora";
    elif [[ "$OSTYPE" == "darwin"* ]]; then echo "macos";
    else echo "unknown"; fi
}
