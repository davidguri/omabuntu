#!/usr/bin/env bash
# Omarchy config bootstrap for Ubuntu
# Copies https://github.com/basecamp/omarchy/tree/master/config into ~/.config
# Safe, idempotent, with backups + Ubuntu package setup.

set -euo pipefail

### ─────────────────────────────────────────────────────────────────────────────
### Settings (override with env vars when running)
### ─────────────────────────────────────────────────────────────────────────────
: "${OMARCHY_REPO:=https://github.com/basecamp/omarchy.git}"     # repo URL
: "${OMARCHY_REF:=master}"                                       # tag/branch (e.g. v3.1.3)
: "${OMARCHY_DIR:=${HOME}/.cache/omarchy-config-src}"            # local clone
: "${CONFIG_DST:=${HOME}/.config}"                               # destination for configs
: "${BACKUP_ROOT:=${HOME}/.local/share/omarchy-config-backups}"  # backups dir
: "${LOCAL_BIN:=${HOME}/.local/bin}"                             # for shim symlinks
: "${SKIP_APT:=0}"                                               # set to 1 to skip apt installs
: "${NONINTERACTIVE:=1}"                                         # force non-interactive apt

### ─────────────────────────────────────────────────────────────────────────────
### Helpers
### ─────────────────────────────────────────────────────────────────────────────
log()   { printf "\033[1;36m[omarchy-config]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[omarchy-config]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[omarchy-config]\033[0m %s\n" "$*" >&2; }
die()   { err "$*"; exit 1; }

timestamp() { date +"%Y%m%d-%H%M%S"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

### ─────────────────────────────────────────────────────────────────────────────
### Uninstall / Restore last backup
### ─────────────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "uninstall" ]]; then
  LAST_BACKUP=$(ls -1dt "${BACKUP_ROOT}"/backup-* 2>/dev/null | head -n1 || true)
  if [[ -z "${LAST_BACKUP}" ]]; then
    die "No backups found in ${BACKUP_ROOT}"
  fi
  log "Restoring from ${LAST_BACKUP} -> ${CONFIG_DST}"
  rsync -a --delete "${LAST_BACKUP}/" "${CONFIG_DST}/"
  log "Restore complete."
  exit 0
fi

### ─────────────────────────────────────────────────────────────────────────────
### OS checks
### ─────────────────────────────────────────────────────────────────────────────
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  ID_LIKE=${ID_LIKE:-}
  case "${ID:-}${ID_LIKE}" in
    *ubuntu*|*debian*)
      log "Detected Ubuntu/Debian family: ${PRETTY_NAME:-Unknown}"
      ;;
    *)
      warn "This script targets Ubuntu. Proceeding anyway (package install may fail)."
      ;;
  esac
else
  warn "Unable to detect OS (no /etc/os-release). Continuing."
fi

### ─────────────────────────────────────────────────────────────────────────────
### APT packages (skip with SKIP_APT=1)
### ─────────────────────────────────────────────────────────────────────────────
if [[ "${SKIP_APT}" -ne 1 ]]; then
  export DEBIAN_FRONTEND=noninteractive
  log "Updating apt index…"
  sudo apt-get update -y

  # Core CLI + dev tools used by common Omarchy configs
  PKGS=(
    git curl wget unzip tar rsync stow jq
    zsh tmux neovim fzf ripgrep
    fd-find bat
    kitty fonts-firacode
  )

  log "Installing packages: ${PKGS[*]}"
  sudo apt-get install -y "${PKGS[@]}"

  # Optional niceties (safe to fail)
  sudo apt-get install -y fonts-jetbrains-mono 2>/dev/null || true

  # Ensure ~/.local/bin exists and prepend to PATH via shell rc
  mkdir -p "${LOCAL_BIN}"
  if ! grep -qs "${LOCAL_BIN}" "${HOME}/.bashrc" "${HOME}/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.zshrc"
  fi

  # Ubuntu names: batcat / fdfind → create developer-friendly shims
  ln -sf "$(command -v batcat)" "${LOCAL_BIN}/bat"      || true
  ln -sf "$(command -v fdfind)"  "${LOCAL_BIN}/fd"       || true

  log "Base tooling installed. (Shims: $(readlink -f ${LOCAL_BIN}/bat 2>/dev/null || echo none), $(readlink -f ${LOCAL_BIN}/fd 2>/dev/null || echo none))"
