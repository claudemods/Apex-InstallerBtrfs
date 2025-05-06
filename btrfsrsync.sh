#!/bin/bash
# Copyright (C) 2019-2025 by claudemods 
# Set turquoise console color
echo -e "\033[38;2;0;255;255m"

# ASCII Art Header
clear
echo -e "\033[1;31m"
cat << "EOF"
░█████╗░██╗░░░░░░█████╗░██╗░░░██╗██████╗░███████╗███╗░░░███╗░█████╗░██████╗░░██████╗
██╔══██╗██║░░░░░██╔══██╗██║░░░██║██╔══██╗██╔════╝████╗░████║██╔══██╗██╔══██╗██╔════╝
██║░░╚═╝██║░░░░░███████║██║░░░██║██║░░██║█████╗░░██╔████╔██║██║░░██║██║░░██║╚█████╗░
██║░░██╗██║░░░░░██╔══██║██║░░░██║██║░░██║██╔══╝░░██║╚██╔╝██║██║░░██║██║░░██║░╚═══██╗
╚█████╔╝███████╗██║░░██║╚██████╔╝██████╔╝███████╗██║░╚═╝░██║╚█████╔╝██████╔╝██████╔╝
░╚════╝░╚══════╝╚═╝░░░░░░╚═════╝░╚═════╝░╚══════╝╚═╝░░░░░╚═╝░╚════╝░╚═════╝░╚═════╝░
EOF
echo -e "\033[38;2;0;255;255mclaudemods Btrfs Installer Rsync v1.01 Build 06/05/2025\033[0m"
echo ""

set -euo pipefail  # Strict error handling

# --- USER INPUT ---
read -p "Enter drive (e.g., /dev/nvme0n1): " drive
read -p "Enter username: " username

# --- VALIDATE INPUTS ---
[[ -z "$drive" || -z "$username" ]] && { echo -e "\033[1;31mError: Missing inputs\033[0m" >&2; exit 1; }
[[ ! -e "$drive" ]] && { echo -e "\033[1;31mError: Drive $drive not found\033[0m" >&2; exit 1; }

# --- PARTITIONING ---
echo -e "\033[38;2;0;255;255m\n[1/6] Partitioning disk...\033[0m"
sudo wipefs --all "$drive"
sudo parted -s "$drive" mklabel gpt
sudo parted -s "$drive" mkpart primary fat32 1MiB 551MiB
sudo parted -s "$drive" set 1 esp on
sudo parted -s "$drive" mkpart primary btrfs 551MiB 100%

# --- FORMATTING ---
echo -e "\033[38;2;0;255;255m\n[2/6] Formatting partitions...\033[0m"
sudo mkfs.vfat -F32 "${drive}1"
sudo mkfs.btrfs -f "${drive}2"

# --- BTRFS SETUP ---
echo -e "\033[38;2;0;255;255m\n[3/6] Configuring Btrfs subvolumes...\033[0m"
sudo mount "${drive}2" /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@var_cache
sudo btrfs subvolume create /mnt/@var_log
sudo umount /mnt

# --- MOUNT HIERARCHY ---
echo -e "\033[38;2;0;255;255m\n[4/6] Mounting filesystems...\033[0m"
sudo mount -o subvol=@ "${drive}2" /mnt
sudo mkdir -p /mnt/{boot/efi,home,var/{cache,log}}
sudo mount -o subvol=@home "${drive}2" /mnt/home
sudo mount -o subvol=@var_cache "${drive}2" /mnt/var/cache
sudo mount -o subvol=@var_log "${drive}2" /mnt/var/log
sudo mount "${drive}1" /mnt/boot/efi

# --- SYSTEM DEPLOYMENT (RSYNC EVERYTHING FROM ROOT) ---
echo -e "\033[38;2;0;255;255m\n[5/6] RSYNC entire root filesystem...\033[0m"
sudo rsync -aHAXSr / /mnt/

# --- FSTAB (WITH FALLBACK) ---
sudo mkdir -p /mnt/etc
if ! sudo genfstab -U /mnt > /mnt/etc/fstab 2>/dev/null; then
    EFI_UUID=$(lsblk -no UUID "${drive}1")
    ROOT_UUID=$(lsblk -no UUID "${drive}2")
    sudo tee /mnt/etc/fstab <<EOF
UUID=$EFI_UUID  /boot/efi  vfat  umask=0077 0 2
UUID=$ROOT_UUID  /          btrfs  subvol=@,compress=zstd 0 0
UUID=$ROOT_UUID  /home      btrfs  subvol=@home,compress=zstd 0 0
UUID=$ROOT_UUID  /var/cache btrfs  subvol=@var_cache,compress=zstd 0 0
UUID=$ROOT_UUID  /var/log   btrfs  subvol=@var_log,compress=zstd 0 0
EOF
fi

# --- CHROOT FIXES ---
echo -e "\033[38;2;0;255;255m\n[6/6] Configuring bootloader...\033[0m"
sudo arch-chroot /mnt /bin/bash -c "
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck || exit 1
    grub-mkconfig -o /boot/grub/grub.cfg || exit 1
    mkinitcpio -P || exit 1
" || { echo -e "\033[1;31mChroot commands failed\033[0m" >&2; exit 1; }

# --- FINAL CONFIG ---
sudo chown -R "$username:" /mnt/home/"$username"
sudo umount -R /mnt 2>/dev/null || true

# --- POST-INSTALL MENU ---
while true; do
    clear
    echo -e "\033[1;31m"
    echo "╔══════════════════════════════════════╗"
    echo "║        Post-Install Menu             ║"
    echo "╠══════════════════════════════════════╣"
    echo "║ 1. Chroot into installed system      ║"
    echo "║ 2. Reboot                            ║"
    echo "║ 3. Exit                              ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "\033[38;2;0;255;255m"
    read -p "Select option (1-3): " choice

    case $choice in
        1)  # CHROOT
            echo -e "\033[38;2;0;255;255mPreparing chroot environment...\033[0m"
            sudo mount "${drive}2" /mnt -o subvol=@
            sudo mount "${drive}1" /mnt/boot/efi
            sudo mount -o subvol=@home "${drive}2" /mnt/home
            sudo mount -o subvol=@var_cache "${drive}2" /mnt/var/cache
            sudo mount -o subvol=@var_log "${drive}2" /mnt/var/log
            echo -e "\033[1;32mEntering chroot. Type 'exit' when done.\033[0m"
            sudo arch-chroot /mnt /bin/bash
            sudo umount -R /mnt
            ;;
        2)  # REBOOT
            echo -e "\033[1;33mRebooting in 3 seconds...\033[0m"
            sleep 3
            sudo reboot
            ;;
        3)  # EXIT
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Try again.\033[0m"
            sleep 2
            ;;
    esac
done
