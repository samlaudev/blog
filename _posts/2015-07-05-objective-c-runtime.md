---
layout: post
title: Objective-C特性：Runtime
date: 2015-07-05
tags: iOS
---

Objective-C是基于C语言加入了**面向对象特性**和**消息转发机制**的动态语言，这意味着它不仅需要一个编译器，还需要**Runtime系统**来动态创建类和对象，进行消息发送和转发。下面通过分析Apple开源的[Runtime代码](http://opensource.apple.com/tarballs/objc4/)(我使用的版本是objc4-646.tar)来深入理解Objective-C的Runtime机制。

## Runtime数据结构

在Objective-C中，使用`[receiver message]`语法并不会马上执行`receiver`对象的`message`方法的代码，而是向`receiver`发送一条`message`消息，这条消息可能由`receiver`来处理，也可能由转发给其他对象来处理，也有可能假装没有接收到这条消息而没有处理。其实`[receiver message]`被编译器转化为:

```
id objc_msgSend ( id self, SEL op, ... );
```

下面从两个数据结构`id`和`SEL`来逐步分析和理解Runtime有哪些重要的数据结构。

### SEL

`SEL`是函数`objc_msgSend `第二个参数的数据类型，表示**方法选择器**，按下面路径打开`objc.h`文件
![SEL Data Structure](/assets/images/2015/166109-73bc4103f4b4e671.png)

查看到`SEL`数据结构如下:

```
typedef struct objc_selector *SEL;
```

其实它就是映射到方法的C字符串，你可以通过Objc编译器命令`@selector()`或者Runtime系统的`sel_registerName`函数来获取一个`SEL`类型的方法选择器。
如果你知道selector对应的方法名是什么，可以通过`NSString* NSStringFromSelector(SEL aSelector)`方法将SEL转化为字符串，再用`NSLog`打印。

### id

接下来看`objc_msgSend `第一个参数的数据类型`id`，`id`是通用类型指针，能够表示任何对象。按下面路径打开`objc.h`文件
![id Data Structure.png](/assets/images/2015/166109-77522a76922f4a1c.png)

查看到`id`数据结构如下：

```
/// Represents an instance of a class.
struct objc_object {
    Class isa  OBJC_ISA_AVAILABILITY;
};

/// A pointer to an instance of a class.
typedef struct objc_object *id;
```

`id`其实就是一个指向`objc_object `结构体指针，它包含一个` Class isa`成员，根据`isa`指针就可以顺藤摸瓜找到**对象所属的类**。

> **注意：**根据Apple的官方文档[Key-Value Observing Implementation Details](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOImplementation.html)提及，key-value observing是使用`isa-swizzling`的技术实现的，`isa`指针在运行时被修改，指向一个中间类而不是真正的类。所以，你不应该使用`isa`指针来确定类的关系，而是使用[class](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Protocols/NSObject_Protocol/index.html#//apple_ref/occ/intfm/NSObject/class)方法来确定实例对象的类。

### Class

`isa`指针的数据类型是`Class`，`Class`表示对象所属的类，按下面路径打开`objc.h`文件
![Class Data Structure](/assets/images/2015/166109-eaeaf50b59b39b16.png)

```
/// An opaque type that represents an Objective-C class.
typedef struct objc_class *Class;
```

可以查看到`Class`其实就是一个`objc_class`结构体指针，但这个头文件找不到它的定义，需要在`runtime.h`才能找到`objc_class`结构体的定义。

按下面路径打开`runtime.h`文件
![objc_class Data Structure](/assets/images/2015/166109-48d88a28a561fd5e.png)

查看到`objc_class`结构体定义如下：

```
struct objc_class {
    Class isa  OBJC_ISA_AVAILABILITY;

#if !__OBJC2__
    Class super_class                                        OBJC2_UNAVAILABLE;
    const char *name                                         OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list *ivars                             OBJC2_UNAVAILABLE;
    struct objc_method_list **methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache *cache                                 OBJC2_UNAVAILABLE;
    struct objc_protocol_list *protocols                     OBJC2_UNAVAILABLE;
#endif

} OBJC2_UNAVAILABLE;
/* Use `Class` instead of `struct objc_class *` */
```

> **注意：**`OBJC2_UNAVAILABLE`是一个Apple对Objc系统运行版本进行约束的宏定义，主要为了兼容非Objective-C 2.0的遗留版本，但我们仍能从中获取一些有用信息。

让我们分析一些重要的成员变量表示什么意思和对应使用哪些数据结构。

* `isa `表示一个Class对象的Class，也就是**Meta Class**。在面向对象设计中，一切都是对象，Class在设计中本身也是一个对象。我们会在`objc-runtime-new.h`文件找到证据，发现`objc_class `有以下定义：

```
struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags

    ......
}
```

由此可见，结构体`objc_class `也是继承`objc_object `，说明**Class在设计中本身也是一个对象**。

 其实`Meta Class`也是一个Class，那么它也跟其他Class一样有自己的`isa`和`super_class`指针，关系如下：
 ![Class isa and superclass relationship from Google](/assets/images/2015/166109-fb22b2cd2fe17745.png)

 上图**实线**是`super_class`指针，**虚线**是`isa`指针。有几个关键点需要解释以下:

 * Root class (class)其实就是`NSObject`，`NSObject`是没有超类的，所以`Root class(class)`的superclass指向nil。
 * 每个Class都有一个`isa`指针指向唯一的Meta class
 * Root class(meta)的superclass指向`Root class(class)`，也就是`NSObject`，形成一个回路。
 * 每个Meta class的`isa`指针都指向Root class (meta)。


* `super_class`表示实例对象对应的父类
* `name`表示类名
* `ivars`表示多个成员变量，它指向`objc_ivar_list `结构体。在`runtime.h`可以看到它的定义：

```
struct objc_ivar_list {
    int ivar_count                                           OBJC2_UNAVAILABLE;
#ifdef __LP64__
    int space                                                OBJC2_UNAVAILABLE;
#endif
    /* variable length structure */
    struct objc_ivar ivar_list[1]                            OBJC2_UNAVAILABLE;
}        
```

`objc_ivar_list `其实就是一个链表，存储多个`objc_ivar`，而`objc_ivar`结构体存储类的单个成员变量信息。

* `methodLists`表示方法列表，它指向`objc_method_list `结构体的二级指针，可以动态修改`*methodLists`的值来添加成员方法，也是Category实现原理，同样也解释Category不能添加**实例变量**的原因。在`runtime.h`可以看到它的定义：

```
struct objc_method_list {
    struct objc_method_list *obsolete                        OBJC2_UNAVAILABLE;

    int method_count                                         OBJC2_UNAVAILABLE;
#ifdef __LP64__
    int space                                                OBJC2_UNAVAILABLE;
#endif
    /* variable length structure */
    struct objc_method method_list[1]                        OBJC2_UNAVAILABLE;
}      
```

同理，`objc_method_list `也是一个链表，存储多个`objc_method `，而`objc_method `结构体存储类的某个方法的信息。

* `cache`用来缓存经常访问的方法，它指向`objc_cache `结构体，后面会重点讲到。
* `protocols`表示类遵循哪些协议

### Method

`Method`表示类中的某个方法，在`runtime.h`文件中找到它的定义：

```
/// An opaque type that represents a method in a class definition.
typedef struct objc_method *Method;

struct objc_method {
    SEL method_name                                          OBJC2_UNAVAILABLE;
    char *method_types                                       OBJC2_UNAVAILABLE;
    IMP method_imp                                           OBJC2_UNAVAILABLE;
}                                                            

```

其实`Method`就是一个指向`objc_method`结构体指针，它存储了方法名(`method_name`)、方法类型(`method_types`)和方法实现(`method_imp`)等信息。而`method_imp `的数据类型是`IMP`，它是一个函数指针，后面会重点提及。

### Ivar

`Ivar`表示类中的实例变量，在`runtime.h`文件中找到它的定义：

```
/// An opaque type that represents an instance variable.
typedef struct objc_ivar *Ivar;

struct objc_ivar {
    char *ivar_name                                          OBJC2_UNAVAILABLE;
    char *ivar_type                                          OBJC2_UNAVAILABLE;
    int ivar_offset                                          OBJC2_UNAVAILABLE;
#ifdef __LP64__
    int space                                                OBJC2_UNAVAILABLE;
#endif
} 

```

`Ivar`其实就是一个指向`objc_ivar`结构体指针，它包含了变量名(`ivar_name`)、变量类型(`ivar_type`)等信息。

### IMP

在上面讲`Method`时就说过，`IMP`本质上就是一个函数指针，指向方法的实现，在`objc.h`找到它的定义：

```
/// A pointer to the function of a method implementation. 
#if !OBJC_OLD_DISPATCH_PROTOTYPES
typedef void (*IMP)(void /* id, SEL, ... */ ); 
#else
typedef id (*IMP)(id, SEL, ...); 
#endif

```

当你向某个对象发送一条信息，可以由这个函数指针来指定方法的实现，它最终就会执行那段代码，这样可以**绕开消息传递**阶段而去执行另一个方法实现。

### Cache

顾名思义，`Cache`主要用来缓存，那它缓存什么呢？我们先在`runtime.h`文件看看它的定义：

```
typedef struct objc_cache *Cache                             OBJC2_UNAVAILABLE;

struct objc_cache {
    unsigned int mask /* total = mask + 1 */                 OBJC2_UNAVAILABLE;
    unsigned int occupied                                    OBJC2_UNAVAILABLE;
    Method buckets[1]                                        OBJC2_UNAVAILABLE;
};

```

`Cache`其实就是一个存储`Method`的链表，主要是为了优化**方法调用**的性能。当对象`receiver`调用方法`message`时，首先根据对象`receiver`的`isa`指针查找到它对应的类，然后在类的`methodLists `中搜索方法，如果没有找到，就使用`super_class `指针到父类中的`methodLists`查找，一旦找到就调用方法。如果没有找到，有可能消息转发，也可能忽略它。但这样查找方式效率太低，因为往往一个类大概只有20%的方法经常被调用，占总调用次数的80%。所以使用Cache来**缓存经常调用的方法**，当调用方法时，优先在Cache查找，如果没有找到，再到`methodLists `查找。

## 消息发送

前面从`objc_msgSend `作为入口，逐步深入分析Runtime的数据结构，了解每个数据结构的作用和它们之间关系后，我们正式转入**消息发送**这个正题。

### objc_msgSend函数

在前面已经提过，当某个对象使用语法`[receiver message]`来调用某个方法时，其实`[receiver message]`被编译器转化为:

```
id objc_msgSend ( id self, SEL op, ... );

```

现在让我们看一下`objc_msgSend`它具体是如何发送消息:

1. 首先根据`receiver `对象的`isa`指针获取它对应的`class`
2. 优先在`class`的`cache`查找`message `方法，如果找不到，再到`methodLists `查找
3. 如果没有在`class`找到，再到`super_class `查找
4. 一旦找到`message`这个方法，就执行它实现的`IMP`。

![Objc Message.gif](/assets/images/2015/166109-e6850954052f1a2e.gif)

### self与super

为了让大家更好地理解`self`和`super`，借用[sunnyxx](http://blog.sunnyxx.com/)博客的[ios程序员6级考试](http://blog.sunnyxx.com/2014/03/06/ios_exam_0_key/)一道题目：下面的代码分别输出什么？

```
@implementation Son : Father
- (id)init
{
    self = [super init];
    if (self)
    {
        NSLog(@"%@", NSStringFromClass([self class]));
        NSLog(@"%@", NSStringFromClass([super class]));
    }
    return self;
}
@end

```

`self`表示当前这个类的对象，而`super`是一个编译器标示符，和`self`指向同一个消息接受者。在本例中，无论是[self class]还是[super class]，接受消息者都是Son对象，但`super`与`self`不同的是，self调用class方法时，是在子类Son中查找方法，而super调用class方法时，是在父类Father中查找方法。

当调用`[self class]`方法时，会转化为`objc_msgSend `函数，这个函数定义如下：

```
id objc_msgSend(id self, SEL op, ...)

```

这时会从当前Son类的方法列表中查找，如果没有，就到Father类查找，还是没有，最后在NSObject类查找到。我们可以从`NSObject.mm`文件中看到`- (Class)class`的实现：

```
- (Class)class {
    return object_getClass(self);
}

```

所以`NSLog(@"%@", NSStringFromClass([self class]));`会输出**Son**。

当调用[super class]方法时，会转化为`objc_msgSendSuper`，这个函数定义如下：

```
id objc_msgSendSuper(struct objc_super *super, SEL op, ...)

```

`objc_msgSendSuper `函数第一个参数super的数据类型是一个指向`objc_super `的结构体，从`message.h`文件中查看它的定义：

```
/// Specifies the superclass of an instance. 
struct objc_super {
    /// Specifies an instance of a class.
    __unsafe_unretained id receiver;

    /// Specifies the particular superclass of the instance to message. 
#if !defined(__cplusplus)  &&  !__OBJC2__
    /* For compatibility with old objc-runtime.h header */
    __unsafe_unretained Class class;
#else
    __unsafe_unretained Class super_class;
#endif
    /* super_class is the first class to search */
};
#endif

```

结构体包含两个成员，第一个是`receiver`，表示某个类的实例。第二个是`super_class`表示当前类的父类。

这时首先会构造出`objc_super `结构体，这个结构体第一个成员是self，第二个成员是` (id)class_getSuperclass(objc_getClass("Son"))`，实际上该函数会输出`Father`。然后在`Father`类查找class方法，查找不到，最后在NSObject查到。此时，内部使用`objc_msgSend(objc_super->receiver, @selector(class))`去调用，与[self class]调用相同，所以结果还是**Son**。

### 隐藏参数self和_cmd

当`[receiver message]`调用方法时，系统会在运行时偷偷地动态传入两个隐藏参数`self`和`_cmd`，之所以称它们为隐藏参数，是因为在源代码中没有声明和定义这两个参数。至于对于`self`的描述，上面已经解释非常清楚了，下面我们重点讲解`_cmd`。

`_cmd`表示当前调用方法，其实它就是一个方法选择器`SEL`。一般用于判断方法名或在Associated Objects中唯一标识键名，后面在Associated Objects会讲到。

## 方法解析与消息转发

`[receiver message]`调用方法时，如果在message方法在receiver对象的类继承体系中没有找到方法，那怎么办？一般情况下，程序在运行时就会Crash掉，抛出* unrecognized selector sent to …*类似这样的异常信息。但在抛出异常之前，还有**三次机会**按以下顺序让你拯救程序。

1. Method Resolution
2. Fast Forwarding
3. Normal Forwarding

![Message Forward from Google](/assets/images/2015/166109-cd2b5f383864ed04.jpg)

### Method Resolution

首先Objective-C在运行时调用`+ resolveInstanceMethod:`或`+ resolveClassMethod:`方法，让你添加方法的实现。如果你添加方法并返回`YES`，那系统在运行时就会重新启动一次消息发送的过程。

举一个简单例子，定义一个类`Message`，它主要定义一个方法`sendMessage`，下面就是它的设计与实现：

```
@interface Message : NSObject

- (void)sendMessage:(NSString *)word;

@end

```

```
@implementation Message

- (void)sendMessage:(NSString *)word
{
    NSLog(@"normal way : send message = %@", word);
}

@end

```

如果我在`viewDidLoad`方法中创建Message对象并调用`sendMessage`方法：

```
- (void)viewDidLoad {
    [super viewDidLoad];
    
    Message *message = [Message new];
    [message sendMessage:@"Sam Lau"];
}

```

控制台会打印以下信息:

```
normal way : send message = Sam Lau


```

但现在我将原来`sendMessage`方法实现给**注释掉**，覆盖`resolveInstanceMethod`方法：

```
#pragma mark - Method Resolution

/// override resolveInstanceMethod or resolveClassMethod for changing sendMessage method implementation
+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    if (sel == @selector(sendMessage:)) {
        class_addMethod([self class], sel, imp_implementationWithBlock(^(id self, NSString *word) {
            NSLog(@"method resolution way : send message = %@", word);
        }), "v@*");
    }
    
    return YES;
}

```

控制台就会打印以下信息：

```
 method resolution way : send message = Sam Lau

```

注意到上面代码有这样一个字符串`"v@*`，它表示方法的参数和返回值，详情请参考[Type Encodings](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1)

如果`resolveInstanceMethod `方法返回`NO`，运行时就跳转到下一步：**消息转发(Message Forwarding)**

### Fast Forwarding

如果目标对象实现`- forwardingTargetForSelector: `方法，系统就会在运行时调用这个方法，只要这个方法返回的不是`nil`或`self`，也会重启消息发送的过程，把这消息转发给其他对象来处理。否则，就会继续**Normal Fowarding**。

继续上面`Message`类的例子，将`sendMessage`和`resolveInstanceMethod`方法**注释掉**，然后添加`forwardingTargetForSelector`方法的实现：

```
#pragma mark - Fast Forwarding
- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if (aSelector == @selector(sendMessage:)) {
        return [MessageForwarding new];
    }
    
    return nil;
}

```

此时还缺一个转发消息的类`MessageForwarding `，这个类的设计与实现如下：

```
@interface MessageForwarding : NSObject

- (void)sendMessage:(NSString *)word;

@end

```

```
@implementation MessageForwarding

- (void)sendMessage:(NSString *)word
{
    NSLog(@"fast forwarding way : send message = %@", word);
}

@end

```

此时，控制台会打印以下信息：

```
fast forwarding way : send message = Sam Lau

```

这里叫Fast，是因为这一步不会创建NSInvocation对象，但Normal Forwarding会创建它，所以相对于更快点。

### Normal Forwarding

如果没有使用Fast Forwarding来消息转发，最后只有使用Normal Forwarding来进行消息转发。它首先调用`methodSignatureForSelector:`方法来获取函数的参数和返回值，如果返回为nil，程序会Crash掉，并抛出*unrecognized selector sent to instance*异常信息。如果返回一个函数签名，系统就会创建一个[NSInvocation](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSInvocation_Class/)对象并调用`-forwardInvocation:`方法。

继续前面的例子，将`forwardingTargetForSelector`方法**注释掉**，添加`methodSignatureForSelector`和`forwardInvocation`方法的实现：

```
#pragma mark - Normal Forwarding
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *methodSignature = [super methodSignatureForSelector:aSelector];
    
    if (!methodSignature) {
        methodSignature = [NSMethodSignature signatureWithObjCTypes:"v@:*"];
    }
    
    return methodSignature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    MessageForwarding *messageForwarding = [MessageForwarding new];
    
    if ([messageForwarding respondsToSelector:anInvocation.selector]) {
        [anInvocation invokeWithTarget:messageForwarding];
    }
}

```

关于这个例子的示例代码请到[github](https://github.com/samlaudev/RuntimeDemo)下载。

### 三种方法的选择

Runtime提供三种方式来将原来的方法实现代替掉，那该怎样选择它们呢？

* __Method Resolution：__由于Method Resolution不能像消息转发那样可以交给其他对象来处理，所以只适用于在**原来的类**中代替掉。
* __Fast Forwarding：__它可以将消息处理转发给**其他对象**，使用范围更广，不只是限于原来的对象。
* __Normal Forwarding：__它跟Fast Forwarding一样可以消息转发，但它能通过NSInvocation对象获取**更多消息发送**的信息，例如：target、selector、arguments和返回值等信息。

#Associated Objects

> Categories can be used to declare either instance methods or class methods but are not usually suitable for declaring additional properties. It’s valid syntax to include a property declaration in a category interface, but it’s not possible to declare an additional instance variable in a category. This means the compiler won’t synthesize any instance variable, nor will it synthesize any property accessor methods. You can write your own accessor methods in the category implementation, but you won’t be able to keep track of a value for that property unless it’s already stored by the original class. ([Programming with Objective-C](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/CustomizingExistingClasses/CustomizingExistingClasses.html))

当想使用Category对已存在的类进行扩展时，一般只能添加实例方法或类方法，而不适合添加额外的属性。虽然可以在Category头文件中声明property属性，但在实现文件中编译器是无法synthesize任何实例变量和属性访问方法。这时需要自定义属性访问方法并且使用Associated Objects来给已存在的类Category添加自定义的属性。Associated Objects提供三个API来向对象**添加、获取和删除**关联值：

* `void objc_setAssociatedObject (id object, const void *key, id value, objc_AssociationPolicy policy )`
* `id objc_getAssociatedObject (id object, const void *key )`
* `void objc_removeAssociatedObjects (id object )`

其中`objc_AssociationPolicy`是个枚举类型，它可以指定Objc内存管理的引用计数机制。

```
typedef OBJC_ENUM(uintptr_t, objc_AssociationPolicy) {
    OBJC_ASSOCIATION_ASSIGN = 0,           /**< Specifies a weak reference to the associated object. */
    OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1, /**< Specifies a strong reference to the associated object. 
                                            *   The association is not made atomically. */
    OBJC_ASSOCIATION_COPY_NONATOMIC = 3,   /**< Specifies that the associated object is copied. 
                                            *   The association is not made atomically. */
    OBJC_ASSOCIATION_RETAIN = 01401,       /**< Specifies a strong reference to the associated object.
                                            *   The association is made atomically. */
    OBJC_ASSOCIATION_COPY = 01403          /**< Specifies that the associated object is copied.
                                            *   The association is made atomically. */
};

```

下面有个关于`NSObject+AssociatedObject` Category添加属性`associatedObject`的[示例代码](https://github.com/samlaudev/RuntimeDemo):

#### NSObject+AssociatedObject.h

```
@interface NSObject (AssociatedObject)

@property (strong, nonatomic) id associatedObject;

@end

```

#### NSObject+AssociatedObject.m

```
@implementation NSObject (AssociatedObject)

- (void)setAssociatedObject:(id)associatedObject
{
    objc_setAssociatedObject(self, @selector(associatedObject), associatedObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)associatedObject
{
    return objc_getAssociatedObject(self, _cmd);
}

@end

```

Associated Objects的key要求是**唯一**并且是**常量**，而`SEL`是满足这个要求的，所以上面的采用隐藏参数`_cmd`作为key。

## Method Swizzling

**Method Swizzling**就是在运行时将一个方法的实现代替为另一个方法的实现。如果能够利用好这个技巧，可以写出**简洁、有效且维护性更好**的代码。可以参考两篇关于Method Swizzling技巧的文章：

* [nshipster Method Swizzling](http://nshipster.com/method-swizzling/)
* [Method Swizzling 和 AOP 实践](http://tech.glowing.com/cn/method-swizzling-aop/)

### Aspect-Oriented Programming(AOP)

类似记录日志、身份验证、缓存等事务非常琐碎，与业务逻辑无关，很多地方都有，又很难抽象出一个模块，这种程序设计问题，业界给它们起了一个名字叫**横向关注点(Cross-cutting concern)**，[AOP](https://en.wikipedia.org/wiki/Aspect-oriented_programming)作用就是分离**横向关注点(Cross-cutting concern)**来提高模块复用性，它可以在既有的代码添加一些额外的行为(记录日志、身份验证、缓存)而无需修改代码。

### 危险性

**Method Swizzling**就像一把瑞士小刀，如果使用得当，它会有效地解决问题。但使用不当，将带来很多麻烦。在stackoverflow上有人已经提出这样一个问题：[What are the Dangers of Method Swizzling in Objective C?](http://stackoverflow.com/questions/5339276/what-are-the-dangers-of-method-swizzling-in-objective-c)，它的**危险性**主要体现以下几个方面：

* Method swizzling is not atomic
* Changes behavior of un-owned code
* Possible naming conflicts
* Swizzling changes the method's arguments
* The order of swizzles matters
* Difficult to understand (looks recursive)
* Difficult to debug

## 总结

虽然在平时项目不是经常用到Objective-C的Runtime特性，但当你阅读一些iOS开源项目时，你就会发现很多时候都会用到。所以深入理解Objective-C的Runtime数据结构、消息转发机制有助于你更容易地阅读和学习开源项目。

## 扩展阅读

[玉令天下博客的Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/)  
[顾鹏博客的Objective-C Runtime](http://tech.glowing.com/cn/objective-c-runtime/)  
[Associated Objects](http://nshipster.com/associated-objects/)  
[Method Swizzling](http://nshipster.com/method-swizzling/)  
[Method Swizzling 和 AOP 实践](http://tech.glowing.com/cn/method-swizzling-aop/)  
[Objective-C Runtime Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ObjCRuntimeRef/index.html#//apple_ref/doc/uid/TP40001418)  
[What are the Dangers of Method Swizzling in Objective C?](http://stackoverflow.com/questions/5339276/what-are-the-dangers-of-method-swizzling-in-objective-c)  
[ios程序员6级考试（答案和解释）](http://blog.sunnyxx.com/2014/03/06/ios_exam_0_key/)  
[Objective C类方法load和initialize的区别](http://blog.iderzheng.com/objective-c-load-vs-initialize/)  