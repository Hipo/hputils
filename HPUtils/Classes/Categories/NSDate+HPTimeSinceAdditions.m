//
//  NSDate+HPTimeSinceAdditions.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "NSDate+HPTimeSinceAdditions.h"


@implementation NSDate (NSDate_HPTimeSinceAdditions)

- (NSString *)stringWithHumanizedTimeDifference {
	NSInteger minute = 60;
	NSInteger hour = minute * 60;
	NSInteger day = hour * 24;
	NSInteger month = day * 30;
	NSInteger year = month * 12;
	
	NSInteger seconds = -(NSInteger)[self timeIntervalSinceNow];
	NSInteger years = floor(seconds / year);
	
	if (years > 0) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@ ago", nil), 
                (years == 1) ? NSLocalizedString(@"A year", nil) : 
                [NSString stringWithFormat:NSLocalizedString(@"%d years", nil), years]];
	} else {
		NSInteger months = floor((seconds - (years * year)) / month);
		
		if (months > 0) {
			return [NSString stringWithFormat:NSLocalizedString(@"%@ ago", nil), 
                    (months == 1) ? NSLocalizedString(@"A month", nil) : 
                    [NSString stringWithFormat:NSLocalizedString(@"%d months", nil), months]];
		} else {
			NSInteger days = floor((seconds - (years * year) - (months * month)) / day);
			
			if (days > 0) {
				return [NSString stringWithFormat:NSLocalizedString(@"%@ ago", nil), 
                        (days == 1) ? NSLocalizedString(@"A day", nil) : 
                        [NSString stringWithFormat:NSLocalizedString(@"%d days", nil), days]];
			} else {
				NSInteger hours = floor((seconds - (years * year) - (months * month) - (days * day)) / hour);
				
				if (hours > 0) {
					return [NSString stringWithFormat:NSLocalizedString(@"%@ ago", nil), 
                            (hours == 1) ? NSLocalizedString(@"An hour", nil) : 
                            [NSString stringWithFormat:NSLocalizedString(@"%d hours", nil), hours]];
				} else {
					NSInteger minutes = floor((seconds - (years * year) - (months * month) - (days * day) - (hours * hour)) / minute);
					
					if (minutes > 2) {
						return [NSString stringWithFormat:NSLocalizedString(@"%d minutes ago", nil), minutes];
					} else {
						return NSLocalizedString(@"Just now", nil);
					}
				}
			}
		}
	}
}

@end
