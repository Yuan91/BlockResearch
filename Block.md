# Block 总结

## Block 本质是什么？
Block 本质也是一个OC对象，它封装了函数调用以及函数调用环境。
通过命令行编译block的源码，我们发现它是一个结构体类型，并且包含一个isa指针。



## Block 内访问外部变量的分析

###  访问基本数据类型

* 访问auto类型的变量，是值捕获，block对应的结构体会生成一个同样的值得变量

* 访问 static 类型的变量，是指针捕获，block 对应的结构体会生成一个指向该变量的指针

* 访问全局变量，不产生捕获行为，可以直接捕获

* block内部访问 self，是会产生值捕获的。因为self关键字其实是方法的隐藏参数，所以block内访问self，相当于访问局部auto变量，会对self产生一个强引用

### 在ARC 下，捕获对象类型的auto变量

* 如果block在栈上，将不会对auto变量产生强引用

* 如果block被拷贝到堆上，会调用 _block_object_assign 函数，该函数根据auto变量的修饰符类型进行相应的内存操作 如果是 __strong 会对 auto 变量进行强引用；如果是 __weak 则仅仅是指向该变量

* 如果block从堆上移除时， 会调用 _block_object_dispose函数，对捕获的变量进行响应的内存操作

## Block类型的分析

###  在ARC和MRC下，block类型的区分

* global 类型，没有访问auto 变量 ---> 对应的内存在 data 区（存储一些全局变量的地方）

* stack 类型，访问了 auto 变量 ---> 内存在栈区，由系统管理，超出作用域之后，会被系统回收

* malloc 类型，对 stack 类型的进行copy 操作。---> 内存在堆区，由程序员自己管理

以上我们关于block类型的分析不管ARC还是MRC都适用的，
但是有些情况我们发现block的类型，并不是按照上面的分析的那样，
那是因为ARC下，系统会在某些情况对block进行copy。

### ARC下自动拷贝Block的情况

* block 作为函数返回值得时候

* block 赋值给 __strong 描述的指针时

* block 作为CocoaApi方法中 含有usingBlock的方法参数时

* block 作为GCD API 的参数时

ARC 下 ，系统在一些情况下会自动对block进行copy 操作，所以在ARC在block用copy和strong其实操作不大，但是为了兼容ARC和MRC，我们还是会用copy进行描述。

## __block 关键字分析

### 作用

__block 可用于解决block内部无法修改auto 变量的问题

### __block 原理分析

编译器会将 __block 描述的变量包装成一个结构体类型，该结构体包含一个指向该变量的指针，不管是基本数据类型还是对象类型。
只是这两者略微有点不同，对象类型生成的结构体对象，包含一个__Block_byref_id_object_copy
和__Block_byref_id_object_dispose函数，这两个函数在block 进行copy和release时会对__block描述的变量进行retain(当变量是__stong描述时)和release。

# Block 捕获外部变量分析(基本数据类型)

以下分析使用命令行：

`clang -rewrite-objc filename.m`

`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 filename.m`

以下分析均基于对基本数据的分析

## Block 基本数据结构分析

Block 本质也是一个OC对象，它封装了函数调用以及函数调用环境。
通过命令行编译block的源码，我们发现它是一个结构体类型，并且包含一个isa指针

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        void (^block) (void) = ^{
           NSLog(@"Hello, World!");
        };
        
        block();
    }
    return 0;
}

```

将以上源码编译,命令： `clang -rewrite-objc main.m`

```
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
    // () 可以看做是类型，转换那么下面这行代码略等于 void (*block) (void) = __main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA))
        void (*block) (void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA));
    //约等于 block->FuncPtr(block)
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
```

整理一下，即block相当于一个__main_block_impl_0结构体，结构体初始化的时候传递__main_block_func_0 和 __main_block_desc_0_DATA 两个参数

```
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
     void (*block) (void) = __main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA))    
    block->FuncPtr(block)
    }
    return 0;
}
```

接下来看一下结构体的构成

```
//block对应的结构体
struct __main_block_impl_0 {
    //包含一个 __block_impl 类型的结构体
  struct __block_impl impl;
  //包含一个 __main_block_desc_0 结构体
  struct __main_block_desc_0* Desc;
  //结构体的初始化方法
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock; //isa指针结构体的类型
    impl.Flags = flags; //默认参数
    impl.FuncPtr = fp; // block实现
    Desc = desc; //Desc属性赋值
  }
};

