---
layout: post
title: 如何在ReactiveCocoa中写单元测试
date: 2015-09-01
tags: iOS
---

现在很多人在开发iOS时都使用[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa)，它是一个函数式和响应式编程的框架，使用Signal来代替KVO、Notification、Delegate和Target-Action等传递消息和解决对象之间状态与状态的依赖过多问题。但很多时候使用它之后，如何编写[单元测试](https://en.wikipedia.org/wiki/Unit_testing)来验证程序是否正确呢？下面首先了解MVVM架构，然后通过一个[例子](https://github.com/samlaudev/RACUnitTest)来讲述我如何在RAC(ReactiveCocoa简称)中使用[Kiwi](https://github.com/kiwi-bdd/Kiwi)来编写单元测试。

## MVVM架构

![MVVM high level](/assets/images/2015/166109-81012f4948373da5.png)
在MVVM架构中，通常都将view和view controller看做一个整体。相对于之前MVC架构中view controller执行很多在view和model之间数据映射和交互的工作，现在将它交给view model去做。
至于选择哪种机制来更新view model或view是没有强制的，但通常我们都选择[ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa)。ReactiveCocoa会监听model的改变然后将这些改变映射到view model的属性中，并且可以执行一些业务逻辑。

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

现在我们抽象出日期转换到字符串的逻辑到view model，使得代码可以**测试**和**复用**，并且帮view controller**瘦身**。

## 登录情景

![登录情景](/assets/images/2015/login.gif)

如图所示，这是一个简单的**登录界面**：有用户名和密码的两个输入框，一个登录按钮。用户输入完用户名和密码后，点击登录按钮后，成功登录。但这里有**限制条件**：用户名必须满足邮件的格式和密码长度必须在6位以上。当同时满足这两个条件后才能点击按钮，否则按钮是不可点击的。大家可以从github中下载[实例代码](https://github.com/samlaudev/RACUnitTest)。

首先我们先画界面，我定义一个`LoginView`，将画登录界面的责任都交给它。然后在`LoginViewController`中的`viewDidLoad`方法调用`buildViewHierarchy `加载它

```
#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];

    // build view hierarchy
    [self buildViewHierarchy];
    // bind data
    [self bindData];
    // handle events
    [self handleEvents];
}

- (void)buildViewHierarchy
{
    [self.view addSubview:self.rootView];
    [self.rootView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}
```

接下来我们要思考UI如何交互和如何设计和实现哪些类来处理。由于用户名和密码要同时满足验证格式时才能点击登录按钮，所以需要时刻监听`usernameTextField`和`passwordTextField`的text属性，对于处理UI交互、数据校验以及转换都交给MVVM架构中`ViewModel`来处理。于是定义一个`LoginViewModel`,并继承`RVMViewModel`，这个`RVMViewModel`有个`active`属性来表示viewModel是否处于活跃状态，当active是YES时，更新或显示UI。当active是NO时，不更新或隐藏UI。

```
@interface LoginViewModel : RVMViewModel

#pragma mark - UI state
/*
 @brief 用户名
 */
@property (copy, nonatomic) NSString *username;
/*
 @brief 密码
 */
@property (copy, nonatomic) NSString *password;

#pragma mark - Handle events
/*
 @brief 处理用户民和密码是否有效才能点击按钮以及登陆事件
 */
@property (nonatomic, strong) RACCommand *loginCommand;

#pragma mark - Methods
- (RACSignal *)isValidUsernameAndPasswordSignal;

@end
```

上面还有一个`loginCommand `属性和`isValidUsernameAndPasswordSignal `方法等下会详细介绍。定义`LoginViewModel `类后，在`LoginViewController`以**组合和委托**的方式来使用`LoginViewModel`并使用**Lazy Initialization**来初始化它。

```
@interface LoginViewController ()

#pragma mark - View model
@property (strong, nonatomic) LoginViewModel *loginViewModel;

@end

@implementation LoginViewController

#pragma mark - Custom Accessors
- (LoginViewModel *)loginViewModel
{
    if (!_loginViewModel) {
        _loginViewModel = [LoginViewModel new];
    }
    return _loginViewModel;
}

```

最后调用`bindData`方法进行[数据绑定](https://en.wikipedia.org/wiki/UI_data_binding)

```
- (void)bindData
{
    RAC(self.loginViewModel, username) = self.rootView.usernameTextField.rac_textSignal;
    RAC(self.loginViewModel, password) = self.rootView.passwordTextField.rac_textSignal;
}
```

### 数据绑定测试

如果usernameTextField.text、passwordTextField.text与loginViewModel.username、loginViewModel.password已经绑定数据，那么usernameTextField.text和passwordTextField.text的数据变动的话，一定会引起loginViewModel.username和loginViewModel.password的改变。那么**测试用例**可以这样设计：

![数据绑定 Test Case](/assets/images/2015/166109-683b8d1e185ab6ca.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

用kiwi编写测试如下：

```
SPEC_BEGIN(LoginViewControllerSpec)

describe(@"LoginViewController", ^{
    __block LoginViewController *controller = nil;

    beforeEach(^{
        controller = [LoginViewController new];
        [controller view];
    });

    afterEach(^{
        controller = nil;
    });

    describe(@"Root View", ^{
        __block LoginView *rootView = nil;

        beforeEach(^{
            rootView = controller.rootView;
        });

        context(@"when view did load", ^{
            it(@"should bind data", ^{
                rootView.usernameTextField.text = @"samlau";
                rootView.passwordTextField.text = @"freedom";

                [rootView.usernameTextField sendActionsForControlEvents:UIControlEventEditingChanged];
                [rootView.passwordTextField sendActionsForControlEvents:UIControlEventEditingChanged];

                [[controller.loginViewModel.username should] equal:rootView.usernameTextField.text];
                [[controller.loginViewModel.password should] equal:rootView.passwordTextField.text];
            });
        });

    });
});

SPEC_END
```

这个测试中有**两点**需要重点解释：

* 初始化完controller之后，`controller`一定要调用`view`方法来加载controller的view，否则不会调用`viewDidLoad`方法。

> 如果有些朋友对controller如何管理view生命周期不了解，可以阅读[View Controller Programming Guide for iOS](https://developer.apple.com/library/ios/featuredarticles/ViewControllerPGforiPhoneOS/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007457-CH1-SW1)文档中的[A View Controller Instantiates Its View Hierarchy When Its View is Accessed](https://developer.apple.com/library/ios/featuredarticles/ViewControllerPGforiPhoneOS/ViewLoadingandUnloading/ViewLoadingandUnloading.html#//apple_ref/doc/uid/TP40007457-CH10-SW2)章节

![Loading a view into memory from Apple Document ](/assets/images/2015/166109-64033d837aa08afb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

* usernameTextField和passwordTextField一定要调用`sendActionsForControlEvents `方法来通知UI已经更新。

```
[rootView.usernameTextField sendActionsForControlEvents:UIControlEventEditingChanged];
[rootView.passwordTextField sendActionsForControlEvents:UIControlEventEditingChanged];
```

一开始时，我并没有调用`sendActionsForControlEvents`方法导致`loginViewModel.username`和`loginViewModel.password`属性并没有更新。当时我开始思考，是不是还需要其他条件还能触发它更新呢？由于我使用`UITextField`的`rac_textSignal`属性，于是我就查看它的源代码：

 ```
 - (RACSignal *)rac_textSignal {
	@weakify(self);
	return [[[[[RACSignal
		defer:^{
			@strongify(self);
			return [RACSignal return:self];
		}]
		concat:[self rac_signalForControlEvents:UIControlEventEditingChanged |  UIControlEventEditingDidBegin]]
		map:^(UITextField *x) {
			return x.text;
		}]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_textSignal", self.rac_description];
 }

 ```

 从源代码可以知道，只有触发`UIControlEventEditingChanged`或`UIControlEventEditingDidBegin`事件时才能创建RACSignal对象。

### 业务逻辑测试

由于这里需要验证用户名和密码，复用性高，我不将处理逻辑放在viewModel中，而是定义一个`DataValidation`来处理。这里的用户名是邮箱格式，而密码要求长度大于等于6即可，方法如下：

```
@interface DataValidation : NSObject

+ (BOOL)isValidEmail:(NSString *)data;
+ (BOOL)isValidPassword:(NSString *)password;

@end

```

**测试用例**设计如下：
![数据验证 Test Case.png](/assets/images/2015/166109-fb67909afc0fcd72.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

然后使用kiwi编写测试如下：

```
SPEC_BEGIN(DataValidationSpec)

describe(@"DataValidation", ^{
    context(@"when email is samlau@163.com", ^{
        it(@"should return YES", ^{
            BOOL result = [DataValidation isValidEmail:@"samlau@163.com"];
            [[theValue(result) should] beYes];
        });
    });
    
    context(@"when email is samlau163.com", ^{
        it(@"should return YES", ^{
            BOOL result = [DataValidation isValidEmail:@"samlau163.com"];
            [[theValue(result) should] beNo];
        });
    });
    
    ......省略两个测试用例
});

```

### ViewModel层测试

前面已经完成了数据绑定和数据校验逻辑，接下来思考使用哪个类处理用户名和密码是否有效才能点击和点击按钮后，如何调用网络层在来匹配用户名和密码，RAC提供一个`RACCommand`类。`LoginViewModel`定义一个属性`loginCommand`，并在**实现文件**中使用`Lazy Initialization`初始化：

```
- (RACCommand *)loginCommand
{
    if (!_loginCommand) {
        _loginCommand = [[RACCommand alloc] initWithEnabled:[self isValidUsernameAndPasswordSignal] signalBlock:^RACSignal *(id input) {

            return [LoginClient loginWithUsername:self.username password:self.password];
        }];
    }
    return _loginCommand;
}

```

上面有一个重要方法`isValidUsernameAndPasswordSignal`来监听和验证用户名和密码:

```
- (RACSignal *)isValidUsernameAndPasswordSignal
{
    return [RACSignal combineLatest:@[RACObserve(self, username), RACObserve(self, password)] reduce:^(NSString *username, NSString *password) {
         return @([DataValidation isValidEmail:username] && [DataValidation isValidPassword:password]);
    }];
}

```

由于上面的方法`isValidUsernameAndPasswordSignal `已经监听`LoginViewModel`的username和password，当username和password其中一个改变时，`DataValidation`类都会调用`isValidEmail`和`isValidPassword`来数据验证，并将结果包裹成`RACSignal`对象返回。

**测试用例**设计如下：

![View Model Test Case](/assets/images/2015/166109-e3edf73d59b18147.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

然后使用kiwi编写测试如下：

```
describe(@"LoginViewModel", ^{
    __block LoginViewModel* viewModel = nil;

    beforeEach(^{
        viewModel = [LoginViewModel new];
    });

    afterEach(^{
        viewModel = nil;
    });

    context(@"when username is samlau@163.com and password is freedom", ^{
        __block BOOL result = NO;

        it(@"should return signal that value is YES", ^{
            viewModel.username = @"samlau@163.com";
            viewModel.password = @"freedom";

            [[viewModel isValidUsernameAndPasswordSignal] subscribeNext:^(id x) {
                result = [x boolValue];
            }];

            [[theValue(result) should] beYes];
        });
    });

    ......省略两个测试用例
});

```

以上测试用例很简单，设置viewModel的username和password，然后调用`isValidUsernameAndPasswordSignal `返回RACSignal对象，使用`subscribeNext`获取它的值，最后验证。

### 网络层测试

最后处理点击登录按钮访问服务器来验证用户名和密码。我定义一个`LoginClient`类来处理：

```
@interface LoginClient : NSObject

+ (RACSignal *)loginWithUsername:(NSString *)username password:(NSString *)password;

@end

```

只要输入username和password两个参数，就能返回是否验证成功的结果被包裹在`RACSignal`对象中。

由于这里我是使用[moco](https://github.com/dreamhead/moco)模拟服务，所以只设计一个成功的测试用例:

![Network Test Case.png](/assets/images/2015/166109-9d6f5119dc46371f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

然后使用kiwi编写测试如下：

```
describe(@"LoginClient", ^{
    context(@"when username is samlau@163.com and password is samlau", ^{
        __block BOOL success = NO;
        __block NSError *error = nil;
        
        it(@"should login successfully", ^{
            RACTuple *tuple = [[LoginClient loginWithUsername:@"samlau@163.com" password:@"samlau"] asynchronousFirstOrDefault:nil success:&success error:&error];
            NSDictionary *result = tuple.first;

            [[theValue(success) should] beYes];
            [[error should] beNil];
            [[result[@"result"] should] equal:@"success"];
        });
    });
});

```

里面使用RAC的一个重要方法`asynchronousFirstOrDefault `来测试异步网络访问的。详情可参考[Test with Reactivecocoa](http://chaoruan.me/test-with-reactivecocoa/)文章。

## 抓取网络数据并显示情景

![](/assets/images/2015/fetch_network_data.gif)

如图所示，输入正确的用户名和密码后，跳转到一个食物列表页面，它从服务端抓取图片、价格和已售份数后以列表的方式显示。

### 网络层测试

首先考虑如何设计和实现API，然后再考虑如何测试。因为它需要从服务端抓取数据，需要设计一个访问食物列表数据的类`FoodListClient`，设计如下：

```
@interface FoodListClient : NSObject

+ (RACSignal *)fetchFoodList;

@end

```

`FoodListClient `实现如下：

```
@implementation FoodListClient

+ (RACSignal *)fetchFoodList
{
    return [[[AFHTTPSessionManager manager] rac_GET:[URLHelper URLWithResourcePath:@"/v1/foodlist"] parameters:nil] replayLazily];
}

@end

```

`fetchFoodList `方法主要从服务端抓取数据后，返回一个JSON格式的数组。因此想测试这个API，只需要使用RAC的`asynchronousFirstOrDefault `方法返回`RACTuple`对象，获取第一个值，测试返回数组不为空即可。使用kiwi编写测试如下：

```
describe(@"FoodListClient", ^{

    context(@"when fetch food list ", ^{
        __block BOOL successful = NO;
        __block NSError *error = nil;

        it(@"should receive data", ^{
            RACSignal *result = [FoodListClient fetchFoodList];
            RACTuple *tuple = [result asynchronousFirstOrDefault:nil success:&successful error:&error];
            NSArray *foodList = tuple.first;

            [[theValue(successful) should] beYes];
            [[error should] beNil];
            [[foodList shouldNot] beEmpty];
        });
    });
});

```


### Model层测试

抓取完数据后，它的数据格式一般都是JSON格式，需要转化为Model方便访问和修改，通常我都使用[Mantle](https://github.com/Mantle/Mantle)来实现。我定义一个`FoodModel`类：

```
@interface FoodModel : MTLModel <MTLJSONSerializing>

/*
 @brief 食物图片URL
 */
@property (copy, nonatomic) NSString *foodImageURL;
/*
 @brief 食物价格
 */
@property (copy, nonatomic) NSString *foodPrice;
/*
 @brief 销量
 */
@property (copy, nonatomic) NSString *saleNumber;

@end

```

那么如何测试它是否转化成功呢？首先基于上一个网络层测试获取返回JSON格式的食物列表数据，然后调用`MTLJSONAdapter `类的`modelsOfClass: fromJSONArray: error:`方法来转化成`FoodModel`的数组。接下来断言**数组不能为空**和**数组的第一个元素是`FoodModel`类**。

使用kiwi编写测试如下：

```
describe(@"FoodModel", ^{

    context(@"when JSON data convert to FoodModel", ^{
        __block BOOL successful = NO;
        __block NSError *error = nil;

        it(@"should return FoodModel array", ^{
            // get data from network
            RACSignal *result = [FoodListClient fetchFoodList];
            RACTuple *tuple = [result asynchronousFirstOrDefault:nil success:&successful error:&error];
            NSArray *foodList = tuple.first;

            // assert that foodList can't be empty
            [[theValue(successful) should] beYes];
            [[error should] beNil];
            [[foodList shouldNot] beEmpty];

            // assert that return FoolModel array
            NSArray *foodModelList = [MTLJSONAdapter modelsOfClass:[FoodModel class] fromJSONArray:foodList error:nil];
            [[foodModelList shouldNot] beEmpty];
            [[foodModelList[0] should] beKindOfClass:[FoodModel class]];
        });
    });
});

```

### ViewModel抓取数据

完成抓取网络数据和转化JSON数据为Model后，我使用`FoodViewModel`来**抓取网络数据**和完成**数据映射**，设计与实现如下：

```
@interface FoodViewModel : RVMViewModel

/*
 @brief FoodModel列表
 */
@property (strong, nonatomic, readonly) NSArray *foodModelList;

@end

```

```
@implementation FoodViewModel

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return nil;
    }

    RAC(self, foodModelList) = [[FoodListClient fetchFoodList] map:^id(RACTuple * tuple) {
        return [MTLJSONAdapter modelsOfClass:[FoodModel class] fromJSONArray:tuple.first error:nil];
    }];

    return self;
}

@end

```

### Controller加载数据

最后`FoodListViewController`负责构建view hierarchy和加载数据:

```
#pragma mark - Lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    // setup title name and background color
    self.title = @"食物列表";
    self.view.backgroundColor = [UIColor whiteColor];
    // build view hierarchy
    [self buildViewHierarchy];
    // when finish fetching data and reload table view
    [RACObserve(self.foodViewModel, foodModelList) subscribeNext:^(NSArray* items) {
        self.foodListDataSource.items = items;
        [self.tableView reloadData];
    }];
}

```

## 总结

编写单元测试是程序员的一项**基本技能**，如果能够设计好的测试用例并编写测试验证结果，不仅保证代码的质量，而且有利于以后重构加一层保护层。一旦修改了代码之后，如果运行单元测试，并没有通过的话，说明你在重构过程中引入新的bug。如果通过了单元测试，说明并没有引入新的bug。

## 扩展阅读

* **ReactiveCocoa**  
  [Test with Reactivecocoa](http://chaoruan.me/test-with-reactivecocoa/)
* **Kiwi**  
  [TDD的iOS开发初步以及Kiwi使用入门](http://onevcat.com/2014/02/ios-test-with-kiwi/)  
  [Kiwi 使用进阶 Mock, Stub, 参数捕获和异步测试](http://onevcat.com/2014/05/kiwi-mock-stub-test/)