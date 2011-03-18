//
//  NSObject+HPKVCAdditions.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//


@interface NSObject (NSObject_HPKVCAdditions)
- (id)nonNullValueForKey:(NSString *)aKey;
- (id)nonNilValueForKey:(NSString *)aKey;
- (NSURL *)URLValueForKey:(NSString *)aKey;
- (NSInteger)integerValueForKey:(NSString *)aKey;
- (CGFloat)CGFloatValueForKey:(NSString *)aKey;
- (NSTimeInterval)timeIntervalValueForKey:(NSString *)aKey;
- (NSDate *)dateValueForKey:(NSString *)aKey;
- (NSDate *)timeValueForKey:(NSString *)aKey withDateFormat:(NSString *)dateFormat;
- (NSDate *)dateValueForKey:(NSString *)aKey withDateFormat:(NSString *)dateFormat;
- (NSDate *)dateValueFromString:(NSString *)string withDateFormat:(NSString *)dateFormat;
- (UIColor *)colorValueWithHexStringForKey:(NSString *)aKey;
@end
