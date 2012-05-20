//
//  HPGalleryView.m
//  HPUtils
//
//  Created by Taylan Pinçe on 11-08-22.
//  Copyright 2011 Hippo Foundry Inc. All rights reserved.
//

#import "HPGalleryView.h"


static NSInteger const kHPGalleryViewTagOffset = 100;
static CGFloat const kHPGalleryPageOffset = 25.0;


@interface HPGalleryView (PrivateMethods)
- (void)removePhotoView:(UIView *)photoView;
- (NSIndexSet *)indicesOfPhotosInRect:(CGRect)rect;
- (CGRect)frameForPhotoWithIndex:(NSInteger)photoIndex;
@end


@implementation HPGalleryView

@synthesize dataSource = _dataSource;

#pragma mark - Init

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
		[self setScrollsToTop:NO];
        [self setPagingEnabled:YES];
        [self setMaximumZoomScale:4.0];
        [self setAutoresizesSubviews:NO];
        [self setDirectionalLockEnabled:YES];
        [self setAlwaysBounceHorizontal:YES];
        [self setShowsVerticalScrollIndicator:NO];
        [self setShowsHorizontalScrollIndicator:NO];
        [self setBackgroundColor:[UIColor blackColor]];
        [self setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | 
                                   UIViewAutoresizingFlexibleHeight)];

        _reusableViews = [[NSMutableSet alloc] init];
        _visibleIndices = [[NSIndexSet alloc] init];
        _visibleBounds = CGRectZero;
        _zoomedPhoto = NSNotFound;
        _currentPhoto = 0;
    }
    
    return self;
}

#pragma mark - Memory management

- (void)dealloc {
    [_visibleIndices release], _visibleIndices = nil;
    [_reusableViews release], _reusableViews = nil;
    
    [super dealloc];
}

#pragma mark - Setters

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
    
	if (!CGSizeEqualToSize(frame.size, self.contentSize) && 
        !CGRectEqualToRect(frame, CGRectZero) && _dataSource != nil) {
		[self refreshLayout];
		[self setNeedsLayout];
	}
}

- (void)setDataSource:(id <HPGalleryViewDataSource>)newDataSource {
    if (_dataSource == newDataSource) {
        return;
    }

    _dataSource = newDataSource;
    
    if (!CGRectEqualToRect(self.bounds, CGRectZero)) {
        [self reloadData];
        [self setNeedsLayout];
    }
}

#pragma mark - Queries

- (CGRect)frameForPhotoWithIndex:(NSInteger)photoIndex {
    return CGRectMake(photoIndex * self.bounds.size.width, 0.0, 
                      (_totalPhotos > 1) ? self.bounds.size.width - kHPGalleryPageOffset : self.bounds.size.width, 
                      self.bounds.size.height);
}

- (NSIndexSet *)indicesOfPhotosInRect:(CGRect)rect {
    if (CGRectIsEmpty(rect)) {
		return [NSIndexSet indexSet];
	}
	
	NSMutableIndexSet *indexSet = [[[NSMutableIndexSet alloc] init] autorelease];
	NSUInteger firstIndex = NSNotFound;
	
	for (NSInteger i = 0; i < _totalPhotos; i++) {
		if (CGRectIntersectsRect(rect, [self frameForPhotoWithIndex:i])) {
			if (firstIndex == NSNotFound) {
				firstIndex = i;
			}
		} else if (firstIndex != NSNotFound) {
			[indexSet addIndexesInRange:NSMakeRange(firstIndex, i - firstIndex)];
			
			firstIndex = NSNotFound;
		}
	}
	
	if (firstIndex != NSNotFound) {
		[indexSet addIndexesInRange:NSMakeRange(firstIndex, _totalPhotos - firstIndex)];
	}
	
	return indexSet;
}

- (NSInteger)indexOfPhotoView:(UIView *)photoView {
    return (photoView.tag - kHPGalleryViewTagOffset);
}

- (UIView *)photoViewWithIndex:(NSInteger)photoIndex {
    return [self viewWithTag:(photoIndex + kHPGalleryViewTagOffset)];
}

#pragma mark - Recycling

- (UIView *)dequeueReusableView {
    UIView *page = [_reusableViews anyObject];
	
    if (page != nil) {
        [[page retain] autorelease];
        
        [_reusableViews removeObject:page];
    }
    
	return page;
}

- (void)removePhotoView:(UIView *)photoView {
    if (photoView == nil) {
        return;
    }
    
    if ([photoView respondsToSelector:@selector(prepareForReuse)]) {
        [photoView performSelector:@selector(prepareForReuse)];
    }
    
    [_reusableViews addObject:photoView];
    
    [photoView removeFromSuperview];
}

- (void)removeHiddenViews {
	NSIndexSet *visibleIndices = [self indicesOfPhotosInRect:self.bounds];
    
    for (UIView *photoView in [self subviews]) {
        if (photoView.tag < kHPGalleryViewTagOffset) {
            continue;
        }
        
        if ([visibleIndices containsIndex:[self indexOfPhotoView:photoView]]) {
            continue;
        }
        
        [self removePhotoView:photoView];
    }
}

- (void)setHiddenViewsVisible:(BOOL)visible {
    NSIndexSet *visibleIndices = [self indicesOfPhotosInRect:self.bounds];
    
    for (UIView *photoView in [self subviews]) {
        if (photoView.tag < kHPGalleryViewTagOffset) {
            continue;
        }
        
        if ([self indexOfPhotoView:photoView] == _currentPhoto) {
            continue;
        }
        
        if (visible) {
            [photoView setHidden:!visible];
        } else {
            if ([visibleIndices containsIndex:[self indexOfPhotoView:photoView]]) {
                continue;
            }
            
            [photoView setHidden:!visible];
        }
    }
}

