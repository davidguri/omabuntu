![omabuntu logo](https://github.com/davidguri/omabuntu//blob/main/ascii-art-text.png?raw=true)

Make a fresh **Xubuntu/Lubuntu 24.04 _Minimal_** look & feel like **Omarchy’s Hyprland** desktop — without Arch.

One command installs Hyprland + Waybar + Wofi + Mako, sets a **black/purple** theme, wires **Omarchy-style keybinds & menu**, and adds a full **developer stack** (VS Code, Docker, Node LTS via nvm, Python, Go, Rust/Cargo, build tools).

---

## ✨ What you get

- **Hyprland** compositor (Wayland), **Wofi** launcher (**Super+Space**)
- **Waybar** top bar, **Mako** notifications, **Hypridle/Hyprlock**
- **Omabuntu menu** (**Super+Alt+Space**): updates, network, audio, displays, settings, etc.
- **Theme**: near-black UI with **dark-purple** accent (configurable)
- **Natural scrolling**, CapsLock→Compose (safe env method)
- **Dev stack**: VS Code, Docker (with group), Node LTS + pnpm/yarn/TS, Python3 + venv + pipx, Go, Cargo (Rust), build-essentials, tmux, neovim, ripgrep, fd, bat, git tools
- **Browser**: Firefox (Wayland enabled)

---

## ✅ Prerequisites

- **Xubuntu 24.04 Minimal** (recommended) or **Lubuntu 24.04 Minimal**
- UEFI system (typical on modern laptops)
- Internet access
- Run the installer **as your normal user** (not root). It will `sudo` as needed.

> Already on a customized image? Remove any broken PPAs first. The installer attempts to clean common offenders.

---

## 🚀 Quick Start

Clone and run from a terminal after your Xubuntu/Lubuntu Minimal install:

```bash
git clone https://github.com/<you>/omabuntu
cd omabuntu
chmod +x scripts/*.sh
./scripts/install.sh
```

Then:
1) **Log out**  
2) At the greeter (SDDM), choose the **Hyprland** session  
3) **Log in**

### Optional flags (set as env vars)

```bash
ACCENT="#7C3AED" ./scripts/install.sh   # change the purple accent
SKIP_SDDM=1 ./scripts/install.sh        # keep LightDM (don’t switch greeter)
LAUNCHER=walker ./scripts/install.sh    # use Walker instead of Wofi (builds via cargo)
```

Defaults: `ACCENT="#6E56CF"`, `LAUNCHER=wofi`, `NONINTERACTIVE=1`.

---

## 🎛️ Daily Use

- **Launcher**: `Super + Space` (Wofi)
- **Menu**: `Super + Alt + Space` (Omabuntu menu)
- **Terminal**: `Super + Enter` (Kitty)
- **Lock**: `Super + Esc`
- **Kill window**: `Super + W`
- **Toggle float**: `Super + T`
- **Fullscreen**: `Super + F`
- **Workspaces**: `Super + 1..4`, `Super + Tab`, `Super + Shift + Tab`
- **Screenshots**:
  - `Super + S` → select area to clipboard
  - `Super + Shift + S` → fullscreen to clipboard

---

## ⚙️ Customization

### Accent color

```bash
# Waybar + Mako (CSS/INI)
sed -i 's/@define-color accent .*/@define-color accent #A855F7;/' ~/.config/waybar/style.css
sed -i 's/^border-color=.*/border-color=#A855F7/' ~/.config/mako/config
pkill -SIGUSR2 waybar

# Hyprland border (0xAARRGGBB)
hyprctl keyword general:col.active_border 0xffA855F7
```

Make it permanent by editing:
- `~/.config/waybar/style.css`
- `~/.config/mako/config`
- `~/.config/hypr/hyprland.conf` (`general { col.active_border = … }`)

### Natural scrolling

```bash
# live + persist
hyprctl keyword input:touchpad:natural_scroll true
grep -q natural_scroll ~/.config/hypr/hyprland.conf ||   printf '\ninput { touchpad { natural_scroll = true } }\n' >> ~/.config/hypr/hyprland.conf
```

### CapsLock → Compose (emoji/accents)

```bash
grep -q '^env = XKB_DEFAULT_OPTIONS' ~/.config/hypr/hyprland.conf ||   sed -i '1ienv = XKB_DEFAULT_OPTIONS, compose:caps' ~/.config/hypr/hyprland.conf
hyprctl reload
```

### Add apps (example: Brave, no Snap)

```bash
sudo apt update
sudo apt install -y curl gnupg
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg   https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg]   https://brave-browser-apt-release.s3.brave.com/ stable main" |   sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update && sudo apt install -y brave-browser
```

---

## 🛠️ Developer Stack Cheatsheet

- **VS Code**: `code`
- **Docker**: `docker --version` (log out/in once to apply group membership)
- **Node**: `node -v`, `npm -v` (installed via nvm LTS)  
  - Globals: `pnpm`, `yarn`, `typescript`, `ts-node`, `eslint`, `prettier`, `vite`
- **Python**: `python3 -m venv .venv && source .venv/bin/activate`
- **Go**: `go version`
- **Rust/Cargo**: `cargo --version`
- **CLI**: `tmux`, `nvim`, `rg`, `fd`, `bat`, `fzf`

---

## 🧩 Settings & Utilities

- **Settings**: `settings` (opens GNOME Settings, falls back to Xfce)
- **Displays**: `wdisplays`
- **Audio Mixer**: `pavucontrol`
- **Network GUI**: `nm-connection-editor`
- **Bluetooth**: `blueman-manager`

