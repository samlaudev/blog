---
layout: page
title: Shell（二）：变量、数据重定向和管道
date: 2015-05-21
tags: 工具
---

在上一篇博客[Shell（一）：功能、配置和插件](http://www.jianshu.com/p/f51b178237c8)中，介绍了为什么要使用shell，shell有哪些功能，如何使用[oh my zsh](http://ohmyz.sh)来提高效率等，本篇重点介绍，shell中的**变量**的如何设置和读取数据，读取之后如何使用变量？每个程序一般都有输入和输出，让我们看看**数据重定向**如何处理输入和输出的？还有，Unix/Linux系统提供丰富的工具，我们如何将这些工具通过**管道**来组合成更加强大的宏工具呢？下面，由我来逐一详细介绍变量、数据重定向和管道。
![Variable & Redirection & Pipe.png](/assets/images/2015/166109-d9ff62f018b1fa7f.png)

## 变量

### 变量的作用

变量与其他程序设计语言一样，都是**存储数据**，然后被程序引用。相比于不使用变量，而是直接使用数据，存在两个问题：

1. 当数据改变时，直接使用数据的时候却不能灵活地根据数据改变而随着改变，而使用变量却不同，它能够做到这点。
2. 当数据发生变化时，如果想保证数据**一致性**，必须查找所有引用该数据的所有地方，然后将它修改，当下一次再需要修改时，也是像这种情况一样，是多么繁琐的事，而变量却不用，只需要修改变量值即可。

因此，变量具有**可变性**和**易于修改**的两个特点。

### 变量的分类

在shell中，大概分为两种变量：**环境变量**和**局部变量**，主要区别在于它们的使用范围不同，环境变量可以在父进程与子进程之间共享，而自定义变量只在本进程使用。举一个简单的例子来说明：
![no share variable.png](/assets/images/2015/166109-5340af1f33b63de3.png)
我首先设置一个shell变量`devname=sam`，然后输入`bash`打开一个新的shell，而这个shell是**子进程**，然后`echo $devname`输出变量值，变量值为空，最后`exit`退出子进程。
![share variable.png](/assets/images/2015/166109-a52aea6563713ca7.png)
但使用`export devname`设置环境变量后，再次进入输入`bash`进入子进程之后，`echo $devname`输出变量值，这次变量值是`sam`

##### 查看环境变量`env`和`set`

如果想查看**系统**中以及**自定义**有哪些环境变量，可以使用`env`命令：
![env command.png](/assets/images/2015/166109-e684c0d41ad4ea88.png)
而`set`命令不仅能查看环境变量，还可以查看与shell接口有关的变量，下面只截取一部分变量：
![set command.png](/assets/images/2015/166109-4dab21dd3ac37e2b.png)

### 变量有哪些操作

##### 显示`echo $variable`

如果你想显示某个变量的值，例如`PATH`，你只需要输入：

```
echo $PATH
```

![echo command.png](/assets/images/2015/166109-a6f216e96c4d0eb9.png)
注意上面一条命令，需要在变量名前加上一个符号`$`，这样才能访问变量

##### 设置`variable=value`和取消`unset`

如果你想设置某个变量的值，只需在变量名和变量值之间用符号`=`连接就行了，例如：
![set variable.png](/assets/images/2015/166109-22611d1027b62f8b.png)
由上面的输入命令`echo $devname`，显示结果为**空**。由此可知，一开始如果没有设置某个变量时，它的是为**空**。另外，**设置变量的规则**还需要几点注意：

1. 在命名变量名时，变量名称只能是英文字母和数字，而且首字母不能是数字。下面演示一个错误的例子：
   ![wrong variable name.png](/assets/images/2015/166109-e1085bcca7536ba2.png)

2. 等号`=`两边不能有**空格**
   ![blank can't exist.png](/assets/images/2015/166109-e4f7ef12542152c1.png)

3. 如果变量值有空格，可用双引号`" "`或单引号`' '`来包围变量值，但两者是有区别：
   双引号`" "`内的一些特殊字符，可以保持原有的特性，例如：
   ![double quotation marks.png](/assets/images/2015/166109-ee26f446e96f7d9b.png)
   而单引号`' '`内的一些特殊字符，仅为一般字符，即纯文本，例如：
   ![single quotation marks.png](/assets/images/2015/166109-ef246fb3e3831fc8.png)

4. 如果想显示一些特殊字符（$、空格、!等），在字符前面加上用转义字符`\`

5. 有些时候，变量的值可能**来源于一些命令**，这时你可以使用反单引号` ` `命令` ` `或`$(命令)`，例如：
   使用反单引号` ` `命令` ` `的方式
   ![get information from comand 1.png](/assets/images/2015/166109-04b087024b4df082.png)
   使用`$(命令)`的方式
   ![get information from comand 2.png](/assets/images/2015/166109-d78a16acd5bcb0f8.png)

6. 如果变量想**增加变量的值**，可以使用`$variable`累加
   ![append variable value.png](/assets/images/2015/166109-edb825a03671d3f3.png)

7. 如果变量需要在其他子进程使用，用`export`关键字来设置变量为环境变量

```
export VARIABLE
```

8. 系统环境变量一般都是**字母全部大写**，例如：`PATH`，`HOME`，`SHELL`等

9. 如果想取消设置变量的值，使用`unset variable`命令。注意，变量之前是没有符号`$`
   ![unset variable.png](/assets/images/2015/166109-58c8ba089d523ee0.png)

### 环境配置文件

之前那些设置的环境变量，一旦退出系统后，就**不能再次使用**，如果想再次使用，必须重新再设置才行。如果想就算退出系统，也能重新使用自定义的环境变量，那怎么办呢？

不用怕，系统提供一些环境配置文件：`/etc/profile`和`~/.bash_profile`。`/etc/profile`是系统整体的设置，每个用户共享，最好不要修改；而`~/.bash_profile`属于单个用户的设置，每个用户设置后，互不影响和共享。但因为我使用[oh my zsh](http://ohmyz.sh)，之前`~/.bash_profile`设置一些配置都不生效了，但它提供一个环境配置文件`.zshrc`，所以如果想设置环境变量TEST，只需将`export TEST=test`添加`.zshrc`即可。
![export variable in zshrc file.png](/assets/images/2015/166109-b03fd4ef8c72ff77.png)

但在`.zshrc`文件设置好环境变量`TEST`后，`echo $TEST`为空，原因是还没使用`source`命令来读取环境配置文件。使用`source .zshrc`命令之后，设置环境变量`TEST`生效了
![source command.png](/assets/images/2015/166109-87a3214c1a5860dd.png)

## 数据重定向

### 含义

当输入命令行时，一般都有输入参数(standard input)，而命令行处理完之后，一般都有输出结果，结果有可能成功(standard output)，也有可能失败(standard error)，而这些结果一般都会输出到屏幕上，如果你想控制结果输出到文件或以文件作为输入的话，你需要了解数据重定向的分类和符号操作。
![Redirection.png](/assets/images/2015/166109-84ba0aab079a82ea.png)

### 分类

数据重定向主要分为三类：

* `stdin`，表示标准输入，代码为0，使用`<`或`<<`操作符
  符号`<`表示以文件内容作为输入
  符号`<<`表示输入时的结束符号
* `stdout`，表示标准输出，代码为1，使用`>`或`>>`操作符
  符号`>`表示以**覆盖**的方式将**正确**的数据输出到指定文件中
  符号`>>`表示以**追加**的方式将**正确**的数据输出到指定文件中
* `stderr`，表示标准错误输出，代码为2，使用`2>`或`2>>`操作符
  符号`2>`表示以**覆盖**的方式将**错误**的数据输出到指定文件中
  符号`2>>`表示以**追加**的方式将**错误**的数据输出到指定文件中

### 使用

##### stdout

当你输入`ls`命令，屏幕会显示当前目录有哪些文件和目录；而当你使用符号`>`时，输出结果将重定向到`dir.txt`文件，而不显示在屏幕上
![stdin demo.png](/assets/images/2015/166109-d3a7244c3ec65212.png)
而符号`>`与符号`>>`有什么**区别**呢？`>`表示当文件存在时，将文件内容清空，然后stdout结果存放到文件中。而`>>`表示当文件存在时，文件内容并没有清空，而是将stdout结果追加到文件尾部。

当你再次输入命令`ls > dir.txt`时，文件内容并没有改变，因为之前文件内容被清空，然后stdout结果存放在`dir.txt`文件
![stdin demo 1.png](/assets/images/2015/166109-245de891334f7e8c.png)

而你这次使用符号`ls >> dir.txt`的话，文件内容被追加到`dir.txt`文件
![stdin demo 2.png](/assets/images/2015/166109-0c2d66e948db3b0f.png)

##### stderr

这次我输入命令`ls test`显示一个不存在的文件，会显示错误信息。然后将错误信息输出到文件`error.txt`。
![stderr demo 1.png](/assets/images/2015/166109-965e4dab95b273f8.png)
如果你想追加错误信息，可以使用`2>>`符号
![stderr demo 2.png](/assets/images/2015/166109-5876573a86ca7274.png)

##### stdout & stderr

* 将stdout和stderr分离：**`>`和`2>`符号**
  输入`ls README.md test`，在屏幕显示既有正确信息，也有错误信息，如果想将正确信息和错误信息分离到不同文件，你可以同时使用`>`和`2>`符号
  ![seperate stdout & stderr.png](/assets/images/2015/166109-90379291047847c8.png)

* 将stdout和stderr合并：**`&>`符号**
  如果你想将正确信息和错误信息**合并**，且输出到同一个文件，可以使用`&>`符号
  ![combine stdout & stderr.png](/assets/images/2015/166109-8666387bac111c1f.png)

##### stdin

一般输入一些简单的数据的方式都是通过**键盘**，但是如果要输入大量的数据，最好还是通过**文件**的方式。举一个简单例子：
首先输入`cat > test`命令之后，你就可以输入内容，那些内容最终会存放在`test`文件
![stdin demo 1.png](/assets/images/2015/166109-972c852dfb7918a0.png)
但如果有大量数据从一个文件导入到`test`文件时，此时需要用到`<`符号
![stdin demo 2.png](/assets/images/2015/166109-46da2f1a875a801a.png)
还一个符号`<<`需要解释，符号`<<`表示输入时的结束符号。输入`cat > test << "eof"`命令之后，你就可以输入内容，那些内容最终会存放在`test`文件，输入完内容后可以输入`eof`来结束输入
![stdin demo 3.png](/assets/images/2015/166109-f0e8ec730763a43f.png)

## 管道

在Unix设计哲学中，有一个重要设计原则--[KISS](http://en.wikipedia.org/wiki/KISS_principle)(Keep it Simple, Stupid)，大概意思就是**只关注如何做好一件事，并把它做到极致**。每个程序都有各自的功能，那么有没有一样东西将不同功能的程序互相连通，自由组合成更为强大的宏工具呢？此时，**管道**出现了，它能够让程序实现了**高内聚，低耦合**。
![How Pipe works.png](/assets/images/2015/166109-fb88f57ffc51ce69.png)
如果我想查看文件是否存在某个关键字，此时我可以使用管道
![Pipe Demo.png](/assets/images/2015/166109-d5bea984276b35b7.png)
命令`cat README.md | grep 'pod'`的处理过程分为两步：

  1. `cat README.md`查看文件内容
  2. 然后将`cat README.md`输出的内容作为`grep 'pod'`命令的输入，再进行处理。

上面一个很关键的符号` | `，就是管道，它能够将前一个命令处理完的`stdout`作为下一条命令`stdin`。下面我们逐一看一下有**哪些命令**是支持管道的：

### 选取命令

* cut：在文件中选取**字段**
* grep：在文件中根据关键字选取**行**，一般都会结合正则表达式来使用

### 排序命令

* sort
* uniq
* wc

### 分割文件命令

* split

### 参数代换

* xargs

## 扩展阅读

* [鸟哥的Linux私房菜-基础学习篇](http://book.douban.com/subject/4889838/)  
* [Unix Pipes 管道原稿](http://coolshell.cn/articles/1351.html)  