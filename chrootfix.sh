sudo arch-chroot /mnt /bin/bash -c grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
sudo arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
sudo arch-chroot /mnt mkinitcpio -P
