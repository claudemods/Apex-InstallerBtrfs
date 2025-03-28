<div align="center">
Apex-InstallerBtrfs
	<div align="center">
Simple Script To Install Cloned Arch Systems As btrfs 

<div align="center">
  <a href="https://www.linux.org" target="_blank"><img src="https://img.shields.io/badge/OS-Linux-e06c75?style=for-the-badge&logo=linux" /></a>
	<a href="https://archlinux.org" target="_blank"><img src="https://img.shields.io/badge/DISTRO-Arch-56b6c2?style=for-the-badge&logo=arch-linux" /></a>
 
<div align="center" style="line-height: 3;">
  <a href="https://www.deepseek.com/" target="_blank">
    <img 
      alt="Homepage" 
      src="https://i.postimg.cc/Hs2vbbZ8/Deep-Seek-Homepage.png?raw=true" 
      style="height: 30px; width: auto;" 
    />
  </a>


you can install a .squashfs or .img.xz


this will ask you for a drive e.g /dev/sda or /dev/vda or /dev/sdb ect


then will then ask you for a location of a .squashfs or .img.xz

default location you might need for .squashfs is /run/archiso/bootmnt/arch/x86_64/airootfs.sfs

after you input a location 

this will then setup your drive as gpt btrfs

Drives Will Be e.g sda1 for efi and e.g sda2 for your linux root filesystem

This will not setup a seperate swap

![main menu](https://github.com/user-attachments/assets/ff69074f-b25a-430f-9cc7-33cda246983d)