// __block_impl 结构体分析
struct __block_impl {
  void *isa; //isa 指针
  int Flags;
  int Reserved;
  void *FuncPtr; //指向block 实现
};

// __main_block_desc_0 结构体分析
static struct __main_block_desc_0 {
  size_t reserved; //保留字段
  size_t Block_size; //block所占内存
}

```

![avatar](https://s1.ax1x.com/2020/03/22/8IMCkt.png)

## Block 访问外部auto局部变量分析

auto变量即自动变量，超出作用域即销毁，C语言中变量默认是auto的.
访问外部auto局部变量是 值捕获

内存布局如下:

![avatar](https://s1.ax1x.com/2020/03/22/8IH8un.png)

测试代码

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        int age = 10;
        void (^block) (void) = ^{
            NSLog(@"age:%d",age);
        };
        age = 20;
        block();
    }
    return 0;
}
```

按照刚刚的方法分析源码

```
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        int age = 10;
        
        //block初始化,可以看到age变量被当做参数传递到struct的构造器中了
        void (*block) (void) = &__main_block_impl_0(__main_block_func_0, &__main_block_desc_0_DATA, age));
        
        age = 20;
        
        //调用block
        block->FuncPtr(block);

    }
    return 0;
}
```

接下分析下每个部分的详细变动

block 实现函数分析

```
//参数 __main_block_impl_0 *__cself,为结构体指针指向 block 对应的结构体
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    //访问结构体中的age变量
  int age = __cself->age; // bound by copy

    NSLog((NSString *)&__NSConstantStringImpl__var_folders_31_0q48nsjs4cd2wxgr2x_t0p980000gn_T_main_587a18_mi_0,age);
}
```

block 结构体分析

```
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
    //我们看到struct中多了一个age变量
  int age;
    //结构体的构造方法也多了一个_age参数,并且后面多了 : age(_age),表示把参数_age赋值给结构体的age变量
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _age, int flags=0) : age(_age) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

## block 访问static局部变量

block内访问static类型捕获的是一个引用

示例代码

```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        auto int age = 10;
        static int number = 10;
        void (^block) (void) = ^{
            NSLog(@"age:%d,number:%d",age,number);
            //print: age:10,number:20
        };
        age = 20;
        number = 20;
        block();
        
    }
    return 0;
}

```

分析源码

```
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        auto int age = 10;
        static int number = 10;
        //可以看到 __main_block_impl_0 构造器,针对auto变量传递的值,针对static变量传递的是指针
        void (*block) (void) = &__main_block_impl_0(__main_block_func_0, &__main_block_desc_0_DATA, age, &number));
        age = 20;
        number = 20;
        block->FuncPtr(block);

    }
    return 0;
}
```

分析block 对应的结构体

```
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  int age;
  int *number;
    //构造器的参数 _number 接受的是变量的指针，而不像age参数是一个值的传递
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _age, int *_number, int flags=0) : age(_age), number(_number) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

## 为什么 auto 局部变量捕获的是值，而 static 变量捕获的是指针

因为block 可能会延迟调用，即超出变量的作用域，而auto变量超出作用域即销毁，所以要捕获它的值；而static则是一直存在的，那么只捕获一个指针即可

测试代码

