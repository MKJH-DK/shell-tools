#!/usr/bin/env bash
# ssh-bootstrap.sh - Cross-device SSH bootstrap for Termux, WSL, and Linux.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_PATH="$SCRIPT_DIR/ssh-bootstrap.toml"
MANAGED_BLOCK_START="# >>> ssh-setup managed block >>>"
MANAGED_BLOCK_END="# <<< ssh-setup managed block <<<"

declare -A CFG_RAW

CONFIG_PATH="$DEFAULT_CONFIG_PATH"
CLI_DRY_RUN=""
CLI_PRINT_PUBLIC_KEY=""
CLI_NO_CLEANUP=""

log() { printf '[OK] %s\n' "$*"; }
info() { printf '[..] %s\n' "$*"; }
warn() { printf '[!!] %s\n' "$*" >&2; }
die() { printf '[!!] %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

run_with_privilege() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    run_cmd "$@"
  elif have sudo; then
    run_cmd sudo "$@"
  elif have doas; then
    run_cmd doas "$@"
  else
    die "Privilege escalation is required for: $*"
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_quotes() {
  local value="$1"
  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  fi
  value="${value//\\\"/\"}"
  value="${value//\\\\/\\}"
  printf '%s' "$value"
}

expand_template() {
  local value="$1"
  local windows_user="${WINDOWS_USER:-}"
  local vault_dir="${VAULT_DIR:-}"
  value="${value/#\~/$HOME}"
  value="${value//\$\{HOME\}/$HOME}"
  value="${value//\$\{USER\}/${USER:-}}"
  value="${value//\$\{WINDOWS_USER\}/$windows_user}"
  value="${value//\$\{VAULT_DIR\}/$vault_dir}"
  printf '%s' "$value"
}

cfg_raw() {
  local key="$1"
  local default_value="${2:-}"
  if [[ -n "${CFG_RAW[$key]+x}" ]]; then
    printf '%s' "${CFG_RAW[$key]}"
  else
    printf '%s' "$default_value"
  fi
}

cfg_string() {
  local key="$1"
  local default_value="${2:-}"
  local raw
  raw="$(cfg_raw "$key" "$default_value")"
  raw="$(trim "$raw")"
  raw="$(strip_quotes "$raw")"
  if [[ -z "$raw" ]]; then
    raw="$default_value"
  fi
  expand_template "$raw"
}

cfg_bool() {
  local key="$1"
  local default_value="${2:-false}"
  local raw
  raw="$(trim "$(cfg_raw "$key" "$default_value")")"
  raw="${raw,,}"
  case "$raw" in
    true|yes|1) printf 'true' ;;
    false|no|0|'') printf 'false' ;;
    *) die "Invalid boolean for $key: $raw" ;;
  esac
}

cfg_int() {
  local key="$1"
  local default_value="${2:-0}"
  local raw
  raw="$(trim "$(cfg_raw "$key" "$default_value")")"
  [[ "$raw" =~ ^[0-9]+$ ]] || die "Invalid integer for $key: $raw"
  printf '%s' "$raw"
}

cfg_array_values() {
  local key="$1"
  local raw body item
  raw="$(trim "$(cfg_raw "$key" "[]")")"
  [[ "$raw" == \[*\] ]] || return 0
  body="${raw#[}"
  body="${body%]}"
  body="$(trim "$body")"
  [[ -z "$body" ]] && return 0

  while IFS= read -r item; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    item="${item%,}"
    item="$(strip_quotes "$item")"
    expand_template "$item"
    printf '\n'
  done < <(printf '%s\n' "$body" | tr ',' '\n')
}

file_exists() {
  local path="$1"
  [[ -f "$path" ]]
}

parse_toml() {
  local file="$1"
  local line current_section key value full_key

  [[ -f "$file" ]] || die "Config file not found: $file"

  current_section=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      continue
    fi

    [[ "$line" =~ ^([A-Za-z0-9_.-]+)[[:space:]]*=[[:space:]]*(.+)$ ]] || die "Unsupported TOML line: $line"
    key="${BASH_REMATCH[1]}"
    value="$(trim "${BASH_REMATCH[2]}")"
    full_key="$key"
    if [[ -n "$current_section" ]]; then
      full_key="$current_section.$key"
    fi
    CFG_RAW["$full_key"]="$value"
  done < "$file"
}

