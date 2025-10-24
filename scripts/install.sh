bash -c '
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

ACCENT="${ACCENT:-#6E56CF}"   # tweak with: ACCENT="#7C3AED" bash setup.sh

echo "==> APT prep (repos, fixes)"
sudo apt update
sudo apt install -y software-properties-common curl gnupg ca-certificates

# Remove broken PPAs that often ship on customized images
sudo add-apt-repository -r -y ppa:zedtux/naturalscrolling 2>/dev/null || true
sudo rm -f /etc/apt/sources.list.d/zedtux-ubuntu-naturalscrolling*.list* || true

# Make sure "universe" is on
sudo add-apt-repository -y universe || true

# Hyprland PPA (24.04 "noble")
if ! apt-cache show hyprland >/dev/null 2>&1; then
  sudo add-apt-repository -y ppa:cppiber/hyprland
fi

# VS Code repo
if ! test -f /etc/apt/sources.list.d/vscode.list; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/ms_vscode.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/ms_vscode.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
fi

sudo apt update

echo "==> Installing desktop stack (Hyprland + tools)"
sudo apt install -y \
  hyprland hyprlock hypridle \
  waybar mako-notifier wofi \
  wl-clipboard grim slurp imagemagick \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  pipewire-audio wireplumber playerctl \
  kitty fzf jq unzip git rsync \
  wlogout blueman network-manager-gnome nm-tray pavucontrol \
  thunar file-roller gnome-system-monitor \
  fonts-jetbrains-mono fonts-noto-color-emoji \
  firefox code

echo "==> Switch greeter to SDDM (Wayland-friendly)"
sudo apt install -y sddm
if systemctl is-enabled lightdm >/dev/null 2>&1 || systemctl status lightdm >/dev/null 2>&1; then
  sudo systemctl disable --now lightdm || true
  sudo systemctl mask lightdm || true
fi
sudo systemctl enable --now sddm || true

echo "==> Developer toolchain"
sudo apt install -y \
  build-essential pkg-config cmake ninja-build \
  python3 python3-venv python3-pip pipx \
  golang-go \
  cargo \
  ripgrep fd-find tmux neovim bat \
  docker.io docker-compose-plugin

# Map fdfind->fd (Ubuntu naming) and batcat->bat if needed
mkdir -p ~/.local/bin
command -v fd >/dev/null 2>&1 || { command -v fdfind >/dev/null 2>&1 && ln -sf "$(command -v fdfind)" ~/.local/bin/fd; }
command -v bat >/dev/null 2>&1 || { command -v batcat >/dev/null 2>&1 && ln -sf "$(command -v batcat)" ~/.local/bin/bat; }
# Docker group so "docker" works without sudo (you must log out/in)
sudo usermod -aG docker "$USER" || true

echo "==> Node (nvm + LTS + global CLIs)"
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default "lts/*"
npm i -g pnpm yarn typescript ts-node eslint prettier vite

echo "==> Configs (Hyprland, Waybar, Mako, Hyprlock)"
mkdir -p ~/.config/{hypr,waybar,mako} ~/.config/environment.d

cat > ~/.config/hypr/hyprland.conf <<EOF
env = XDG_CURRENT_DESKTOP, Hyprland
env = GTK_USE_PORTAL, 1
env = MOZ_ENABLE_WAYLAND, 1
env = PATH, \$PATH:\$HOME/.local/bin:\$HOME/.nvm/versions/node/current/bin
monitor=,preferred,auto,1

# Launcher & terminal
\$term = kitty
\$menu = wofi --show drun

# Autostart
exec-once = waybar
exec-once = mako
exec-once = hypridle
exec-once = nm-tray
exec-once = blueman-applet
exec-once = pavucontrol --start-hidden

# Input (natural scroll will be appended below)
# env-based compose key (safer than old kb_options)
env = XKB_DEFAULT_OPTIONS, compose:caps

