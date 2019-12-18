---
layout: post
title: 行为驱动开发iOS
date: 2015-04-24 
tags: iOS
---

![Designer News.png](/assets/images/2015/166109-09799d12cae59648.png)

前段时间在[design+code](https://designcode.io/iosdesign)购买了一个学习iOS设计和编码在线课程，使用Sketch设计App，然后使用Swift语言实现[Designer News](https://news.layervault.com)客户端。作者Meng To已经开源到[Github:MengTo/DesignerNewsApp · GitHub](https://github.com/MengTo/DesignerNewsApp)。虽然实现整个Designer News客户端基本功能，但是采用臃肿MVC(Model-View-Controller)架构，不易于代码的测试和复用，于是使用[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa)实现MVVM(Model-View-View Model)架构，加上一个用Objective-C实现的BDD测试框架[Kiwi](https://github.com/kiwi-bdd/Kiwi)来单元测试，就可以行为驱动开发iOS App。

# ReactiveCocoa

ReactiveCocoa是一个用Objective-C编写，具有函数式和响应式特性的编程框架。大多数的开发者他们解决问题的思考方式都是如何完成任务，通常的做法就是编写很多指令，然后修改重要数据结构的状态，这种编程范式叫做命令式编程([Imperative Programming](http://en.wikipedia.org/wiki/Imperative_programming))。与命令式编程不同的是函数式编程([Functional Programming](http://en.wikipedia.org/wiki/Functional_programming))，思考问题的方式是完成什么任务，怎样描述这个任务。关于对函数式编程入门概念的理解，可以参考酷壳《[函数式编程](http://coolshell.cn/articles/10822.html)》这篇文章，深入浅出对函数式编程的思考方式、特性和技术通过一些示例来讲解。

### ReactiveCocoa解决哪些问题？

* **对象之间状态与状态的依赖过多问题**
  借用ReactiveCocoa中一个例子来说明：用户在登录界面时，有一个用户名输入框和密码输入框，还有一个登录按钮。登录交互要求如下：

  1. 当用户名和密码符合验证格式，并且之前还没登录时，登录按钮才能点击。
  2. 当点击登录成功登录后，设置已登录状态。

 传统的做法代码如下：

 ```
 static void *ObservationContext = &ObservationContext;

 - (void)viewDidLoad {
    [super viewDidLoad];

    [LoginManager.sharedManager addObserver:self forKeyPath:@"loggingIn" options:NSKeyValueObservingOptionInitial context:&ObservationContext];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(loggedOut:) name:UserDidLogOutNotification object:LoginManager.sharedManager];

    [self.usernameTextField addTarget:self action:@selector(updateLogInButton) forControlEvents:UIControlEventEditingChanged];
    [self.passwordTextField addTarget:self action:@selector(updateLogInButton) forControlEvents:UIControlEventEditingChanged];
    [self.logInButton addTarget:self action:@selector(logInPressed:) forControlEvents:UIControlEventTouchUpInside];
}
 
 - (void)dealloc {
    [LoginManager.sharedManager removeObserver:self forKeyPath:@"loggingIn" context:ObservationContext];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
 
 - (void)updateLogInButton {
    BOOL textFieldsNonEmpty = self.usernameTextField.text.length > 0 && self.passwordTextField.text.length > 0;
    BOOL readyToLogIn = !LoginManager.sharedManager.isLoggingIn && !self.loggedIn;
    self.logInButton.enabled = textFieldsNonEmpty && readyToLogIn;
}

 - (IBAction)logInPressed:(UIButton *)sender {
    [[LoginManager sharedManager]
        logInWithUsername:self.usernameTextField.text
        password:self.passwordTextField.text
        success:^{
            self.loggedIn = YES;
        } failure:^(NSError *error) {
            [self presentError:error];
        }];
}

 - (void)loggedOut:(NSNotification *)notification {
    self.loggedIn = NO;
}

 - (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == ObservationContext) {
        [self updateLogInButton];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

 ```

以上使用KVO、Notification、Target-Action等处理事件或消息的方式编写的代码分散到各个地方，变得杂乱和难以理解；但是使用RACSignal统一处理的话，代码更加简洁和易读。使用RAC后代码如下：

```
- (void)viewDidLoad {
    [super viewDidLoad];

    @weakify(self);

    RAC(self.logInButton, enabled) = [RACSignal
        combineLatest:@[
            self.usernameTextField.rac_textSignal,
            self.passwordTextField.rac_textSignal,
            RACObserve(LoginManager.sharedManager, loggingIn),
            RACObserve(self, loggedIn)
        ] reduce:^(NSString *username, NSString *password, NSNumber *loggingIn, NSNumber *loggedIn) {
            return @(username.length > 0 && password.length > 0 && !loggingIn.boolValue && !loggedIn.boolValue);
        }];

    [[self.logInButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(UIButton *sender) {
        @strongify(self);

        RACSignal *loginSignal = [LoginManager.sharedManager
            logInWithUsername:self.usernameTextField.text
            password:self.passwordTextField.text];

            [loginSignal subscribeError:^(NSError *error) {
                @strongify(self);
                [self presentError:error];
            } completed:^{
                @strongify(self);
                self.loggedIn = YES;
            }];
    }];

    RAC(self, loggedIn) = [[NSNotificationCenter.defaultCenter
        rac_addObserverForName:UserDidLogOutNotification object:nil]
        mapReplace:@NO];
}
```

* **传统MVC架构中，由于Controller承担数据验证、映射数据模型到View和操作View层次结构等多个责任，导致Controller过于臃肿，不利于代码的复用和测试。**
  在传统的MVC架构中，主要有Model, View和Controller三部分组成。Model主要是保存数据和处理业务逻辑，View将数据显示，而Controller调解关于Model和View之间的所有交互。
  当数据到达时，Model通过Key-Value Observation来通知View Controller, 然后View Controller更新View。当View与用户交互后，View Controller更新Model。

![Typical MVC paradigm.png](/assets/images/2015/166109-4ab227d57daf5394.png)

正如你所见，View Controller隐式承担很多责任：数据验证、映射数据模型到View和操作View层次结构。MVVM将很多逻辑从View Controller移走到View-Model，等介绍完ReactiveCocoa后会介绍MVVM架构。还有一些关于如何**减负**View Controller好文章请参阅[objc中国](http://objccn.io)更轻量的View Controllers系列：

 * [更轻量的 View Controllers](http://objccn.io/issue-1-1/)

 * [整洁的 Table View 代码](http://objccn.io/issue-1-2/)

 * [测试 View Controllers](http://objccn.io/issue-1-3/)

* **使用Signal来代替KVO、Notification、Delegate和Target-Action等传递消息**
  iOS开发中有多种消息传递方式，KVO、Notification、Delegate、Block和Target-Action，对于它们之间有什么差异以及如何选择请参考《[消息传递机制](http://objccn.io/issue-7-4/)》。但RAC提供[RACSignal](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/swift-development/Documentation/FrameworkOverview.md)来统一消息传递机制，不再为如何选择何种传递消息方式而烦恼。

  RAC对常用UI控件事件进行封装成一个RACSignal对象，以便对发生的各种事件进行监听。
  KVO示例代码如下：

```
// When self.username changes, logs the new name to the console.
//
// RACObserve(self, username) creates a new RACSignal that sends the current
// value of self.username, then the new value whenever it changes.
// -subscribeNext: will execute the block whenever the signal sends a value.
[RACObserve(self, username) subscribeNext:^(NSString *newName) {
    NSLog(@"%@", newName);
}];
```

Target-Action示例代码如下：

```
// Logs a message whenever the button is pressed.
//
// RACCommand creates signals to represent UI actions. Each signal can
// represent a button press, for example, and have additional work associated
// with it.
//
// -rac_command is an addition to NSButton. The button will send itself on that
// command whenever it's pressed.
self.button.rac_command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
    NSLog(@"button was pressed!");
    return [RACSignal empty];
}];
```

Notification示例代码如下：

```
 // Respond to when email text start and end editing
 [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UITextFieldTextDidBeginEditingNotification object:self.emailTextField] subscribeNext:^(id x) {
      [self.emailImageView animate];
      self.emailImageView.image = [UIImage imageNamed:@"icon-mail-active"];
      self.emailTextField.background = [UIImage imageNamed:@"input-outline-active"];
  }];

 [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UITextFieldTextDidEndEditingNotification object:self.emailTextField] subscribeNext:^(id x) {
      self.emailTextField.background = [UIImage imageNamed:@"input-outline"];
      self.emailImageView.image = [UIImage imageNamed:@"icon-mail"];
  }];
```

除此之外，还可以使用[AFNetworking](https://github.com/AFNetworking/AFNetworking)访问服务器后对返回数据自创建一个RACSignal。示例代码如下：

```
 + (RACSubject*)storiesForSection:(NSString*)section page:(NSInteger)page
{
    RACSubject* signal = [RACSubject subject];

    NSDictionary* parameters = @{
        @"page" : [NSString stringWithFormat:@"%ld", (long)page],
        @"client_id" : clientID
    };

    [[AFHTTPSessionManager manager] GET:[DesignerNewsURL stroiesURLString] parameters:parameters success:^(NSURLSessionDataTask* task, id responseObject) {
                NSLog(@"url string = %@", task.currentRequest.URL);
                [signal sendNext:responseObject];
                [signal sendCompleted];
    } failure:^(NSURLSessionDataTask* task, NSError* error) {
                NSLog(@"url string = %@", task.currentRequest.URL);
                [signal sendError:error];
    }];

    return signal;
}
```

有些朋友可以感觉有点奇怪，上面代码明明返回的是[RACSubject](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/swift-development/Documentation/FrameworkOverview.md)，而不是RACSignal，其实RACSubject是RACSignal的子类，但是RACSubject写出代码更加简洁，所以采用RACSubject(官方**不推荐**使用)。等下将RAC核心类设计时，你就会了解它们之间的关系和如何选择。

### ReactiveCocoa核心类设计

关于RAC核心类设计，官方文档有详细的解释：[Framework Overview](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/swift-development/Documentation/FrameworkOverview.md)

### Sequence和Signal基本操作

了解完整个RAC核心类设计之后，要学会对Sequence和Signal基本操作，比如：用signal执行side effects，转换streams, 合并stream和合并signal。详情请查阅官方文档：[Basic Operators](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/swift-development/Documentation/BasicOperators.md)

### MVVM架构

![MVVM high level.png](/assets/images/2015/166109-81012f4948373da5.png)
在MVVM架构中，通常都将view和view controller看做一个整体。相对于之前MVC架构中view controller执行很多在view和model之间数据映射和交互的工作，现在将它交给view model去做。
至于选择哪种机制来更新view model或view是没有强制的，但通常我们都选择ReactiveCocoa。ReactiveCocoa会监听model的改变然后将这些改变映射到view model的属性中，并且可以执行一些业务逻辑。
举个例子来说，有一个model包含一个dateAdded的属性，我想监听它的变化然后更新view model的dateAdded属性。但model的dateAdded属性的数据类型是NSDate，而view model的数据类型是NSString，所以在view model的init方法中进行数据绑定，但需要数据类型转换。示例代码如下：

```
RAC(self,dateAdded) = [RACObserve(self.model,dateAdded) map:^(NSDate*date){ 
    return [[ViewModel dateFormatter] stringFromDate:date];
}];
```

ViewModel调用dateFormatter进行数据转换，且方法dateFormatter可以复用到其他地方。然后view controller监听view model的dateAdded属性且绑定到label的text属性。

```
RAC(self.label,text) = RACObserve(self.viewModel,dateAdded);
```

现在我们抽象出日期转换到字符串的逻辑到view model，使得代码可以**测试**和**复用**，并且帮view controller*瘦身*。

# Kiwi

Kiwi是一个iOS行为驱动开发([Behavior Driven Development](http://en.wikipedia.org/wiki/Behavior-driven_development))的库。相比于Xcode提供单元测试的XCTest是从**测试**的角度思考问题，而Kiwi是从**行为**的角度思考问题，测试用例都遵循三段式**Given-When-Then**的描述，清晰地表达测试用例是测试什么样的对象或数据结构，在基于什么上下文或情景，然后做出什么响应。

```
describe(@"Team", ^{
    context(@"when newly created", ^{
        it(@"has a name", ^{
            id team = [Team team];
            [[team.name should] equal:@"Black Hawks"];
        });

        it(@"has 11 players", ^{
            id team = [Team team];
            [[[team should] have:11] players];
        });
    });
});

```

我们很容易根据上下文将其提取为Given..When..Then的三段式自然语言

```
Given a Team, when be newly created, it should have a name, it should have 11 player

```

用Xcode自带的XCTest测试框架写过测试代码的朋友可能体会到，以上代码更加易于阅读和理解。就算以后有新的开发者加入或修护代码时，不需要太大的成本去阅读和理解代码。具体如何使用Kiwi，请参考两篇文章：

+ [TDD的iOS开发初步以及Kiwi使用入门](http://onevcat.com/2014/02/ios-test-with-kiwi/)
+ [Kiwi 使用进阶 Mock, Stub, 参数捕获和异步测试](http://onevcat.com/2014/05/kiwi-mock-stub-test/)

# Designer News UI

在编写Designer News客户端代码之前，首先通过UI来了解整个App的概况。设计Designer News UI的工具是[Sketch](http://bohemiancoding.com/sketch/)，想获得Designer News UI，请点击[下载Designer New UI](http://pan.baidu.com/s/1mg3ipAC)。
![Designer News Design.png](/assets/images/2015/166109-6ff5f2ae0b8f357d.png)
如果将所有的页面都逐个说明如何编写，会比较耗时间，所以只拿**登陆页面**来说明我是如何行为驱动开发iOS，但我会将整个项目的代码上传到[github](https://github.com/samlaudev/DesignerNewsForObjc)。

# 登陆界面

由于这个项目简单并且只有一个人开发(*多人开发的话，采用Storyboard不易于代码合并*)，加上Storyboard可以可视化的添加UI组件和Auto Layout的约束，并且可以同时预览多个不同分辨率iPhone的效果，极大地提高开发界面效率。
![Login.png](/assets/images/2015/166109-dc861450ea00c802.png)

# 登陆交互

登陆界面有Email输入框和密码输入框，当用户选中其他一个输入框时，左边对应的图标变成蓝色，同时会有pop动画表示用户准备要输入内容。
当用户没有输入有效的Email或密码格式时，用户是不能点击登陆按钮，只有当用户输入有效的邮件和密码格式时，才能点击登陆按钮。
![Login.gif](/assets/images/2015/166109-3d69043a4f832c73.gif)

我们可以使用**RAC**通过监听Text Field的**UITextFieldTextDidBeginEditingNotification**和**UITextFieldTextDidEndEditingNotification**的通知来处理用户选中Email输入框和密码输入框时改变图标和显示的动画。

```
#pragma mark - Text Field notification
- (void)textFieldStartEndEditing
{
    // Respond to when email text start and end editing
    [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UITextFieldTextDidBeginEditingNotification object:self.emailTextField] subscribeNext:^(id x) {
        [self.emailImageView animate];
        self.emailImageView.image = [UIImage imageNamed:@"icon-mail-active"];
        self.emailTextField.background = [UIImage imageNamed:@"input-outline-active"];
    }];

    [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UITextFieldTextDidEndEditingNotification object:self.emailTextField] subscribeNext:^(id x) {
        self.emailTextField.background = [UIImage imageNamed:@"input-outline"];
        self.emailImageView.image = [UIImage imageNamed:@"icon-mail"];
    }];

    // Respond to when password text start and end editing
    [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UITextFieldTextDidBeginEditingNotification object:self.passwordTextField] subscribeNext:^(id x) {
        [self.passwordImageView animate];
        self.passwordTextField.background = [UIImage imageNamed:@"input-outline-active"];
        self.passwordImageView.image = [UIImage imageNamed:@"icon-password-active"];
    }];

    [[[NSNotificationCenter defaultCenter] rac_addObserverForName:UITextFieldTextDidEndEditingNotification object:self.passwordTextField] subscribeNext:^(id x) {
        self.passwordTextField.background = [UIImage imageNamed:@"input-outline"];
        self.passwordImageView.image = [UIImage imageNamed:@"icon-password"];
    }];
}

```

当点击登陆按钮后，客户端向服务端发送验证请求，服务端验证完账户和密码后，用户便可以成功登陆。所以，接下来要了解RESTful API的基本概念和Designer News提供的RESTful API。

# Designer News API

### RESTful API基本概念和设计

**REST**全称是Representational State Transfer，翻译过来就是表现层状态转化。要想真正理解它的含义，从几个关键字入手：Resource, Representation, State Transfer

* ##### Resource(资源)

  资源就是网络上的实体，它可以是文字、图片、声音、视频或一种服务。但网络有这么多资源，该如何标识它们呢？你可以用[URL(统一资源定位符)](https://en.wikipedia.org/wiki/Uniform_Resource_Locator)来唯一标识和定位它们。只要获得资源对应的URL，你就可以访问它们。

* ##### Representation(表现层)

  资源是一种信息实体，它有多种表示方式。比如，文本可以用.txt格式表示，也可以用xml、json或html格式表示。

* ##### State Transfer(状态转换)

  客户端访问服务端，服务端处理完后返回客户端，在这个过程中，一般都会引起数据状态的改变或转换。
  客户端操作服务端，都是通过HTTP协议，而在这个HTTP协议中，有几个动词:**GET**, **POST**, **DELETE**和**UPDATE**

  * GET表示获取资源
  * POST表示新增资源
  * DELETE表示删除资源
  * UPDATE表示更新资源

理解RESTful核心概念后，我们来简单了解RESTful API设计以便可以看懂Designer News提供API。就拿Designer News获取Stories对应URL的一个例子来说明：
**客户端请求**
`GET https://api-news.layervault.com/api/v1/stories?client_id=91a5fed537b58c60f36be1sdf71ed1320e9e4af2bda4366f7dn3d79e63835278`

**服务端返回结果**(部分结果)

```
{
  "stories": [
    {
      "id": 46826,
      "title": "A Year of DuckDuckGo",
      "comment": "",
      "comment_html": null,
      "comment_count": 4,
      "vote_count": 17,
      "created_at": "2015-03-28T14:05:38Z",
      "pinned_at": null,
      "url": "https://news.layervault.com/click/stories/46826",
      "site_url": "https://api-news.layervault.com/stories/46826-a-year-of-duckduckgo",
      "user_id": 3334,
      "user_display_name": "Thomas W.",
      "user_portrait_url": "https://designer-news.s3.amazonaws.com/rendered_portraits/3334/original/portrait-2014-09-16_13_25_43__0000-333420140916-9599-7pse94.png?AWSAccessKeyId=AKIAI4OKHYH7JRMFZMUA&Expires=1459149709&Signature=%2FqqLAgqpOet6fckn4TD7vnJQbGw%3D",
      "hostname": "designwithtom.com",
      "user_url": "http://news.layervault.com/u/3334/thomas-wood",
      "badge": null,
      "user_job": "Online Designer at IDG UK",
      "sponsored": false,
      "comments": [
        {
          "id": 142530,
          "body": "Had no idea it had those customization settings — finally making the switch.",
          "body_html": "<p>Had no idea it had those customization settings — finally making the switch.</p>\\n",
          "created_at": "2015-03-28T18:41:37Z",
          "depth": 0,
          "vote_count": 0,
          "url": "https://api-news.layervault.com/comments/142530",
          "user_url": "http://news.layervault.com/u/3826/matt-soria",
          "user_id": 3826,
          "user_display_name": "Matt S.",
          "user_portrait_url": "https://designer-news.s3.amazonaws.com/rendered_portraits/3826/original/portrait-2014-04-12_11_08_21__0000-382620140412-5896-1udai4f.png?AWSAccessKeyId=AKIAI4OKHYH7JRMFZMUA&Expires=1459125745&Signature=%2BDdWMtto3Q10dd677sUOjfvQO3g%3D",
          "user_job": "Web Dood @ mattsoria.com",
          "comments": []
        },

```

 * **协议(protocol)**
   用户与API通信采用[HTTPs](http://www.ruanyifeng.com/blog/2014/02/ssl_tls.html)协议
 * **域名(domain name)**
   应该尽可能部署到专用域名下`https://api-news.layervault.com/`，但有时会进一步扩展为`https://api-news.layervault.com/api`
 * **版本(version)**
   应该将API版本号`v1`放入URL
 * **路径(Endpoint)**
   路径`https://api-news.layervault.com/api/v1/stories`表示API具体网址，代表网络一种资源，所以不能有动词，只有使用名词来表示。
 * **HTTP动词**
   动词`GET `，表示从服务端获取Stories资源
 * **过滤信息(Filtering)**
   `?client_id=91a5fed537b58c60f36be1sdf71ed1320e9e4af2bda4366f7dn3d79e63835278`指定client_id的Stories资源
 * **状态码(Status Codes)**
   服务器向客户端返回表示成功或失败的状态码，状态码列表请参考[Status Code Definitions](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html)
 * **错误处理(Error handling)**
   服务端处理用户请求失败后，一般都返回`error`字段来表示错误信息

```
{
    error: "Invalid client id"
}

```

### Designer News提供API

[Designer News API Reference](http://developers.news.layervault.com)提供基于[HTTP](http://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol)协议遵循RESTful设计的API，并且允许应用程序通过[ oAuth 2](http://en.wikipedia.org/wiki/OAuth)授权协议来获取授权权限来访问用户信息。

### 访问API工具

一般来说，在写访问服务端代码之前，我都会用[Paw](https://luckymarmot.com/paw)([下载地址](http://pan.baidu.com/s/1gd0AYBp))工具来测试API是否可行；另一方面，用[JSON](http://www.json.org/json-zh.html)文件保存服务端返回的数据，用于[moco](https://github.com/dreamhead/moco)模拟服务端的服务。至于为什么需要moco模拟服务端，后面会讲解，现在通过**用户登录Designer News**这个例子介绍如何使用Paw来测试API。
我们先看看Designer News提供访问用户登录的API

![Designer News Login API.png](/assets/images/2015/166109-a67519fbcbff3cca.png)

根据以上提供的信息，API的路径是`https://api-news.layervault.com/oauth/token`，参数有`grant_type`，`username `，`password `，`client_secret `。其中`username`和`password`在[Designer News]()注册才能获取，而`client_id`和`client_secret `需要发送email到<news@layervault.com>申请。使用Paw发送请求和服务端返回结果如下：
![New Send Request.png](/assets/images/2015/166109-1dde4864556cd0f5.png)

# Moco模拟服务端

[Moco](https://github.com/dreamhead/moco)是一个可以轻松搭建测试服务器的工具。

### 为什么需要模拟服务端

作为一个移动开发人员，有时由于服务端开发进度慢，空有一个iPhone应用但发挥不出作用。幸好有了Moco，只需配置一下请求和返回数据，很快就可以搭建一个模拟服务，无需等待服务端开发完成才能继续开发。当服务端完成后，修改访问地址即可。

有时服务端API应该是什么样子都还没清楚，由于有了moco模拟服务，在开发过程中，可以不断调整API设计，搞清楚真正自己想要的API是什么样子的。就这样，在服务端代码还没真正动手之前，已经提供一份真正满足自己需要的API文档，剩下的就交给服务端照着API去实现就行了。

还有一种情况就是，服务端已经写好了，剩下客户端还没完成。由于moco是本地服务，访问速度比较快，所以通过使用moco来模拟服务端，这样不仅可以提高客户端的访问速度，还提高网络层测试代码访问速度的稳定性，Designer News就是这样情况。

### 如何使用Moco模拟服务

##### 安装

如果你是使用Mac或Linux，可以尝试一下步骤：

1.  确定你安装JDK 6以上
2.  下载[脚本](https://github.com/dreamhead/moco/blob/master/moco-shell/moco?raw=true)
3.  把它放在你的**$PATH**路径
4.  设置它可以执行(chmod 755 ~/bin/moco)

现在你可以运行一下命令测试安装是否成功

1. 编写配置文件foo.json，内容如下：

```
[
      {
        "response" :
          {
            "text" : "Hello, Moco"
          }
      }
]

```

2. 运行Moco HTTP服务器
   `moco start -p 12306 -c foo.json`
3. 打开浏览器访问`http://localhost:12306`，你回看见"Hello, Moco"

##### 配置服务

由于有时候服务端返回的数据比较多，所以将服务端响应的数据独立在一个JSON文件中。以登陆为例，将数据存放在**login_response.json**

```
{
    "access_token": "4422ea7f05750e93a101cb77ff76dffd3d65d46ebf6ed5b94d211e5d9b3b80bc",
    "token_type": "bearer",
    "scope": "user",
    "created_at": 1428040414
}

```

而将请求uri路径，方法(method)和参数(queries)等配置放在**login_conf.json**文件中

```
[
  {
    "request" :
      {
        "uri" : "/oauth/token",
        "method" : "post",
        "queries" : 
          {
            "grant_type" : "password",
            "username" : "liuyaozhu13hao@163.com",
            "password" : "freedom13",
            "client_secret" : "53e3822c49287190768e009a8f8e55d09041c5bf26d0ef982693f215c72d87da",
            "client_id" : "750ab22aac78be1c6d4bbe584f0e3477064f646720f327c5464bc127100a1a6d"
          }
      },
    "response" :
      {
        "file" : "./Login/login_response.json"
      }
  }
]

```

不知道有没有留意到上面uri路径不是全路径`http://localhost:12306/oauth/token`，因为协议默认是http，而且通常运行在本机localhost，所以在启动模拟服务时只需指定端口**12306**就行。想更加详细了解如何配置，请查阅官网的[HTTP(s) APIs](https://github.com/dreamhead/moco/blob/master/moco-doc/apis.md)
还有一个需要配置地方就是，由于实际开发中肯定不止一个客户端请求，所以还需要一个配置文件**settings.json**来包含很有的请求。

```
[
    {
        "include" : "./Story/stories_conf.json"
    },
    {
        "include" : "./Login/login_conf.json"
    },
    {
        "include" : "./Story/story_upvote_conf.json"
    }
]

```

##### 启动服务

将路径跳转到**DesignerNewsForObjc/DesignerNewsForObjcTests/JSON**目录，找到settings.json文件，使用命令行来启动服务：
`moco start -p 12306 -g settings.json`

##### 使用Paw验证是否配置成功

![Send request to Local Server.png](/assets/images/2015/166109-f487c378fdd9da0c.png)

# 行为驱动开发(BDD)

### 为什么需要BDD

不知道各位在编写测试的时候，有没有思考过一个问题：我应该**测试什么**？要回答这个问题并不是那么简单，在没得到答案之前，你还是继续按照你的想法编写测试。
`-(void)testValidateEmail;`
像这样的测试，存在一个根本问题。它不会告诉你应该会发生什么，也不会预期实际会发生什么。还有，当它发生错误时，不会提示你在哪里发生错误，错误的原因是什么，因此你需要深入代码才能知道失败的原因。这样就需要大量额外和不必要的认知负荷。
这时BDD出现了，帮助开发者确定**应该测试什么**，它提供DSL([Domain-specific language](), 域特定语言)，测试用例都遵循三段式Given-When-Then的描述，清晰地表达测试用例是测试什么样的对象或数据结构，在基于什么上下文或情景，然后做出什么响应。
所以，我们应该关注**行为**，而不是**测试**。那行为具体是什么？当你设计app里面的其中对象时，它的接口定义方法及其依赖关系，这些方法和依赖关系决定了你的对象如何与其他对象交互，以及它的功能是什么，定义你的对象的**行为**。

### BDD过程

行为驱动开发大概三个步骤：

1. 选择最重要的行为，并编写行为的测试文件。此时，由于测试对象的类还没编写，所以编译失败。创建测试对象的类并编写类的伪实现，让编译通过。
2. 实现**被测试类**的行为，让测试通过。
3. 如果发现代码中有重复代码，**重构**被测试类来消除重复

如果暂时不理解其中步骤细节，没有关系，继续向下阅读，后面有例子介绍来帮助你理解三个步骤的含义。

# 登陆验证

### 网络访问层

##### DesignerNewsURL

`DesignerNewsURL `类封装网络访问URL

```
#import <Foundation/Foundation.h>

extern NSString* const baseURL;
extern NSString* const clientID;
extern NSString* const clientSecret;

@interface DesignerNewsURL : NSObject

+ (NSString*)loginURLString;
+ (NSString*)stroiesURLString;
+ (NSString*)storyIdURLStringWithId:(NSInteger)storyId;
+ (NSString*)storyUpvoteWithId:(NSInteger)storyId;
+ (NSString*)storyReplyWithId:(NSInteger)storyId;
+ (NSString*)commentUpvoteWithId:(NSInteger)commentId;
+ (NSString*)commentReplyWithId:(NSInteger)commentId;

@end

```

这里还有个技巧就是在`DesignerNewsURL.m`实现文件有个条件编译，判断是在测试环境还是产品环境来决定`baseURL`的值，可以很方便在测试环境与产品环境互相切换。

```
#ifndef TEST
NSString* const baseURL = @"https://api-news.layervault.com";
#else
NSString* const baseURL = @"http://localhost:12306";
#endif

NSString* const clientID = @"750ab22aac78be1c6d4bbe584f0e3477064f646720f327c5464bc127100a1a6d";
NSString* const clientSecret = @"53e3822c49287190768e009a8f8e55d09041c5bf26d0ef982693f215c72d87da";

```

##### 行为驱动开发LoginClient

在编写代码之前，我们应该先想想如何设计`LoginClient`类。首先根据[Single responsibility principle](http://en.wikipedia.org/wiki/Single_responsibility_principle)(责任单一原则)，`LoginClient`主要负责用户登录的网络访问。需要提供一个接口，只要给定用户名(username)和密码(password)，用户就能登录，由于我是使用RAC来处理返回结果，所以这个接口返回RACSignal对象。

* 创建一个`LoginClient`kiwi文件，编写对应行为。

![Create LoginClient 1.png](/assets/images/2015/166109-edf59fc5929ce73b.png)

![Create LoginClient 2.png](/assets/images/2015/166109-edb3549b46c61a34.png)


  ```
  SPEC_BEGIN(LoginClientSpec)

  describe(@"LoginClient", ^{
    
      context(@"when user input correct username and password", ^{
        __block RACSignal *loginSignal;
        
        beforeEach(^{
            NSString *username = @"liuyaozhu13hao@163.com";
            NSString *password = @"freedom13";
            loginSignal = [LoginClient loginWithUsername:username password:password];
        });
        
        it(@"should return login signal that can't be nil", ^{
            [[loginSignal shouldNot] beNil];
        });
       
        it(@"should login successfully", ^{
            __block NSString *accessToken = nil;
            
            [loginSignal subscribeNext:^(NSString *x) {
                accessToken = x;
                NSLog(@"accessToken = %@", accessToken);
            }error:^(NSError *error) {
                [[accessToken shouldNot] beNil];
            } completed:^{
                [[accessToken shouldNot] beNil];
            } ];
        });
        
      });
});

  SPEC_END

  ```

根据三段式**Given-When-Then**描述，上面代码我们可以理解为：在给定LoginClient对象，当用户输入正确的用户名和密码时，应该登录成功。
这时，由于还没创建`LoginClient`类，所以会不通过编译，创建`LoginClient`类，并编写它的**伪实现**，让`LoginClientSpec.m `通过编译。

![LoginClient.h.png](/assets/images/2015/166109-f74339a77145df91.png)

![LoginClient.m.png](/assets/images/2015/166109-847f87928ac19a50.png)
运行测试，测试失败。

![LoginClient Failed.png](/assets/images/2015/166109-eb1277b54de80b54.png)

* 实现LoginClient，通过其测试

![LoginClient.m .png](/assets/images/2015/166109-2cc97a1c090f7bc3.png)

![LoginClient Pass Test.png](/assets/images/2015/166109-925c05f7efd3b16b.png)

* 由于无冗余代码，无需重构

### Model层

由于这次登陆请求服务端返回数据比较简单，只是获取`access_token`字段数据，所以不需要model来映射和存储数据。不过在获取多个Stories时，就会使用到model来处理。

### Controller与ViewModel层

`controller`是处理用户交互的入口，通常我都会将处理用户交互的逻辑、数据绑定和数据校验都交给`ViewModel`来精简`controller`代码，同时最大程度地复用业务逻辑的代码。
我们先回顾用户登陆时的步骤：1. 用户先输入email和密码，只有email和密码符合格式要求时才能点击按钮。2. 用户成功登陆后，跳转到故事列表主页。
我们先分析一下如何实现步骤1， 想要对email和密码进行验证，必须要监听它们两个值的变化，所以需要对`emailTextField`和`passwordTextField`使用**RAC**进行数据绑定。

创建`LoginViewControllerSpec`kiwi文件，测试绑定行为代码如下：

```
SPEC_BEGIN(LoginViewControllerSpec)

describe(@"LoginViewController", ^{
    __block LoginViewController *controller;
    
    beforeEach(^{
        controller = [UIViewController loadViewControllerWithIdentifierForMainStoryboard:@"LoginViewController"];
        [controller view];
    });
    
    afterEach(^{
        controller = nil;
    });
    
    describe(@"Email Text Field", ^{
        context(@"when touch text field", ^{
            it(@"should not be nil", ^{
                [[controller.emailTextField shouldNot] beNil];
            });
        });
        
        context(@"when text field's text is hello", ^{
            it(@"shoud euqal view model's email property", ^{
                controller.emailTextField.text = @"hello";
                [controller.emailTextField sendActionsForControlEvents:UIControlEventEditingChanged];
                [[controller.viewModel.email should] equal:@"hello"];
            });
        });
    });
    
    describe(@"Password Text Field", ^{
        context(@"when touch text field", ^{
            it(@"should not be nil", ^{
                [[controller.passwordTextField shouldNot] beNil];
            });
        });
        
        context(@"when text field' text is hello", ^{
            it(@"should equal view model's password property", ^{
                controller.passwordTextField.text = @"hello";
                [controller.passwordTextField sendActionsForControlEvents:UIControlEventEditingChanged];
                
                [[controller.viewModel.password should] equal:@"hello"];
            });
        });
    });
});

SPEC_END

```

这里有两个关键点，一个是从`Storyboard`中加载`controller`，否则不能获取emailTextField和password，如果采用手写UI代码就不需要了。另一个就是emailTextField或passwordTextField必须调用`sendActionsForControlEvents:UIControlEventEditingChanged`方法，才能触发textField的text属性改变。

编译失败后，在`LoginViewController.m`编写`- (void)bindViewModel`方法通过测试

```
RAC(self.viewModel, email) = self.emailTextField.rac_textSignal;
RAC(self.viewModel, password) = self.passwordTextField.rac_textSignal;

```

实现完数据绑定行为后，接下来要数据校验，交给`LoginViewModel`来处理。创建`LoginViewModelSpec.m`文件，提供`email`和`password`属性给`LoginViewModel`，返回验证结果的`RACSignal`，测试验证行为代码如下：

```
SPEC_BEGIN(LoginViewModelSpec)

describe(@"LoginViewModel", ^{
    // Initialize
    __block LoginViewModel *viewModel;
    
    beforeEach(^{
        viewModel = [[LoginViewModel alloc] init];
    });
    
    afterEach(^{
        viewModel = nil;
    });

    context(@"when email and password is valid", ^{
        it(@"should get valid signal", ^{
            viewModel.email = @"liuyaozhu13hao@163.com";
            viewModel.password = @"123456";
            
            __block BOOL result;
           
            [[viewModel checkEmailPasswordSignal] subscribeNext:^(id x) {
                result = [x boolValue];
            } completed:^{
                [[theValue(result) should] beYes];
            }];
        });
    });
    
    context(@"when email is valid, but password is invalid", ^{
        it(@"should get invalid signal", ^{
            viewModel.email = @"liuyaozhu13hao@163.com";
            viewModel.password = @"1";
            
            __block BOOL result;
            
            [[viewModel checkEmailPasswordSignal] subscribeNext:^(id x) {
                result = [x boolValue];
            } completed:^{
                [[theValue(result) shouldNot] beYes];
            }];
        });
    });
    
    context(@"when password is valid, but email is invalid", ^{
        it(@"should get invalid signal", ^{
            viewModel.email = @"liuyaozhu";
            viewModel.password = @"123456";
            
            __block BOOL result;
            [[viewModel checkEmailPasswordSignal] subscribeNext:^(id x) {
                result = [x boolValue];
            } completed:^{
                [[theValue(result) shouldNot] beYes];
            }];
        });
    });
});

SPEC_END

```

编译失败后(已经创建`LoginViewModel `类)，添加`- (RACSignal*)checkEmailPasswordSignal`并实现验证数据，通过测试

```
- (RACSignal*)checkEmailPasswordSignal
{
    RACSignal* emailSignal = RACObserve(self, email);
    RACSignal* passwordSignal = RACObserve(self, password);

    return [RACSignal combineLatest:@[ emailSignal, passwordSignal ] reduce:^(NSString* email, NSString* password) {
        BOOL result = [email isValidEmail] && [password isValidPassword];
        
        return @(result);
    }];
}

```

最后需要在`LoginViewModel`创建属性为`loginButtonCommand`的`RACCommand`来处理点击登陆按钮的交互。在`LoginViewControllerSpec.m`测试`loginButton.rac_command`不能为空

```
describe(@"Login Button", ^{
      context(@"when load view", ^{
            it(@"should be not nil", ^{
                [[controller.loginButton shouldNot] beNil];
            });
            
            it(@"should have rac command that not be nil", ^{
                [[controller.loginButton.rac_command shouldNot] beNil];
            });
      });
 });

```

测试失败，在`LoginViewController.m`编写`- (void)bindViewModel`方法以下代码片段

```
self.loginButton.rac_command = self.viewModel.loginButtonCommand;

```

在`LoginViewModel.m`延迟初始化`loginButtonCommand`属性

```
#pragma mark - Lazy initialization
- (RACCommand*)loginButtonCommand
{
    if (!_loginButtonCommand) {
        _loginButtonCommand = [[RACCommand alloc] initWithEnabled:[self checkEmailPasswordSignal] signalBlock:^RACSignal * (id input) {
            self.active = YES;
            
            return [[LoginClient loginWithUsername:self.email password:self.password] doNext:^(NSString *token) {
                self.active = NO;
                // Save the token
                [LocalStore saveToken:token];
                // Dismiss view controller and fetch data, reload
                self.dismissBlock();
            }];
        }];
    }

    return _loginButtonCommand;
}

```

通过测试，完成登陆基本流程，至于登陆成功后如何返回故事列表页面，这里不详细介绍，各位可以通过阅读[工程代码](https://github.com/samlaudev/DesignerNewsForObjc)便可以得到答案。

# 总结

最近一段时间都再看关于敏捷开发的书籍([用户故事与敏捷方法](http://book.douban.com/subject/4743056/)，[硝烟中的Scrum和XP](http://book.douban.com/subject/3390446/), [解析极限编程](http://book.douban.com/subject/6828074/))，对敏捷开发很感兴趣，但发觉很少公司或博客介绍如何实践敏捷开发iOS，所以在网上搜集一些资料，发现有很多优秀的实践(测试驱动开发，重构，持续集成测试，增量设计，增量计划)值得去学习，通过自己对敏捷开发中**各种实践**的理解来重写这个Designer News，这个Designer News功能还没全部完成，希望各位看完这篇文章尝试以这样方式来完成整个app。如果我有些观点或实践理解有误，请各位多多指点。

# 扩展阅读

*  **ReactiveCocoa**
   [ReactiveCocoa - iOS开发的新框架](http://www.infoq.com/cn/articles/reactivecocoa-ios-new-develop-framework)
   [ReactiveCocoa2实战](http://limboy.me/ios/2014/06/06/deep-into-reactivecocoa2.html)
   [ReactiveCocoa Essentials: Understanding and Using RACCommand](http://codeblog.shape.dk/blog/2013/12/05/reactivecocoa-essentials-understanding-and-using-raccommand/)
   [Test with Reactivecocoa](http://chaoruan.me/test-with-reactivecocoa/)
*  **Kiwi**
   [TDD的iOS开发初步以及Kiwi使用入门](http://onevcat.com/2014/02/ios-test-with-kiwi/)
   [Kiwi 使用进阶 Mock, Stub, 参数捕获和异步测试](http://onevcat.com/2014/05/kiwi-mock-stub-test/)
*  **RESTful API**
   [理解RESTful架构](http://www.ruanyifeng.com/blog/2011/09/restful.html)
   [RESTful API 设计指南](http://www.ruanyifeng.com/blog/2014/05/restful_api.html)
   [理解OAuth 2.0](http://www.ruanyifeng.com/blog/2014/05/oauth_2_0.html)
   [SSL/TLS协议运行机制的概述](http://www.ruanyifeng.com/blog/2014/02/ssl_tls.html)
*  **Moco**
   [Moco能集成测试，还能移动开发；能前端开发，还能模拟Web服务器！](http://mp.weixin.qq.com/s?__biz=MjM5MjY3OTgwMA==&mid=203752863&idx=1&sn=57fd563d7218a6d11d2c77b3cb4f5020#rd)
*  **测试**
   [行为驱动开发](http://objccn.io/issue-15-1/)
   [XCTest 测试实战](http://objccn.io/issue-15-2/)
   [依赖注入](http://objccn.io/issue-15-3/)
   [糟糕的测试](http://objccn.io/issue-15-4/)
   [置换测试: Mock, Stub 和其他](