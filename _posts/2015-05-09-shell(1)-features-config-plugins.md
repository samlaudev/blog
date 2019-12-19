---
layout: page
title: Shell（一）：功能、配置和插件
date: 2015-05-09
tags: 工具
---

关于[shell](http://zh.wikipedia.org/wiki/Unix_shell)，一个广义的解释就是在用户与操作系统之间，提供一个工具或接口给用户来操作计算机系统；用户在shell中通过输入命令行，按下回车键，shell执行命令后就能返回结果，达到操作计算机的效果。
但有很多人会问，为什么要学习shell呢？以下是我对为什么要学习shell的看法：

* 在通过[ssh](http://zh.wikipedia.org/wiki/Secure_Shell)来远程操纵Linux/Unix服务器时，都是使用shell而不是用户界面
* 相比于通过点击多个用户界面来执行操作，输入命令行更加直接和快捷
* 利用管道组合各种可用工具，来创建和定制宏工具
* 使用shell script将重复简单的任务自动化

而shell有很多种：Bourne Shell， C Shell，Korn Shell，Bourne-again Shell，TENEX C Shell等，通过命令`cat /etc/shells`可以查看系统支持哪些shell:

![System Support Shell.png](/assets/images/2015/166109-02b426c2d32b0934.png)


Linux/Unix默认都是使用Bash(Bourne-again Shell)，但我更倾向于使用[zsh](http://www.zsh.org)，但由于配置过于复杂，前期很少人使用，但后来有外国程序员弄出一个[Oh My ZSH](http://ohmyz.sh)来管理zsh的配置和支持更多插件，使得zsh变得更容易使用和更加强大。
![zsh shell.png](/assets/images/2015/166109-df3c06c4e7b65954.png)

## Shell有哪些功能

* ### 命令历史记录

  一旦你在shell敲入正确命令并能执行后，shell就会存储你所敲入命令的历史记录（存放在`~/.bash_history`文件），方便你再次运行之前的命令。
   你可以按方向键`↑`和`↓`来查看之前执行过的命令

![Shell Command History.gif](/assets/images/2015/166109-51793d1f54d6060a.gif)
可以用`!!`来执行上一条命令，但最常用还是使用`ctrl-r`来搜索命令历史记录

![Shell Search Command History.gif](/assets/images/2015/166109-6383cdb49c6a14f0.gif)

* ### 命令和文件补全(按`tab`键)

  当你输入命令或文件名时，你可以通过按`tab`键来补全命令或文件名，这样可以让你**更快**敲入命令和敲入**正确**的命令。
  有时你忘记具体某个命令，但你记住命令开头的几个字母是`gi`，可以敲入字母`gi`，按`tab`键来显示与前几个字母有关的所有命令：

 ![Shell Command Complete.gif](/assets/images/2015/166109-76903a2cfddb398e.gif)
 当用`cd`命令前往某个目录时，你不必敲入整个路径的所有目录名，你只需敲入目录前几个字母，然后按`tab`键逐个补全目录名即可。
 ![Shell Auto Complete Dir.gif](/assets/images/2015/166109-5f9909550edaaf94.gif)

* ### 命令别名

  命令别名是一个比较有用的东西，特别适应用于**简化命令输入**。比如，你要更新cocoapods时，在shell输入以下命令行

```
pod update --verbose --no-repo-update
```

但每次都输入这么长的命令行，多么麻烦啊。所以，这时使用命令别名来简化命令行的输入：

```
alias pod_update='pod update --verbose --no-repo-update'
```

下次你只需要输入`pod_update`就可以更新cocoapod
你可以使用`alias`命令来**显示所有命令别名**

 ![list all alias .png](/assets/images/2015/166109-d4d5d22f4b52209c.png)

* ### 任务控制(job control)

  使用shell登陆系统后，想要一边复制文件、一边查找文件、一边进行编译代码、一边下载软件，当然可以通过开启多个shell来完成，但如果想只在一个shell来完成以上多个任务时，此时可以使用shell的一个特性**任务控制**。

 在学会如何使用命令来控制任务之前，先了解两个概念：**前台(foreground)**和**后台(background)**。**前台**就是出现提示符让用户操作的环境，而**后台**就是不能与用户交互的环境，你无法使用 `ctrl-c` 终止它，可使用 `bg/fg` 呼叫该任务。

 下面介绍一些命令如何控制任务：

##### 1. 将任务放在后台运行：`命令行 + &`

  ![job control 1.png](/assets/images/2015/166109-10b25ab7e0c4e586.png)

 注意一下上面打印信息，`[1]`表示job number(任务编号)，`7089`表示PID(进程号)。在后台执行的命令，如果有stdout和stderr，数据依旧输出到屏幕上，可以通过数据重定向传输到文件中，就不会影响前台的工作。

  ![job control 2.png](/assets/images/2015/166109-2ad8d923483440c1.png)

##### 2. 将任务丢到后台暂停：`ctrl-z`

 在shell中执行`find / -print`命令，然后按下`ctrl-z`将任务丢到后台暂停：
 ![job control 3.png](/assets/images/2015/166109-3ff13fa5839f03f0.png)
 由上面打印可知，任务`find / -print`暂停执行，并将任务放在后台，返回一个job number`[2]`

##### 3. 查看后台所有任务状态：`jobs -l`

 输入`jobs -l` 查看后台所有的任务状态：
 ![job control 4.png](/assets/images/2015/166109-632448cb14ef4487.png)
 仔细查看打印信息，有没有留意到在PID `7417`和`7431`之前有`-`和`+`两个符号，`-`表示最近第二个被放到后台的任务号码，`+`表示最近被放到后台的任务号码。

##### 4. 将后台的任务拿到前台处理：`fg %jobnumber`

 输入`fg`会默认取出`+`的任务，然后迅速按下`ctrl-z`
 ![job control 5.png](/assets/images/2015/166109-afa0e37fda621de0.png)
 看上面打印的**PID**是`7431`，确实如此。再次输入`jobs -l`来查看后台所有任务的信息
 ![job control 6.png](/assets/images/2015/166109-533b6547be382ced.png)
这次输入`fg %1`来讲后台的任务拿到前台处理。

##### 5. 将后台的任务变成运行中：`bg %jobnumber`

 输入`jobs -l`查看任务状态：
 ![job control 7.png](/assets/images/2015/166109-fa578aa3108b5e13.png)
 然后输入`bg %2; jobs -l`将后台任务变成运行，并查看任务状态，然后不断地输入打印信息，这时需要关闭终端才能**kill**这个shell进程的子进程。

##### 6. 管理后台当中的任务：`kill -signal %jobnumber`

 有时，任务在后台运行或暂停，这时我想结束这个任务，怎样办呢？你可以使用`kill`命令将任务结束。
 输入`find / -print`命令，并按下`ctrl-z`暂停任务：
 ![job control 8.png](/assets/images/2015/166109-043f63b316ea067b.png)
输入`kill -9 %1;jobs -l`结束任务并显示任务状态：
![job control 9.png](/assets/images/2015/166109-4d117e76dc34e699.png)

* ### shell script

  shell script是利用shell的功能所编写的一个**程序**，这个程序使用纯文本文件来保存一些shell的命令，并遵循shell的语法规则，搭配数据重定向、管道、和正则表达式等功能来组合各种工具，实现简单重复任务的自动化。

* ### 通配符

  除了完整的字符串之外，shell还支持许多的通配符来帮助用户查询和命令执行。我简答地列出常用的几个通配符：

| 符号 |                             含义                             |
| ---- | :----------------------------------------------------------: |
| *    |                   表示0到无穷多个任意字符                    |
| ?    |                      表示有一个任意字符                      |
| []   | 表示有一个在中括号内的字符。例如[abc]表示有个字符，可能是abc其中一个 |
| [-]  | 表示在编码顺序内的所有字符。例如[1-7]表示有个字符，范围1到7其中一个 |
| [^]  | 表示反向选择。例如表示有一个字符，只要不是a,b,c的其他字符都可以 |

## iTerm 2(for mac) && Oh My Zsh

如果你是mac的用户，推荐一个终端应用[iTerm 2](https://www.iterm2.com), iTerm 2 相比mac自带的 Terminal 应用，有太多优点了。例如，支持画面分割，可以设置主题，各种使用的快捷键，以及快速唤出。配合 [Oh My Zsh](http://ohmyz.sh) 使用，简直优雅到爆！


### Oh My Zsh安装

* ##### curl方式

```
curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
```

* ##### wget方式

```
wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O - | sh
```

安装完之后，关闭当前终端，并重新打开一个，oh my zsh的默认主题是`robbyrussell`，效果如下：

![robbyrussell theme.jpg](/assets/images/2015/166109-79a2d5a7e321e175.jpg)

### 配置

如果你想定制和扩展zsh，oh my zsh提供配置文件`~/.zshrc`来配置，可以设置环境变量和别名；

```
# Support autojump
[[ -s ~/.autojump/etc/profile.d/autojump.sh ]] && . ~/.autojump/etc/profile.d/autojump.sh

# setup moco alias name
alias moco_service="moco start -p 12306 -g settings.json"

#setup macvim alias name
alias vim="/Applications/MacVim.app/Contents/MacOS/Vim"

#setup pod update alias name
alias pod_update='pod update --verbose --no-repo-update'
```

在[Themes](https://github.com/robbyrussell/oh-my-zsh/wiki/themes)列出所有可用主题，每个主题都有截屏效果并教你如何设置，选择你喜欢的主题，在配置文件`~/.zshrc`查找字符串`ZSH_THEME="robbyrussell"`，通过改变`ZSH_THEME `环境变量来改变主题。例如，

```
ZSH_THEME="agnoster"
```

**oh my zsh**提供数十种主题，相关文件在`~/.oh-my-zsh/themes` 目录，可以编辑主题来满足自身需求，我是使用默认的`robbyrussell `，不过做了一点小小改动：

```
PROMPT='%{$fg_bold[red]%}➜ %{$fg_bold[green]%}%p%{$fg[cyan]%}%d %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%}% %{$reset_color%}> '
#PROMPT='${ret_status}%{$fg_bold[green]%}%p %{$fg[cyan]%}%c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}> '
```

与原来不同的是，将c(表示当前目录)改为d(表示绝对路径)，另外在尾部添加一个`>`作为隔离符号，效果如下：
![modified robbyrussell.png](/assets/images/2015/166109-1ffecf5374f54b8a.png)

### 插件

**oh my zsh**提供丰富的插件，存放在`~/.oh-my-zsh/plugins`目录下：
![oh my zsh plugins.png](/assets/images/2015/166109-b270679d1bc47291.png)想了解每个插件的功能以及如何使用，只要打开相关插件的目录下zsh文件即可，以git插件为例：
![git plugin.png](/assets/images/2015/166109-3986a379fc0b311e.png)
打开`git.plugin.zsh`文件，里面有很多命名别来来简化命令的输入。你可以根据自己的需要来启用哪些插件，只需在`~/.zshrc`配置文件追加内容即可：

```
plugins=(git autojump osx)
```

我来介绍一下一些[常用插件](https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins)的使用吧：

##### git

当你处在一个git受控的目录下时，Shell明确显示`git`和`branch`信息，另外简化git很多命令，具体使用请参考：[Plugin:git](https://github.com/robbyrussell/oh-my-zsh/wiki/Plugin:git)

##### autojump

autojump插件使你能够快速切换路径，再也不需要逐个敲入目录，只需敲入目标目录，就可以迅速切换目录。

* 安装
  如果你是mac用户，可以使用`brew`安装：

 ```
 brew install autojump

 ```

 如果是linux用户，首先下载**autojump**最近版本，比如：

 ```
 git clone git://github.com/joelthelion/autojump.git

 ```

 然后进入目录，执行

 ```
 ./install.py

 ```

 最近将以下代码加入`~/.zshrc`配置文件：

 ```
 [[ -s ~/.autojump/etc/profile.d/autojump.sh ]] && . ~/.autojump/etc/profile.d/autojump.sh

 ```

* 使用
  如果你之前打开过`~/.oh-my-zsh/themes`目录，现在只需敲入`j themes`就可以快速切换到`~/.oh-my-zsh/themes`目录。

 ![autojump.png](/assets/images/2015/166109-9fb511830731d9c0.png)


##### osx

* `tab` - 在一个新标签打开当前目录
* `cdf ` - cd到当前Finder目录
* `quick-look` - 快速浏览特殊的文件
* `man-preview` - 在Preview应用打开特定的man page
* `trash` - 将特定的文件移到垃圾桶


### 使用

1. 因为zsh兼容bash，所以之前使用bash的人切换到zsh毫无压力
2. 智能拼写纠正，比如你输入`cls`，会提示
   ![auto correct.png](/assets/images/2015/166109-e3fe01c7d9ba5676.png)
3. 各种补全：除了支持命令补全和文件补全之外，还支持命令参数补全，插件内容补全，只需要按`tab`键
4. 使用`autojump`智能跳转
5. 目录浏览和跳转：输入d，就显示在会话里访问的目录列表，输入列表前的序号，即可以跳转

 ![list dir and jump.png](/assets/images/2015/166109-f9314d62486c6103.png)

6. 输入`..`可以返回到上级目录

 ![parent dir.png](/assets/images/2015/166109-9ecea4f84729f9c7.png)

 YouTube有个演示视频 [zsh shell](https://www.youtube.com/watch?v=HGBgMX5HW_g)详细介绍如果使用Oh My Zsh

## 总结

作为的一个程序员，我觉得shell是一个必不可少的工具，使用它能够毫不费劲地操作计算机。在shell提示下，通过调用各种各样的工具，并结合管道，将这些工具根据自己需要组合起来，创建和制定宏工具，甚至编写shell script来将简单而重复的工作自动化，做到**Don't repeat your self**。

## 扩展阅读

* Linux Shell  
  [工作管理 (job control)](http://vbird.dic.ksu.edu.tw/linux_basic/0440processcontrol.php#background)
* oh my shell  
  [终极 Shell](http://macshuo.com/?p=676)