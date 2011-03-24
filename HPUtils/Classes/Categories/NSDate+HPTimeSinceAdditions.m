//
//  NSDate+HPTimeSinceAdditions.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "NSDate+HPTimeSinceAdditions.h"


@implementation NSDate (NSDate_HPTimeSinceAdditions)

- (NSString *)timeSince {
	NSInteger minute = 60;
	NSInteger hour = minute * 60;
	NSInteger day = hour * 24;
	NSInteger month = day * 30;
	NSInteger year = month * 12;
	
	NSInteger seconds = -(NSInteger)[self timeIntervalSinceNow];
	NSInteger years = floor(seconds / year);
	
	if (years > 0) {
		return [NSString stringWithFormat:@"More than %@ ago", (years == 1) ? @"a year" : [NSString stringWithFormat:@"%d years", years]];
	} else {
		NSInteger months = floor((seconds - (years * year)) / month);
		
		if (months > 0) {
			return [NSString stringWithFormat:@"%@ ago", (months == 1) ? @"A month" : [NSString stringWithFormat:@"%d months", months]];
		} else {
			NSInteger days = floor((seconds - (years * year) - (months * month)) / day);
			
			if (days > 0) {
				return [NSString stringWithFormat:@"%@ ago", (days == 1) ? @"A day" : [NSString stringWithFormat:@"%d days", days]];
			} else {
				NSInteger hours = floor((seconds - (years * year) - (months * month) - (days * day)) / hour);
				
				if (hours > 0) {
					return [NSString stringWithFormat:@"%@ ago", (hours == 1) ? @"An hour" : [NSString stringWithFormat:@"%d hours", hours]];
				} else {
					NSInteger minutes = floor((seconds - (years * year) - (months * month) - (days * day) - (hours * hour)) / minute);
					
					if (minutes > 2) {
						return [NSString stringWithFormat:@"%@ ago", (minutes == 1) ? @"A minute" : [NSString stringWithFormat:@"%d minutes", minutes]];
					} else {
						return @"Just now";
					}
				}
			}
		}
	}
}

@end
