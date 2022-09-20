---
title: 关于部署舒适的 WSL 开发环境
date: 2022-09-10T16:53:50+08:00
draft: false
tags: wsl
---

本来安装的 Linux 和 Windows 的双系统，结果学习、上课都需要腾讯会议、钉钉、QQ、微信，在 Linux 上用着很不舒服：腾讯会议阉割了功能，钉钉直播时无法正常接收同学、老师在直播间发的消息，QQ 和微信各种 bug 和卡顿以及十分违和的 wine、deepin wine。 无奈，迁移回 Windows 系统。

回到 Windows 后，虽然日常生活舒服了很多，但是开发过程需要运行的 Linux 脚本无法在 Windows 上运行，虚拟机无法调用电脑上的独立显卡，经过多重筛选，只能勉强使用 WSL2。

WSL2 有很多优点：可以调用 Windows 上的程序，甚至可以配合 Linux 管道使用，十分方便；内核运行在 Hyper-V 上，底层上也是原生的 Linux，经过微软优化，拥有理想的启动速度；可以调用宿主机上几乎所有的资源，其中就包括独立显卡，可以配置 CUDA 环境供 Linux 子系统使用；实现好的 WSLg 拥有不错的图形显示功能，可以在 Linux 上原生运行图形程序。

WSL2 也有很多缺点：子系统实际上是经过阉割的 Linux 子系统，0号进程必须是/init，无法使用依赖于 systemd 的程序，当然，大多数的依赖 systemd 的服务都可以使用命令手动启动，无伤大雅；WSL2 说到底还是运行于虚拟机中，对于一些高级的功能如 kvm 虚拟化功能，无法使用；对于系统硬件的控制仍然需要通过 Windows，没有 Linux 实体机上修改硬件状态来的优雅；就是不喜欢微软的 WSL2，我就是倔，就是不喜欢，用起来总有种二手 Linux 的感觉；等等。

但是不管 WSL2 好不好，我喜不喜欢，在不争气的国产 app 严重依赖的微软的操作系统上，我还能怎样呢。接下来就来说一说怎么利用自定义的镜像文件配置好 WSL2 环境。

# 将 ISO/disk.raw 转换成可以导入 WSL2 使用的 tar.gz 文件

