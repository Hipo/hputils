//
//  UIDevice+HPCapabilityAdditions.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#include <sys/types.h>
#include <sys/sysctl.h>

#import "UIDevice+HPCapabilityAdditions.h"


static NSString * const kHPPlatformCodeiPhone1G = @"iPhone1,1";
static NSString * const kHPPlatformCodeiPhone3G = @"iPhone1,2";
static NSString * const kHPPlatformCodeiPhone3GS = @"iPhone2,1";
static NSString * const kHPPlatformCodeiPhone4G = @"iPhone3,1";
static NSString * const kHPPlatformCodeiPhone4GS = @"iPhone4,1";
static NSString * const kHPPlatformCodeiPodTouch1G = @"iPod1,1";
static NSString * const kHPPlatformCodeiPodTouch2G = @"iPod2,1";
static NSString * const kHPPlatformCodeiPodTouch3G = @"iPod3,1";
static NSString * const kHPPlatformCodeiPodTouch4G = @"iPod4,1";
static NSString * const kHPPlatformCodeiPad1G = @"iPad1,1";
static NSString * const kHPPlatformCodeiPad2G = @"iPad2,1";
static NSString * const kHPPlatformCodeSimulator = @"i386";


@implementation UIDevice (UIDevice_CapabilityAdditions)

- (NSString *)platformCode {
	static NSString *platform = nil;
	
	if (platform == nil) {
		size_t size;
		
		sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        
		char *machine = malloc(size);
        
		sysctlbyname("hw.machine", machine, &size, NULL, 0);
		
		platform = [[NSString alloc] initWithCString:machine 
											encoding:NSASCIIStringEncoding];
		
		free(machine);
	}
	
	return platform;
}

- (HPDeviceType)deviceType {
    NSString *platform = [self platformCode];
    
    if ([platform isEqualToString:kHPPlatformCodeiPhone1G]) {
        return HPDeviceTypeiPhone1G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPhone3G]) {
        return HPDeviceTypeiPhone3G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPhone3GS]) {
        return HPDeviceTypeiPhone3GS;
    } else if ([platform isEqualToString:kHPPlatformCodeiPhone4G]) {
        return HPDeviceTypeiPhone4G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPhone4GS]) {
        return HPDeviceTypeiPhone4GS;
    } else if ([platform isEqualToString:kHPPlatformCodeiPodTouch1G]) {
        return HPDeviceTypeiPodTouch1G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPodTouch2G]) {
        return HPDeviceTypeiPodTouch2G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPodTouch3G]) {
        return HPDeviceTypeiPodTouch3G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPodTouch4G]) {
        return HPDeviceTypeiPodTouch4G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPad1G]) {
        return HPDeviceTypeiPad1G;
    } else if ([platform isEqualToString:kHPPlatformCodeiPad2G]) {
        return HPDeviceTypeiPad2G;
    } else if ([platform isEqualToString:kHPPlatformCodeSimulator]) {
        return HPDeviceTypeSimulator;
    } else {
        return HPDeviceTypeUnknown;
    }
}

- (BOOL)canScanBarcodes {
    HPDeviceType hardwareType = [self deviceType];
    
    return (hardwareType != HPDeviceTypeiPad1G && hardwareType != HPDeviceTypeiPhone1G && 
            hardwareType != HPDeviceTypeiPhone3G && hardwareType != HPDeviceTypeiPodTouch1G && 
            hardwareType != HPDeviceTypeiPodTouch2G && hardwareType != HPDeviceTypeiPodTouch3G && 
            hardwareType != HPDeviceTypeSimulator);
}

- (BOOL)canMakePhoneCalls {
    return ([[self platformCode] rangeOfString:@"iPhone"].location != NSNotFound);
}

- (BOOL)isTablet {
#ifdef UI_USER_INTERFACE_IDIOM
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
#else
    return NO;
#endif
}

@end
