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
                # Chroot into the installed system (using only drive 2)
                local mount_point="/mnt"
                local drive2="${drive}2"
                
                echo -e "${TURQUOISE}Mounting ${drive2} to ${mount_point}${NC}"
                execute_command "sudo mount ${drive2} ${mount_point}"
                
                # Bind necessary directories for chroot
                execute_command "sudo mount --bind /dev ${mount_point}/dev"
                execute_command "sudo mount --bind /dev/pts ${mount_point}/dev/pts"
                execute_command "sudo mount --bind /sys ${mount_point}/sys"
                execute_command "sudo mount --bind /proc ${mount_point}/proc"
                
                # Chroot into the system
                echo -e "${TURQUOISE}Entering chroot...${NC}"
                execute_command "sudo arch-chroot ${mount_point}"
                
                # Unmount after exiting chroot
                echo -e "${TURQUOISE}Unmounting chroot environment...${NC}"
                execute_command "sudo umount ${mount_point}/dev/pts"
                execute_command "sudo umount ${mount_point}/dev"
                execute_command "sudo umount ${mount_point}/sys"
                execute_command "sudo umount ${mount_point}/proc"
                execute_command "sudo umount ${mount_point}"
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
execute_command "sudo btrfs subvolume create /mnt/@cache"
execute_command "sudo btrfs subvolume create /mnt/@home"
execute_command "sudo btrfs subvolume create /mnt/@log"

# Unmount the root partition to remount with subvolumes
execute_command "sudo umount /mnt"

# Mount the root subvolume
execute_command "sudo mount -o subvol=@ ${drive}2 /mnt"

# Create directories for other subvolumes
execute_command "sudo mkdir -p /mnt/{boot/efi,cache,home,var/log,temp,temp_mount}"

# Mount other subvolumes
execute_command "sudo mount -o subvol=@cache ${drive}2 /mnt/cache"
execute_command "sudo mount -o subvol=@home ${drive}2 /mnt/home"
execute_command "sudo mount -o subvol=@log ${drive}2 /mnt/var/log"

# Mount the EFI System Partition (ESP) to /boot/efi
execute_command "sudo mount ${drive}1 /mnt/boot/efi"

# Execute the img.xz.sh script with the provided path and filename
echo -e "${TURQUOISE}Extracting system image...${NC}"
execute_command "sudo ./img.xz.sh \"$img_xz_file\""

# Mount the temporary image
execute_command "sudo mount -o loop /mnt/temp/temp.img /mnt/temp_mount"

# Copy contents from the temporary image to the root partition
execute_command "sudo rsync -a /mnt/temp_mount/ /mnt/"

# Set ownership for the user's home directory
echo -e "${TURQUOISE}Setting up user permissions...${NC}"
execute_command "sudo chown $username:$username /mnt/home/$username"
execute_command "sudo chown $username:$username /mnt/home/"

# Unmount and clean up
echo -e "${TURQUOISE}Cleaning up temporary files...${NC}"
execute_command "sudo umount /mnt/temp_mount"
execute_command "sudo rm /mnt/temp/temp.img"
execute_command "sudo rmdir /mnt/temp"
execute_command "sudo rmdir /mnt/temp_mount"

# Generate fstab
echo -e "${TURQUOISE}Generating fstab...${NC}"
execute_command "sudo genfstab -U -p /mnt >> /mnt/etc/fstab"

# Execute the chrootfix.sh script
echo -e "${TURQUOISE}Running chrootfix.sh...${NC}"
execute_command "sudo ./chrootfix.sh"

# Unmount everything
echo -e "${TURQUOISE}Unmounting partitions...${NC}"
execute_command "sudo umount -l /mnt/boot/efi"
execute_command "sudo umount -l /mnt"

# Installation complete message
echo -e "${TURQUOISE}"
echo "╔══════════════════════════════════════╗"
echo "║      Installation Complete!         ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# Show post-install menu
post_install_menu "$drive"
