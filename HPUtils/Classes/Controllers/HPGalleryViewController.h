//
//  HPGalleryViewController.h
//  HPUtils
//
//  Created by Taylan Pinçe on 12-06-11.
//  Copyright (c) 2012 Hippo Foundry. All rights reserved.
//

#import "HPModalViewControllerDelegate.h"
#import "HPPhotoView.h"
#import "HPGalleryView.h"


@interface HPGalleryViewController : UIViewController 
<HPPhotoViewDelegate, HPGalleryViewDataSource, UIScrollViewDelegate> {
@private
    NSArray *_imageURLs;
    HPGalleryView *_galleryView;
    
    NSInteger _currentPage;
    
    BOOL _toolbarVisible;
    BOOL _rotationInProgress;
    BOOL _zoomInProgress;
    BOOL _doubleTapInProgress;
    
    id <HPModalViewControllerDelegate> _delegate;
}

@property (nonatomic, readonly, retain) NSArray *imageURLs;
@property (nonatomic, readonly, retain) HPGalleryView *galleryView;
@property (nonatomic, readonly, assign) NSInteger currentPage;
@property (nonatomic, assign) id <HPModalViewControllerDelegate> delegate;

- (id)initWithImageURLs:(NSArray *)imageURLs;

@end