```
void (^block)(void);
void test(){
    int test_A = 10;
    static int test_B = 10;
    block = ^{
        NSLog(@"test_A:%d,test_B:%d",test_A,test_B);
    };
    test_A = 20;
    test_B = 20;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        //调用test函数,给block赋值.
        //注意此时test_A变量的作用域已经结束,是不能通过指针来访问的,所以需要捕获值
        test();
        block();
        //print:test_A:10,test_B:20
    }
    return 0;
}
```

分析源码

```
//main 源码
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        test();
        block->FuncPtr(block);

    }
    return 0;
}

//test函数的源码，可以看到test_A变量定义在这个函数中
//但是它的实际调用是在__test_block_func_0 中超出了它的作用域
//所以block 需要对其尽心值捕获
void test(){
    int test_A = 10;
    static int test_B = 10;
    block = &__test_block_impl_0(__test_block_func_0, &__test_block_desc_0_DATA, test_A, &test_B));
    test_A = 20;
    test_B = 20;
}

//block调用的地方
static void __test_block_func_0(struct __test_block_impl_0 *__cself) {
  int test_A = __cself->test_A; // bound by copy
  int *test_B = __cself->test_B; // bound by copy

        NSLog((NSString *)&__NSConstantStringImpl__var_folders_31_0q48nsjs4cd2wxgr2x_t0p980000gn_T_main_9215ab_mi_0,test_A,(*test_B));
}

//block 结构体的定义
struct __test_block_impl_0 {
  struct __block_impl impl;
  struct __test_block_desc_0* Desc;
  int test_A;
  int *test_B;
  __test_block_impl_0(void *fp, struct __test_block_desc_0 *desc, int _test_A, int *_test_B, int flags=0) : test_A(_test_A), test_B(_test_B) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

## block访问全局变量的分析

测试代码

```
int age = 10;
static int number = 10;
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void (^block) (void) = ^{
            NSLog(@"age:%d,number:%d",age,number);
            //print: age:20,number:20
        };
        age = 20;
        number = 20;
        block();
    }
    return 0;
}
```

源代码分析

```
//block 没有定义与全局变量对应的变量
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};

//block调用分析
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    //调用block 的时候,直接访问的是全局变量的
            NSLog((NSString *)&__NSConstantStringImpl__var_folders_31_0q48nsjs4cd2wxgr2x_t0p980000gn_T_main_b1df0b_mi_0,age,number);

        }
```

## block 访问self的分析

测试代码

```
- (void)test{
    void(^block) (void) =^{
        NSLog(@"----%p",self);
    };
    block();
}
```

源码分析

```
//可以看到test方法，其实是包含两个参数的self和cmd，其实所有的oc方法编译后都会包含这两个参数，也就是我们方法内使用的参数其实都是局部变量，按钮我们前面的分析，block是会会对self捕获的

static void _I_Person_test(Person * self, SEL _cmd) {

    void(*block) (void) =&__Person__test_block_impl_0(__Person__test_block_func_0, &__Person__test_block_desc_0_DATA, self, 570425344));
    block->FuncPtr(block);
}

