#include <iostream>
#include <string>
#include <vector>
#include <cstdlib>
#include <filesystem>
#include <unistd.h> // For usleep (progress bar animation)

namespace fs = std::filesystem;

// Function to execute shell commands silently
void executeCommand(const std::string& command) {
    int result = std::system(command.c_str());
    if (result != 0) {
        std::cerr << "Command failed: " << command << std::endl;
        exit(1);
    }
}

// Function to display a progress bar
void displayProgressBar(int progress) {
    std::cout << "\r[";
    int pos = progress / 2;
    for (int i = 0; i < 50; ++i) {
        if (i < pos) std::cout << "\033[32m#\033[0m"; // Green
        else std::cout << " ";
    }
    std::cout << "] " << progress << " %";
    std::cout.flush();
}

// Function to handle .squashfs or .airootfs.sfs installation
void installSquashfs(const std::string& drive, const std::string& squashfsFile, const std::string& username) {
    std::vector<std::string> commands = {
        "sudo umount -l " + drive + "* 2>/dev/null",  // Unmount all partitions
        "sudo wipefs --all " + drive,  // Wipe the drive
        "sudo parted -s " + drive + " mklabel gpt",  // Create GPT partition table
        "sudo parted -s " + drive + " mkpart primary fat32 1MiB 551MiB",  // EFI System Partition
        "sudo parted -s " + drive + " set 1 esp on",  // Set ESP flag
        "sudo parted -s " + drive + " mkpart primary btrfs 551MiB 100%",  // Root partition
        "sudo mkfs.vfat " + drive + "1",  // Format ESP as FAT32
        "sudo mkfs.btrfs " + drive + "2",  // Format root partition as Btrfs
        "sudo mount " + drive + "2 /mnt",  // Mount root partition
        "sudo btrfs subvolume create /mnt/@",  // Create root subvolume
        "sudo btrfs subvolume create /mnt/@cache",  // Create cache subvolume
        "sudo btrfs subvolume create /mnt/@home",  // Create home subvolume
        "sudo btrfs subvolume create /mnt/@log",  // Create log subvolume
        "sudo umount /mnt",  // Unmount root partition
        "sudo mount -o subvol=@ " + drive + "2 /mnt",  // Mount root subvolume
        "sudo mkdir -p /mnt/{boot/efi,cache,home,var/log}",  // Create directories
        "sudo mount -o subvol=@cache " + drive + "2 /mnt/cache",  // Mount cache subvolume
        "sudo mount -o subvol=@home " + drive + "2 /mnt/home",  // Mount home subvolume
        "sudo mount -o subvol=@log " + drive + "2 /mnt/var/log",  // Mount log subvolume
        "sudo mount " + drive + "1 /mnt/boot/efi",  // Mount ESP
        "sudo unsquashfs -f -d /mnt " + squashfsFile,  // Extract squashfs file
        "sudo chown " + username + " /mnt/home",  // Set ownership for /mnt/home
        "sudo genfstab -U -p /mnt >> /mnt/etc/fstab",  // Generate fstab
        "sudo ./chrootfix.sh",  // Execute chrootfix.sh
        "sudo umount -l /mnt/boot/efi",  // Unmount ESP
        "sudo umount -l /mnt"  // Unmount root partition
    };

    // Execute all commands for .squashfs or .airootfs.sfs
    for (size_t i = 0; i < commands.size(); ++i) {
        executeCommand(commands[i]);

        // Update progress bar at key stages
        if (i == 7) displayProgressBar(25); // After mkfs.btrfs
        else if (i == 19) displayProgressBar(50); // After unsquashfs
        else if (i == 21) displayProgressBar(75); // After genfstab
        else if (i == 22) displayProgressBar(85); // After chrootfix.sh
        else if (i == 23) displayProgressBar(100); // After umount
    }

    std::cout << "\nSquashfs setup completed successfully!" << std::endl;
}

