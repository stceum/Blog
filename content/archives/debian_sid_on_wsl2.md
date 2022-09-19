---
title: "Debian sid with systemd on WSL2"
date: 2022-09-19T14:22:49+08:00
draft: false
---

***

{{% center %}}
This is the backup page for [Debian sid with systemd on WSL2](https://gist.github.com/fardjad/7ee02761fdaa6b620e0ee8a715121883)

written by [fardjad](https://gist.github.com/fardjad)

Connet [me](mailto:zh_elepika@126.com) if this page bothers you and I will delete it.
{{% /center %}}

***

# Debian sid with systemd on WSL2
> Instructions for running Debian sid with systemd on WSL2

## Instructions

1. Make sure you're running Windows 10 Build 19041+ (run `ver`)
2. [Enable the Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/install-on-server) (reboot if needed):

		# In an elevated PowerShell session
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
               
3. Follow the instructions on [this page](https://docs.microsoft.com/en-us/windows/wsl/install-on-server#extract-and-install-a-linux-distribution) or install a Linux distro from the Microsoft Store (this is required for preparing a Debian sid WSL distro)

4. [Download](https://cdimage.debian.org/cdimage/cloud/sid/daily) the latest Debian sid cloud image. Make sure to download the latest `.tar.xz` file for your processor architecture (ex. `debian-sid-generic-amd64-daily-20200710-323.tar.xz`)

5. Create a rootfs archive from the downloaded sid image:

		# In WSL (assuming you're running Debian Linux)
        
        
        # Extract the disk image from the archive
        # Make sure tar and xz-tools are installed (ie. apt install tar xz-utils)
        
        tar xf debian-sid-generic-*.tar.xz
        
        
        # mount the Linux filesystem
        # make sure fdisk, grep, and gawk are installed (ie. apt install fdisk grep gawk)
        
        sector_size=$(/sbin/fdisk -l disk.raw | grep 'Sector size' | grep -Po '\K([0-9]+)(?= bytes$)')
        start=$(/sbin/fdisk -l disk.raw | grep 'Linux filesystem' | awk '{ print $2 }')
        offset=$(($start * $sector_size))
        
        sudo mkdir -p /mnt/sid
        sudo mount -o loop,offset=$offset disk.raw /mnt/sid
        
        
        # Create a rootfs `tar.gz` archive
        
        sudo tar -C /mnt/sid -cpzf debian-sid.tar.gz .
        sudo chown $(id -un):$(id -gn) debian-sid.tar.gz
        
6. Open File Explorer, navigate to `\\wsl$\name-of-the-distro`, and move the rootfs archive file to a directory accessible to Windows
7. Open a PowerShell prompt in the directory containing the rootfs archive and import it:

		wsl --import debian-sid \path\to\the\directory\you\want\to\install\debian-sid\into debian-sid.tar.gz --version 2
        
8. Start a shell in Debian sid and run the following commands:

        # Update the OS
        apt update
        apt full-upgrade -y
        
        # Make sure sudo is installed
        apt install sudo
        
9. Edit `/etc/adduser.conf` and set `ADD_EXTRA_GROUPS` to 1
10. Create a non-root (ie. `adduser YOUR_USERNAME`)
11. Edit `/etc/wsl.conf` and make sure the following lines exist in the file:

		[user]
		default = YOUR_USERNAME
        
12. Restart WSL:

		# In PowerShell
        wsl --shutdown
        wsl -d debian-sid
        
13. Remove unnecessary packages/files:

		apt remove --purge 'grub-*' 'linux-image-*'
        rm -rf /boot/*
        rm -rf /lost+found

14. **TODO: Adapt [this](https://github.com/DamionGans/ubuntu-wsl2-systemd-script)**

15. Create a file in `/etc/profile.d/wsl.sh` with the following contents:

		# Start or enter a PID namespace in WSL2
        source /usr/sbin/start-systemd-namespace
        
        # TODO: move the following lines into a script and allow running it script without a password (ie. /etc/sudoers.d/...)
        sudo systemctl default
        sudo systemctl reset-failed
        
16. Mask the services with `not-found` state:

		TODO: do something with the output of the following command (possibly pipe to xargs systemctl mask)
        systemctl --plain --no-legend --no-pager --state=not-found --all | awk '{ print $1 }'