usage() {
  cat <<'EOF'
Usage: ./ssh-bootstrap.sh [options]

Options:
  --config PATH          Use a specific TOML config file.
  --dry-run              Print planned actions without writing files.
  --print-public-key     Print the device public key at the end.
  --no-print-public-key  Do not print the device public key.
  --no-cleanup           Skip the interactive cleanup phase.
  -h, --help             Show this help.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        [[ $# -ge 2 ]] || die "--config requires a path"
        CONFIG_PATH="$2"
        shift 2
        ;;
      --dry-run)
        CLI_DRY_RUN="true"
        shift
        ;;
      --print-public-key)
        CLI_PRINT_PUBLIC_KEY="true"
        shift
        ;;
      --no-print-public-key)
        CLI_PRINT_PUBLIC_KEY="false"
        shift
        ;;
      --no-cleanup)
        CLI_NO_CLEANUP="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

detect_environment() {
  if [[ "$(cfg_bool "auto_detect_environment" "true")" == "false" ]]; then
    local manual_env
    manual_env="$(cfg_string "environment" "")"
    [[ -n "$manual_env" ]] || die "auto_detect_environment=false requires environment in the config"
    printf '%s' "$manual_env"
    return 0
  fi

  if [[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" == *com.termux* ]]; then
    printf 'termux'
  elif [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    printf 'wsl'
  else
    printf 'linux'
  fi
}

discover_windows_user() {
  local candidate

  if [[ -n "${WINDOWS_USER:-}" ]]; then
    printf '%s' "$WINDOWS_USER"
    return 0
  fi

  if [[ -n "${USERPROFILE:-}" ]] && [[ "$USERPROFILE" =~ [\\/]+Users[\\/]+([^\\/]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ -d "/mnt/c/Users/${USER:-}" ]]; then
    printf '%s' "${USER:-}"
    return 0
  fi

  for candidate in /mnt/c/Users/*; do
    [[ -d "$candidate" ]] || continue
    candidate="$(basename "$candidate")"
    if [[ -d "/mnt/c/Users/$candidate/Desktop/mkjh/vault" ]] || [[ -d "/mnt/c/Users/$candidate/Desktop/mkjh vault" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  printf ''
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

ensure_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    return 0
  fi
  info "Creating directory: $path"
  run_cmd mkdir -p "$path"
}

set_mode_if_exists() {
  local mode="$1"
  local path="$2"
  [[ -e "$path" ]] || return 0
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] chmod %s %s\n' "$mode" "$path"
    return 0
  fi
  chmod "$mode" "$path" 2>/dev/null || warn "Could not set mode $mode on $path"
}

backup_file() {
  local path="$1"
  local stamp backup_path
  [[ -f "$path" ]] || return 0
  stamp="$(date '+%Y%m%d-%H%M%S')"
  backup_path="${path}.bak.${stamp}"
  info "Backing up $path -> $backup_path"
  run_cmd cp "$path" "$backup_path"
}

ensure_openssh_tools() {
  if have ssh && have ssh-keygen; then
    return 0
  fi

  if [[ "$(cfg_bool "auto_install_openssh" "false")" != "true" ]]; then
    die "OpenSSH tools are missing. Install ssh/ssh-keygen or set auto_install_openssh=true."
  fi

  info "OpenSSH tools missing. Attempting package installation."
  case "$ENVIRONMENT" in
    termux)
      have pkg || die "pkg not available. Install OpenSSH manually."
      run_cmd pkg install -y openssh
      ;;
    wsl|linux)
      if have pacman; then
        run_with_privilege pacman -Sy --noconfirm --needed openssh
      elif have apt-get; then
        run_with_privilege apt-get update
        run_with_privilege apt-get install -y openssh-client
      elif have apk; then
        run_with_privilege apk add openssh-client
      else
        die "No supported package manager found for OpenSSH auto-install."
      fi
      ;;
    *)
      die "Unsupported environment for OpenSSH auto-install: $ENVIRONMENT"
      ;;
  esac
}

find_vault_dir() {
  local manual_vault shared_path candidate
  manual_vault="$(cfg_string "vault_dir" "")"
  if [[ -n "$manual_vault" ]]; then
    [[ -d "$manual_vault" ]] || die "Configured vault_dir does not exist: $manual_vault"
    printf '%s' "$manual_vault"
    return 0
  fi

  shared_path="$(cfg_string "shared_config_path" "")"
  if [[ -n "$shared_path" ]]; then
    candidate="$(cd "$(dirname "$shared_path")/.." 2>/dev/null && pwd)" || true
    if [[ -n "$candidate" && -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  fi

  if [[ "$(cfg_bool "auto_detect_vault" "true")" != "true" ]]; then
    die "vault_dir is empty and auto_detect_vault=false"
  fi

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done < <(cfg_array_values "search_paths.$ENVIRONMENT.vault_roots")

  if [[ "$ENVIRONMENT" == "wsl" ]]; then
    for candidate in "/mnt/c/Users"/*/Desktop/mkjh/vault "/mnt/c/Users"/*/Desktop/mkjh\ vault "/mnt/c/Users"/*/Documents/mkjh/vault "/mnt/c/Users"/*/Documents/mkjh\ vault; do
      [[ -d "$candidate" ]] || continue
      printf '%s' "$candidate"
      return 0
    done
  fi

  die "Could not detect a vault directory. Set vault_dir in ssh-bootstrap.toml."
}

build_shared_config_content() {
  cat <<EOF
$MANAGED_BLOCK_START
# Managed by ssh-bootstrap.sh.
# Private keys stay local on each device.

Host *
  ServerAliveInterval $SERVER_ALIVE_INTERVAL
  ServerAliveCountMax $SERVER_ALIVE_COUNT_MAX
  TCPKeepAlive $TCP_KEEPALIVE_TEXT

Host $GITHUB_ALIAS
  HostName $GITHUB_HOSTNAME
  User $GITHUB_USER
  IdentityFile "$GITHUB_KEY"
  IdentitiesOnly yes

Host $ARCH_ALIAS
  HostName $ARCH_HOSTNAME
  User $ARCH_USER
  IdentityFile "$ARCH_KEY"
  IdentitiesOnly yes
  ServerAliveInterval $SERVER_ALIVE_INTERVAL
  ServerAliveCountMax $SERVER_ALIVE_COUNT_MAX
  TCPKeepAlive $TCP_KEEPALIVE_TEXT
$MANAGED_BLOCK_END
EOF
}

merge_shared_config_content() {
  local existing_content="$1"
  local managed_block="$2"
  local merged_content

  if [[ "$existing_content" == *"$MANAGED_BLOCK_START"* ]] && [[ "$existing_content" == *"$MANAGED_BLOCK_END"* ]]; then
    merged_content="$existing_content"
    merged_content="${merged_content%%"$MANAGED_BLOCK_START"*}"
    merged_content+="$managed_block"
    merged_content+="${existing_content#*"$MANAGED_BLOCK_END"}"
    printf '%s\n' "$merged_content"
    return 0
  fi

  if [[ -n "$(trim "$existing_content")" ]]; then
    printf '%s\n\n%s\n' "$existing_content" "$managed_block"
  else
    printf '%s\n' "$managed_block"
  fi
}

build_bootstrap_config_content() {
  cat <<EOF
# Generated by ssh-bootstrap.sh.
IgnoreUnknown Include
Include "${EFFECTIVE_SHARED_CONFIG_PATH:-$SHARED_CONFIG_PATH}"
Include "$LOCAL_OVERRIDE_DIR/*.conf"
EOF
}

write_file_if_needed() {
  local path="$1"
  local content="$2"
  local backup_on_change="$3"
  local allow_overwrite="$4"
  local temp_file

  temp_file="$(mktemp)"
  printf '%s\n' "$content" > "$temp_file"

  if [[ -f "$path" ]] && cmp -s "$temp_file" "$path"; then
    info "No change needed: $path"
    rm -f "$temp_file"
    return 0
  fi

  if [[ -f "$path" && "$allow_overwrite" != "true" ]]; then
    warn "Skipping existing file because overwrite is disabled: $path"
    rm -f "$temp_file"
    return 0
  fi

  if [[ -f "$path" && "$backup_on_change" == "true" ]]; then
    backup_file "$path"
  fi

  info "Writing file: $path"
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] write %s\n' "$path"
    rm -f "$temp_file"
    return 0
  fi

  cp "$temp_file" "$path" && rm -f "$temp_file"
}

manage_shared_config_file() {
  local desired_block existing_content merged_content
  desired_block="$(build_shared_config_content)"

  if [[ ! -f "$SHARED_CONFIG_PATH" ]]; then
    if [[ "$CREATE_SHARED_CONFIG_IF_MISSING" == "true" ]]; then
      write_file_if_needed "$SHARED_CONFIG_PATH" "$desired_block" "false" "true"
    elif [[ "$SHARED_CONFIG_ONLY_IF_MISSING" == "true" ]]; then
      warn "Shared config is missing and creation is disabled: $SHARED_CONFIG_PATH"
    fi
  else
    if [[ "$MANAGE_EXISTING_SHARED_CONFIG" == "true" ]]; then
      existing_content="$(<"$SHARED_CONFIG_PATH")"
      merged_content="$(merge_shared_config_content "$existing_content" "$desired_block")"
      write_file_if_needed \
        "$SHARED_CONFIG_PATH" \
        "$merged_content" \
        "$BACKUP_EXISTING_CONFIG" \
        "true"
    else
      info "Shared config already exists and management is disabled: $SHARED_CONFIG_PATH"
    fi
  fi

  # Ensure the effective local copy is in sync for environments with restrictive permissions (like Termux)
  if [[ "$EFFECTIVE_SHARED_CONFIG_PATH" != "$SHARED_CONFIG_PATH" ]]; then
    if [[ -f "$SHARED_CONFIG_PATH" ]]; then
      write_file_if_needed "$EFFECTIVE_SHARED_CONFIG_PATH" "$(<"$SHARED_CONFIG_PATH")" "false" "true"
    fi
  fi
}

create_local_key_if_missing() {
  local key_dir key_comment
  key_dir="$(dirname "$EFFECTIVE_KEY_PATH")"
  ensure_dir "$key_dir"
  set_mode_if_exists 700 "$key_dir"

  if [[ -f "$EFFECTIVE_KEY_PATH" ]]; then
    info "Local SSH key already exists: $EFFECTIVE_KEY_PATH"
    return 0
  fi

  key_comment="${DEVICE_NAME:-$(hostname 2>/dev/null || printf '%s' "$USER")}"
  key_comment="${key_comment}-${ENVIRONMENT}"

  info "Generating local SSH key: $EFFECTIVE_KEY_PATH"
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] ssh-keygen -t ed25519 -f %s -N "" -C %s\n' "$EFFECTIVE_KEY_PATH" "$key_comment"
    return 0
  fi

  ssh-keygen -t ed25519 -f "$EFFECTIVE_KEY_PATH" -N "" -C "$key_comment" >/dev/null
}

find_existing_key_candidate() {
  local candidate

  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    if file_exists "$candidate"; then
      printf '%s' "$candidate"
      return 0
    fi
  done < <(cfg_array_values "existing_keys.candidates")

  printf ''
}

ensure_public_key_exists() {
  local key_path="$1"
  local pub_path="${key_path}.pub"

  if [[ -f "$pub_path" ]]; then
    return 0
  fi

  info "Public key missing for $key_path. Generating $pub_path"
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] ssh-keygen -y -f %s > %s\n' "$key_path" "$pub_path"
    return 0
  fi

  ssh-keygen -y -f "$key_path" > "$pub_path"
}

resolve_effective_key_path() {
  local existing_key

  if file_exists "$LOCAL_KEY_PATH"; then
    EFFECTIVE_KEY_PATH="$LOCAL_KEY_PATH"
    KEY_SOURCE="configured"
    return 0
  fi

  if [[ "$(cfg_bool "prefer_existing_keys" "true")" == "true" ]]; then
    existing_key="$(find_existing_key_candidate)"
    if [[ -n "$existing_key" ]]; then
      EFFECTIVE_KEY_PATH="$existing_key"
      KEY_SOURCE="existing"
      info "Adopting existing SSH key: $EFFECTIVE_KEY_PATH"
      return 0
    fi
  fi

  if [[ "$(cfg_bool "generate_key_if_missing" "true")" == "true" ]]; then
    EFFECTIVE_KEY_PATH="$LOCAL_KEY_PATH"
    KEY_SOURCE="generated"
    return 0
  fi

  die "No usable SSH key found. Set local_key_path, add an existing key candidate, or allow key generation."
}

validate_private_key_path() {
  local key_path="$1"
  case "$ENVIRONMENT" in
    termux)
      case "$key_path" in
        /storage/*|/sdcard/*)
          die "SSH key path points to shared Android storage. Keep private keys under the Termux home directory."
          ;;
      esac
      ;;
  esac
}

prompt_yn() {
  local prompt="$1"
  local default="${2:-n}"
  local reply
  if [[ "$default" == "y" ]]; then
    printf '%s [Y/n] ' "$prompt"
  else
    printf '%s [y/N] ' "$prompt"
  fi
  read -r reply </dev/tty
  reply="${reply,,}"
  if [[ -z "$reply" ]]; then
    reply="$default"
  fi
  [[ "$reply" == "y" || "$reply" == "yes" ]]
}

MOVE_KEY_RESULT=""

move_key_to_dir() {
  local src="$1"
  local dest_dir="$2"
  local name dest
  name="$(basename "$src")"
  dest="$dest_dir/$name"
  MOVE_KEY_RESULT=""

  if [[ "$src" == "$dest" ]]; then
    return 0
  fi
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ -f "$dest" ]]; then
    warn "Target already exists, skipping: $dest"
    return 1
  fi

  run_cmd mv "$src" "$dest"
  log "Moved $src -> $dest"

  # Move public key too
  if [[ -f "${src}.pub" ]]; then
    run_cmd mv "${src}.pub" "${dest}.pub"
    log "Moved ${src}.pub -> ${dest}.pub"
  fi

  MOVE_KEY_RESULT="$dest"
}

cleanup_phase() {
  local ssh_dir keys_dir
  ssh_dir="$(dirname "$LOCAL_BOOTSTRAP_CONFIG_PATH")"
  keys_dir="$ssh_dir/keys"

  printf '\n--- Cleanup ---\n'

  # 1. Offer to move keys into ~/.ssh/keys/
  local keys_to_move=()
  local key_labels=()
  for key_path in "$GITHUB_KEY" "$ARCH_KEY"; do
    [[ -f "$key_path" ]] || continue
    # Skip if already in keys dir
    case "$key_path" in "$keys_dir"/*) continue ;; esac
    # Skip duplicates
    local already=false
    for existing in "${keys_to_move[@]+"${keys_to_move[@]}"}"; do
      [[ "$existing" == "$key_path" ]] && already=true
    done
    $already && continue
    keys_to_move+=("$key_path")
  done

  if [[ ${#keys_to_move[@]} -gt 0 ]]; then
    info "Keys outside $keys_dir:"
    for kp in "${keys_to_move[@]}"; do
      printf '  %s\n' "$kp"
    done
    if prompt_yn "Move these keys to $keys_dir?"; then
      ensure_dir "$keys_dir"
      set_mode_if_exists 700 "$keys_dir"
      for kp in "${keys_to_move[@]}"; do
        move_key_to_dir "$kp" "$keys_dir" || continue
        [[ -n "$MOVE_KEY_RESULT" ]] || continue
        # Update in-memory paths so shared config gets regenerated
        [[ "$kp" == "$GITHUB_KEY" ]] && GITHUB_KEY="$MOVE_KEY_RESULT"
        [[ "$kp" == "$ARCH_KEY" ]] && ARCH_KEY="$MOVE_KEY_RESULT"
        [[ "$kp" == "$EFFECTIVE_KEY_PATH" ]] && EFFECTIVE_KEY_PATH="$MOVE_KEY_RESULT"
        set_mode_if_exists 600 "$MOVE_KEY_RESULT"
        set_mode_if_exists 644 "${MOVE_KEY_RESULT}.pub"
      done
      # Regenerate configs with updated paths
      info "Regenerating configs with updated key paths..."
      manage_shared_config_file
      write_file_if_needed \
        "$LOCAL_BOOTSTRAP_CONFIG_PATH" \
        "$(build_bootstrap_config_content)" \
        "false" \
        "true"
    fi
  fi

  # 2. Offer to remove backup config files
  local bak_files=()
  while IFS= read -r -d '' f; do
    bak_files+=("$f")
  done < <(find "$ssh_dir" -maxdepth 1 -name '*.bak.*' -print0 2>/dev/null)

  if [[ ${#bak_files[@]} -gt 0 ]]; then
    info "Backup config files found:"
    for f in "${bak_files[@]}"; do
      printf '  %s\n' "$f"
    done
    if prompt_yn "Delete these backup files?"; then
      for f in "${bak_files[@]}"; do
        run_cmd rm "$f"
        log "Deleted $f"
      done
    fi
  fi

  # 3. Offer to remove known_hosts.old
  local kh_old="$ssh_dir/known_hosts.old"
  if [[ -f "$kh_old" ]]; then
    if prompt_yn "Delete $kh_old?"; then
      run_cmd rm "$kh_old"
      log "Deleted $kh_old"
    fi
  fi
}

summarize() {
  printf '\n'
  log "Environment: $ENVIRONMENT"
  log "Vault directory: $VAULT_DIR"
  log "Shared config (source): $SHARED_CONFIG_PATH"
  log "Shared config (effective): $EFFECTIVE_SHARED_CONFIG_PATH"
  log "Bootstrap config: $LOCAL_BOOTSTRAP_CONFIG_PATH"
  log "Configured key path: $LOCAL_KEY_PATH"
  log "Effective key path: $EFFECTIVE_KEY_PATH"
  log "Key source: $KEY_SOURCE"

  if [[ "$PRINT_PUBLIC_KEY" == "true" ]]; then
    printf '\nPublic key:\n'
    if [[ "$DRY_RUN" == "true" ]]; then
      printf '[dry-run] cat %s.pub\n' "$EFFECTIVE_KEY_PATH"
    elif [[ -f "${EFFECTIVE_KEY_PATH}.pub" ]]; then
      cat "${EFFECTIVE_KEY_PATH}.pub"
    else
      warn "Public key file missing: ${EFFECTIVE_KEY_PATH}.pub"
    fi
  fi
}

main() {
  parse_args "$@"
  parse_toml "$CONFIG_PATH"

  ENVIRONMENT="$(detect_environment)"
  if [[ "$ENVIRONMENT" == "wsl" ]]; then
    WINDOWS_USER="$(discover_windows_user)"
    export WINDOWS_USER
  fi

  DRY_RUN="$(cfg_bool "dry_run" "false")"
  PRINT_PUBLIC_KEY="$(cfg_bool "print_public_key" "true")"
  if [[ -n "$CLI_DRY_RUN" ]]; then
    DRY_RUN="$CLI_DRY_RUN"
  fi
  if [[ -n "$CLI_PRINT_PUBLIC_KEY" ]]; then
    PRINT_PUBLIC_KEY="$CLI_PRINT_PUBLIC_KEY"
  fi

  VAULT_DIR="$(find_vault_dir)"
  export VAULT_DIR
  SHARED_CONFIG_PATH="$(cfg_string "shared_config_path" "$VAULT_DIR/_ssh/shared.conf")"
  EFFECTIVE_SHARED_CONFIG_PATH="$SHARED_CONFIG_PATH"

  if [[ "$ENVIRONMENT" == "termux" ]]; then
    case "$SHARED_CONFIG_PATH" in
      /storage/*|/sdcard/*|*/storage/shared/*)
        EFFECTIVE_SHARED_CONFIG_PATH="$HOME/.ssh/shared.conf"
        info "Termux detected: using local copy of shared config for SSH permissions: $EFFECTIVE_SHARED_CONFIG_PATH"
        ;;
    esac
  fi

  LOCAL_KEY_PATH="$(cfg_string "local_key_path" "~/.ssh/keys/id_ed25519_default")"
  LOCAL_BOOTSTRAP_CONFIG_PATH="$(cfg_string "local_bootstrap_config_path" "~/.ssh/config")"
  LOCAL_OVERRIDE_DIR="$(cfg_string "local_override_dir" "~/.ssh/local")"
  DEVICE_NAME="$(cfg_string "device_name" "")"

  SERVER_ALIVE_INTERVAL="$(cfg_int "server_alive_interval" "60")"
  SERVER_ALIVE_COUNT_MAX="$(cfg_int "server_alive_count_max" "3")"
  TCP_KEEPALIVE="$(cfg_bool "tcp_keepalive" "true")"
  if [[ "$TCP_KEEPALIVE" == "true" ]]; then
    TCP_KEEPALIVE_TEXT="yes"
  else
    TCP_KEEPALIVE_TEXT="no"
  fi

  GITHUB_ALIAS="$(cfg_string "hosts.github.alias" "github.com")"
  GITHUB_HOSTNAME="$(cfg_string "hosts.github.hostname" "github.com")"
  GITHUB_USER="$(cfg_string "hosts.github.user" "git")"
  GITHUB_KEY="$(cfg_string "hosts.github.key" "")"

  ARCH_ALIAS="$(cfg_string "hosts.arch.alias" "arch")"
  ARCH_HOSTNAME="$(cfg_string "hosts.arch.hostname" "192.168.1.93")"
  ARCH_USER="$(cfg_string "hosts.arch.user" "admin")"
  ARCH_KEY="$(cfg_string "hosts.arch.key" "")"

  BACKUP_EXISTING_CONFIG="$(cfg_bool "backup_existing_config" "true")"
  OVERWRITE_EXISTING_BOOTSTRAP_CONFIG="$(cfg_bool "overwrite_existing_bootstrap_config" "true")"
  CREATE_SHARED_CONFIG_IF_MISSING="$(cfg_bool "create_shared_config_if_missing" "true")"
  MANAGE_EXISTING_SHARED_CONFIG="$(cfg_bool "manage_existing_shared_config" "true")"
  SHARED_CONFIG_ONLY_IF_MISSING="$(cfg_bool "shared_config_only_if_missing" "true")"

  validate_private_key_path "$LOCAL_KEY_PATH"
  ensure_openssh_tools
  resolve_effective_key_path
  validate_private_key_path "$EFFECTIVE_KEY_PATH"

  # Per-host keys: fall back to global EFFECTIVE_KEY_PATH if not set
  [[ -z "$GITHUB_KEY" ]] && GITHUB_KEY="$EFFECTIVE_KEY_PATH"
  [[ -z "$ARCH_KEY" ]] && ARCH_KEY="$EFFECTIVE_KEY_PATH"

  # Validate per-host keys exist
  if [[ ! -f "$GITHUB_KEY" ]]; then
    warn "GitHub key not found: $GITHUB_KEY (will be created if generate_key_if_missing=true)"
  fi
  if [[ ! -f "$ARCH_KEY" ]]; then
    warn "Arch key not found: $ARCH_KEY"
  fi
  validate_private_key_path "$GITHUB_KEY"
  validate_private_key_path "$ARCH_KEY"

  ensure_dir "$(dirname "$LOCAL_BOOTSTRAP_CONFIG_PATH")"
  ensure_dir "$LOCAL_OVERRIDE_DIR"
  ensure_dir "$(dirname "$SHARED_CONFIG_PATH")"
  ensure_dir "$(dirname "$EFFECTIVE_SHARED_CONFIG_PATH")"
  set_mode_if_exists 700 "$(dirname "$LOCAL_BOOTSTRAP_CONFIG_PATH")"
  set_mode_if_exists 700 "$LOCAL_OVERRIDE_DIR"

  create_local_key_if_missing
  ensure_public_key_exists "$EFFECTIVE_KEY_PATH"

  # Ensure public keys exist for per-host keys
  [[ -f "$GITHUB_KEY" ]] && ensure_public_key_exists "$GITHUB_KEY"
  [[ -f "$ARCH_KEY" ]] && ensure_public_key_exists "$ARCH_KEY"

  manage_shared_config_file

  write_file_if_needed \
    "$LOCAL_BOOTSTRAP_CONFIG_PATH" \
    "$(build_bootstrap_config_content)" \
    "$BACKUP_EXISTING_CONFIG" \
    "$OVERWRITE_EXISTING_BOOTSTRAP_CONFIG"

  set_mode_if_exists 700 "$(dirname "$EFFECTIVE_KEY_PATH")"
  set_mode_if_exists 600 "$LOCAL_BOOTSTRAP_CONFIG_PATH"
  set_mode_if_exists 600 "$EFFECTIVE_KEY_PATH"
  set_mode_if_exists 644 "${EFFECTIVE_KEY_PATH}.pub"
  set_mode_if_exists 600 "$GITHUB_KEY"
  set_mode_if_exists 644 "${GITHUB_KEY}.pub"
  set_mode_if_exists 600 "$ARCH_KEY"
  set_mode_if_exists 644 "${ARCH_KEY}.pub"
  set_mode_if_exists 644 "$SHARED_CONFIG_PATH"
  set_mode_if_exists 600 "$EFFECTIVE_SHARED_CONFIG_PATH"

  summarize

  if [[ "$CLI_NO_CLEANUP" != "true" && "$DRY_RUN" != "true" ]]; then
    cleanup_phase
  fi
}

main "$@"
