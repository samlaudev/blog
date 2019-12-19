---
layout: post
title: iOS应用程序的生命周期
date: 2015-06-22
tags: iOS
---

iOS应用程序一般都是由**自己编写的代码**和**系统框架**(system frameworks)组成，系统框架提供一些基本infrastructure给所有app来运行，而你提供自己编写的代码来定制app的外观和行为。因此，了解iOS infrastructure和它们如何工作对编写app是很有帮助的。

## Main函数入口

所有基于C编写的app的**入口**都是`main`函数，但iOS应用程序有点不同。不同就是你不需要为iOS应用程序而自己编写`main`函数，当你使用Xcode创建工程的时候就已经提供了。除非一些特殊情况，否则你**不应该**修改Xcode提供的`main`函数实现。示例代码如下：

```
#import <UIKit/UIKit.h>
#import "AppDelegate.h"

int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    } 
}
```

上面实例代码中有一个很重要的函数[UIApplicationMain](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIKitFunctionReference/index.html#//apple_ref/c/func/UIApplicationMain)，它主要是创建app的几个核心对象来处理以下过程：

1. 从可用`Storyboard`文件加载用户界面
2. 调用`AppDelegate`自定义代码来做一些初始化设置
3. 将app放入`Main Run Loop`环境中来响应和处理与用户交互产生的事件

## 应用程序的架构

iOS应用程序都遵循`Model-View-Controller`的架构，`Model`负责存储数据和处理业务逻辑，`View`负责显示数据和与用户交互，`Controller`是两者的中介，协调`Model`和`View`相互协作。它们的**通讯规则**如下：

1. `Controller`能够访问`Model`和`View`，`Model`和`View`不能互相访问
   ![MVC Communication - Reference from Stanford University.png](/assets/images/2015/166109-1ca32c3031c071ae.png)

2. 当`View`与用户交互产生事件时，使用`target-action`方式来处理
   ![MVC Communication - Reference from Stanford University.png](/assets/images/2015/166109-0a7f865fbfcf22c1.png)

3. 当`View`需要处理一些特殊UI逻辑或获取数据源时，通过`delegate`或`data source`方式交给`Controller`来处理
   ![MVC Communication - Reference from Stanford University.png](/assets/images/2015/166109-7023447d80bc2277.png)

4. `Model`不能直接与`Controller`通信，当`Model`有数据更新时，可以通过`Notification`或`KVO (Key Value Observing)`来通知`Controller`更新`View`
   ![MVC Communication - Reference from Stanford University.png](/assets/images/2015/166109-2ecd208e2cf93528.png)

了解iOS的MVC设计模式之后，我们从下图来了解在MVC模式下iOS应用程序有哪些**关键对象**以及它们**职责**主要是什么？
![The Structure of an App.png](/assets/images/2015/166109-ab7e67c32b810a08.png)

* [UIApplication](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIApplication_Class/)对象
  用户与iOS设备交互时产生的事件(Multitouch Events，Motion Event，Remote Control Event)交由`UIApplication`对象来分发给**control objects**([UIControl](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIControl_Class/index.html#//apple_ref/occ/cl/UIControl))对应的**target objects**来处理并且管理整个事件循环，而一些关于app运行时重要事件委托给`app delegate`来处理。

* [App delegate](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIApplicationDelegate_Protocol/)对象
  `App delegate`对象遵循`UIApplicationDelegate`协议，响应app运行时重要事件(app启动、app内存不足、app终止、切换到另一个app、切回app)，主要用于app在启动时初始化一些重要数据结构；例如，初始化`UIWindow`，设置一些属性，为window添加`rootViewController`。

* [View controller](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIViewController_Class/)对象
  `View Controller`有一个`view`属性是view层次结构中的**根view**，你可以添加子view来构建复杂的view；controller有一些`viewDidLoad`、`viewWillAppear`等方法来管理view的生命周期；由于它继承`UIResponder`，所有还会响应和处理用户事件。

* [Documents](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIDocument_Class/)和data model对象
  **data model**对象主要用来存储数据。例如，饿了么app在搜索切换地址后，有历史记录搜索地址历史，当app下次启动时，读取和显示搜索地址历史。
  **document**对象(继承UIDocument)用来管理一些或所有的data model对象。document对象并不是必须的，但提供一种方便的方式来分组属于单个文件或多个文件的数据。

* [UIWindow](https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UIWindow_Class/)对象
  `UIWindow`对象位于view层次结构中的最顶层，它充当一个基本容器而不显示内容，如果想显示内容，添加一个content view到window。
  它也是继承`UIResponder `，所以它也是会响应和处理用户事件。

* [View](https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UIView_Class/)、[control](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIControl_Class/)、[layer](https://developer.apple.com/library/ios/documentation/GraphicsImaging/Reference/CALayer_class/)对象
  `View`对象可以通过addSubview和removeFromSuperview 等方法**管理**view的层次结构，使用layoutIfNeeded和setNeedsLayout等方法**布局**view的层次结构，当你发现系统提供view已经满足不了你想要的外观需求时，可以重写drawRect方法或通过layer属性来构造复杂的**图形外观和动画**。还有一点，UIView也是继承UIResponder，所以也能够**处理用户事件**。
  `Control`对象通常就是处理特定类型用户交互的View，常用的有button、switch、text field等。
  除了使用`View`和`Control`来构建view层次结构来影响app外观之外，还可以使用Core Animation框架的`Layer`对象来渲染view外观和构建复杂的动画。

## Main Run Loop

一个iOS应用程序的**main run loop**主要作用是处理所有与用户相关的事件。`UIApplication`对象在启动时就设置main run loop和使用它来处理事件和更新基于view的界面。正如它名字所示，main run loop是运行在应用程序的主线程。这样就确保与接收到用户相关的事件被**有序地**处理。

下图显示main run loop的架构和用户事件最终是怎样被应用程序处理。当用户与设备交互时，系统就会生成与交互关联的事件，然后被应用程序的UIKit通过一个特殊的端口来分发。应用程序把事件放入队列，然后**逐个**分发到main run loop来执行。`UIApplication`对象是第一个对象接收到事件，然后决定怎样处理它。一个**touch event**通常都被分发到main window对象，然后依次分发到**发生触碰的view**。其他event的接收事件对象路径可能有点不同。
![Main Run Loop from Apple Document](/assets/images/2015/166109-2048b199de727ec6.png)

大多数的事件通过使用main run loop来分发，但有些不是。有些事件被发送到一个delegate对象或传递到你提供的block中。想了解更多如何处理大多数类型的事件，其中包括touch、remote control、motion、accelerometer和gyroscopic等事件，请查阅[Event Handle Guide for iOS](https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS/Introduction/Introduction.html)。

## 应用程序的状态和多任务

有时系统会从app一种状态切换另一种状态来响应系统发生的事件。例如，当用户按下home键、电话打入、或其他中断发生时，当前运行的应用程序会切换状态来响应。应用程序的状态有以下几种：

![App State from Apple Document](/assets/images/2015/166109-fa48f62bf0ab9db6.png)

* Not running：app还没运行
* Inactive：app运行在foreground但没有接收事件
* Active：app运行在foreground和正在接收事件
* Background：运行在background和正在执行代码
* Suspended：运行在background但没有执行代码

大多数发生状态转换时都会调用`delegate`对象对应的方法来响应app的状态改变。下面汇总了`delegate`对象的所有方法，当app状态发生转换时，你可能会使用到它们。

* `application:willFinishLaunchingWithOptions:` - 这个方法是你在启动时的第一次机会来执行代码
* `application:didFinishLaunchingWithOptions:` - 这个方法允许你在显示app给用户之前执行最后的初始化操作
* `applicationDidBecomeActive:` - app已经切换到active状态后需要执行的操作
* `applicationWillResignActive:` - app将要从前台切换到后台时需要执行的操作
* `applicationDidEnterBackground:` - app已经进入后台后需要执行的操作
* `applicationWillEnterForeground:` - app将要从后台切换到前台需要执行的操作，但app还不是active状态
* `applicationWillTerminate:` - app将要结束时需要执行的操作

现在讲下app启动、来回切换app和锁屏时状态的切换和调用对应哪些delegate对象的方法：

* app启动和active/inactive
  ![Launch and active/inactive from Apple WWDC 2011 Session](/assets/images/2015/166109-ab5e6bc7a51e890e.gif)
  如图所示，当app启动时，首先由`not running`状态切换到`inactive`状态，此时调用`application:didFinishLaunchingWithOptions:`方法；然后由`inactive`状态切换到`active`状态，此时调用`applicationDidBecomeActive:`方法。

 ![Launch and active/inactive 2 from Apple WWDC 2011 Session](/assets/images/2015/166109-74666714bc4bffb9.gif)

 当app发生中断时，由`active`状态切换到`inactive`状态，此时调用`applicationWillResignActive:`方法。

* 来回切换app
  ![Switch from an app from Apple WWDC 2011 Session](/assets/images/2015/166109-83f006b9026dbbe5.gif)
  如图所示，当切换到另一个app时，由状态`active`切换到`inactive`，此时调用`applicationWillResignActive:`方法；然后从`inactive`状态切换到`running`状态，此时调用`applicationDidEnterBackground:`方法。

 ![Switch to an app from Apple WWDC 2011 Session](/assets/images/2015/166109-a6743964db4677be.gif)
而当切换回本来的app时，由`running`状态切换到`inactive`状态，此时调用`applicationWillEnterForeground:`方法，然后由`inactive`状态切换到`active`状态，调用`applicationDidBecomeActive:`方法。

* 锁屏
  ![Device lock from Apple WWDC 2011 Session](/assets/images/2015/166109-c9ac753d01595b03.gif)
  如何所示，当手机锁屏时，由状态`active`切换到`inactive`，此时调用`applicationWillResignActive:`；然后再由`inactive`状态切换到`running`状态，此时调用`applicationDidEnterBackground:`方法。

 更多关于app状态切换以及调用`app delegate`哪些方法，请观看WWDC 2011 Session的[session_320__adopting_multitasking_in_your_app](https://developer.apple.com/videos/wwdc/2011/)视频。

## 应用程序的终止

系统常常是为其他app启动时由于内存不足而回收内存最后需要终止应用程序，但有时也会是由于app很长时间才响应而终止。如果app当时运行在后台并且没有暂停，系统会在应用程序终止之前调用`applicationWillTerminate:`来保存用户的一些重要数据以便下次启动时恢复到app原来的状态。

## 总结

本文总结了iOS应用程序从启动到结束过程中有哪些关键对象在参与，以及当用户与系统交互时产生事件时，系统利用main run loop来管理事件循环，决定将事件交给系统哪些对象处理和如何处理。而当app启动、来回切换app和锁屏时，app的状态如何切换和调用对应的哪些`app delegate`对象来处理。

## 扩展阅读

[App Programming Guide for iOS](https://developer.apple.com/library/ios/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/TheAppLifeCycle/TheAppLifeCycle.html#//apple_ref/doc/uid/TP40007072-CH2-SW1)  
[Developing iOS 7 App for iPhone and iPad](https://itunes.apple.com/us/course/developing-ios-7-apps-for/id733644550)  
[深入理解RunLoop](http://blog.ibireme.com/2015/05/18/runloop/)  
[Objective-C Autorelease Pool 的实现原理](http://blog.leichunfeng.com/blog/2015/05/31/objective-c-autorelease-pool-implementation-principle/)