#pragma mark - Layout

- (void)refreshVisibleViews {
    for (UIView *photoView in [self subviews]) {
        if (photoView.tag < kHPGalleryViewTagOffset) {
            continue;
        }

        [photoView setFrame:[self frameForPhotoWithIndex:[self indexOfPhotoView:photoView]]];
    }
}

- (void)layoutSubviews {
    if (_zoomedPhoto != NSNotFound) {
        UIView *zoomView = [self photoViewWithIndex:_zoomedPhoto];
        
        for (UIView *photoView in [self subviews]) {
            if (photoView.tag < kHPGalleryViewTagOffset) {
                continue;
            }
            
            NSInteger viewIndex = [self indexOfPhotoView:photoView];

            if (viewIndex > _zoomedPhoto) {
                [photoView setFrame:CGRectMake(zoomView.frame.size.width + kHPGalleryPageOffset + ((viewIndex - _zoomedPhoto - 1) * self.bounds.size.width), 
                                               floorf((zoomView.frame.size.height - photoView.frame.size.height) / 2.0), 
                                               photoView.frame.size.width, photoView.frame.size.height)];
            } else {
                [photoView setFrame:CGRectMake((viewIndex - _zoomedPhoto) * self.bounds.size.width, 
                                               floorf((zoomView.frame.size.height - photoView.frame.size.height) / 2.0), 
                                               photoView.frame.size.width, photoView.frame.size.height)];
            }
        }
        
        return;
    }

    _currentPhoto = MIN(MAX(floorf(self.contentOffset.x / self.bounds.size.width), 0), _totalPhotos - 1);

	CGRect visibleBounds = CGRectInset(self.bounds, -kHPGalleryPageOffset * 2.0, 0.0);
	NSIndexSet *visibleIndices = [self indicesOfPhotosInRect:visibleBounds];

    if ([visibleIndices isEqualToIndexSet:_visibleIndices]) {
        return;
    }

	NSMutableIndexSet *oldIndices = [[self indicesOfPhotosInRect:_visibleBounds] mutableCopy];
	NSUInteger index = [oldIndices firstIndex];
    
	while (index != NSNotFound) {
		if (![visibleIndices containsIndex:index]) {
            [self removePhotoView:[self photoViewWithIndex:index]];
		}
		
		index = [oldIndices indexGreaterThanIndex:index];
	}
    
    NSMutableIndexSet *visibleMutableIndices = [visibleIndices mutableCopy];
    
	[visibleMutableIndices removeIndexes:oldIndices];
	
	index = [visibleMutableIndices firstIndex];
	
	while (index != NSNotFound) {
		UIView *photoView = [_dataSource galleryView:self viewForPhotoWithIndex:index];
		
		[photoView setTag:(index + kHPGalleryViewTagOffset)];
		[photoView setFrame:[self frameForPhotoWithIndex:index]];
        
		[self addSubview:photoView];
		
		index = [visibleMutableIndices indexGreaterThanIndex:index];
	}
    
    [_visibleIndices release], _visibleIndices = nil;
    
	_visibleBounds = visibleBounds;
    _visibleIndices = [visibleIndices copy];
    
    [visibleMutableIndices release];
    [oldIndices release];
}

- (void)reloadData {
    [_visibleIndices release], _visibleIndices = nil;
    [_reusableViews release], _reusableViews = nil;
    
	_visibleBounds = CGRectZero;
    _visibleIndices = [[NSIndexSet alloc] init];
    _reusableViews = [[NSMutableSet alloc] init];
    
	for (UIView *photoView in [self subviews]) {
        [photoView removeFromSuperview];
	}
	
	[self refreshLayout];
	[self setNeedsLayout];
}

- (void)reloadAdjacentViews {
    [self removeHiddenViews];
    
    [_visibleIndices release], _visibleIndices = nil;
    
    _visibleBounds = self.bounds;
    _visibleIndices = [[self indicesOfPhotosInRect:_visibleBounds] copy];
    
    [self setNeedsLayout];
}

- (void)refreshLayout {
    if (_dataSource) {
        _totalPhotos = [_dataSource numberOfPhotosInGalleryView:self];
    } else {
        _totalPhotos = 0;
    }
    
    [self setContentSize:CGSizeMake((self.bounds.size.width * _totalPhotos), self.bounds.size.height)];
}

#pragma mark - Zooming

- (void)enterZoomMode {
    if (_zoomedPhoto != NSNotFound) {
        return;
    }

    _zoomedPhoto = _currentPhoto;
    
    [self bringSubviewToFront:[self photoViewWithIndex:_currentPhoto]];
    [self setPagingEnabled:NO];
    [self setDirectionalLockEnabled:NO];
    [self setNeedsLayout];
}

- (void)exitZoomModeWithPageSwitch:(BOOL)pageSwitch {
    if (_zoomedPhoto == NSNotFound) {
        return;
    }

    [self refreshLayout];
    [self refreshVisibleViews];
    
    if (pageSwitch) {
        [self setContentOffset:CGPointMake(_currentPhoto * self.bounds.size.width, 0.0) animated:NO];
    }

    [self setPagingEnabled:YES];
    [self setDirectionalLockEnabled:YES];
    
    _zoomedPhoto = NSNotFound;

    [self setNeedsLayout];
}

@end
