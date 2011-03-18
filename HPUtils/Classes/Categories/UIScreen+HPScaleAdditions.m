//
//  UIScreen+HPScaleAdditions.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "UIScreen+HPScaleAdditions.h"


@implementation UIScreen (UIScreen_HPScaleAdditions)

- (CGFloat)scaleRatio {
	if ([self respondsToSelector:@selector(scale)]) {
		return self.scale;
	} else {
		return 1.0;
	}
}

@end
