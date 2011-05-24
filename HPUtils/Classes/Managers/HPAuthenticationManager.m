//
//  HPAuthenticationManager.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-20.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPKeychainItem.h"
#import "HPAuthenticationManager.h"


static NSString * const kHPAuthenticationIdentifierKey = @"HPKeychainIdentifier";
static NSString * const kHPAuthenticationAccessGroupKey = @"HPKeychainAccessGroup";

NSString * const HPAuthenticationManagerUsernameKey = @"username";
NSString * const HPAuthenticationManagerPasswordKey = @"password";


@implementation HPAuthenticationManager

#pragma mark - Singleton and init management

static HPAuthenticationManager *_sharedManager = nil;

+ (HPAuthenticationManager *)sharedManager {
    if (_sharedManager == nil) {
        _sharedManager = [[super allocWithZone:NULL] init];
    }
    
	return _sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedManager] retain];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;
}

- (void)release {
    
}

- (id)autorelease {
    return self;
}

- (id)init {
    self = [super init];
    
	if (self) {
        _isAuthenticated = NO;
		
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *identifier = [infoDictionary objectForKey:kHPAuthenticationIdentifierKey];
        NSString *accessGroup = [infoDictionary objectForKey:kHPAuthenticationAccessGroupKey];

        if (identifier != nil) {
            _keychainItem = [[HPKeychainItem alloc] initWithIdentifier:identifier 
                                                           accessGroup:accessGroup];
            
            NSString *username = [_keychainItem objectForKey:(id)kSecAttrAccount];
            NSString *password = [_keychainItem objectForKey:(id)kSecValueData];
            
            if (username != nil && ![username isEqualToString:@""] && 
                password != nil && ![password isEqualToString:@""]) {
                _isAuthenticated = YES;
            }
        }
	}
	
	return self;
}

#pragma mark - Authentication calls

- (BOOL)isAuthenticated {
    return _isAuthenticated;
}

- (NSDictionary *)userCredentials {
    if (_isAuthenticated) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
                [_keychainItem objectForKey:(id)kSecAttrAccount], HPAuthenticationManagerUsernameKey, 
                [_keychainItem objectForKey:(id)kSecValueData], HPAuthenticationManagerPasswordKey, nil];
    } else {
        return nil;
    }
}

- (void)removeUserCredentials {
    [_keychainItem resetKeychainItem];
    
    _isAuthenticated = NO;
}

- (void)saveUserCredentials:(NSDictionary *)credentials {
    [_keychainItem setObject:[credentials objectForKey:HPAuthenticationManagerUsernameKey] 
                      forKey:(id)kSecAttrAccount];
    
    [_keychainItem setObject:[credentials objectForKey:HPAuthenticationManagerPasswordKey] 
                      forKey:(id)kSecValueData];
    
    _isAuthenticated = YES;
}

- (void)updateUsername:(NSString *)username {
    NSDictionary *credentials = [self userCredentials];
    
    if (credentials != nil) {
        [self removeUserCredentials];

        [self saveUserCredentials:[NSDictionary dictionaryWithObjectsAndKeys:
                                   [credentials objectForKey:HPAuthenticationManagerPasswordKey], 
                                   HPAuthenticationManagerPasswordKey, 
                                   username, HPAuthenticationManagerUsernameKey, nil]];
    }
}

#pragma mark - Memory management

- (void)dealloc {
    [_keychainItem release], _keychainItem = nil;
    
    [super dealloc];
}

@end
