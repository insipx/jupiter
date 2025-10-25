#!/bin/bash

zpool import -f rpool && \
mount -t zfs rpool/system/root /mnt && \
mkdir -p /mnt/{nix,var,home,boot/firmware,var/lib} && \
mount -t zfs rpool/local/nix /mnt/nix && \
mount -t zfs rpool/system/var /mnt/var && \
mount -t zfs rpool/safe/home /mnt/home && \
mount -t zfs rpool/safe/var/lib /mnt/var/lib && \
mount /dev/nvme0n1p2 /mnt/boot && \
mount /dev/nvme0n1p1 /mnt/boot/firmware
