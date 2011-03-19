//
//  HPLoadingWindow.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-19.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "HPLoadingWindow.h"


static NSString * const kHPLoadingWindowConfirmationAnimationKey = @"confirmationAnimation";


@interface HPLoadingWindow (PrivateMethods)
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
@end


@implementation HPLoadingWindow

static HPLoadingWindow *_sharedInstance = nil;

+ (HPLoadingWindow *)sharedInstance {
    if (_sharedInstance == nil) {
        _sharedInstance = [[super allocWithZone:NULL] init];
    }
    
	return _sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedInstance] retain];
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

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
		_animating = NO;
        
		[self setAlpha:0.0];
		[self setHidden:YES];
		[self setWindowLevel:UIWindowLevelStatusBar];
		[self setBackgroundColor:[UIColor clearColor]];
		[self setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
		
		_shieldView = [[UIView alloc] initWithFrame:CGRectZero];
		
		[_shieldView setBackgroundColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.2]];
		[_shieldView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
		
		[self addSubview:_shieldView];
		
		_backgroundView = [[UIView alloc] initWithFrame:CGRectMake(floorf(frame.size.width / 2) - 60.0, floorf(frame.size.height / 2) - 50.0, 120.0, 120.0)];
		
		_backgroundView.layer.cornerRadius = 10.0;
		_backgroundView.layer.masksToBounds = YES;
		
		[_backgroundView setBackgroundColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.75]];
		[_backgroundView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | 
											  UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
		
		[self addSubview:_backgroundView];
		
        _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		
		[_loadingIndicator setHidesWhenStopped:YES];
		[_loadingIndicator setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | 
												UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
		
		[self addSubview:_loadingIndicator];
		
		_statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		
		[_statusLabel setTextColor:[UIColor whiteColor]];
		[_statusLabel setTextAlignment:UITextAlignmentCenter];
		[_statusLabel setFont:[UIFont boldSystemFontOfSize:16.0]];
		[_statusLabel setBackgroundColor:[UIColor clearColor]];
		[_statusLabel setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | 
										   UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
		
		[self addSubview:_statusLabel];
		
		_statusIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 37.0, 37.0)];
		
		[_statusIcon setHidden:YES];
		[_statusIcon setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | 
										  UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
		
		[self addSubview:_statusIcon];
    }
	
    return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	
	[_shieldView setFrame:self.bounds];
	[_loadingIndicator setCenter:CGPointMake(floor(self.frame.size.width / 2), floorf(self.frame.size.height / 2))];
	[_statusLabel setFrame:CGRectMake(40.0, _loadingIndicator.frame.origin.y + _loadingIndicator.frame.size.height + 15.0, self.frame.size.width - 80.0, 25.0)];
	[_statusIcon setCenter:_loadingIndicator.center];
}

- (void)continueAnimatingWithMessage:(NSString *)message {
	[_statusLabel setText:message];
}

- (void)startAnimatingWithMessage:(NSString *)message style:(HPLoadingWindowStyle)style {
	if (_animating) {
		[self continueAnimatingWithMessage:message];
	}
	
	_animating = YES;
	_displayStyle = style;
	
	[self setUserInteractionEnabled:(_displayStyle != HPLoadingWindowStyleNonBlocking)];
	
	[_shieldView setHidden:(_displayStyle == HPLoadingWindowStyleNonBlocking)];
	[_backgroundView setTransform:CGAffineTransformMakeScale(0.4, 0.4)];
	[_statusLabel setText:message];
	[_statusIcon setHidden:YES];
	
	[self setHidden:NO];
	[self makeKeyAndVisible];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	
	[self setAlpha:1.0];
	[_backgroundView setTransform:CGAffineTransformIdentity];
	
	[UIView commitAnimations];
	
	[_loadingIndicator startAnimating];
}

- (void)stopAnimatingWithMessage:(NSString *)message success:(BOOL)success {
	if (!_animating) {
		return;
	}
	
	_animating = NO;
	
	[_loadingIndicator stopAnimating];
	[_statusIcon setImage:[UIImage imageNamed:(success) ? @"success.png" : @"error.png"]];
	[_statusIcon setHidden:NO];
	[_statusLabel setText:message];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	
	[self setAlpha:0.0];
    
	[_backgroundView setTransform:CGAffineTransformMakeScale(1.6, 1.6)];
	
	[UIView commitAnimations];
}

- (void)displayConfirmationWithMessage:(NSString *)message {
	[_statusIcon setImage:[UIImage imageNamed:@"success.png"]];
	[_statusIcon setHidden:NO];
	[_statusLabel setText:message];
	[_shieldView setHidden:NO];
	[_backgroundView setTransform:CGAffineTransformMakeScale(0.4, 0.4)];
	
	[self setHidden:NO];
	[self makeKeyAndVisible];
	
	[UIView beginAnimations:kHPLoadingWindowConfirmationAnimationKey context:NULL];
	[UIView setAnimationDuration:0.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	
	[self setAlpha:1.0];
    
	[_backgroundView setTransform:CGAffineTransformIdentity];
	
	[UIView commitAnimations];
}

- (void)hideConfirmation {
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	
	[self setAlpha:0.0];
    
	[_backgroundView setTransform:CGAffineTransformMakeScale(1.6, 1.6)];
	
	[UIView commitAnimations];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	if ([animationID isEqualToString:kHPLoadingWindowConfirmationAnimationKey]) {
		[self hideConfirmation];
	} else {
		[self setHidden:YES];
		
		[[[[UIApplication sharedApplication] windows] objectAtIndex:0] makeKeyAndVisible];
	}
}

- (void)dealloc {
	[_statusLabel release];
	[_statusIcon release];
	[_loadingIndicator release];
	[_backgroundView release];
	[_shieldView release];

    [super dealloc];
}

@end
