//
//  main.m
//  block
//
//  Created by du on 2020/3/21.
//  Copyright © 2020 du. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Person.h"

//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        // insert code here...
//
//
//        //MARK: block 基本分析
////        void (^block) (void) = ^{
////           NSLog(@"Hello, World!");
////        };
////        block();
//
//
//
////MARK: block 捕获外部变量分析
//        int age = 10;
//        void (^block) (void) = ^{
//            NSLog(@"age:%d",age);
//        };
//        age = 20;
//        block();
//
//    }
//    return 0;
//}

//MARK: 捕获static 变量分析
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        auto int age = 10;
//        static int number = 10;
//        void (^block) (void) = ^{
//            NSLog(@"age:%d,number:%d",age,number);
//            //print: age:10,number:20
//        };
//        age = 20;
//        number = 20;
//        block();
//
//    }
//    return 0;
//}


//MARK: 捕获全局变量

//void (^block)(void);
//void test(){
//    int test_A = 10;
//    static int test_B = 10;
//    block = ^{
//        NSLog(@"test_A:%d,test_B:%d",test_A,test_B);
//    };
//    test_A = 20;
//    test_B = 20;
//}
//
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        //调用test函数,给block赋值.
//        //此时test_A变量的作用域已经结束,是不能通过指针来访问的,所以需要捕获值
//        test();
//        block();
//        //print:test_A:10,test_B:20
//    }
//    return 0;
//}

//MARK: block访问全局变量
//int age = 10;
//static int number = 10;
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        void (^block) (void) = ^{
//            NSLog(@"age:%d,number:%d",age,number);
//            //print: age:20,number:20
//        };
//        age = 20;
//        number = 20;
//        block();
//    }
//    return 0;
//}


//MARK: block 类型分析
//在MRC 下分析
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        void (^block) (void) = ^{
//            NSLog(@"test");
//        };
//        NSLog(@"%@",[block class]);
//        NSLog(@"%@",[[block class] superclass]);
//        NSLog(@"%@",[[[block class] superclass] superclass]);
//        NSLog(@"%@",[[[[block class] superclass] superclass] superclass]);
//
//        auto int a = 0;
//        void(^ block1) (void) = ^{
//            NSLog(@"==%d",a);
//        };
//        NSLog(@"block1:%@",[block1 class]);
//
//        static int b = 0;
//        void(^ block2) (void) = ^{
//            NSLog(@"==%d",b);
//        };
//        NSLog(@"block2:%@",[block2 class]);
//
//        void(^ block3) (void) = ^{
////            NSLog(@"==%d",b);
//        };
//        NSLog(@"block3:%@",[block3 class]);
//
//        NSLog(@"block1copy:%@",[[block1 copy] class]);
//
//    }
//    return 0;
//}



//MARK: block 栈区分析
//void (^block) (void);
//void test() {
//    int a = 10;
//    block = ^{
//        NSLog(@"==%d",a);
//    };
//}
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        test();
//        block();
//    }
//    return 0;
//}

//MARK: ARC 下自动拷贝操作
//typedef void(^XXBlock)(void);
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        int a = 10;
//        XXBlock block = ^{
//            NSLog(@"==%d",a);
//        };
//        NSLog(@"class:%@",[block class]);
//    }
//    return 0;
//}

//MARK: Block 访问auto类型的对象
//
//typedef void(^XXBlock)(void);
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//
//        XXBlock block = nil;
//        {
//             Person *p = [[Person alloc]init];
//             p.name = @"哈哈";
//            __weak Person *weakPerson = p;
//            block = ^{
//                NSLog(@"%@",p.name);
//            };
//        }
//        NSLog(@"======");
//    }
//    return 0;
//}

//MARK: block 修改外部变量
//typedef void(^XXBlock)(void);
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//
//        __block int a = 10;
//        XXBlock block = ^{
//            a = 20;
//        };
//
//        block();
//    }
//    return 0;
//}

//MARK: __block 变量的访问分析

//struct __Block_byref_a_0 {
//  void *__isa;
// struct __Block_byref_a_0 *__forwarding;
// int __flags;
// int __size;
// int a;
//};
//
//struct __block_impl {
//  void *isa;
//  int Flags;
//  int Reserved;
//  void *FuncPtr;
//};
//
//struct __main_block_impl_0 {
//  struct __block_impl impl;
//  struct __main_block_desc_0* Desc;
//  struct __Block_byref_a_0 *a; // by ref
//};
//
//typedef void(^XXBlock)(void);
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        __block int a = 10;
//        XXBlock block = ^{
//            a = 20;
//
//        };
//        block();
//        NSLog(@"--->%p",&a);
//    }
//    return 0;
//}

//MARK:- __block 修饰对象类型
//typedef void(^XXBlock)(void);
//int main(int argc, const char * argv[]) {
//    @autoreleasepool {
//        __block Person * p = [[Person alloc]init];
//        XXBlock block = ^{
//            NSLog(@"--->%@",p);
//
//        };
//
//        block();
//    }
//    return 0;
//}

//测试代码
typedef void(^XXBlock)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
         int a = 10;
//        Person * p = [[Person alloc]init];
//        int b = 10;
        static int c = 10;
//        NSLog(@"原始%p",&a);
//        NSLog(@"原始变量P的地址:%p",&a);
//        NSLog(@"------:%p",a);
        XXBlock block = ^{
//            a = 20;
//            p = nil;
            NSLog(@"%d",a);
            NSLog(@"%d",c);
//            NSLog(@"block内%p",&a);
//            NSLog(@"block内P的地址:%p",&a);
//            NSLog(@"=======:%p",a);
        };
        
        block();
    }
    return 0;
}

