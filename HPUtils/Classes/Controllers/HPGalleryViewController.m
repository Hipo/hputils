//
//  HPGalleryViewController.m
//  HPUtils
//
//  Created by Taylan Pinçe on 12-06-11.
//  Copyright (c) 2012 Hippo Foundry. All rights reserved.
//

#import "HPRequestManager.h"
#import "HPGalleryViewController.h"
#import "UIDevice+HPCapabilityAdditions.h"


@interface HPGalleryViewController (Private)

- (void)loadImageAtURL:(NSString *)imageURL;
- (void)didTapCloseButton:(id)sender;

@end


@implementation HPGalleryViewController

@synthesize imageURLs = _imageURLs;
@synthesize galleryView = _galleryView;
@synthesize currentPage = _currentPage;
@synthesize delegate = _delegate;

- (id)initWithImageURLs:(NSArray *)imageURLs {
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {
        _imageURLs = [imageURLs copy];
        _rotationInProgress = NO;
        _doubleTapInProgress = NO;
        _toolbarVisible = YES;
        _zoomInProgress = NO;
        
        [self setWantsFullScreenLayout:YES];
        
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] 
                                        initWithTitle:NSLocalizedString(@"Close", nil) 
                                        style:UIBarButtonItemStylePlain 
                                        target:self 
                                        action:@selector(didTapCloseButton:)];
        
        [self.navigationItem setRightBarButtonItem:closeButton];
        
        [closeButton release];
    }
    
    return self;
}

- (void)dealloc {
    [_imageURLs release], _imageURLs = nil;
    [_galleryView release], _galleryView = nil;
    
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)loadView {
    UIView *mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [mainView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | 
                                   UIViewAutoresizingFlexibleHeight)];
    
    self.view = mainView;
    
    [mainView release];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _galleryView = [[HPGalleryView alloc] initWithFrame:
                    CGRectMake(0.0, 0.0, self.view.bounds.size.width, 
                               self.view.bounds.size.height)];
    
    [_galleryView setDelegate:self];
    [_galleryView setDataSource:self];
    
    [self.view addSubview:_galleryView];
    
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
    
    if ([self.navigationController.navigationBar respondsToSelector:@selector(backgroundImageForBarMetrics:)]) {
        [self.navigationController.navigationBar setBackgroundImage:nil 
                                                      forBarMetrics:UIBarMetricsDefault];
    }
}

- (void)viewDidUnload {
    [_galleryView release], _galleryView = nil;
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent 
                                                animated:YES];
    
    [_galleryView setContentOffset:CGPointMake(_currentPage * _galleryView.bounds.size.width, 0.0) 
                          animated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
    [self performSelector:@selector(toggleToolbar) 
               withObject:nil 
               afterDelay:2.0];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    if (![[UIDevice currentDevice] isTablet]) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque 
                                                    animated:YES];
    }
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    _rotationInProgress = YES;
    
    if (_zoomInProgress) {
        [_galleryView setZoomScale:1.0 animated:NO];
        [_galleryView exitZoomModeWithPageSwitch:YES];
        
        _zoomInProgress = NO;
    }
    
    [_galleryView setScrollEnabled:NO];
    [_galleryView removeHiddenViews];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [_galleryView setContentOffset:CGPointMake(_currentPage * _galleryView.bounds.size.width, 0.0)];
    [_galleryView refreshVisibleViews];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    [_galleryView setScrollEnabled:YES];
    [_galleryView refreshLayout];
    [_galleryView reloadAdjacentViews];
    
    _rotationInProgress = NO;
}

#pragma mark - Button actions

- (void)didTapCloseButton:(id)sender {
    [_delegate modalViewControllerDidClose:self];
}

- (void)toggleToolbar {
    [NSObject cancelPreviousPerformRequestsWithTarget:self 
                                             selector:@selector(toggleToolbar) 
                                               object:nil];
    
    if (!_rotationInProgress) {
        _toolbarVisible = !_toolbarVisible;
        
        [[UIApplication sharedApplication] setStatusBarHidden:!_toolbarVisible 
                                                withAnimation:UIStatusBarAnimationFade];
        
        if (_toolbarVisible) {
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.4];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationWillStartSelector:@selector(animationDidStart:context:)];
        [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
        
        [self.navigationController.navigationBar setAlpha:(_toolbarVisible) ? 1.0 : 0.0];
        
        [UIView commitAnimations];
    }
	
	if (_toolbarVisible) {
		[self performSelector:@selector(toggleToolbar) 
				   withObject:nil 
				   afterDelay:2.0];
	}
}

- (void)animationDidStart:(NSString *)animationID context:(void *)context {
    [[UIApplication sharedApplication] setStatusBarHidden:!_toolbarVisible 
                                            withAnimation:UIStatusBarAnimationFade];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    if (!_toolbarVisible) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
}

