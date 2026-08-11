#!/bin/bash

# Timeshift + Cronie setup script (Arch Linux)

set -euo pipefail

is_installed() {
    pacman -Qs "$1" &>/dev/null
}

is_active() {
    systemctl is-active "$1" &>/dev/null
}

echo "[*] Checking root filesystem..."
rootfs=$(findmnt -no FSTYPE /)
if [[ "$rootfs" == "btrfs" ]]; then
    echo "[+] btrfs detected - Timeshift snapshots supported"
else
    echo "[!] Root filesystem is $rootfs. Timeshift snapshots require btrfs."
    read -rp "Continue anyway? [y/N]: " choice
    [[ "$choice" == [Yy]* ]] || { echo "Aborted."; exit 1; }
fi

cmds=()

echo "[*] Checking Timeshift..."
if is_installed timeshift; then
    echo "[+] Timeshift already installed"
else
    cmds+=('pacman -S --noconfirm timeshift')
fi

echo "[*] Checking Cronie..."
if is_installed cronie; then
    echo "[+] Cronie already installed"
else
    cmds+=('pacman -S --noconfirm cronie')
fi

if is_active cronie; then
    echo "[+] Cronie service already running"
else
    cmds+=('systemctl enable --now cronie.service')
fi

grub_btrfs=0
echo "[*] Checking grub-btrfs..."
if is_installed grub-btrfs; then
    if is_active grub-btrfsd; then
        echo "[+] grub-btrfs daemon running - snapshots appear in GRUB menu"
    else
        cmds+=('systemctl enable --now grub-btrfsd.service')
        grub_btrfs=1
    fi
else
    echo "[!] grub-btrfs not installed - snapshots won't show in GRUB"
    read -rp "Install grub-btrfs? [y/N]: " choice
    if [[ "$choice" == [Yy]* ]]; then
        cmds+=('pacman -S --noconfirm grub-btrfs')
        cmds+=('systemctl enable --now grub-btrfsd.service')
        grub_btrfs=1
    fi
fi

if (( ${#cmds[@]} == 0 )); then
    echo "[+] Nothing to do - everything already set up."
else
    echo "[*] Applying ${#cmds[@]} privileged step(s) with a single authentication..."
    printf -v script '%s\n' "${cmds[@]}"
    pkexec bash -c "$script"
fi

echo "[+] Done."
if (( grub_btrfs )); then
    echo "    Regenerate GRUB menu to pick up new snapshots:"
    echo "      pkexec grub-mkconfig -o /boot/grub/grub.cfg"
fi
echo "    Configure snapshot schedules:"
echo "      GUI:   pkexec timeshift-gtk"
echo "      CLI:   pkexec timeshift --create --comments <note>"
