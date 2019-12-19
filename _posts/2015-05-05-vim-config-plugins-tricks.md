---
layout: page
title: Vim配置、插件和使用技巧
date: 2015-05-05
tags: 工具
---

![vim_cheat_sheet_for_programmers.png](/assets/images/2015/166109-2405264e12db784e.png)

常言道：工欲善其事，必先利其器 ，作为一个程序员，一个常用的工具就是**编辑器**，我选择一个能极大提高自己开发效率的编辑器**vim**（有些人可能选择[emacs](http://www.gnu.org/software/emacs/)）。而[vim](http://www.vim.org)编辑器方面具有以下几种特性：

* 跨平台及统一环境
  无论是在windows还是在*nix，vim是一个很完美的跨平台文本编辑器，甚至可以直接在服务器平台CentOS，Ubuntu等直接配置使用，配置文件大同小异，操作习惯基本相同。

* 定制化及可扩展
  vim提供一个**vimrc**的配置文件来配置vim，并且自己可以定制一些插件来实现文件浏览（[NERD Tree](https://github.com/scrooloose/nerdtree)），代码补全（[YouCompleteMe](https://github.com/Valloric/YouCompleteMe)，语法检查（[syntastic](https://github.com/scrooloose/syntastic)），文件模糊搜索（[ctrlp](https://github.com/kien/ctrlp.vim)），显示vim状态栏（[Vim Powerline](https://github.com/Lokaltog/vim-powerline)）,主题颜色（[Molokai](https://github.com/tomasr/molokai)）,显示文件结构（[tagbar](https://github.com/majutsushi/tagbar)）等多种功能。

* 高效命令行
  使用vim编辑文本，只需在键盘上操作就可以，根本无需用到鼠标。就拿光标移动来说，与重复击键、一个字符一个字符或一行一行移动相比，按一次键就能以词、行、块或函数为单位移动，效率高得多。有时一些重复删除、粘帖的操作，也只需一条命令就可以完成，甚至你可以用键映射来简化或组合多种命令来提高效率。

# 配置

如果你需要配置vim，只需在Home目录创建一个**~/.vimrc**文件即可以配置vim了，可以参考我的[vimrc](https://github.com/samlaudev/ConfigurationFiles/blob/master/vim/vimrc)配置文件。由于我需要安装插件，并且将需要安装的插件列表分离到另外一个文件**~/.vimrc.bundles**，这个文件也是存放在Home目录，文件内容可以参考[vimrc.bundles](https://github.com/samlaudev/ConfigurationFiles/blob/master/vim/vimrc.bundles)。若想加载**~/.vimrc.bundles**文件，必须在**~/.vimrc**文件加入以下代码片段：

```
if filereadable(expand("~/.vimrc.bundles"))
  source ~/.vimrc.bundles
endif
```

# 插件

### 插件管理工具vunble

[vundle](https://github.com/gmarik/Vundle.vim)是vim的插件管理工具，它能够搜索、安装、更新和移除vim插件，再也不需要手动管理vim插件。

1. 在**Home**目录创建**~/.vim**目录和**.vimrc**文件（可复制我的[vimrc](https://github.com/samlaudev/ConfigurationFiles/blob/master/vim/vimrc)文件）
2. 安装vundle

 ```
 git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle

 ```

3.  在.vimrc配置文件中添加vundle支持

```
filetype off
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
```

但实际上我是添加一个**~/.vimrc.bundles**文件来保存所有插件的配置，必须在**~/.vimrc**文件加入以下代码片段：

```
if filereadable(expand("~/.vimrc.bundles"))
  source ~/.vimrc.bundles
endif
```

而**~/.vimrc.bundles**文件内容必须包含：

 ```
  filetype off
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
 ```

 你可以复制到我[**~/.vimrc.bundles**](https://github.com/samlaudev/ConfigurationFiles/blob/master/vim/vimrc.bundles)文件到**Home**目录。

### 安装插件

bundle分为三类，比较常用就是**第二种**：

1. 在Github vim-scripts 用户下的repos,只需要写出repos名称
2. 在Github其他用户下的repos, 需要写出”用户名/repos名”
3. 不在Github上的插件，需要写出git全路径

![Bundle Type.png](/assets/images/2015/166109-f02a8b94ec2066e4.png)
将安装的插件在**~/.vimrc**配置，但是我是将插件配置信息放在**~/.vimrc.bundles**：

```
" Define bundles via Github repos
Bundle 'christoomey/vim-run-interactive'
Bundle 'Valloric/YouCompleteMe'
Bundle 'croaky/vim-colors-github'
Bundle 'danro/rename.vim'
Bundle 'majutsushi/tagbar'
Bundle 'kchmck/vim-coffee-script'
Bundle 'kien/ctrlp.vim'
Bundle 'pbrisbin/vim-mkdir'
Bundle 'scrooloose/syntastic'
Bundle 'slim-template/vim-slim'
Bundle 'thoughtbot/vim-rspec'
Bundle 'tpope/vim-bundler'
Bundle 'tpope/vim-endwise'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-rails'
Bundle 'tpope/vim-surround'
Bundle 'vim-ruby/vim-ruby'
Bundle 'vim-scripts/ctags.vim'
Bundle 'vim-scripts/matchit.zip'
Bundle 'vim-scripts/tComment'
Bundle "mattn/emmet-vim"
Bundle "scrooloose/nerdtree"
Bundle "Lokaltog/vim-powerline"
Bundle "godlygeek/tabular"
Bundle "msanders/snipmate.vim"
Bundle "jelera/vim-javascript-syntax"
Bundle "altercation/vim-colors-solarized"
Bundle "othree/html5.vim"
Bundle "xsbeats/vim-blade"
Bundle "Raimondi/delimitMate"
Bundle "groenewege/vim-less"
Bundle "evanmiller/nginx-vim-syntax"
Bundle "Lokaltog/vim-easymotion"
Bundle "tomasr/molokai"
Bundle "klen/python-mode"
```

打开vim，运行`:BundleInstall`或在shell中直接运行`vim +BundleInstall +qall`

![Install Bundle.png](/assets/images/2015/166109-14c56d86441dfd6a.png)

安装完插件之后，可能还有一个问题：就是**vim版本**不够高
![Vim版本不够高.png](/assets/images/2015/166109-603e5665b800944a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

可以使用以下命令更新vim版本

```
brew install macvim --override-system-vim
```

然后运行以下命令符号连接到`/Application`

```
brew linkapps macvim
```

最后在`.zshrc`配置文件中使用别名来使用更新后的vim

```
#setup macvim alias
alias vim='/usr/local/opt/macvim/MacVim.app/Contents/MacOS/Vim'

```

### 常用插件

##### NERD Tree

[NERD Tree](https://github.com/scrooloose/nerdtree)是一个树形目录插件，方便浏览当前目录有哪些目录和文件。

![NERD Tree Plugin Bundle.png](/assets/images/2015/166109-28b83bff7e947a17.png)
我在**~/.vimrc**文件中配置NERD Tree，设置一个启用或禁用**NERD Tree**的键映射

```
nmap <F5> :NERDTreeToggle<cr>

```

![NERD Tree Configuration.png](/assets/images/2015/166109-1ecb9bb634c1200f.png)
所以你只需按**F5**键就能启用或禁用**NERD Tree**，NERD Tree提供一些常用快捷键来操作目录：

* 通过**hjkl**来移动光标
* **o**打开关闭文件或目录，如果想打开文件，必须光标移动到文件名
* **t**在标签页中打开
* **s**和**i**可以水平或纵向分割窗口打开文件 
* **p**到上层目录
* **P**到根目录
* **K**到同目录第一个节点
* **P**到同目录最后一个节点

##### YouCompleteMe & syntastic

[YouCompleteMe](http://valloric.github.io/YouCompleteMe/)是一个快速、支持模糊匹配的vim代码补全引擎。由于它是基于[Clang](http://clang.llvm.org)引擎为C/C++/Objective-C提供代码提示，也支持其他语言代码提示的引擎，例如基于[Jedi](https://github.com/davidhalter/jedi)的Python代码补全，基于[OmniSharp](https://github.com/OmniSharp/omnisharp-server)的C#代码补全，基于[Gocode](https://github.com/nsf/gocode)的Go代码补全。

![YouCompleteMe.gif](/assets/images/2015/166109-08dee1f09c6bafec.gif)
只需敲入代码，就自动提示想输入的代码列表，你可以选择其中一个，然后**tab**键就可以补全代码。

**YouCompleteMe**已经集成了[Syntastic](https://github.com/scrooloose/syntastic)，所以一旦你编写代码时语法错误，就会有红色错误提示

![syntastic.png](/assets/images/2015/166109-b54169a2a59de534.png)

##### ctrlp

不知道你有没有遇到这样一种情况：在大规模的工程项目中，目录和文件嵌套比较深，打开一个文件要逐个逐个进入目录才能打开，这样的话，比较耗时间和效率很低，[ctrlp](https://github.com/kien/ctrlp.vim)重新定义打目录和文件方式，特别适用于大规模项目文件的浏览。

**启用ctrlp**

*  运行命令`:CtrlP`或`:CtrlP [starting-directory]`来以查找文件模式来启用** ctrlp**
*  运行命令`:CtrlPBuffer `或`:CtrlPMRU`来以查找缓冲或最近打开文件模式来启用**ctrlp**
*  运行命令`CtrlPMixed `来查找文件、查找缓冲和最近打开文件混合模式来启动** ctrlp**

**基本使用**

* 按`<c-f>`和`<c-b>`在三种查找模式中互相切换
* 按`<c-y>`来创建新文件和对应的父目录
* 按`<c-d>`来切换到只查找文件名而不是全路径
* 按`<c-j> `，`<c-k>`或箭头方向键来移动查找结果列表
* 按`<c-t>`或`<c-v>`，`<c-x>`来以新标签或分割窗口的方式来打开文件
* 按`<c-z>`来标识或取消标识文件，然后按`<c-o>`来打开文件
* 按`<c-n>`，`<c-p>`来在提示历史中选择下一个/上一个字符串

**演示视频**
具体如何使用ctrlp，请参考happypetterd的[演示视频](http://haoduoshipin.com/episodes/64)，讲解非常清楚。

##### Vim Powerline

[Vim Powerline](https://github.com/Lokaltog/vim-powerline)是一个显示vim状态栏插件，它能够显示vim模式、操作环境、编码格式、行数/列数等信息

![Vim Powerline.png](/assets/images/2015/166109-820004ded9adbb03.png)

##### Molokai

[Molokai](https://github.com/tomasr/molokai)是vim颜色主题，效果如下

![Molokai Color Scheme for Vim.png](/assets/images/2015/166109-b4a2f541641070d2.png)

# 常用命令

对于入门vim基本命令可以参考 [简明 Vim 练级攻略](http://coolshell.cn/articles/5426.html)，以下是本人关于**移动光标**、**插入/修改**、**删除**、**复制**、**粘帖**、**撤销和恢复**等常用命令

* 移动光标

  1. 对于在**行内移动**，通过使用`f/F + 字符`来移动到特定的字符，然后再使用`. `  来重复执行命令；`f`表示向前移动，`F`表示向后移动。如果想直接移动到行首或行尾，使用`^ `或`$`
  2. 对于在**多行移动**，就有多种选择：**第一种**是通过`gg`，`G`，`行数 + G`指定行数来移动，`gg`表示移动文件的第一行，`G`表示移动文件的最后一行，`行数 + G`表示移动到特定的行。**第二种**就是通过**正则搜索**的方式来移动，`/string`表示正向查找，`?string`表示反向查找，`n`查找下一个匹配的结果，`N`表示上一个匹配的结果，按`up/down`可以浏览搜索历史。**第三种**就是使用**标记**来移动，`m + {a-z}`标记位置(适用于单个文件，如果是多个文件，使用大写字母`{A-Z}`)，``{mark}`移动到标记位置的列，`'{mark}` 移动到标记位置的行首，还有一些特殊的标记，`'`表示跳转前光标的位置

* 选择文本  
  `v`不规则选择  
  `V`按行选择  
  `Ctrl + V`按列选择  

* 插入/修改  
  `i`在当前字符前面插入  
  `I`在行首插入  
  `a`在当前字符后面插入  
  `A`在行尾插入  
  `o`在当前行的下一行插入  
  `O`在当前行的上一行插入  
  `r`更改当前的字符  
  `R`更改多个字符  
  `cw/caw`更改单词  
  `cf + 字符`更改从当前字符到指定字符  
  `c$`更改从当前字符到行尾  
  `cc`更改整行  

* 删除  
  `x`删除字符  
   `df + 字符`删除从当前字符到指定字符  
   `dw/daw`删除单词  
   `d$`删除从当前光标到行尾  
   `dd`删除一行  

* 剪切与粘帖  
  `dd + p`delete一行，然后放在当前光标下方  
  `dd + P`delete一行，然后放在当前光标上方  
  `dw + p` delete单词，然后放在当前光标后面  
  `dw + P` delete单词，然后放在当前光标前面  
  `p/P`可接受计数前缀，重复粘贴  

* 复制  
  `yw`复制单词  
  `yf`复制从当前字符到指定字符  
  `y$`复制当前光标到行尾  
  `yy`复制整行  

* 撤销和恢复  
  `u`撤销  
  `ctrl + r`重做  

* 重复操作   
  `数字+action`表示执行某个操作多少次  
  `.`重复上一个操作  

* 宏录制  
  `q + 寄存器(a-z)`开始录制  
  `录制动作`  
  `q`停止录制  
  `@ + 寄存器 / @@`replay被录制的宏  

# 扩展阅读

* **Vim配置**  
  [从零搭建和配置OSX开发环境](http://yuez.me/cong-ling-da-jian-he-pei-zhi-osxkai-fa-huan-jing/)  
  [将你的Vim 打造成轻巧强大的IDE](http://yuez.me/jiang-ni-de-vim-da-zao-cheng-qing-qiao-qiang-da-de-ide/)
* **Vim插件**  
  [vim中的杀手级插件: vundle](http://zuyunfei.com/2013/04/12/killer-plugin-of-vim-vundle/)  
  [谁说Vim不是IDE？（三）](http://www.cnblogs.com/chijianqiang/archive/2012/11/06/vim-3.html)  
  [vim中的杀手级插件: YouCompleteMe](http://zuyunfei.com/2013/05/16/killer-plugin-of-vim-youcompleteme/)  
* **Vim入门和使用技巧**  
  [简明 Vim 练级攻略](http://coolshell.cn/articles/5426.html)  
* **Vimscript**  
  [Learn Vimscript the Hard Way](http://learnvimscriptthehardway.stevelosh.com/)