//我们在看一下block的数据结构
struct __Person__test_block_impl_0 {
  struct __block_impl impl;
  struct __Person__test_block_desc_0* Desc;
  //可以看到block是持有了一个当前类的对象的
  Person *self;
  __Person__test_block_impl_0(void *fp, struct __Person__test_block_desc_0 *desc, Person *_self, int flags=0) : self(_self) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

## 结论

block对于其中变量的捕获与否，主要是存内存方面考虑的。

* 因为block可能存在延时调用的情况，所以对于局部自动变量，要进行值捕获。（延时调用局部变量超出作用域）

* 对于局部static变量，要捕获它的指针。（延时调用，超出作用域，但是还可以通过指针访问）

* 对于全局变量，不会不会捕获，可以直接访问

* block访问self、成员变量，都会捕获当前类。因为self其实是方法中的参数，也就是局部变量

![avatar](https://s1.ax1x.com/2020/03/22/8IHoDI.png)

# Block 内部访问 对象类型的auto 变量分析

## 结论

当block 内部访问了对象类型的auto变量(ARC下)

* 如果block在栈上，将不会对auto变量产生强引用

* 如果block被拷贝到堆上，会调用 _block_object_assign 函数，该函数根据auto变量的修饰符类型进行相应的内存操作
如果是 __strong 会对 auto 变量进行强引用；如果是 __weak 则仅仅是指向该变量

* 如果block从堆上移除时， 会调用 _block_object_dispose函数，对捕获的变量进行响应的内存操作

![avatar](https://s1.ax1x.com/2020/03/22/8IqPOA.png)

//测试代码
```
typedef void(^XXBlock)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        XXBlock block = nil;
        {
            //对象类型的auto变量
             Person *p = [[Person alloc]init];
             p.name = @"哈哈";

            block = ^{
                //block访问了对象类型的auto变量， 将会使对象引用计数加一
                NSLog(@"%@",p.name);
            };
        }
        NSLog(@"======");

        /**
        结果：block 作用域过后，person 才会释放
        ======
        Person dealloc
*/
    }
    return 0;
}

```

//源码分析

`xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 main.m`

使用新的命令分析源码，因为要加上内存管理的环境

```
//1.main 函数没有什么大的变化
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

        XXBlock block = __null;
        {
            //Person *p = [[Person alloc]init];
             Person *p = ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"), sel_registerName("alloc")), sel_registerName("init"));

            //p.name = @"哈哈";
             ((void (*)(id, SEL, NSString * _Nonnull))(void *)objc_msgSend)((id)p, sel_registerName("setName:"), (NSString *)&__NSConstantStringImpl__var_folders_31_0q48nsjs4cd2wxgr2x_t0p980000gn_T_main_d03723_mi_0);
            
            block = &__main_block_impl_0(__main_block_func_0, &__main_block_desc_0_DATA, p, 570425344));
        }
        NSLog((NSString *)&__NSConstantStringImpl__var_folders_31_0q48nsjs4cd2wxgr2x_t0p980000gn_T_main_d03723_mi_2);
    }
    return 0;
}

//2.看block 的结构体

//block 结构体多了一个__strong的变量
//如果被对象类型的auto变量 为 weak 那么 这个地方就是 __weak 描述
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  Person *__strong p;
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, Person *__strong _p, int flags=0) : p(_p) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};

//3.看block描述的结构体

//多了两个变量
static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
    // 对应 __main_block_copy_0 函数
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
    //对应 __main_block_dispose_0 函数
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};

//4.接下来看这两个函数的内容

//当block被拷贝时会调用 __main_block_copy_0 函数
//该函数最终调用 _Block_object_assign 方法,依据auto变量是strong还是weak进行内存管理操作
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->p, (void*)src->p, 3/*BLOCK_FIELD_IS_OBJECT*/);}

//最终调用 _Block_object_dispose
static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->p, 3/*BLOCK_FIELD_IS_OBJECT*/);}

```

# Block 类型分析

## Block 是什么

测试代码
```
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void (^block) (void) = ^{
            NSLog(@"test");
        };
        NSLog(@"%@",[block class]);
        NSLog(@"%@",[[block class] superclass]);
        NSLog(@"%@",[[[block class] superclass] superclass]);
        NSLog(@"%@",[[[[block class] superclass] superclass] superclass]);
        /**
        打印结果：
        __NSGlobalBlock__
        __NSGlobalBlock
        NSBlock
        NSObject
        */
    }
    return 0;
}
```

由此可知block 也是一个最终继承自nsobject的oc对象，通过block的数据结构知道它也是有一个isa指针的，指向具体的类

## Block的类型

* global 类型，没有访问auto 变量 ---> 对应的内存在 data 区（存储一些全局变量的地方）

* stack 类型，访问了 auto 变量 ---> 内存在栈区，由系统管理，超出作用域之后，会被系统回收

* malloc 类型，对 stack 类型的进行copy 操作。---> 内存在堆区，由程序员自己管理

![avatar](https://s1.ax1x.com/2020/03/22/8IqR6H.png)

```
//在MRC下编译
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        //访问auto
        auto int a = 0;
        void(^ block1) (void) = ^{
            NSLog(@"==%d",a);
        };
        NSLog(@"block1:%@",[block1 class]);
        
        //访问static
        static int b = 0;
        void(^ block2) (void) = ^{
            NSLog(@"==%d",b);
        };
        NSLog(@"block2:%@",[block2 class]);
        
        //不访问外部变量
        void(^ block3) (void) = ^{
            NSLog(@"==%d",b);
        };
        NSLog(@"block3:%@",[block3 class]);
        //copy
        NSLog(@"block1copy:%@",[[block1 copy] class]);
        /**
        __NSStackBlock__
        __NSGlobalBlock__
        __NSGlobalBlock__
        block1copy：__NSMallocBlock__
        */
    }
    return 0;
}
```

## 栈区block的一个分析

MRC下运行如下代码

```
void (^block) (void);
void test() {
    int a = 10;
    block = ^{
        NSLog(@"==%d",a);
    };
}

//MARK: block 栈区分析
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        test();
        block();
    }
    return 0;
}
```

以上代码会打印出：`==-272632456`

由以上代码可知，该block类型为栈block,当test()调用后，block会被系统回收，产生了垃圾数据，所以打印不正常。

## 对Block进行copy操作后，类型的变化

* global copy之后，还是global类型的block

* stack block copy之后，变成 malloc 类型的block

* malloc 类型的block，copy之后引用计数加一

![avatar](https://s1.ax1x.com/2020/03/22/8ILJHI.md.png)

## ARC 下对block 的自动拷贝

以上我们关于block类型的分析不管ARC还是MRC都适用的，
但是有些情况我们发现block的类型，并不是按照上面的分析的那样，
那是因为ARC下，系统会在某些情况对block进行copy。
总结如下，ARC自动拷贝block

* block 作为函数返回值得时候

* block 赋值给 __strong 描述的指针时

* block 作为CocoaApi方法中 含有usingBlock的方法参数时

* block 作为GCD API 的参数时

代码分析
```
typedef void(^XXBlock)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int a = 10;
        //block 捕获 auto 变量，按理说应该是 栈block.
        //但是 ARC 下 ，因为该block 被 __strong （隐士）描述，所以进行了自动copy
        //就从栈区 拷贝到了 堆区
        XXBlock block = ^{
            NSLog(@"==%d",a);
        };
        NSLog(@"class:%@",[block class]); //class:__NSMallocBlock__
    }
    return 0;
}
```

# __block 分析

## __block 修改变量分析

结论如下：

* __block 可用于解决block内部无法修改auto 变量的问题

* __block 不能修饰全局变量、静态变量

* 编译器会将 __block 变量包装成一个对象

内存布局如下：

![avavtar](https://s1.ax1x.com/2020/03/22/8IXkwR.md.png)

__block描述的变量，在被拷贝分析时遵循如下结论：

![avatar](https://s1.ax1x.com/2020/03/22/8IzFgK.png)

测试代码

```
typedef void(^XXBlock)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        __block int a = 10;
        XXBlock block = ^{
            a = 20;
        };
        
        block();
    }
    return 0;
}
```

源码分析

```
//1.main 分析
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

        //对应 __block int a = 10; __Block_byref_a_0 为新的结构体类型
         __Block_byref_a_0 a = {
             (void*)0,
             (__Block_byref_a_0 *)&a,
             0,
             sizeof(__Block_byref_a_0),
             10};
        
        XXBlock block = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_a_0 *)&a, 570425344));

        block->FuncPtr(block);
    }
    return 0;
}

//2.看一下新定义的结构体
struct __Block_byref_a_0 {
  void *__isa;
__Block_byref_a_0 *__forwarding;
 int __flags;
 int __size;
 int a; //包含一个 a 的变量值，即我们在 代码中定义的变量
};

//3.看一个block的结构体 定义发生哪些变化
struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  __Block_byref_a_0 *a; // 新增一个变量对应的结构体类型 指针
  __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_a_0 *_a, int flags=0) : a(_a->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

## __block修饰变量的访问分析

对于__block修饰的变量，我们其实是访问它包装的结构体内部对应的变量

测试代码
```
typedef void(^XXBlock)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        __block int a = 10;
        XXBlock block = ^{
            a = 20;
        };        
        block();
        NSLog(@"--->%p",&a);
        
    }
    return 0;
}
```

### 论证方法一：分析内部代码

源码分析

```
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 

        __attribute__((__blocks__(byref))) __Block_byref_a_0 a = {(void*)0,(__Block_byref_a_0 *)&a, 0, sizeof(__Block_byref_a_0), 10};
        XXBlock block = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_a_0 *)&a, 570425344));

        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);

