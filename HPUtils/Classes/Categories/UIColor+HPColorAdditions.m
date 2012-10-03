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

+ (UIColor *)colorFromHexString:(NSString *)hexString {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];

    if ([cleanString length] == 3) {
        cleanString = [NSString stringWithFormat:@"%@%@%@%@%@%@",
                       [cleanString substringWithRange:NSMakeRange(0, 1)],[cleanString substringWithRange:NSMakeRange(0, 1)],
                       [cleanString substringWithRange:NSMakeRange(1, 1)],[cleanString substringWithRange:NSMakeRange(1, 1)],
                       [cleanString substringWithRange:NSMakeRange(2, 1)],[cleanString substringWithRange:NSMakeRange(2, 1)]];
    }

    if ([cleanString length] == 6) {
        cleanString = [cleanString stringByAppendingString:@"ff"];
    }
    
    unsigned int baseValue;

    [[NSScanner scannerWithString:cleanString] scanHexInt:&baseValue];
    
    float red = ((baseValue >> 24) & 0xFF) / 255.0f;
    float green = ((baseValue >> 16) & 0xFF) / 255.0f;
    float blue = ((baseValue >> 8) & 0xFF) / 255.0f;
    float alpha = ((baseValue >> 0) & 0xFF) / 255.0f;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@end
