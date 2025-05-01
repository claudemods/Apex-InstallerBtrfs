#!/bin/bash
# Color definitions
RED='\033[0;31m'
TURQUOISE='\033[38;2;0;255;255m'
NC='\033[0m' # No Color

# Display ASCII art header
echo -e "${RED}"
cat << "EOF"
░█████╗░██╗░░░░░░█████╗░██╗░░░██╗██████╗░███████╗███╗░░░███╗░█████╗░██████╗░░██████╗
██╔══██╗██║░░░░░██╔══██╗██║░░░██║██╔══██╗██╔════╝████╗░████║██╔══██╗██╔══██╗██╔════╝
██║░░╚═╝██║░░░░░███████║██║░░░██║██║░░██║█████╗░░██╔████╔██║██║░░██║██║░░██║╚█████╗░
██║░░██╗██║░░░░░██╔══██║██║░░░██║██║░░██║██╔══╝░░██║╚██╔╝██║██║░░██║██║░░██║░╚═══██╗
╚█████╔╝███████╗██║░░██║╚██████╔╝██████╔╝███████╗██║░╚═╝░██║╚█████╔╝██████╔╝██████╔╝
░╚════╝░╚══════╝╚═╝░░░░░░╚═════╝░╚═════╝░╚══════╝╚═╝░░░░░╚═╝░╚════╝░╚═════╝░╚═════╝░
EOF
echo -e "${TURQUOISE}Apex btrfs installer v1.01${NC}"
echo ""

# Function to execute a command with output
execute_command() {
    echo -e "${TURQUOISE}Executing: $1${NC}"
    eval "$1"
    return $?
}

# img.xz handler
handle_img_xz() {
    if [ -z "$1" ]; then
        echo "Usage: $0 <path_to_img.xz_file>"
        exit 1
    fi

    input_file="$1"
    execute_command "sudo mkdir -p /mnt/temp"
    execute_command "sudo xz -d -k -c --ignore-check \"$input_file\" > /mnt/temp/temp.img"

    if [ $? -eq 0 ]; then
        echo "Decompression successful. Output saved to /mnt/temp/temp.img"
        execute_command "sudo mount -o loop /mnt/temp/temp.img /mnt/temp_mount"
        execute_command "sudo rsync -a /mnt/temp_mount/ /mnt/"
    else
        echo "Decompression failed."
        exit 1
    fi
}

# chroot fix commands
chroot_fix() {
    echo -e "${TURQUOISE}Running chroot fixes...${NC}"
    execute_command "sudo arch-chroot /mnt /bin/bash -c 'grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck'"
    execute_command "sudo arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg"
    execute_command "sudo arch-chroot /mnt mkinitcpio -P"
}

# Post-install menu function
post_install_menu() {
    local drive=$1
    while true; do
        echo -e "${TURQUOISE}"
        echo "╔══════════════════════════════════════╗"
        echo "║        Post-Install Menu             ║"
        echo "╠══════════════════════════════════════╣"
        echo "║ 1. Chroot into installed system      ║"
        echo "║ 2. Reboot                            ║"
        echo "║ 3. Exit                              ║"
        echo "╚══════════════════════════════════════╝"
        echo -n -e "${NC}Enter your choice (1/2/3): "
        read -r choice

        case $choice in
            1)
                # Mount exactly as you requested
                echo -e "${TURQUOISE}Mounting partitions for chroot...${NC}"
                execute_command "sudo mount ${drive}1 /mnt/boot/efi"  # EFI partition
                execute_command "sudo mount -o subvol=@ ${drive}2 /mnt"  # Root subvolume
                execute_command "sudo mount -o subvol=@home "${drive}2" /mnt/home"  # Root subvolume
                execute_command "sudo mount -o subvol=@var_cache "${drive}2" /mnt/var/cache"  # Root subvolume
                execute_command "sudo mount -o subvol=@var_log "${drive}2" /mnt/var/log"  # Root subvolume

                # Chroot into the system
                echo -e "${TURQUOISE}Entering chroot...${NC}"
                execute_command "sudo arch-chroot /mnt"

                # Unmount after exiting chroot
                echo -e "${TURQUOISE}Unmounting chroot environment...${NC}"
                execute_command "sudo umount /mnt/boot/efi"
                execute_command "sudo umount /mnt"
                ;;
            2)
                # Reboot the system
                echo -e "${TURQUOISE}Rebooting system...${NC}"
                execute_command "sudo reboot"
                exit 0
                ;;
            3)
                # Exit the program
                echo -e "${TURQUOISE}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${TURQUOISE}Invalid choice. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Main script execution
echo -e "${TURQUOISE}"

