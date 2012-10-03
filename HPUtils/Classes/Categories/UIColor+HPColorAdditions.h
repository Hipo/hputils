//
//  UIColor+HPColorAdditions.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//


/** UIColor extension that adds convenience methods
 */
@interface UIColor (UIColor_HPColorAdditions)
+ (UIColor *)lightBlueBackgroundColor;
+ (UIColor *)darkBlueForegroundColor;

/** Generates a UIColor instance from any hex color code
 
 @param hexString hex string for the target color, can be in #aaa or #aaabbb format
 */
+ (UIColor *)colorFromHexString:(NSString *)hexString;
@end
