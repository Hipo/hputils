//
//  NSString+HPHashAdditions.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

#import "NSString+HPHashAdditions.h"


@implementation NSString (NSString_HPHashAdditions)

#pragma mark - SHA1

- (NSString *)SHA1Hash {
	const char *cString = [self cStringUsingEncoding:NSUTF8StringEncoding];
	
	NSData *stringData = [NSData dataWithBytes:cString length:[self length]];
	
	uint8_t digest[CC_SHA1_DIGEST_LENGTH];
	
	CC_SHA1([stringData bytes], [stringData length], digest);
	
	NSMutableString *outputString = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
	
	for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
		[outputString appendFormat:@"%02x", digest[i]];
	}
	
	return outputString;
}

- (NSData *)SHA1HashWithSalt:(NSString *)salt {
    const char *cKey  = [salt cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [self cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    return [NSData dataWithBytes:cHMAC length:sizeof(cHMAC)];
}

- (NSData *)HMACSHA1withKey:(NSString *)key {
    NSData *clearTextData = [self dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH] = {0};
    
    CCHmacContext hmacContext;
    CCHmacInit(&hmacContext, kCCHmacAlgSHA1, keyData.bytes, keyData.length);
    CCHmacUpdate(&hmacContext, clearTextData.bytes, clearTextData.length);
    CCHmacFinal(&hmacContext, digest);

    return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

#pragma mark - MD5

- (NSString *)md5HexDigest {
	const char *cString = [self cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[CC_MD5_DIGEST_LENGTH];

    CC_MD5(cString, strlen(cString), result);
    
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x", result[i]];
    }
    
    return ret;
}

#pragma mark - UUID

+ (NSString *)stringWithUUID {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    NSString *uuidString = (NSString *)CFUUIDCreateString(nil, uuidObj);

    CFRelease(uuidObj);
    
    return [uuidString autorelease];
}

@end
