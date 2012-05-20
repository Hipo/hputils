//
//  HPGalleryView.h
//  HPUtils
//
//  Created by Taylan Pinçe on 11-08-22.
//  Copyright 2011 Hippo Foundry Inc. All rights reserved.
//


@protocol HPGalleryViewDataSource;

@interface HPGalleryView : UIScrollView {
@private
    CGRect _visibleBounds;
    NSInteger _totalPhotos;
    NSInteger _currentPhoto;
    NSInteger _zoomedPhoto;
    NSIndexSet *_visibleIndices;
    NSMutableSet *_reusableViews;
    
    id <HPGalleryViewDataSource> _dataSource;
}

@property (nonatomic, assign) id <HPGalleryViewDataSource> dataSource;

- (void)reloadData;
- (void)refreshLayout;
- (void)removeHiddenViews;
- (void)refreshVisibleViews;
- (void)reloadAdjacentViews;
- (void)enterZoomMode;
- (void)exitZoomModeWithPageSwitch:(BOOL)pageSwitch;
- (void)setHiddenViewsVisible:(BOOL)visible;

- (UIView *)dequeueReusableView;
- (NSInteger)indexOfPhotoView:(UIView *)photoView;
- (UIView *)photoViewWithIndex:(NSInteger)photoIndex;

@end


@protocol HPGalleryViewDataSource <NSObject>
@required
- (NSInteger)numberOfPhotosInGalleryView:(HPGalleryView *)galleryView;
- (UIView *)galleryView:(HPGalleryView *)galleryView viewForPhotoWithIndex:(NSInteger)photoIndex;
@end