        //NSLog(@"--->%d",a);  编译后的源码
        //可以看到 变量a 其实是通过结构体访问的
        NSLog((NSString *)&__NSConstantStringImpl__var_folders_31_0q48nsjs4cd2wxgr2x_t0p980000gn_T_main_276c8e_mi_0,(a.__forwarding->a));
    }
    return 0;
}
```

### 论证方法二：地址分析

我们把内部生成的结构体类型，拿出来，进行强制类型转换
拿出内部类型

```
struct __Block_byref_a_0 {
  void *__isa;
 struct __Block_byref_a_0 *__forwarding;
 int __flags;
 int __size;
 int a;
};

struct __block_impl {
  void *isa;
  int Flags;
  int Reserved;
  void *FuncPtr;
};

struct __main_block_impl_0 {
  struct __block_impl impl;
  struct __main_block_desc_0* Desc;
  struct __Block_byref_a_0 *a; // by ref
};
```

在main中进行强制类型转换

```
typedef void(^XXBlock)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        __block int a = 10;
        XXBlock block = ^{
            a = 20;
        };
        
        block();
        struct __main_block_impl_0 *astruct = (__bridge struct __main_block_impl_0 *)block;
        NSLog(@"--->%p",&a);
        //打印结果： --->0x100600a28
    }
    return 0;
}
```

我们打控制台分析
```
//block内 将变量a包装的结构体地址
p/x astruct->a
(__Block_byref_a_0 *) $3 = 0x0000000100600a10