All available from **Omabuntu menu** (`Super + Alt + Space`) under **System**.

---

## 🧯 Troubleshooting

### Black screen after install (greeter switch)
Likely LightDM stopped and SDDM didn’t start. Use a TTY or safe reboot.

- Try TTY: **Ctrl+Alt+F3** (or **Ctrl+Alt+Fn+F3**), log in, then:
  ```bash
  sudo apt install -y sddm
  sudo systemctl enable --now sddm
  ```
- If TTY won’t open, use **REISUB** (safe reboot): hold **Alt + PrtSc/SysRq**, then press **R E I S U B** slowly.

### No “Hyprland” option at login

```bash
sudo apt update
sudo apt install -y hyprland xdg-desktop-portal-hyprland
```

### Red “config error” overlay in Hyprland
Reset to a minimal known-good config:

```bash
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf <<'EOF'
env = XDG_CURRENT_DESKTOP, Hyprland
env = GTK_USE_PORTAL, 1
monitor=,preferred,auto,1
$term=kitty
$menu=wofi --show drun
exec-once=waybar
exec-once=mako
general { gaps_in=6; gaps_out=12; border_size=2; col.active_border=0xff6e56cf; col.inactive_border=0xff222222; layout=master; }
bind=SUPER,RETURN,exec,$term
bind=SUPER,SPACE,exec,$menu
EOF
hyprctl reload
```

### Natural scrolling keeps flipping (target device)
```bash
sudo apt -y install jq
dev="$(hyprctl -j devices | jq -r '.mice[] | select(.libinput_props.is_touchpad==true or .isTouchpad==true) .name' | head -n1)"
[ -n "$dev" ] && hyprctl keyword "device:$dev:natural_scroll" true && printf "\ndevice:%s {\n  natural_scroll = true\n}\n" "$dev" >> ~/.config/hypr/hyprland.conf && hyprctl reload
```

### Network/Bluetooth applets missing
```bash
nm-connection-editor &    # network
blueman-manager &         # bluetooth
```

---

## 🧹 Uninstall

Create and run the uninstaller:

```bash
cat > ~/uninstall-omabuntu.sh <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
# Options:
# KEEP_APPS=1        keep installed packages
# PURGE_DEV=1        remove dev toolchain
# REMOVE_REPOS=1     remove Hyprland PPA & VS Code repo
# RESTORE_LIGHTDM=1  switch back to LightDM greeter
rm -rf ~/.config/hypr ~/.config/waybar ~/.config/mako ~/.config/environment.d/99-hyprland.conf
sudo rm -f /usr/local/bin/omarchy-menu /usr/local/bin/settings
PACK_UI="hyprland hyprlock hypridle waybar mako-notifier wofi xdg-desktop-portal-hyprland wl-clipboard grim slurp imagemagick pipewire-audio wireplumber playerctl kitty wlogout blueman network-manager-gnome nm-tray pavucontrol thunar file-roller gnome-system-monitor fonts-jetbrains-mono fonts-noto-color-emoji firefox code fzf jq unzip rsync sddm"
PACK_DEV="build-essential pkg-config cmake ninja-build python3-venv python3-pip pipx golang-go cargo ripgrep fd-find tmux neovim bat docker.io docker-compose-plugin"
[ -z "${KEEP_APPS:-}" ] && sudo apt purge -y $PACK_UI || true
[ -n "${PURGE_DEV:-}" ] && sudo apt purge -y $PACK_DEV && sudo apt autoremove -y || true
[ -n "${REMOVE_REPOS:-}" ] && sudo add-apt-repository -r -y ppa:cppiber/hyprland || true
[ -n "${REMOVE_REPOS:-}" ] && sudo rm -f /etc/apt/sources.list.d/vscode.list /usr/share/keyrings/ms_vscode.gpg && sudo apt update || true
if [ -n "${RESTORE_LIGHTDM:-}" ]; then
  sudo apt install -y lightdm
  sudo systemctl disable --now sddm || true
  sudo systemctl enable --now lightdm
fi
echo "Done. Consider: sudo reboot"
SH
chmod +x ~/uninstall-omabuntu.sh
~/uninstall-omabuntu.sh
```

Examples:

```bash
# Full revert: remove UI + dev + repos, restore LightDM
PURGE_DEV=1 REMOVE_REPOS=1 RESTORE_LIGHTDM=1 ~/uninstall-omabuntu.sh

# Just remove configs & Hyprland UI, keep your apps
KEEP_APPS=1 RESTORE_LIGHTDM=1 ~/uninstall-omabuntu.sh
```

---

## 🧾 License

MIT © 2025 **<Your Name>**.  
Feel free to fork, adapt, and PR improvements.

---

## 🙋 FAQ

**Q: I installed but still land in Xfce.**  
A: Log out → in the session menu pick **Hyprland** → log in. If autologin bypasses the menu, temporarily disable autologin or switch greeters to SDDM:
```bash
sudo apt install -y sddm
sudo systemctl disable --now lightdm || true
sudo systemctl enable --now sddm
```

**Q: Which key is “Super”?**  
A: The **Windows** key (PC), **⌘ Command** (Mac keyboards), often **GUI** on 60% boards.

**Q: Can I change the launcher?**  
A: Yes. Use `LAUNCHER=walker ./scripts/install.sh` (the script will build Walker via cargo). Keybind stays **Super+Space**.

**Q: How do I update later?**  
A: Use the menu → **System → Update (apt full-upgrade)** or run:
```bash
sudo apt update && sudo apt full-upgrade -y
```

