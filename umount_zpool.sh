#!/bin/bash

# 1. Unmount boot partitions
umount /mnt/boot/firmware
umount /mnt/boot

# 2. Unmount ZFS datasets (in reverse order of mounting)
umount /mnt/var/lib
umount /mnt/home
umount /mnt/var
umount /mnt/nix
umount /mnt

# 3. Export the ZFS pool
zpool export rpool