1. [开启](https://learn.microsoft.com/en-us/windows/wsl/install-on-server)所有 WSL2 需要的 Windows features，包括 Microsoft-Windows-Subsystem-Linux 等；按照步骤安装一个微软商店可以下载的 WSL2 发行版；确保有一个可以直接使用的 WSL2 环境；

2. 下载你喜欢的发行版的镜像，可以下载那种跑在云服务器上的 ISO 镜像，推荐 Ubuntu（毕竟人家和微软有很多合作）；

3. 在现在的 WSL2 环境中解压镜像，得到名字类似 disk.raw 文件，此处以 disk.raw 为例演示；
   
   ```shell
   # Extract image
   tar xf ubuntu-*.tar.xz

   # mount Linux system
   sector_size=$(/sbin/fdisk -l disk.raw | grep 'Sector size' | grep -Po '\K([0-9]+)(?= bytes$)')
   start=$(/sbin/fdisk -l disk.raw | grep 'Linux filesystem' | awk '{ print $2 }')
   offset=$(($start * $sector_size))
   
   sudo mkdir -p /mnt/disk
   sudo mount -o loop,offset=$offset disk.raw /mnt/disk

   # Create a rootfs `tar.gz` archive
        
   sudo tar -C /mnt/sid -cpzf ubuntu.tar.gz .
   sudo chown $(id -un):$(id -gn) ubuntu.tar.gz
   ```

   至此，得到了一个可以导入 WSL2 使用的自定义发行版的 tar.gz 文件；

4. 打开 powershell，使用 `wsl` 命令导入镜像； 
   
   ```powershell
   # unregister(delete) old WSL2 distro
   wsl --unregister Ubuntu
   # Import
   wsl --import ubuntu \path\to\the\directory\you\want\to\install\ubuntu\into ubuntu.tar.gz --version 2
   ```

   至此，成功导入了自定义的 WSL2 镜像；

5. WSL2 中，更新源、更新系统软件（换清华源按照[官网](https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/)替换文件即可）
   ```shell
   # Update the OS
   apt update
   apt full-upgrade -y
   
   # Make sure sudo is installed
   apt install sudo
   ```

6. WSL2 中，新建普通用户并授予 sudo 权限；

   ```shell
   # Edit `/etc/adduser.conf` and set `ADD_EXTRA_GROUPS` to 1
   vim /etc/adduser.conf # nano /etc/adduser.conf
   # Create a non-root (ie. `adduser YOUR_USERNAME`)
   adduser YOUR_USERNAME
   # Edit `/etc/wsl.conf` and make sure the following lines exist in the file:
   cat << EOF > /etc/wsl.conf
   [user]
   default = YOUR_USERNAME
   EOF
   ```

7. powershell 中，重启 WSL2；
   ```powershell
   # In PowerShell
   wsl --shutdown
   wsl -d ubuntu
   ```

8. WSL2 中，删除无用的软件包和依赖；
   
   ```shell
   sudo apt remove --purge 'grub-*' 'linux-image-*'
   sudo rm -rf /boot/*
   sudo rm -rf /lost+found
   ```

至此，得到了一个纯净的使用自定义镜像的 WSL2 环境。

# 该死的 WSL2 不使用静态 IP 怎么办

好了，表面上看起来很美好，我又可以开心的运行我的 Linux 脚本了，于是我拿着 Github 项目链接，屁颠屁颠的跑到 WSL2 那里 `git clone` 一顿操作猛如虎————我代理呢？

经过我的一番测试，发现 WSL2 虚拟机无法使用主机的服务，所以主机上的代理服务器除非对局域网开放，否则无法访问。什么，你让我打开对局域网访问？不，我拒绝，不优雅而且不安全，万一身边哪个家伙闲着没事端口扫描局域网呢。于是我选择折中的方法，将主机上的代理服务端口映射到 WSL2 中。

当你配置好映射后发现，当你重启 WSL2 之后，就没法用了，为啥？WSL2 的 IP 它变了！哦！原来是 IP 变了！好的，你变了。这很微软，可以理解。

在搜索引擎的加持下，我发现国外的一位朋友和我有着同样的疑问，并且[热心网友](https://superuser.com/questions/1582234/make-ip-address-of-wsl2-static)给了很多可以接受的解决方法。

***

Q:

I am running an SSH server within WSL2 on a WIN10 machine. To make that work I am using:

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=22 connectaddress=172.19.237.178 connectport=22
```

This works fine initially. `172.19.237.178` is the IP of the WSL2 VM.

There is just one problem. I have the sshd set to run when the PC boots, and every time I boot the machine WSL2 has a different IP. Is there any way to configure WSL2 to use a static IP?

Edit: See [this question](https://superuser.com/questions/1586386/how-to-find-wsl2-machines-ip-address-from-windows) for a workaround to determine the WSL machine's IP.

edited Dec 28, 2020 at 22:09 

asked Sep 1, 2020 at 14:23 [Nick](https://superuser.com/users/519695/nick)

> I just took a look through this [GitHub issue thread](https://github.com/microsoft/WSL/issues/4210) about people having the same issue as you. Looks like it's just not supported right now. It looks like some people on that thread were able to get results that were acceptable by forwarding some of the VM's ports to the host, but that may not work in your situation. – [Sam Forbis](https://superuser.com/users/1128831/sam-forbis) Sep 1, 2020 at 14:46

> @SamForbis I saw the same thread, and agree, I don't think the workaround will do what I need. I am trying to write scripts to RSYNC files from a remote computer into WSL.A workaround might be to determine when WSL has booted, figure out its IP, and then do the routing. The host's IP is static, so if I could just make the `v4tov4` routing always work at boot then it doesn't matter that WSL's IP isn't static. – [Nick](https://superuser.com/users/519695/nick) Sep 1, 2020 at 17:11

***

A1:

The IP address of a WSL2 machine cannot be made static, [however it can be determined using](https://superuser.com/a/1603307/519695) [`wsl hostname -I`](https://superuser.com/a/1603307/519695)

Based on this I was able to create the following powershell script that will start sshd on my WSL machine and route traffic to it.

```powershell
wsl.exe sudo /etc/init.d/ssh start
$wsl_ip = (wsl hostname -I).trim()
Write-Host "WSL Machine IP: ""$wsl_ip"""
netsh interface portproxy add v4tov4 listenport=22 connectport=22 connectaddress=$wsl_ip
```

I added the following to my sudoers file via visudo to avoid needing a password to start sshd

```config
%sudo ALL=(ALL) NOPASSWD: /etc/init.d/ssh
```

Finally, from an administrative powershell terminal, I scheduled my script to run at startup

```powershell
$trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:15
Register-ScheduledJob -Trigger $trigger -FilePath C:\route_ssh_to_wsl.ps1 -Name RouteSSHtoWSL
```

edited Jan 22, 2021 at 16:06

answered Jan 20, 2021 at 21:36
[Nick](https://superuser.com/users/519695/nick)

> Why don't we use `set v4tov4` instead of `add v4tov4`? – [Hunkoys](https://superuser.com/users/387901/hunkoys) Oct 29, 2021 at 18:34

> I didn't think to try it. Is there an advantage to using set rather than add? I'm always running this script at startup so there are no existing portproxies when I run it so I never encounter an issue with using add. – [Nick](https://superuser.com/users/519695/nick) Nov 2, 2021 at 13:50

> @Nick Hello sir, your answer was really helpful to me. It got me closer to what I'm looking for, but I haven't been able to completely solve my problem yet. I won't mind if you could help me take a look at this question that I posted over here [superuser.com/questions/1685689/…](https://superuser.com/questions/1685689/update-windows-host-file-with-wsl-ip-on-start-up) – [Ikechukwu](https://superuser.com/users/1065065/ikechukwu) Nov 5, 2021 at 7:26

> @Nick I just thought add might actually create a new set of rules everytime the ip changes. I haven't tried add though, so I can't prove it. set seems to work. It updates existing rules. – [Hunkoys](https://superuser.com/users/387901/hunkoys) Nov 10, 2021 at 5:49

> Thanks to an upvote of my answer I can now comment, this answer is almost good for me, except `wsl hostname -I` returns two IP ("IP1 IP2") and I want first one, I then do: `$wsl_ip = (wsl hostname -I).split(" ")[0]` – [gluttony](https://superuser.com/users/1023342/gluttony) Jun 16 at 9:20

***

A2:

This solution helped me to set up a static ip of my wsl, try:

Run this on your windows host machine:

```powershell
netsh interface ip add address "vEthernet (WSL)" 192.168.99.1 255.255.255.0
```

And this on your wsl linux machine:

```shell
sudo ip addr add 192.168.99.2/24 broadcast 192.168.99.255 dev eth0 label eth0:1;
```

But to keep this IP after the rebooting your sytem you need to set up those commands in the startup scrip.

edited Apr 17 at 14:40

answered Apr 8 at 12:43 [Artemius Pompilius](https://superuser.com/users/1683639/artemius-pompilius)

> This is perfect. This solved my problem. Thank you. – [Rahmani](https://superuser.com/users/293650/rahmani) Jul 17 at 17:18

> How do you run a `sudo` command on bootup inside WSL? For `netsh` I found [social.technet.microsoft.com/Forums/office/en-US/…](https://social.technet.microsoft.com/Forums/office/en-US/cdf96a00-f0d1-4ba1-b887-3f0035fb01af/running-netsh-commands-on-start-up?forum=win10itprogeneral) – [chx](https://superuser.com/users/41259/chx) Sep 15 at 18:28

> Hm, It just works inside my WSL) And `netsh` works on windows too (if you launch cmd like an Admin user) – [Artemius Pompilius](https://superuser.com/users/1683639/artemius-pompilius) Sep 19

***

A3:

Here's a very compact solution for WSL2 that will auto-start the SSH server. It eliminates having to deal with Powershell signing/execution policies and having to run it on a schedule.

1. Run `wsl sudo nano /etc/wsl.conf` and add these lines:

```config
[boot]
command="service ssh start"
```

This will auto-start SSH server on every WSL startup.

2. (Optional) If you'd like to use a custom port (like `2022`) for SSH (for example, if you use multiple WSL distros), run:

```powershell
wsl sudo sed -i 's|.*Port.*|Port 2022|' /etc/ssh/sshd_config
```

This works because WSL2 maps ports from its distros to the Windows' localhost. Now you can just connect to your host using `localhost:22` (or a custom port).

answered May 28 at 23:21 [dinvlad](https://superuser.com/users/380504/dinvlad)

***

# Reference

1. [Debian sid with systemd on WSL2](https://gist.github.com/fardjad/7ee02761fdaa6b620e0ee8a715121883)

2. [Make IP address of WSL2 static](https://superuser.com/questions/1582234/make-ip-address-of-wsl2-static)