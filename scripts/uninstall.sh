#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

read -rp "This will remove configs and the menu. Continue? [y/N] " a
[[ "$a" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

rm -rf ~/.config/hypr ~/.config/waybar ~/.config/mako ~/.config/environment.d/99-hyprland.conf
sudo rm -f /usr/local/bin/omarchy-menu

echo "Configs removed. Display manager unchanged."
echo "If you switched from LightDM to SDDM and want to revert:"
echo "  sudo systemctl disable --now sddm && sudo systemctl enable --now lightdm"
echo "Done."
