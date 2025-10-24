#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

# hypr-omarchy-ui installer (Ubuntu 24.04 Lubuntu/Xubuntu Minimal)
# License: MIT (see LICENSE)

# ---- Options (env or flags) ------------------------------------------------
#  ACCENT="#6E56CF"     Dark-purple accent
#  LAUNCHER="wofi"      (wofi|walker) – default: wofi (lighter)
#  SKIP_SDDM=1          Don’t switch DM; keep LightDM
#  NONINTERACTIVE=1     Force non-interactive apt
ACCENT="${ACCENT:-#6E56CF}"
LAUNCHER="${LAUNCHER:-wofi}"
NONINTERACTIVE="${NONINTERACTIVE:-1}"
export DEBIAN_FRONTEND="${NONINTERACTIVE:+noninteractive}"

# ---- Guardrails -------------------------------------------------------------
source /etc/os-release
if [[ "${ID}" != "ubuntu" && "${ID_LIKE:-}" != *"ubuntu"* ]]; then
  echo "This targets Ubuntu 24.04 derivatives (Lubuntu/Xubuntu Minimal)."; exit 1;
fi
command -v apt >/dev/null || { echo "apt not found"; exit 1; }

# ---- Packages ---------------------------------------------------------------
sudo apt update
sudo apt install -y \
  hyprland hyprlock hypridle waybar mako-notifier \
  wl-clipboard grim slurp imagemagick \
  xdg-desktop-portal xdg-desktop-portal-wlr \
  pipewire-audio wireplumber playerctl \
  kitty jq curl git unzip fzf wlogout \
  blueman network-manager-gnome \
  fonts-jetbrains-mono fonts-noto-color-emoji \
  sddm || true

# Launcher choice
case "$LAUNCHER" in
  wofi)
    sudo apt install -y wofi
    ;;
  walker)
    # Lightweight but compiles; if you really want Walker set LAUNCHER=walker
    sudo apt install -y cargo libgtk-4-dev libadwaita-1-dev
    ~/.cargo/bin/walker --version >/dev/null 2>&1 || cargo install --locked walker
    mkdir -p ~/.local/bin
    cat > ~/.local/bin/walker <<'SH'
#!/usr/bin/env bash
exec "$HOME/.cargo/bin/walker" "$@"
SH
    chmod +x ~/.local/bin/walker
    ;;
  *)
    echo "Unknown LAUNCHER=$LAUNCHER (use wofi|walker)"; exit 1;;
esac

# ---- Switch to SDDM (unless skipped) ---------------------------------------
if [[ -z "${SKIP_SDDM:-}" ]]; then
  if systemctl is-enabled lightdm >/dev/null 2>&1 || systemctl status lightdm >/devnull 2>&1; then
    sudo systemctl disable --now lightdm || true
    sudo systemctl mask lightdm || true
  fi
  sudo systemctl enable --now sddm || true
fi

# ---- Copy configs -----------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$REPO_DIR/templates"

mkdir -p ~/.config/hypr ~/.config/waybar ~/.config/mako ~/.config/environment.d

# Hyprland
sed "s/__ACCENT__/${ACCENT}/g" "$TEMPLATES/hypr/hyprland.conf" > ~/.config/hypr/hyprland.conf
cp -f "$TEMPLATES/hypr/hyprlock.conf" ~/.config/hypr/hyprlock.conf

# Waybar + Mako (with accent)
cp -f "$TEMPLATES/waybar/config.jsonc" ~/.config/waybar/config.jsonc
sed "s/__ACCENT__/${ACCENT}/g" "$TEMPLATES/waybar/style.css" > ~/.config/waybar/style.css
sed "s/__ACCENT__/${ACCENT}/g" "$TEMPLATES/mako/config" > ~/.config/mako/config

# Session env
cat > ~/.config/environment.d/99-hyprland.conf <<'ENV'
PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin
XDG_CURRENT_DESKTOP=Hyprland
GTK_USE_PORTAL=1
ENV

# ---- Omarchy-style menu ----------------------------------------------------
sudo tee /usr/local/bin/omarchy-menu >/dev/null <<'SH'
#!/usr/bin/env bash
set -euo pipefail
pick() { printf "%s\n" "$@" | fzf --prompt="$1 > " --height=40% --reverse --border | sed 's/^[^)]*) //'; }
apps_menu() { __LAUNCHER_PLACEHOLDER__; }
style_menu() {
  kitty -e bash -lc '
    echo -e "\nEdit ~/.config/waybar/style.css and ~/.config/mako/config for colors (accent is __ACCENT__)."
    read -p "[Enter] to open Waybar CSS..." _; ${EDITOR:-nano} ~/.config/waybar/style.css
    pkill -SIGUSR2 waybar || true
  '
}
power_menu() { command -v wlogout >/dev/null && exec wlogout || hyprctl dispatch exit; }
system_menu() {
  choice=$(pick "System" \
    "1) Update (apt full-upgrade)" \
    "2) Restart Waybar" \
    "3) Reload Hyprland" \
    "4) Toggle DND (mako)" \
    "5) Network (nm-connection-editor)" \
    "6) Bluetooth (blueman-manager)")
  case "$choice" in
    "Update (apt full-upgrade)") kitty -e bash -lc 'sudo apt update && sudo apt full-upgrade -y' ;;
    "Restart Waybar") pkill -SIGUSR2 waybar || (pkill waybar; nohup waybar >/dev/null 2>&1 &);;
    "Reload Hyprland") hyprctl reload ;;
    "Toggle DND (mako)") (makoctl mode | grep -q dnd) && makoctl mode -s default || makoctl mode -s dnd ;;
    "Network (nm-connection-editor)") nohup nm-connection-editor >/dev/null 2>&1 & ;;
    "Bluetooth (blueman-manager)")   nohup blueman-manager      >/dev/null 2>&1 & ;;
  esac
}
main() {
  top=$(pick "Menu" "1) Apps (Launcher)" "2) Style (Themes)" "3) System" "4) Power")
  case "$top" in
    "Apps (Launcher)") apps_menu ;;
    "Style (Themes)")  style_menu ;;
    "System")          system_menu ;;
    "Power")           power_menu ;;
  esac
}
main
SH
sudo chmod +x /usr/local/bin/omarchy-menu

# Replace launcher placeholder in menu
if [[ "$LAUNCHER" == "wofi" ]]; then
  sudo sed -i 's/__LAUNCHER_PLACEHOLDER__/wofi --show drun/' /usr/local/bin/omarchy-menu
else
  sudo sed -i 's/__LAUNCHER_PLACEHOLDER__/walker/' /usr/local/bin/omarchy-menu
fi
sudo sed -i "s/__ACCENT__/${ACCENT}/g" /usr/local/bin/omarchy-menu

# ---- Done ------------------------------------------------------------------
echo
echo "✅ Installed."
echo "→ Log out, choose the 'Hyprland' session in SDDM, then log back in."
echo "→ Super+Space = ${LAUNCHER^},  Super+Alt+Space = omarchy-menu."
echo "→ Accent: ${ACCENT}"