#pragma mark - GalleryViewDelegate and DataSource calls

- (NSInteger)numberOfPhotosInGalleryView:(HPGalleryView *)galleryView {
    return [_imageURLs count];
}

- (UIView *)galleryView:(HPGalleryView *)galleryView viewForPhotoWithIndex:(NSInteger)photoIndex {
    HPPhotoView *photoView = (HPPhotoView *)[galleryView dequeueReusableView];
    
    if (photoView == nil) {
        photoView = [[[HPPhotoView alloc] initWithFrame:self.view.bounds] autorelease];
        
        [photoView setDelegate:self];
    }
    
    [photoView startLoadingAnimated:YES];
    
    NSString *imageURL = [_imageURLs objectAtIndex:photoIndex];
    
    [[HPRequestManager sharedManager] loadImageAtURL:imageURL 
                                       withIndexPath:nil 
                                          identifier:nil 
                                          scaleToFit:self.view.bounds.size 
                                         contentMode:UIViewContentModeScaleAspectFit 
                                     completionBlock:^(id resource, NSError *error) {
                                         if (error == nil) {
                                             [photoView.imageView setImage:(UIImage *)resource];
                                             [photoView endLoadingAnimated:YES withSuccess:YES];
                                         } else {
                                             [photoView endLoadingAnimated:YES withSuccess:NO];
                                         }
                                     }];
    
    return photoView;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return [_galleryView photoViewWithIndex:_currentPage];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    _zoomInProgress = YES;
    
    [_galleryView enterZoomMode];
    [_galleryView setHiddenViewsVisible:NO];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
    [_galleryView setHiddenViewsVisible:YES];
    
    if (scale == 1.0) {
        [_galleryView exitZoomModeWithPageSwitch:YES];
        
        _zoomInProgress = NO;
    } else if (scale > 1.5) {
        scale = (scale > 2.5) ? 4.0 : 2.0;
        
        HPPhotoView *photoView = (HPPhotoView *)[_galleryView photoViewWithIndex:_currentPage];
        NSString *imageURL = [_imageURLs objectAtIndex:_currentPage];
        
        [[HPRequestManager sharedManager] loadImageAtURL:imageURL 
                                           withIndexPath:nil 
                                              identifier:nil 
                                              scaleToFit:self.view.bounds.size 
                                             contentMode:UIViewContentModeScaleAspectFit 
                                         completionBlock:^(id resource, NSError *error) {
                                             if (error == nil) {
                                                 [photoView.imageView setImage:(UIImage *)resource];
                                             }
                                         }];
    }
    
    _doubleTapInProgress = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!_rotationInProgress && !_zoomInProgress) {
        _currentPage = MIN(MAX(floorf(scrollView.contentOffset.x / scrollView.bounds.size.width), 0), 1 - 1);
    } else if (!scrollView.zooming && !_doubleTapInProgress && _zoomInProgress && scrollView.zoomScale > 1.0) {
        CGFloat pageSwitchOffset = 90.0;
        
        if ((scrollView.contentOffset.x + self.view.bounds.size.width) > (self.view.bounds.size.width * scrollView.zoomScale) + pageSwitchOffset) {
            if (_currentPage < 1 - 1) {
                [_galleryView setZoomScale:1.0 animated:NO];
                [_galleryView exitZoomModeWithPageSwitch:NO];
                
                _zoomInProgress = NO;
                
                [_galleryView setContentOffset:CGPointMake((_currentPage + 1) * self.view.bounds.size.width, 0.0) 
                                      animated:YES];
            }
        } else if (scrollView.contentOffset.x < -pageSwitchOffset) {
            if (_currentPage > 0) {
                [_galleryView setZoomScale:1.0 animated:NO];
                [_galleryView exitZoomModeWithPageSwitch:NO];
                
                _zoomInProgress = NO;
                
                [_galleryView setContentOffset:CGPointMake((_currentPage - 1) * self.view.bounds.size.width, 0.0) 
                                      animated:YES];
            }
        }
    }
}

#pragma mark - PhotoViewDelegate calls

- (void)photoViewDidTap:(HPPhotoView *)photoView {
    [self toggleToolbar];
}

- (void)photoViewDidDoubleTap:(HPPhotoView *)photoView {
    _doubleTapInProgress = YES;
    
    if (_galleryView.zoomScale > 2.0) {
        [_galleryView setZoomScale:1.0 animated:YES];
    } else if (_galleryView.zoomScale > 1.0) {
        [_galleryView setZoomScale:4.0 animated:YES];
    } else {
        [_galleryView setZoomScale:2.0 animated:YES];
    }
}

@end
