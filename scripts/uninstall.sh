# create + run
cat > ~/uninstall-omarchy-ui.sh <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail

# === Options (set env vars before running) ===========================
# KEEP_APPS=1        -> keep installed desktop/dev packages
# PURGE_DEV=1        -> also remove dev toolchain (docker, node, etc.)
# REMOVE_REPOS=1     -> remove Hyprland PPA + VS Code repo
# RESTORE_LIGHTDM=1  -> switch back to LightDM greeter
# DRY_RUN=1          -> show what would happen, don’t change anything
# =====================================================================

log(){ printf "\033[1;36m==>\033[0m %s\n" "$*"; }
run(){ if [[ -n "${DRY_RUN:-}" ]]; then echo "DRY: $*"; else eval "$@"; fi; }

log "Stopping Hyprland session services (this may log you out)"
run "systemctl --user stop waybar.service 2>/dev/null || true"
run "pkill -x waybar 2>/dev/null || true"
run "pkill -x mako 2>/dev/null || true"

log "Remove user configs"
run "rm -rf ~/.config/hypr ~/.config/waybar ~/.config/mako ~/.config/environment.d/99-hyprland.conf"

log "Remove helper scripts"
run "sudo rm -f /usr/local/bin/omarchy-menu /usr/local/bin/settings"

PACKAGES_DESKTOP=(
  hyprland hyprlock hypridle
  waybar mako-notifier wofi
  xdg-desktop-portal-hyprland
  wl-clipboard grim slurp imagemagick
  pipewire-audio wireplumber playerctl
  kitty wlogout blueman network-manager-gnome nm-tray pavucontrol
  thunar file-roller gnome-system-monitor
  fonts-jetbrains-mono fonts-noto-color-emoji
  firefox code fzf jq unzip rsync
  sddm
)

PACKAGES_DEV=(
  build-essential pkg-config cmake ninja-build
  python3-venv python3-pip pipx
  golang-go
  cargo
  ripgrep fd-find tmux neovim bat
  docker.io docker-compose-plugin
)

if [[ -z "${KEEP_APPS:-}" ]]; then
  log "Purging desktop packages"
  run "sudo apt purge -y ${PACKAGES_DESKTOP[*]} || true"
  run "sudo apt autoremove -y || true"
else
  log "KEEP_APPS=1 set — skipping package removal"
fi

if [[ -n "${PURGE_DEV:-}" ]]; then
  log "Purging developer toolchain"
  run "sudo apt purge -y ${PACKAGES_DEV[*]} || true"
  run "sudo apt autoremove -y || true"
  # nvm & globals
  log "Removing nvm (Node) user install"
  run "rm -rf \"$HOME/.nvm\""
  # docker group membership persists; user can remove manually if desired
fi

if [[ -n "${REMOVE_REPOS:-}" ]]; then
  log "Removing Hyprland PPA + VS Code repo"
  run "sudo add-apt-repository -r -y ppa:cppiber/hyprland || true"
  run "sudo rm -f /etc/apt/sources.list.d/vscode.list /usr/share/keyrings/ms_vscode.gpg || true"
  run "sudo apt update || true"
fi

if [[ -n "${RESTORE_LIGHTDM:-}" ]]; then
  log "Restoring LightDM greeter"
  run "sudo apt install -y lightdm"
  run "sudo systemctl disable --now sddm || true"
  run "sudo systemctl enable --now lightdm"
else
  log "Leaving display manager as-is (set RESTORE_LIGHTDM=1 to switch back)"
fi

log "Done."
echo "• If you removed SDDM, you might already be back at LightDM."
echo "• A reboot is recommended: sudo reboot"
SH
chmod +x ~/uninstall-omarchy-ui.sh
~/uninstall-omarchy-ui.sh
