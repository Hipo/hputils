//
//  UITouch+HPTouchSorting.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-21.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "UITouch+HPTouchSorting.h"


@implementation UITouch (UITouch_HPTouchSorting)

- (NSComparisonResult)compareAddress:(id)obj {
    if ((void *)self < (void *)obj) {
        return NSOrderedAscending;
    } else if ((void *)self == (void *)obj) {
        return NSOrderedSame;
    } else {
        return NSOrderedDescending;
    }
}

@end
