#!/bin/bash

# Set terminal color to turquoise
echo -ne "\033]10;#00ffff\007"
echo -ne "\033]11;#000000\007"

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

# Function to execute a command without showing it
execute_command() {
    echo -e "${TURQUOISE}[EXEC] $1${NC}"
    eval "$1"
    return $?
}

# Function to display colored menu
show_menu() {
  clear
  echo -e "${TURQUOISE}"
  echo "╔══════════════════════════════════════╗"
  echo "║      Select Image Type               ║"
  echo "╠══════════════════════════════════════╣"
  echo "║ 1. squashfs/airootfs.sfs             ║"
  echo "║ 2. .img.xz                           ║"
  echo "╚══════════════════════════════════════╝"
  echo -e "${NC}"
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

# Show image type menu
while true; do
  show_menu
  read -p "Select image type [1-2]: " image_type
  
  case $image_type in
    1)
      read -p "Enter the full path to the squashfs/airootfs file (e.g., /path/to/filename.squashfs or airootfs.sfs): " image_file
      break
      ;;
    2)
      read -p "Enter the full path to the .img.xz file: " image_file
      echo -e "${TURQUOISE}Executing btrfsimgxz.sh script...${NC}"
      sudo bash btrfsimgxz.sh
      exit $?
      ;;
    *)
      echo "Invalid option, please try again."
      sleep 1
      ;;
  esac
done

# Ask for the username to use in the chown command
read -p "Enter the username for chown command (e.g., yourusername): " username

# Verify the inputs
if [[ -z "$drive" || -z "$image_file" || -z "$username" ]]; then
  echo "Error: Drive, image file path, and username must be provided."
  exit 1
fi

# Check if the drive exists
if [[ ! -e "$drive" ]]; then
  echo "Error: Drive $drive does not exist."
  exit 1
fi

# Check if the image file exists
if [[ ! -f "$image_file" ]]; then
  echo "Error: File $image_file does not exist."
  exit 1
fi

# Reset color before executing commands
echo -e "${NC}"

# Continue with the original squashfs processing

# Wipe the drive and create a new GPT partition table
echo -e "${TURQUOISE}Wiping drive and creating partitions...${NC}"
execute_command "sudo wipefs --all ${drive}"
execute_command "sudo parted -s ${drive} mklabel gpt"

# Create partitions
echo -e "${TURQUOISE}Creating partitions...${NC}"
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
echo -e "${TURQUOISE}Creating Btrfs subvolumes...${NC}"
execute_command "sudo btrfs subvolume create /mnt/@"
execute_command "sudo btrfs subvolume create /mnt/@cache"
execute_command "sudo btrfs subvolume create /mnt/@home"
execute_command "sudo btrfs subvolume create /mnt/@log"

# Unmount the root partition to remount with subvolumes
execute_command "sudo umount /mnt"

# Mount the root subvolume
execute_command "sudo mount -o subvol=@ ${drive}2 /mnt"

# Create directories for other subvolumes
execute_command "sudo mkdir -p /mnt/{boot/efi,cache,home,var/log}"

# Mount other subvolumes
execute_command "sudo mount -o subvol=@cache ${drive}2 /mnt/cache"
execute_command "sudo mount -o subvol=@home ${drive}2 /mnt/home"
execute_command "sudo mount -o subvol=@log ${drive}2 /mnt/var/log"

# Mount the EFI System Partition (ESP) to /boot/efi
execute_command "sudo mount ${drive}1 /mnt/boot/efi"

# Extract the image file directly to the root partition
echo -e "${TURQUOISE}Extracting system image...${NC}"
if [[ "$image_file" == *.squashfs || "$image_file" == *.sfs ]]; then
  echo -e "${TURQUOISE}Starting unsquashfs extraction... This may take a while.${NC}"
  sudo unsquashfs -f -d /mnt "$image_file"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to extract SquashFS image.${NC}"
    exit 1
  fi
else
  echo "Error: Unsupported image format. Only .squashfs and .sfs files are supported."
  exit 1
fi

# Set ownership for the user's home directory
echo -e "${TURQUOISE}Setting up user permissions...${NC}"
execute_command "sudo chown $username /mnt/home/$username"
execute_command "sudo chown $username /mnt/home/"

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
