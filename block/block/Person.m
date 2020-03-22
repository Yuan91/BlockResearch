//
//  Person.m
//  block
//
//  Created by du on 2020/3/21.
//  Copyright © 2020 du. All rights reserved.
//

#import "Person.h"

@implementation Person


- (instancetype)initWithName:(NSString *)name{
    self = [super init];
    if (self) {
        self.name = name;
    }
    return self;
}

- (void)test{
    void (^block)(void) = ^{
        NSLog(@"-->%@",self);
    };
}

- (void)dealloc{
    NSLog(@"Person dealloc");
}

@end
