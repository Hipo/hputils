//
//  HPLocationManager.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>


@interface HPLocationManager : NSObject <CLLocationManagerDelegate> {
@private
	NSDate *_queryStartTime;
	NSMutableSet *_executionBlocks;
	CLLocationManager *_locationManager;
    CLLocationAccuracy _desiredAccuracy;
    double _intervalModifier;
}

@property (nonatomic, assign) CLLocationAccuracy desiredAccuracy;
@property (nonatomic, assign) double intervalModifier;

+ (HPLocationManager *)sharedManager;

- (void)refreshLocation;
- (void)cancelLocationQuery;
- (void)getLocationWithExecutionBlock:(void (^)(CLLocation *, NSError *))block;

@end