//包装的结构体的a变量地址，可以看到这个地址和控制台打印的地址是一样的
p/x &(astruct->a->a)
(int *) $4 = 0x0000000100600a28
```

## __block 修饰基本数据类型变量的内存管理分析

因为__block 修饰的变量其实内部是是将变量包装成一个结构体对象的，所以在内存方面和Block访问`对象类型的auto变量`基本是一致的

这一块是不区分基本数据类型和对象类型的，只要用__block 描述都是在内部包装成结构体

* 当block 在栈上，并不会对__block 变量进行引用

* 当block copy到堆上时：①Block 内部会调用copy函数② copy内部会调用 _block_object_assign 函数 ③ _block_object_assign函数会对__block 变量形成强引用

* 当block 从堆中释放时：①会调用block的dispose 函数 ---> _block_object_dispose函数 ---> _block_object_dispose函数会对 __block 变量进行一次 release 操作

## block内访问 __block修饰的变量 和 对象类型auto变量 总结
 
 如果是对象类型，_block_object_assign会根据是__strong 还是 __weak描述，做不通的内存操作。
 __strong 进行 retainCount 加一，__weak则不会
 如果是__block修饰的变量 ，_block_object_assign 都会进行 retainCount 加一


## fowarding 指针分析

为什么存在下面的代码

```
//a 是结构体，__forwarding 是结构体内的指针，指向结构体本身。最后一个a是结构体内的变量
a.__forwarding->a
```

```
struct __Block_byref_a_0 {
  void *__isa;
__Block_byref_a_0 *__forwarding;
 int __flags;
 int __size;
 int a;
};
```

操作如下：

![avatar](https://s1.ax1x.com/2020/03/22/8IXLcD.md.png)


在block 拷贝后，栈上block的fowarding指针也会指向**堆block**,所以通过fowaring访问，总能访问到堆上的block内容

## __block 修改对象类型分析

基本原理与__block 修饰基本数据类型一致，__block修饰的对象类型被编译后的源码，也是一个结构体，只不过这个结构体内部多一个copy和dispose函数。会在适当的时机对变量进行 copy 和 dispose 操作

![avatar](https://s1.ax1x.com/2020/03/22/8IvgL4.md.png)

//测试代码
```
typedef void(^XXBlock)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        __block Person * p = [[Person alloc]init];
        XXBlock block = ^{
            NSLog(@"--->%@",p);
            
        };
        
        block();
    }
    return 0;
}
```

//分析一下源码
```
//查看编译后的main 函数
int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        
        //__block 描述的变量,是一个 __Block_byref_p_0
         __Block_byref_p_0 p = {0,
             &p,
             33554432,
             sizeof(__Block_byref_p_0),
             __Block_byref_id_object_copy_131,
             __Block_byref_id_object_dispose_131,
            objc_getClass("Person"),
             sel_registerName("alloc")),
             sel_registerName("init"))};
        
        //定义 block
        XXBlock block = &__main_block_impl_0(__main_block_func_0,
                                             &__main_block_desc_0_DATA,
                                             (__Block_byref_p_0 *)&p,
                                             570425344));
        //调用 block
        block->FuncPtr(block);
    }
    return 0;
}

