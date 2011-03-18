//
//  UIColor+HPColorAdditions.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "UIColor+HPColorAdditions.h"


@implementation UIColor (UIColor_HPColorAdditions)

+ (UIColor *)lightBlueBackgroundColor {
	static UIColor *color = nil;
	
	if (color == nil) {
		color = [[UIColor alloc] initWithRed:214.0 / 255.0 green:221 / 255.0 blue:224.0 / 255.0 alpha:1.0];
	}
	
	return color;
}

+ (UIColor *)darkBlueForegroundColor {
	static UIColor *color = nil;
	
	if (color == nil) {
		color = [[UIColor alloc] initWithRed:63.0 / 255.0 green:92.0 / 255.0 blue:132.0 / 255.0 alpha:1.0];
	}
	
	return color;
}

@end