// Function to handle .img.xz installation
void installImgXz(const std::string& drive, const std::string& imgXzFile, const std::string& username) {
    std::vector<std::string> commands = {
        "sudo umount -l " + drive + "* 2>/dev/null",  // Unmount all partitions
        "sudo wipefs --all " + drive,  // Wipe the drive
        "sudo parted -s " + drive + " mklabel gpt",  // Create GPT partition table
        "sudo parted -s " + drive + " mkpart primary fat32 1MiB 551MiB",  // EFI System Partition
        "sudo parted -s " + drive + " set 1 esp on",  // Set ESP flag
        "sudo parted -s " + drive + " mkpart primary btrfs 551MiB 100%",  // Root partition
        "sudo mkfs.vfat " + drive + "1",  // Format ESP as FAT32
        "sudo mkfs.btrfs " + drive + "2",  // Format root partition as Btrfs
        "sudo mount " + drive + "2 /mnt",  // Mount root partition
        "sudo btrfs subvolume create /mnt/@",  // Create root subvolume
        "sudo btrfs subvolume create /mnt/@cache",  // Create cache subvolume
        "sudo btrfs subvolume create /mnt/@home",  // Create home subvolume
        "sudo btrfs subvolume create /mnt/@log",  // Create log subvolume
        "sudo umount /mnt",  // Unmount root partition
        "sudo mount -o subvol=@ " + drive + "2 /mnt",  // Mount root subvolume
        "sudo mkdir -p /mnt/{boot/efi,cache,home,var/log,temp,temp_mount}",  // Create directories
        "sudo mount -o subvol=@cache " + drive + "2 /mnt/cache",  // Mount cache subvolume
        "sudo mount -o subvol=@home " + drive + "2 /mnt/home",  // Mount home subvolume
        "sudo mount -o subvol=@log " + drive + "2 /mnt/var/log",  // Mount log subvolume
        "sudo mount " + drive + "1 /mnt/boot/efi",  // Mount ESP
        "sudo ./img.xz.sh " + imgXzFile,  // Execute img.xz.sh script
        "sudo mount -o loop /mnt/temp/temp.img /mnt/temp_mount",  // Mount temporary image
        "sudo rsync -a /mnt/temp_mount/ /mnt/",  // Copy contents to root partition
        "sudo chown " + username + " /mnt/home",  // Set ownership for /mnt/home
        "sudo umount /mnt/temp_mount",  // Unmount temporary image
        "sudo rm /mnt/temp/temp.img",  // Remove temporary image
        "sudo rmdir /mnt/temp",  // Remove temp directory
        "sudo rmdir /mnt/temp_mount",  // Remove temp_mount directory
        "sudo genfstab -U -p /mnt >> /mnt/etc/fstab",  // Generate fstab
        "sudo ./chrootfix.sh",  // Execute chrootfix.sh
        "sudo umount -l /mnt/boot/efi",  // Unmount ESP
        "sudo umount -l /mnt"  // Unmount root partition
    };

    // Execute all commands for .img.xz
    for (size_t i = 0; i < commands.size(); ++i) {
        executeCommand(commands[i]);

        // Update progress bar at key stages
        if (i == 7) displayProgressBar(25); // After mkfs.btrfs
        else if (i == 22) displayProgressBar(50); // After rsync
        else if (i == 28) displayProgressBar(75); // After genfstab
        else if (i == 29) displayProgressBar(85); // After chrootfix.sh
        else if (i == 30) displayProgressBar(100); // After umount
    }

    std::cout << "\nImg.xz setup completed successfully!" << std::endl;
}

int main() {
    // Start ./cyan in the background and keep it running
    executeCommand("./cyan &");

    // Display ASCII art in red
    std::cout << "\033[31m" << R"(
░█████╗░██╗░░░░░░█████╗░██╗░░░██╗██████╗░███████╗███╗░░░███╗░█████╗░██████╗░░██████╗
██╔══██╗██║░░░░░██╔══██╗██║░░░██║██╔══██╗██╔════╝████╗░████║██╔══██╗██╔══██╗██╔════╝
██║░░╚═╝██║░░░░░███████║██║░░░██║██║░░██║█████╗░░██╔████╔██║██║░░██║██║░░██║╚█████╗░
██║░░██╗██║░░░░░██╔══██║██║░░░██║██║░░██║██╔══╝░░██║╚██╔╝██║██║░░██║██║░░██║░╚═══██╗
╚█████╔╝███████╗██║░░██║╚██████╔╝██████╔╝███████╗██║░╚═╝░██║╚█████╔╝██████╔╝██████╔╝
░╚════╝░╚══════╝╚═╝░░░░░░╚═════╝░╚═════╝░╚══════╝╚═╝░░░░░╚═╝░╚════╝░╚═════╝░╚═════╝░
)" << "\033[0m" << std::endl;

// Display message in color 38;2;0;255;255m
std::cout << "\033[38;2;0;255;255mApex Installer Btrfs v1.02\033[0m" << std::endl;

std::string drive, filePath, username;

// Ask for the drive to use (in green)
std::cout << "\033[32mEnter the drive to use (e.g., /dev/sdX): \033[0m";
std::getline(std::cin, drive);

// Ask for the full path to the file (in green)
std::cout << "\033[32mEnter the full path to the file (e.g., /path/to/filename.img.xz, /path/to/filename.squashfs, or /path/to/filename.airootfs.sfs): \033[0m";
std::getline(std::cin, filePath);

// Ask for the username (in green)
std::cout << "\033[32mEnter the username for chown command (e.g., yourusername): \033[0m";
std::getline(std::cin, username);

// Check if the file is .img.xz, .squashfs, or .airootfs.sfs
if (filePath.find(".img.xz") != std::string::npos) {
    installImgXz(drive, filePath, username);
} else if (filePath.find(".squashfs") != std::string::npos ||
    filePath.find(".airootfs.sfs") != std::string::npos) {
    installSquashfs(drive, filePath, username);
    } else {
        std::cerr << "Error: Unsupported file type. Please provide a .img.xz, .squashfs, or .airootfs.sfs file." << std::endl;
        return 1;
    }

    return 0;
}
