//
//  HPAuthenticationManager.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-20.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

extern NSString * const HPAuthenticationManagerUsernameKey;
extern NSString * const HPAuthenticationManagerPasswordKey;


@class HPKeychainItem;

@interface HPAuthenticationManager : NSObject {
@private
    HPKeychainItem *_keychainItem;
    
    BOOL _isAuthenticated;
}

+ (HPAuthenticationManager *)sharedManager;

- (BOOL)isAuthenticated;
- (NSDictionary *)userCredentials;
- (void)removeUserCredentials;
- (void)saveUserCredentials:(NSDictionary *)credentials;

@end