//查看一下 __block 描述生成的结构体 __Block_byref_p_0 类型
struct __Block_byref_p_0 {
  void *__isa; //8 字节
__Block_byref_p_0 *__forwarding; //8 字节
 int __flags;//4 字节
 int __size;//44 字节
 //想比__block 修饰的基本数据类型，这个结构体多了 下面两个函数 __Block_byref_id_object_copy 和 __Block_byref_id_object_dispose
 void (*__Block_byref_id_object_copy)(void*, void*);//8 字节
 void (*__Block_byref_id_object_dispose)(void*);//8 字节
 Person *p;
}; 

//当block 被拷贝时会调用block 的 __main_block_copy_0 函数
static void __main_block_copy_0(
                                struct __main_block_impl_0*dst,
                                struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->p,
                                                                                      (void*)src->p, 8/*BLOCK_FIELD_IS_BYREF*/);}

//该函数会调用 __block 描述的结构的 __Block_byref_id_object_copy_131 函数
static void __Block_byref_id_object_copy_131(void *dst, void *src) {
 _Block_object_assign((char*)dst + 40, *(void * *) ((char*)src + 40), 131);
}
可以看到该函数最终，还是调用了_Block_object_assign
(char*)dst + 40 //为该 结构体中的持有的__block 描述的变量，即为p变量。+40 是偏移40个字节的意思


```

 # Block 循环引用

 ## 循环引用原因分析

 ## 循环引用分析解决 

 ARC 下解决循环引用

 ![avatar](https://s1.ax1x.com/2020/03/22/8IzTqe.png)

 MRC 下解决循环引用
 ![avatar](https://s1.ax1x.com/2020/03/22/8IzHVH.png)
 
 ### ARC 下

__weak 和 __unsafe__unretain 都可以解决循环引用，不同之处在于：

* __weak 在指向的对象被释放后，会自动置位nil，但是__unsafe__unretain 不会

* __unsafe__unretain 指向的对象被销毁后，如果仍然使用指向访问会发生野指针问题

* 我们可以通过__block 解决循环引用，但是他的弊端是必须要调用block，并且在block内部，将产生循环的指针置位nil