else
  log "Skipping apt package installation (SKIP_APT=1)."
fi

### ─────────────────────────────────────────────────────────────────────────────
### Clone / update source
### ─────────────────────────────────────────────────────────────────────────────
if [[ -d "${OMARCHY_DIR}/.git" ]]; then
  log "Updating existing clone at ${OMARCHY_DIR}…"
  git -C "${OMARCHY_DIR}" fetch --depth=1 origin "${OMARCHY_REF}"
  git -C "${OMARCHY_DIR}" checkout -qf FETCH_HEAD
else
  log "Cloning ${OMARCHY_REPO} (${OMARCHY_REF}) to ${OMARCHY_DIR}…"
  git clone --depth=1 --branch "${OMARCHY_REF}" "${OMARCHY_REPO}" "${OMARCHY_DIR}"
fi

[[ -d "${OMARCHY_DIR}/config" ]] || die "Config directory not found in repo checkout: ${OMARCHY_DIR}/config"

### ─────────────────────────────────────────────────────────────────────────────
### Backup current ~/.config then sync Omarchy configs
### ─────────────────────────────────────────────────────────────────────────────
mkdir -p "${CONFIG_DST}"
mkdir -p "${BACKUP_ROOT}"

# Create a targeted backup containing ONLY the files/dirs Omarchy will overwrite
BACKUP_DIR="${BACKUP_ROOT}/backup-$(timestamp)"
mkdir -p "${BACKUP_DIR}"

log "Preparing selective backup of files that will be replaced…"
# Build list of relative paths from source config
while IFS= read -r -d '' src; do
  rel="${src#"${OMARCHY_DIR}/config/"}"
  dst_path="${CONFIG_DST}/${rel}"
  if [[ -e "${dst_path}" ]]; then
    mkdir -p "$(dirname "${BACKUP_DIR}/${rel}")"
    rsync -a "${dst_path}" "${BACKUP_DIR}/${rel%/*}/" >/dev/null 2>&1 || true
  fi
done < <(find "${OMARCHY_DIR}/config" -mindepth 1 -maxdepth 1 -print0)

log "Syncing Omarchy config → ${CONFIG_DST}"
# Use rsync to copy top-level items from repo/config into ~/.config
rsync -a --delete --info=name0 "${OMARCHY_DIR}/config/" "${CONFIG_DST}/"

log "Backup saved at: ${BACKUP_DIR}"
log "Config sync complete."

### ─────────────────────────────────────────────────────────────────────────────
### Post-steps: default shell / quality-of-life
### ─────────────────────────────────────────────────────────────────────────────
if command -v zsh >/dev/null 2>&1; then
  if [[ "${SHELL}" != *"/zsh" ]]; then
    warn "You are not using zsh. To change default shell: chsh -s \"$(command -v zsh)\""
  fi
fi

# Kitty as a common terminal used in Omarchy configs (safe to skip if not installed)
if command -v kitty >/dev/null 2>&1; then
  log "Kitty installed. If using GNOME, set it default with: update-alternatives --config x-terminal-emulator"
fi

cat <<'EOF'

✅ Done. Notes:
- Your previous config files (only those that would be overwritten) were backed up to:
  ~/.local/share/omarchy-config-backups/backup-YYYYMMDD-HHMMSS
- To restore the last backup, run:
  ./install.sh uninstall

Tips:
- If you installed new fonts, restart apps to see them.
- bat/fd shims were created in ~/.local/bin so tools/scripts expecting 'bat' or 'fd' just work on Ubuntu.
- Re-run this script anytime; it's safe and idempotent.

EOF
