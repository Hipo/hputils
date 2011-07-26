//
//  HPLocationManager.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPErrors.h"
#import "HPLocationManager.h"


double const kMaximumAllowedLocationInterval = 60.0 * 5.0;
double const kLocationAccuracyHundredMetersTimeOut = 4.0;
double const kLocationAccuracyKilometerTimeOut = 8.0;
double const kLocationAccuracyThreeKilometersTimeOut = 12.0;
double const kLocationTimeOut = 16.0;
double const kLocationCheckInterval = 4.0;


@interface HPLocationManager (PrivateMethods)
- (void)cancelLocationCheck;
- (void)checkLocationStatus;
- (void)sendLocationToBlocks:(CLLocation *)location withError:(NSError *)error;
@end


@implementation HPLocationManager

@synthesize desiredAccuracy = _desiredAccuracy;
@synthesize intervalModifier = _intervalModifier;

#pragma mark - Singleton and init management

static HPLocationManager *_sharedManager = nil;

+ (HPLocationManager *)sharedManager {
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
		_queryStartTime = nil;
		_executionBlocks = [[NSMutableSet alloc] init];
		_locationManager = [[CLLocationManager alloc] init];
        _desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        _intervalModifier = 1.0;
		
		[_locationManager setDelegate:self];
		[_locationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
	}
	
	return self;
}

