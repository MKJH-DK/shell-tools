# ssh-setup

Small cross-device SSH bootstrap for Termux, WSL, Linux, and Arch servers.

## Design

The vault holds one shared SSH host config at `_ssh/shared.conf`. Each device keeps its own private key locally. The preferred standard path is `~/.ssh/keys/id_ed25519_default`, but the bootstrap will first try to adopt an already-existing local key so the first run does not break an existing setup. The generated local `~/.ssh/config` only includes the shared vault config plus optional local override files from `~/.ssh/local/*.conf`.

That gives one synced source of truth for aliases and keepalive settings, while key material stays off the vault and off Android shared storage.

## Files

- `ssh-bootstrap.toml`: main config with paths, host defaults, keepalive, and vault search paths.
- `ssh-bootstrap.sh`: bootstrap script that detects environment, finds the vault, adopts an existing local key when possible, generates a new one only if needed, writes the local bootstrap config, and creates or updates a managed block inside the shared config in the vault.
- `shared.conf.example`: example shared SSH config for the vault.

## First Run

```bash
cd ssh-setup
chmod +x ssh-bootstrap.sh
./ssh-bootstrap.sh
```

The script will:

- detect `termux`, `wsl`, or `linux`
- find a likely vault directory from the configured search paths
- create `~/.ssh`, `~/.ssh/keys`, and `~/.ssh/local`
- reuse an existing local SSH key if one is found in the configured candidate list
- generate `~/.ssh/keys/id_ed25519_default` only if no usable local key exists
- create `<vault>/_ssh/shared.conf` if missing
- update or insert a managed block in an existing shared config while preserving unrelated hosts and custom entries
- write `~/.ssh/config` as a small bootstrap include layer
- back up an existing local SSH config before replacing it

## Config

Edit `ssh-bootstrap.toml` when you want to change paths or defaults.

Common fields:

- `vault_dir`: manually pin the vault root instead of auto-detection.
- `shared_config_path`: manually pin the shared SSH config path.
- `local_key_path`: local per-device private key path.
- `local_bootstrap_config_path`: generated local SSH config path.
- `local_override_dir`: extra local config fragments, included after the shared config.
- `device_name`: optional label used in the generated SSH key comment.
- `prefer_existing_keys`: prefer an already-existing local key before generating a new one.
- `generate_key_if_missing`: allow fallback key generation when no existing key is found.
- `manage_existing_shared_config`: update an existing shared config instead of leaving it untouched.
- `server_alive_interval`, `server_alive_count_max`, `tcp_keepalive`: keepalive defaults.
- `auto_detect_vault`, `auto_detect_environment`: turn detection on or off.
- `dry_run`: preview changes without writing files.
- `print_public_key`: print the generated public key at the end.
- `auto_install_openssh`: try to install OpenSSH if `ssh` or `ssh-keygen` is missing.

You can also adjust:

- `[hosts.github]`
- `[hosts.arch]`
- `[existing_keys]`
- `[search_paths.termux]`
- `[search_paths.wsl]`
- `[search_paths.linux]`

By default the script checks common existing key paths such as:

- `~/.ssh/id_ed25519_default`
- `~/.ssh/id_ed25519`
- `~/.ssh/id_rsa`
- `~/.ssh/id_ecdsa`
- `~/.ssh/id_ed25519_github`
- `~/.ssh/id_rsa_github`

If one of these exists, the managed shared config block will reference that existing key path instead of forcing a new key.

## Changing The Vault Path

Use either:

1. `vault_dir = "/your/vault/path"`
2. `shared_config_path = "/your/vault/_ssh/shared.conf"`
3. updated search paths under `[search_paths.*]`

The script expands `~`, `${HOME}`, `${USER}`, and `${WINDOWS_USER}` inside configured paths.

## Key Rotation For One Device

1. Replace or regenerate the effective local key currently used by the shared config.
2. Add the new public key to GitHub.
3. Add the new public key to the server's `authorized_keys`.
4. Remove the old public key from GitHub and the server when ready.

No shared host config changes are needed when rotating a key on a single device.

## Public Key Targets

GitHub:

1. Copy the printed `.pub` key.
2. Add it in GitHub SSH keys for your account.

Server:

1. Copy the same `.pub` key.
2. Append it to `~admin/.ssh/authorized_keys` or the relevant user's `authorized_keys`.

## Dry Run

```bash
./ssh-bootstrap.sh --dry-run
```

## Shared Config Maintenance

Change aliases, hostnames, users, or keepalive values in `<vault>/_ssh/shared.conf`. Because every device includes that one file, the updated host definitions are picked up everywhere after sync.

If `manage_existing_shared_config = true`, the bootstrap script manages only a marker-delimited block inside that file:

- `# >>> ssh-setup managed block >>>`
- `# <<< ssh-setup managed block <<<`

If the markers already exist, only that block is replaced.
If the markers do not exist, the block is appended to the end of the existing file.
Unrelated hosts and custom SSH entries outside the managed block are preserved.
Existing files are backed up first when `backup_existing_config = true`.
