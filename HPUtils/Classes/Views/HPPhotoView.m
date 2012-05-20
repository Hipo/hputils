//
//  HPPhotoView.m
//  HPUtils
//
//  Created by Taylan Pince on 11-07-21.
//  Copyright 2011 Hippo Foundry Inc. All rights reserved.
//

#import "HPPhotoView.h"


@interface HPPhotoView (PrivateMethods)
- (void)handleSingleTap:(NSDictionary *)touches;
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
@end


@implementation HPPhotoView

@synthesize delegate = _delegate;
@synthesize imageView = _imageView;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        
        [_imageView setAlpha:0.0];
        [_imageView setContentMode:UIViewContentModeScaleAspectFit];
        [_imageView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | 
                                         UIViewAutoresizingFlexibleHeight)];
        
        [self addSubview:_imageView];
        
        _errorIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"error.png"]];
        
        [_errorIcon sizeToFit];
        [_errorIcon setHidden:YES];
        [_errorIcon setCenter:CGPointMake(self.bounds.size.width / 2.0, 
                                          self.bounds.size.height / 2.0)];
        
        [_errorIcon setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | 
                                         UIViewAutoresizingFlexibleRightMargin |
                                         UIViewAutoresizingFlexibleTopMargin | 
                                         UIViewAutoresizingFlexibleBottomMargin)];
        
        [self addSubview:_errorIcon];
        
        _loadIndicator = [[UIActivityIndicatorView alloc] 
                          initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        
        [_loadIndicator sizeToFit];
        [_loadIndicator setHidesWhenStopped:YES];
        [_loadIndicator setCenter:CGPointMake(self.bounds.size.width / 2.0, 
                                              self.bounds.size.height / 2.0)];
        
        [_loadIndicator setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | 
                                             UIViewAutoresizingFlexibleRightMargin |
                                             UIViewAutoresizingFlexibleTopMargin | 
                                             UIViewAutoresizingFlexibleBottomMargin)];
        
        [self addSubview:_loadIndicator];
    }
    
    return self;
}

- (void)prepareForReuse {
    [_imageView setImage:nil];
    [_errorIcon setHidden:YES];
    [_loadIndicator stopAnimating];
    [_imageView setHidden:NO];
    [_imageView setAlpha:0.0];
}

#pragma mark - Start/End loading

- (void)startLoadingAnimated:(BOOL)animated {
    [_loadIndicator setAlpha:0.0];
	[_loadIndicator setHidden:NO];
	[_loadIndicator startAnimating];
	
	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.4];
	}
	
	[_loadIndicator setAlpha:1.0];
	[_imageView setAlpha:0.0];
    [_errorIcon setAlpha:0.0];
	
	if (animated) {
		[UIView commitAnimations];
	}
}

- (void)endLoadingAnimated:(BOOL)animated withSuccess:(BOOL)success {
    if (!success) {
        [_errorIcon setAlpha:0.0];
        [_errorIcon setHidden:NO];
    }
    
	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	}
	
	[_loadIndicator setAlpha:0.0];
    
    if (success) {
        [_imageView setAlpha:1.0];
    } else {
        [_errorIcon setAlpha:1.0];
    }
	
	if (animated) {
		[UIView commitAnimations];
	}
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	[_loadIndicator stopAnimating];
}

#pragma mark - Touch events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *aTouch = [touches anyObject];
    
    if (aTouch.tapCount == 2) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *theTouch = [touches anyObject];
    
    if (theTouch.tapCount == 1) {
        NSDictionary *touchLoc = [NSDictionary dictionaryWithObject:
                                  [NSValue valueWithCGPoint:[theTouch locationInView:self]] forKey:@"location"];
        
        [self performSelector:@selector(handleSingleTap:) withObject:touchLoc afterDelay:0.3];
    } else if (theTouch.tapCount == 2) {
        if ([_delegate respondsToSelector:@selector(photoViewDidDoubleTap:)]) {
            [_delegate photoViewDidDoubleTap:self];
        }
    }
}

- (void)handleSingleTap:(NSDictionary *)touches {
    if ([_delegate respondsToSelector:@selector(photoViewDidTap:)]) {
        [_delegate photoViewDidTap:self];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    
}

#pragma mark - Memory management

- (void)dealloc {
    [_imageView release], _imageView = nil;
    [_loadIndicator release], _loadIndicator = nil;
    
    [super dealloc];
}

@end
