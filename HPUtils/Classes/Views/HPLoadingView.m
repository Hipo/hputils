//
//  HPLoadingView.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPLoadingView.h"
#import "UIColor+HPColorAdditions.h"


static NSString * const kHPLoadingViewAnimationStart = @"loadingAnimationStart";
static NSString * const kHPLoadingViewAnimationEnd = @"loadingAnimationEnd";


@interface HPLoadingView (PrivateMethods)
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
@end


@implementation HPLoadingView

@synthesize contentView = _contentView;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setBackgroundColor:[UIColor lightBlueBackgroundColor]];
        
        CGFloat centerYOffset = 20.0;
        
        _loadIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        
        [_loadIndicator setHidesWhenStopped:YES];
        [_loadIndicator setCenter:CGPointMake(floorf(self.bounds.size.width / 2.0), 
                                              floorf(self.bounds.size.height / 2.0) - centerYOffset)];
        [_loadIndicator setAutoresizingMask:(UIViewAutoresizingFlexibleTopMargin | 
                                             UIViewAutoresizingFlexibleBottomMargin | 
                                             UIViewAutoresizingFlexibleLeftMargin | 
                                             UIViewAutoresizingFlexibleRightMargin)];
        
        [self addSubview:_loadIndicator];
        
        _contentView = [[UIView alloc] initWithFrame:self.bounds];
        
        [_contentView setHidden:YES];
        [_contentView setBackgroundColor:self.backgroundColor];
        [_contentView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | 
                                           UIViewAutoresizingFlexibleHeight)];
        
        [self addSubview:_contentView];
    }
    
    return self;
}

- (void)startLoadingAnimated:(BOOL)animated {
    if ([_loadIndicator isAnimating]) {
        return;
    }
    
    [_loadIndicator setAlpha:0.0];
    [_loadIndicator startAnimating];
    
    if (animated) {
        [UIView beginAnimations:kHPLoadingViewAnimationStart context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    }
    
    if (!_contentView.hidden) {
        [_contentView setAlpha:0.0];
    }
    
    [_loadIndicator setAlpha:1.0];
    
    if (animated) {
        [UIView commitAnimations];
    } else {
        [_contentView setHidden:YES];
        [_errorView setHidden:YES];
    }
}

- (void)endLoadingWithMessage:(NSString *)message animated:(BOOL)animated {
    BOOL success = (message == nil);
    
    if (success) {
        [_contentView setAlpha:0.0];
        [_contentView setHidden:NO];
    } else {
        if (_errorView == nil) {
            _errorView = [[UIView alloc] initWithFrame:CGRectInset(self.bounds, 40.0, 40.0)];
            
            CGFloat centerYOffset = 20.0;
            UIImageView *errorIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"warning.png"]];
            
            [errorIcon sizeToFit];
            [errorIcon setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | 
                                            UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin)];
            [errorIcon setCenter:CGPointMake(floorf(_errorView.bounds.size.width / 2.0), 
                                             floorf(_errorView.bounds.size.height / 2.0) - centerYOffset)];
            
            [_errorView addSubview:errorIcon];
            
            UILabel *errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, errorIcon.frame.origin.y + errorIcon.frame.size.height + 5.0, 
                                                                            _errorView.bounds.size.width, 20.0)];
            
            [errorLabel setTag:1];
            [errorLabel setTextAlignment:UITextAlignmentCenter];
            [errorLabel setBackgroundColor:self.backgroundColor];
            [errorLabel setFont:[UIFont boldSystemFontOfSize:14.0]];
            [errorLabel setShadowColor:[UIColor whiteColor]];
            [errorLabel setShadowOffset:CGSizeMake(0.0, 1.0)];
            [errorLabel setTextColor:[UIColor darkBlueForegroundColor]];
            [errorLabel setNumberOfLines:0];
            [errorLabel setLineBreakMode:UILineBreakModeWordWrap];
            [errorLabel setAutoresizingMask:(UIViewAutoresizingFlexibleBottomMargin | 
                                             UIViewAutoresizingFlexibleWidth)];
            
            [_errorView addSubview:errorLabel];
            
            [errorLabel release];
            [errorIcon release];
            
            [_errorView setBackgroundColor:self.backgroundColor];
            [_errorView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | 
                                             UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin)];
            
            [self addSubview:_errorView];
        }
        
        [(UILabel *)[_errorView viewWithTag:1] setText:message];
        
        [_errorView setAlpha:0.0];
        [_errorView setHidden:NO];
    }
    
    if (animated) {
        [UIView beginAnimations:kHPLoadingViewAnimationEnd context:NULL];
        [UIView setAnimationDuration:0.3];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    }
    
    [_loadIndicator setAlpha:0.0];
    
    if (success) {
        [_contentView setAlpha:1.0];
        [_errorView setAlpha:0.0];
    } else {
        [_contentView setAlpha:0.0];
        [_errorView setAlpha:1.0];
    }
    
    if (animated) {
        [UIView commitAnimations];
    } else {
        [_loadIndicator stopAnimating];
    }
}

- (void)endLoadingWithSuccess:(BOOL)success animated:(BOOL)animated {
    if (success) {
        [self endLoadingWithMessage:nil animated:animated];
    } else {
        [self endLoadingWithMessage:@"Connection Error" animated:animated];
    }
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    if ([animationID isEqualToString:kHPLoadingViewAnimationStart]) {
        [_contentView setHidden:YES];
        [_errorView setHidden:YES];
    } else if ([animationID isEqualToString:kHPLoadingViewAnimationEnd]) {
        [_loadIndicator stopAnimating];
    }
}

- (void)dealloc {
    [_loadIndicator release];
    [_contentView release];
    [_errorView release];
    
    [super dealloc];
}

@end
