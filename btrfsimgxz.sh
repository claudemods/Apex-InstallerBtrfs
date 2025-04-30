#!/bin/bash

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
sudo wipefs --all ${drive}
sudo parted -s ${drive} mklabel gpt

# Create partitions
sudo parted -s ${drive} mkpart primary fat32 1MiB 551MiB  # EFI System Partition
sudo parted -s ${drive} set 1 esp on  # Set the ESP flag
sudo parted -s ${drive} mkpart primary btrfs 551MiB 100%  # Root partition (Btrfs)

# Format partitions
sudo mkfs.vfat ${drive}1  # Format ESP as FAT32
sudo mkfs.btrfs -f ${drive}2  # Format root partition as Btrfs

# Mount the root partition
sudo mount ${drive}2 /mnt

# Create Btrfs subvolumes for the folder layout
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@cache
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@log

# Unmount the root partition to remount with subvolumes
sudo umount /mnt

# Mount the root subvolume
sudo mount -o subvol=@ ${drive}2 /mnt

# Create directories for other subvolumes
sudo mkdir -p /mnt/{boot/efi,cache,home,var/log,temp,temp_mount}

# Mount other subvolumes
sudo mount -o subvol=@cache ${drive}2 /mnt/cache
sudo mount -o subvol=@home ${drive}2 /mnt/home
sudo mount -o subvol=@log ${drive}2 /mnt/var/log

# Mount the EFI System Partition (ESP) to /boot/efi
sudo mount ${drive}1 /mnt/boot/efi

# Execute the img.xz.sh script with the provided path and filename
sudo ./img.xz.sh "$img_xz_file"

# Mount the temporary image
sudo mount -o loop /mnt/temp/temp.img /mnt/temp_mount

# Copy contents from the temporary image to the root partition
sudo rsync -a /mnt/temp_mount/ /mnt/

# Create the user's home directory as a folder (not a subvolume)



# First chown command (for /mnt/home)
# Second chown command (for /mnt/@/home/username)
sudo chown $username:$username /mnt/home/$username
sudo chown $username:$username /mnt/home/


# Unmount and clean up
sudo umount /mnt/temp_mount
sudo rm /mnt/temp/temp.img
sudo rmdir /mnt/temp
sudo rmdir /mnt/temp_mount

# Generate fstab
sudo genfstab -U -p /mnt >> /mnt/etc/fstab

# Execute the chrootfix.sh script
sudo ./chrootfix.sh

# Unmount everything
sudo umount -l /mnt/boot/efi
sudo umount -l /mnt

echo "Setup completed successfully!"