# Visuals (Hex 0xAARRGGBB)
general {
  gaps_in = 6
  gaps_out = 12
  border_size = 2
  col.active_border   = 0xff${ACCENT#\#}
  col.inactive_border = 0xff222222
  layout = master
}

# Binds (Omarchy-style)
bind = SUPER, RETURN, exec, \$term
bind = SUPER, SPACE,  exec, \$menu
bind = SUPER ALT, SPACE, exec, omarchy-menu

bind = SUPER, W, killactive
bind = SUPER, F, fullscreen
bind = SUPER, T, togglefloating

bind = SUPER, H, movefocus, l
bind = SUPER, L, movefocus, r
bind = SUPER, K, movefocus, u
bind = SUPER, J, movefocus, d
bind = SUPER SHIFT, H, swapwindow, l
bind = SUPER SHIFT, L, swapwindow, r
bind = SUPER SHIFT, K, swapwindow, u
bind = SUPER SHIFT, J, swapwindow, d

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, TAB, workspace, e+1
bind = SUPER SHIFT, TAB, workspace, e-1

# Screenshots
bind = SUPER, S, exec, grim -g "\$(slurp)" - | wl-copy
bind = SUPER SHIFT, S, exec, grim - | wl-copy

# Volume/media
bindle = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
bindle = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%
bindle = , XF86AudioMute,        exec, pactl set-sink-mute @DEFAULT_SINK@ toggle
bindle = , XF86AudioPlay,        exec, playerctl play-pause
bindle = , XF86AudioNext,        exec, playerctl next
bindle = , XF86AudioPrev,        exec, playerctl previous

# Lock/power
bind = SUPER, ESC, exec, hyprlock
bind = SUPER, Q,   exec, wlogout

# Float common dialogs
windowrulev2 = float, title:^(Open|Save|Confirm|Preferences|Settings)
EOF

# Waybar
cat > ~/.config/waybar/config.jsonc <<EOF
{
  "layer": "top",
  "position": "top",
  "height": 28,
  "modules-left": ["hyprland/workspaces","hyprland/window"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio","network","cpu","memory","battery","tray"],
  "clock": { "format": "{:%a %d %b  %H:%M}" },
  "cpu": { "format": "CPU {usage}%" },
  "memory": { "format": "RAM {used:0.1f}G" },
  "battery": { "format": "{capacity}% {icon}", "format-icons": ["","","","",""] },
  "pulseaudio": { "format": " {volume}%" },
  "network": { "format-wifi": " {signalStrength}%", "format-ethernet": "", "tooltip": false }
}
EOF

cat > ~/.config/waybar/style.css <<EOF
@define-color accent ${ACCENT};
@define-color bg #0A0A0A;
@define-color bg2 #121212;
@define-color fg #EDEDED;
@define-color muted #8A8A8A;

* { font-family: "JetBrains Mono","Noto Sans",sans-serif; font-size: 12.5px; }
window#waybar { background: alpha(@bg,0.9); color:@fg; border-bottom:1px solid alpha(@fg,0.05); }
#workspaces button { color:@muted; }
#workspaces button.focused { background:@accent; color:#fff; }
#workspaces button:hover { background: alpha(@accent,0.25); color:@fg; }
#clock,#cpu,#memory,#battery,#pulseaudio,#network,#tray { padding: 0 10px; }
#pulseaudio,#network,#cpu,#memory,#battery { background: alpha(@bg2,0.95); margin:4px 4px; border-radius:6px; }
EOF

# Mako (notifications)
cat > ~/.config/mako/config <<EOF
font=JetBrains Mono 12
background-color=#0A0A0AF0
text-color=#EDEDED
border-color=${ACCENT}
border-size=2
default-timeout=4500
icon-path=/usr/share/icons
anchor=top-right
margin=12,12,0,0
EOF

# Hyprlock
cat > ~/.config/hypr/hyprlock.conf <<EOF
background { color = rgba(10,10,10,1) }
label { text = \$TIME; color = rgba(237,237,237,1); font_size = 46; position = 0,80; halign = center; valign = center; }
input-field { size = 300,42; outline_thickness = 2; dots_size = 0.3;
  outer_color = rgba(110,86,207,1); inner_color = rgba(18,18,18,1); font_color = rgba(237,237,237,1); }
EOF

# Session env
cat > ~/.config/environment.d/99-hyprland.conf <<EOF
PATH=\$PATH:\$HOME/.local/bin:\$HOME/.nvm/versions/node/current/bin
XDG_CURRENT_DESKTOP=Hyprland
GTK_USE_PORTAL=1
EOF

echo "==> Natural scrolling (live + persist)"
# Live
hyprctl keyword input:touchpad:natural_scroll true || true
# Persist
grep -q "natural_scroll" ~/.config/hypr/hyprland.conf || cat >> ~/.config/hypr/hyprland.conf <<EOF

input {
  touchpad { natural_scroll = true }
}
EOF

echo "==> Settings launcher + Omarchy-style menu"
# Settings command (prefers GNOME Settings, falls back to Xfce)
echo -e "#!/usr/bin/env bash\n(gnome-control-center || xfce4-settings-manager || lxqt-config) >/dev/null 2>&1 & disown" | sudo tee /usr/local/bin/settings >/dev/null
sudo chmod +x /usr/local/bin/settings
# Install settings helpers
sudo apt install -y gnome-control-center wdisplays pavucontrol qt6ct lxappearance xfce4-settings

# Menu
sudo tee /usr/local/bin/omarchy-menu >/dev/null <<'"SH"'
#!/usr/bin/env bash
set -euo pipefail
pick(){ printf "%s\n" "$@" | fzf --prompt="$1 > " --height=40% --reverse --border | sed "s/^[0-9]) //"; }
apps(){ wofi --show drun; }
style(){
  kitty -e bash -lc "echo -e '\nEdit ~/.config/waybar/style.css and ~/.config/mako/config for colors.'; read -p '[Enter] to open Waybar CSS...' _; ${EDITOR:-nano} ~/.config/waybar/style.css; pkill -SIGUSR2 waybar || true"
}
power(){ command -v wlogout >/dev/null && exec wlogout || hyprctl dispatch exit; }
system(){
  choice=$(pick System \
    "1) Update (apt full-upgrade)" \
    "2) Restart Waybar" \
    "3) Reload Hyprland" \
    "4) Toggle DND (mako)" \
    "5) Network (nm-connection-editor)" \
    "6) Bluetooth (blueman-manager)" \
    "7) Audio Mixer (pavucontrol)" \
    "8) Displays (wdisplays)" \
    "9) System Monitor (gnome-system-monitor)" \
    "10) Settings")
  case "$choice" in
    "Update (apt full-upgrade)") kitty -e bash -lc "sudo apt update && sudo apt full-upgrade -y" ;;
    "Restart Waybar") pkill -SIGUSR2 waybar || (pkill waybar; nohup waybar >/dev/null 2>&1 &);;
    "Reload Hyprland") hyprctl reload ;;
    "Toggle DND (mako)") (makoctl mode | grep -q dnd) && makoctl mode -s default || makoctl mode -s dnd ;;
    "Network (nm-connection-editor)") nohup nm-connection-editor >/dev/null 2>&1 & ;;
    "Bluetooth (blueman-manager)")   nohup blueman-manager      >/dev/null 2>&1 & ;;
    "Audio Mixer (pavucontrol)")     nohup pavucontrol          >/dev/null 2>&1 & ;;
    "Displays (wdisplays)")          nohup wdisplays            >/dev/null 2>&1 & ;;
    "System Monitor (gnome-system-monitor)") nohup gnome-system-monitor >/dev/null 2>&1 & ;;
    "Settings") settings ;;
  esac
}
main(){
  top=$(pick Menu "1) Apps" "2) Style" "3) System" "4) Power")
  case "$top" in
    Apps) apps ;;
    Style) style ;;
    System) system ;;
    Power) power ;;
  esac
}
main
"SH"
sudo chmod +x /usr/local/bin/omarchy-menu

echo
echo "✅ Done."
echo "• Log out → at the greeter pick the **Hyprland** session → log in."
echo "• Keys: Super+Enter=Kitty, Super+Space=Wofi, Super+Alt+Space=Menu, Super+Esc=Lock."
echo "• Dev tools: code, docker (relog to use without sudo), node (nvm), python/go/rust, neovim/tmux/rg/fd."
echo "• Natural scrolling enabled & persistent."
'