# Ask for the drive to use
read -p "Enter the drive to use (e.g., /dev/sdX): " drive

# Ask for the full path to the img.xz file
read -p "Enter the full path to the img.xz file (e.g., /path/to/filename.img.xz): " img_xz_file

# Ask for the username to use in the chown command
read -p "Enter the username for chown command (e.g., yourusername): " username

# Verify the inputs
if [[ -z "$drive" || -z "$img_xz_file" || -z "$username" ]]; then
  echo "Error: Drive, img.xz file path, and username must be provided."
  exit 1
fi

# Check if the drive exists
if [[ ! -e "$drive" ]]; then
  echo "Error: Drive $drive does not exist."
  exit 1
fi

# Check if the img.xz file exists
if [[ ! -f "$img_xz_file" ]]; then
  echo "Error: File $img_xz_file does not exist."
  exit 1
fi

# Wipe the drive and create a new GPT partition table
echo -e "${TURQUOISE}Wiping drive and creating partitions...${NC}"
execute_command "sudo wipefs --all ${drive}"
execute_command "sudo parted -s ${drive} mklabel gpt"

# Create partitions
execute_command "sudo parted -s ${drive} mkpart primary fat32 1MiB 551MiB"  # EFI System Partition
execute_command "sudo parted -s ${drive} set 1 esp on"  # Set the ESP flag
execute_command "sudo parted -s ${drive} mkpart primary btrfs 551MiB 100%"  # Root partition (Btrfs)

# Format partitions
echo -e "${TURQUOISE}Formatting partitions...${NC}"
execute_command "sudo mkfs.vfat ${drive}1"  # Format ESP as FAT32
execute_command "sudo mkfs.btrfs -f ${drive}2"  # Format root partition as Btrfs

# Mount the root partition
echo -e "${TURQUOISE}Setting up Btrfs subvolumes...${NC}"
execute_command "sudo mount ${drive}2 /mnt"

# Create Btrfs subvolumes for the folder layout
execute_command "sudo btrfs subvolume create /mnt/@"
execute_command "sudo btrfs subvolume create /mnt/@home"
execute_command "sudo btrfs subvolume create /mnt/@var_log"

# Unmount the root partition to remount with subvolumes
execute_command "sudo umount /mnt"

# Mount the root subvolume
execute_command "sudo mount -o subvol=@ ${drive}2 /mnt"

# Create directories for other subvolumes
execute_command "sudo mkdir -p /mnt/{boot/efi,home,var/log,temp,temp_mount}"

# Mount other subvolumes
execute_command "sudo mount -o subvol=@home ${drive}2 /mnt/home"
execute_command "sudo mount -o subvol=@var_log ${drive}2 /mnt/var/log"

# Mount the EFI System Partition (ESP) to /boot/efi
execute_command "sudo mount ${drive}1 /mnt/boot/efi"

# Handle the img.xz file
echo -e "${TURQUOISE}Extracting system image...${NC}"
handle_img_xz "$img_xz_file"

# Set ownership for the user's home directory
echo -e "${TURQUOISE}Setting up user permissions...${NC}"
execute_command "sudo chown $username /mnt/home/$username"
execute_command "sudo chown $username /mnt/home/"

# Generate proper fstab with correct subvolume paths
echo -e "${TURQUOISE}Generating fstab...${NC}"
execute_command "sudo mkdir -p /mnt/etc"
{
    echo "# /etc/fstab"
    echo "UUID=$(lsblk -no UUID ${drive}1)  /boot/efi  vfat  umask=0077 0 2"
    echo "UUID=$(lsblk -no UUID ${drive}2)  /          btrfs  subvol=@ 0 0"
    echo "UUID=$(lsblk -no UUID ${drive}2)  /home      btrfs  subvol=@home 0 0"
    echo "UUID=$(lsblk -no UUID ${drive}2)  /var/log   btrfs  subvol=@var_log 0 0"
} | sudo tee /mnt/etc/fstab >/dev/null

# Run chroot fixes
chroot_fix

# Clean up temporary files
echo -e "${TURQUOISE}Cleaning up temporary files...${NC}"
execute_command "sudo umount /mnt/temp_mount"
execute_command "sudo rm /mnt/temp/temp.img"
execute_command "sudo rmdir /mnt/temp"
execute_command "sudo rmdir /mnt/temp_mount"

# Unmount everything
echo -e "${TURQUOISE}Unmounting partitions...${NC}"
execute_command "sudo umount -R /mnt"

# Installation complete message
echo -e "${TURQUOISE}"
echo "╔══════════════════════════════════════╗"
echo "║      Installation Complete!         ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# Show post-install menu
post_install_menu "$drive"
