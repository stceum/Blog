---
title: "一些常用的命令"
date: 2020-06-22T09:06:00+08:00
draft: false
tags: Linux
---

# 一些常用的命令

- **[`tar` 命令](#1)**
- **[`git add` 命令](#2)**
- **[`ln` 命令](#3)**



## <h2 id="1">tar 命令</h2>

***[原文链接](https://segmentfault.com/a/1190000002421723),此处仅为备份***

Linux 上有功能强大的 tar 命令，tar 最初是为了制作磁带备份（tape archive）而设计的，它的作用是把文件和目录备份到磁带中，然后从磁带中提取或恢复文件。现在我们可以使用 tar 来备份数据到任何存储介质上。它是文件级备份，不必考虑底层文件系统类别，并且支持增量备份。

### 部分常用选项

- -z, --gzip：使用 gzip 工具（解）压缩，后缀一般为 `.gz`
- -c, --create：tar 打包，后缀一般为 `.tar`
- -f, --file=：后面立刻接打包或压缩后得到的文件名
- -x, --extract：解包命令，与 `-c` 对应
- -p：保留备份数据的原本权限和属性
- -g：后接增量备份的快照文件
- -C：指定解压缩的目录
- --exclude：排除不打包的目录或文件，支持正则匹配

其他

- -X, --exclude-from：在一个文件中列出要排除的目录或文件（在 `--exclude=` 较多时使用）
- -t, --list：列出备份档案中的文件列表，不与 `-c`、`-x` 同时出现
- -j, --bzip2：使用 bzip2 工具（解）压缩，后缀一般为 `.bz2`
- -P：保留绝对路径，解压时同样会自动解压到绝对路径下
- -v：（解）压缩过程显示文件处理过程，常用但不建议对大型文件使用

### 增量备份（网站）数据

许多系统（应用或网站）每天都有静态文件产生，对于一些比较重要的静态文件如果有进行定期备份的需求，就可以通过 tar 打包压缩备份到指定的地方，特别是对一些总文件比较大比较多的情况，还可以利用 `-g` 选项来做增量备份。

备份的目录最好使用相对路径，也就是进入到需要备份的根目录下

具体示例方法如下。

```shell
备份当前目录下的所有文件
# tar -g /tmp/snapshot_data.snap -zcpf /tmp/data01.tar.gz .

在需要恢复的目录下解压恢复
# tar -zxpf /tmp/data01.tar.gz -C .
```

`-g` 选项可以理解备份时给目录文件做一个快照，记录权限和属性等信息，第一次备份时 `/tmp/snapshot_data.snap` 不存在，会新建一个并做完全备份。当目录下的文件有修改后，再次执行第一条备份命令（记得修改后面的档案文件名），会自动根据 `-g` 指定的快照文件，增量备份修改过的文件，包括权限和属性，没有动过的文件不会重复备份。

另外需要注意上面的恢复，是“保留恢复”，即存在相同文件名的文件会被覆盖，而原目录下已存在（但备份档案里没有）的，会依然保留。所以如果你想完全恢复到与备份文件一模一样，需要清空原目录。如果有增量备份档案，则还需要使用同样的方式分别解压这些档案，而且要注意顺序。

下面演示一个比较综合的例子，要求：

- 备份 `/tmp/data` 目录，但 `cache` 目录以及临时文件排除在外
- 由于目录比较大（>4G），所以全备时分割备份的档案（如每个备份档案文件最大1G）
- 保留所有文件的权限和属性，如用户组和读写权限

```shell
# cd /tmp/data

做一次完全备份
# rm -f /tmp/snapshot_data.snap
# tar -g /tmp/snapshot_data.snap -zcpf - --exclude=./cache ./ | split -b 1024M - /tmp/bak_data$(date -I).tar.gz_
分割后文件名后会依次加上aa,ab,ac,...，上面最终的备份归档会保存成
bak_data2014-12-07.tar.gz_aa
bak_data2014-12-07.tar.gz_ab
bak_data2014-12-07.tar.gz_ac
...

增量备份
可以是与完全备份一模一样的命令，但需要注意的是假如你一天备份多次，可能导致档案文件名重复，那么就会导致
备份实现，因为 split 依然会从 aa, ab 开始命名，如果一天的文件产生（修改）量不是特别大，那么建议增量部分不
分割处理了：（ 一定要分割的话，文件名加入更细致的时间如 $(date +%Y-%m-%d_%H) ）
# tar -g /tmp/snapshot_data.snap -zcpf /tmp/bak_data2014-12-07.tar.gz --exclude=./cache ./

第二天增备
# tar -g /tmp/snapshot_data.snap -zcpf /tmp/bak_data2014-12-08.tar.gz --exclude=./cache ./
```

恢复过程

```shell
恢复完全备份的档案文件
可以选择是否先清空 /tmp/data/ 目录
# cat /tmp/bak_data2014-12-07.tar.gz_* | tar -zxpf - -C /tmp/data/

恢复增量备份的档案文件
$ tar –zxpf /tmp/bak_data2014-12-07.tar.gz -C /tmp/data/
$ tar –zxpf /tmp/bak_data2014-12-08.tar.gz -C /tmp/data/
...
一定要保证是按时间顺序恢复的，像下面文件名规则也可以使用上面通配符的形式
```

如果需要定期备份，如每周一次全备，每天一次增量备份，则可以结合 crontab 实现。

### 备份文件系统

备份文件系统方法有很多，例如 cpio, rsync, dump, tar，这里演示一个通过 `tar` 备份整个 Linux 系统的例子，整个备份与恢复过程与上面类似。
首先 Linux（这里是 CentOS ）有一部分目录是没必要备份的，如 `/proc`、`/lost+found`、`/sys`、`/mnt`、`/media`、`/dev`、`/proc`、`/tmp`，如果是备份到磁带 `/dev/st0` 则不必关心那么多，因为我这里是备份到本地 `/backup` 目录，所以也需要排除，还有其它一些 NFS 或者网络存储挂载的目录。

```shell
创建排除列表文件
# vi /backup/backup_tar_exclude.list
/backup
/proc
/lost+found
/sys
/mnt
/media
/dev
/tmp

$ tar -zcpf /backup/backup_full.tar.gz -g /backup/tar_snapshot.snap --exclude-from=/backup/tar_exclude.list /
```

### 注意

使用 tar 无论是备份数据还是文件系统，需要考虑是在原系统上恢复还是另一个新的系统上恢复。

- tar 备份极度依赖于文件的 atime 属性，
- 文件所属用户是根据用户 ID 来确定的，异机恢复需要考虑相同用户拥有相同 USERID
- 备份和恢复的过程尽量不要运行其他进程，可能会导致数据不一致
- 软硬连接文件可以正常恢复

## <h2 id="2">`git add` 命令</h2>

***[原文链接](https://www.yiibai.com/git/git_add.html)***

`git add` 命令将文件内容添加到索引(将修改添加到暂存区)。也就是将要提交的文件的信息添加到索引库中。

**简介**

```shell
$ git add [--verbose | -v] [--dry-run | -n] [--force | -f] [--interactive | -i] [--patch | -p]
      [--edit | -e] [--[no-]all | --[no-]ignore-removal | [--update | -u]]
      [--intent-to-add | -N] [--refresh] [--ignore-errors] [--ignore-missing]
      [--chmod=(+|-)x] [--] [<pathspec>…]
```

### 描述

此命令将要提交的文件的信息添加到索引库中(将修改添加到暂存区)，以准备为下一次提交分段的内容。 它通常将现有路径的当前内容作为一个整体添加，但是通过一些选项，它也可以用于添加内容，只对所应用的工作树文件进行一些更改，或删除工作树中不存在的路径了。

“索引”保存工作树内容的快照，并且将该快照作为下一个提交的内容。 因此，在对工作树进行任何更改之后，并且在运行 `git commit` 命令之前，必须使用 `git add` 命令将任何新的或修改的文件添加到索引。

该命令可以在提交之前多次执行。它只在运行 `git add` 命令时添加指定文件的内容; 如果希望随后的更改包含在下一个提交中，那么必须再次运行 `git add` 将新的内容添加到索引。

`git status` 命令可用于获取哪些文件具有为下一次提交分段的更改的摘要。

默认情况下，`git add` 命令不会添加忽略的文件。 如果在命令行上显式指定了任何忽略的文件，`git add` 命令都将失败，并显示一个忽略的文件列表。由Git执行的目录递归或文件名遍历所导致的忽略文件将被默认忽略。 `git add` 命令可以用 `-f(force)` 选项添加被忽略的文件。

### 示例

以下是一些示例 -

添加 `documentation` 目录及其子目录下所有 `*.txt` 文件的内容：

```shell
$ git add documentation/*.txt
```

> 注意，在这个例子中，星号`*`是从 shell 引用的; 这允许命令包含来自 `Documentation/` 目录和子目录的文件。

将所有 `git-*.sh` 脚本内容添加：

```shell
$ git add git-*.sh
```

因为这个例子让 shell 扩展星号(即明确列出文件)，所以它不考虑子目录中的文件，如：`subdir/git-foo.sh` 这样的文件不会被添加。

**基本用法**

```shell
$ git add <path>
```

通常是通过 `git add <path>` 的形式把 `<path>` 添加到索引库中，`<path>` 可以是文件也可以是目录。

git不仅能判断出 `<path>` 中，修改(不包括已删除)的文件，还能判断出新添的文件，并把它们的信息添加到索引库中。

```shell
$ git add .  # 将所有修改添加到暂存区
$ git add *  # Ant风格添加修改
$ git add *Controller   # 将以Controller结尾的文件的所有修改添加到暂存区

$ git add Hello*   # 将所有以Hello开头的文件的修改添加到暂存区 例如:HelloWorld.txt,Hello.java,HelloGit.txt ...

$ git add Hello?   # 将以Hello开头后面只有一位的文件的修改提交到暂存区 例如:Hello1.txt,HelloA.java 如果是HelloGit.txt或者Hello.java是不会被添加的
```

`git add -u [<path>]`: 把 `<path>` 中所有跟踪文件中被修改过或已删除文件的信息添加到索引库。它不会处理那些不被跟踪的文件。省略 `<path>` 表示 `.` ,即当前目录。

`git add -A`: []表示把中所有跟踪文件中被修改过或已删除文件和所有未跟踪的文件信息添加到索引库。省略 `<path>` 表示 `.` ,即当前目录。

```shell
$ git add -i
```

我们可以通过 `git add -i [<path>]` 命令查看中被所有修改过或已删除文件但没有提交的文件，并通过其 `revert` 子命令可以查看 `<path>` 中所有未跟踪的文件，同时进入一个子命令系统。

比如：

```shell
$ git add -i
           staged     unstaged path
  1:        +0/-0      nothing branch/t.txt
  2:        +0/-0      nothing branch/t2.txt
  3:    unchanged        +1/-0 readme.txt

*** Commands ***
  1: [s]tatus     2: [u]pdate     3: [r]evert     4: [a]dd untracked
  5: [p]atch      6: [d]iff       7: [q]uit       8: [h]elp
```

这里的 `t.txt` 和 `t2.txt` 表示已经被执行了 `git add`，待提交。即已经添加到索引库中。
`readme.txt` 表示已经处于 tracked 下，它被修改了，但是还没有执行 `git add`。即还没添加到索引库中。

## <h2 id="3">`ln` 命令</h2>

***[原文链接](https://www.runoob.com/linux/linux-comm-ln.html)***

Linux ln 命令是一个非常重要命令，它的功能是为某一个文件在另外一个位置建立一个同步的链接。

当我们需要在不同的目录，用到相同的文件时，我们不需要在每一个需要的目录下都放一个必须相同的文件，我们只要在某个固定的目录，放上该文件，然后在 其它的目录下用 ln 命令链接（link）它就可以，不必重复的占用磁盘空间。

### 语法

```shell
 $ ln [参数][源文件或目录][目标文件或目录]
```

其中参数的格式为

`[-bdfinsvF] [-S backup-suffix] [-V {numbered,existing,simple}]`

`[--help] [--version] [--]`

**命令功能** :
Linux 文件系统中，有所谓的链接 `(link)`，我们可以将其视为档案的别名，而链接又可分为两种 : 硬链接 `(hard link)` 与软链接 `(symbolic link)`，硬链接的意思是一个档案可以有多个名称，而软链接的方式则是产生一个特殊的档案，该档案的内容是指向另一个档案的位置。硬链接是存在同一个文件系统中，而软链接却可以跨越不同的文件系统。

不论是硬链接或软链接都不会将原本的档案复制一份，只会占用非常少量的磁碟空间。

**软链接**：

- 1.软链接，以路径的形式存在。类似于 Windows 操作系统中的快捷方式
- 2.软链接可以 跨文件系统 ，硬链接不可以
- 3.软链接可以对一个不存在的文件名进行链接
- 4.软链接可以对目录进行链接

**硬链接**：

- 1.硬链接，以文件副本的形式存在。但不占用实际空间。
- 2.不允许给目录创建硬链接
- 3.硬链接只有在同一个文件系统中才能创建

#### 命令参数

**必要参数**：

- -b 删除，覆盖以前建立的链接
- -d 允许超级用户制作目录的硬链接
- -f 强制执行
- -i 交互模式，文件存在则提示用户是否覆盖
- -n 把符号链接视为一般目录
- -s 软链接(符号链接)
- -v 显示详细的处理过程

**选择参数**：

- -S "-S<字尾备份字符串> "或 "--suffix=<字尾备份字符串>"
- -V "-V <备份方式>"或"--version-control=<备份方式>"
- --help 显示帮助信息
- --version 显示版本信息

### 实例

给文件创建软链接，为 log2013.log 文件创建软链接 link2013，如果 log2013.log 丢失，link2013 将失效：

```shell
$ ln -s log2013.log link2013
```

输出：

```shell
[root@localhost test]# ll
-rw-r--r-- 1 root bin      61 11-13 06:03 log2013.log
[root@localhost test]# ln -s log2013.log link2013
[root@localhost test]# ll
lrwxrwxrwx 1 root root     11 12-07 16:01 link2013 -> log2013.log
-rw-r--r-- 1 root bin      61 11-13 06:03 log2013.log
```

给文件创建硬链接，为 `log2013.log` 创建硬链接 `ln2013`，`log2013.log` 与 `ln2013` 的各项属性相同

```shell
$ ln log2013.log ln2013
```

输出：

```shell
[root@localhost test]# ll
lrwxrwxrwx 1 root root     11 12-07 16:01 link2013 -> log2013.log
-rw-r--r-- 1 root bin      61 11-13 06:03 log2013.log
[root@localhost test]# ln log2013.log ln2013
[root@localhost test]# ll
lrwxrwxrwx 1 root root     11 12-07 16:01 link2013 -> log2013.log
-rw-r--r-- 2 root bin      61 11-13 06:03 ln2013
-rw-r--r-- 2 root bin      61 11-13 06:03 log2013.log
```