#pragma mark - CLLocationManagerDelegate calls

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    switch ([error code]) {
        case kCLErrorDenied: {
            [self sendLocationToBlocks:nil 
                             withError:[NSError errorWithDomain:kHPErrorDomain 
                                                           code:kHPLocationDeniedErrorCode 
                                                       userInfo:nil]];
            break;
        }
        default:
            [self cancelLocationCheck];
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager 
    didUpdateToLocation:(CLLocation *)newLocation 
           fromLocation:(CLLocation *)oldLocation {
	if (-1 * [newLocation.timestamp timeIntervalSinceNow] > kMaximumAllowedLocationInterval) {
		return;
	}
	
	CLLocationAccuracy accuracy = newLocation.horizontalAccuracy;
	NSTimeInterval interval = -1 * [_queryStartTime timeIntervalSinceNow];

	if (accuracy <= _desiredAccuracy || accuracy <= kCLLocationAccuracyNearestTenMeters || 
		(accuracy <= kCLLocationAccuracyHundredMeters && interval > kLocationAccuracyHundredMetersTimeOut * _intervalModifier) || 
		(accuracy <= kCLLocationAccuracyKilometer && interval > kLocationAccuracyKilometerTimeOut * _intervalModifier) || 
		(accuracy <= kCLLocationAccuracyThreeKilometers && interval > kLocationAccuracyThreeKilometersTimeOut * _intervalModifier) || 
		interval > kLocationTimeOut * _intervalModifier) {
		[self sendLocationToBlocks:newLocation withError:nil];
	}
}

#pragma mark - Location update calls

- (void)refreshLocation {
	if (_queryStartTime != nil) {
        return;
    }
    
    _queryStartTime = [[NSDate date] retain];
    
    [_locationManager startUpdatingLocation];
    
    [self performSelector:@selector(checkLocationStatus) 
               withObject:nil 
               afterDelay:kLocationCheckInterval];
}

- (void)getLocationWithExecutionBlock:(void (^)(CLLocation *, NSError *))block {
	if (_queryStartTime != nil) {
		[_executionBlocks addObject:[[block copy] autorelease]];
	} else if (_locationManager.location == nil || 
               (_locationManager.location != nil && 
                (-1 * [_locationManager.location.timestamp timeIntervalSinceNow]) > kMaximumAllowedLocationInterval)) {
		_queryStartTime = [[NSDate date] retain];
        
		[_executionBlocks addObject:[[block copy] autorelease]];
		[_locationManager startUpdatingLocation];
		
		[self performSelector:@selector(checkLocationStatus) 
				   withObject:nil 
				   afterDelay:kLocationCheckInterval];
	} else {
		block(_locationManager.location, nil);
	}
}

- (void)checkLocationStatus {
	if (_queryStartTime == nil) {
		return;
	}
	
	CLLocationAccuracy accuracy = _locationManager.location.horizontalAccuracy;
	NSTimeInterval interval = -1 * [_queryStartTime timeIntervalSinceNow];
	
	if (interval >= kLocationAccuracyHundredMetersTimeOut && interval < kLocationAccuracyKilometerTimeOut * _intervalModifier) {
		if (accuracy <= kCLLocationAccuracyHundredMeters) {
			[self sendLocationToBlocks:_locationManager.location withError:nil];
		} else {
			[self performSelector:@selector(checkLocationStatus) 
					   withObject:nil 
					   afterDelay:(kLocationCheckInterval)];
		}
	} else if (interval >= kLocationAccuracyKilometerTimeOut && interval < kLocationAccuracyThreeKilometersTimeOut * _intervalModifier) {
		if (accuracy <= kCLLocationAccuracyKilometer) {
			[self sendLocationToBlocks:_locationManager.location withError:nil];
		} else {
			[self performSelector:@selector(checkLocationStatus) 
                       withObject:nil 
                       afterDelay:(kLocationCheckInterval)];
		}
	} else if (interval >= kLocationAccuracyThreeKilometersTimeOut && interval < kLocationTimeOut * _intervalModifier) {
		if (accuracy <= kCLLocationAccuracyThreeKilometers) {
			[self sendLocationToBlocks:_locationManager.location withError:nil];
		} else {
			[self performSelector:@selector(cancelLocationCheck) 
                       withObject:nil 
                       afterDelay:(kLocationCheckInterval)];
		}
	} else if (interval >= kLocationTimeOut * _intervalModifier) {
		[self cancelLocationCheck];
	} else {
        [self performSelector:@selector(checkLocationStatus) 
				   withObject:nil 
				   afterDelay:(kLocationCheckInterval)];
    }
}

- (void)cancelLocationCheck {
	if (_queryStartTime != nil) {
		[self sendLocationToBlocks:_locationManager.location 
						 withError:[NSError errorWithDomain:kHPErrorDomain 
													   code:kHPLocationFailureErrorCode 
												   userInfo:nil]];
	}
}

- (void)sendLocationToBlocks:(CLLocation *)location withError:(NSError *)error {
	CLLocationAccuracy accuracy = location.horizontalAccuracy;
	NSTimeInterval interval = -1 * [_queryStartTime timeIntervalSinceNow];
    
    if (accuracy <= kCLLocationAccuracyNearestTenMeters || interval >= kLocationTimeOut) {
        [_queryStartTime release], _queryStartTime = nil;
        [_locationManager stopUpdatingLocation];
    } else {
        [self performSelector:@selector(checkLocationStatus) 
                   withObject:nil 
                   afterDelay:(kLocationCheckInterval)];
    }
	
    for (void(^block)(CLLocation *location, NSError *error) in _executionBlocks) {
		block(location, error);
	}
	
	[_executionBlocks removeAllObjects];
}

#pragma mark - Accuracy

- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    if (_desiredAccuracy == desiredAccuracy) {
        return;
    }
    
    _desiredAccuracy = desiredAccuracy;
    
    [_locationManager setDesiredAccuracy:_desiredAccuracy];
    
    [self refreshLocation];
}

#pragma mark - Cancellation

- (void)cancelLocationQuery {
    [_locationManager stopUpdatingLocation];
    [_queryStartTime release], _queryStartTime = nil;
    [_executionBlocks removeAllObjects];
}

#pragma mark - Memory management

- (void)dealloc {
	[_queryStartTime release], _queryStartTime = nil;
	[_executionBlocks release], _executionBlocks = nil;
	[_locationManager release], _locationManager = nil;
	
	[super dealloc];
}

@end
