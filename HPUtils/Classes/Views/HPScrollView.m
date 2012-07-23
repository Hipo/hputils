//
//  HPScrollView.m
//  HPUtils
//
//  Created by Taylan Pince on 11-04-17.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPScrollView.h"


static NSInteger const kHPScrollViewTagOffset = 1;


@interface HPScrollView (PrivateMethods)
- (void)removePage:(UIView *)page withIndex:(NSInteger)pageIndex;
- (CGRect)frameForCellAtIndex:(NSInteger)index;
- (NSIndexSet *)indicesOfCellsInRect:(CGRect)rect;
@end


@implementation HPScrollView

@dynamic delegate;
@synthesize dataSource;
@synthesize renderEdgeInsets = _renderEdgeInsets;
@synthesize identifier = _identifier;
@synthesize headerView = _headerView;
@synthesize footerView = _footerView;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
		[self setScrollsToTop:NO];
        [self setPagingEnabled:YES];
        [self setAutoresizesSubviews:NO];
        [self setDirectionalLockEnabled:YES];
        [self setAutoresizingMask:UIViewAutoresizingNone];
		
        _horizontalPageIndex = 0;
        _renderEdgeInsets = UIEdgeInsetsZero;
        _currentIndices = [[NSIndexSet alloc] init];
        _reusablePages = [[NSMutableSet alloc] init];
		_cellContainer = [[UIView alloc] initWithFrame:CGRectZero];
		
        [_cellContainer setAutoresizesSubviews:NO];
		[_cellContainer setBackgroundColor:self.backgroundColor];
		
		[self addSubview:_cellContainer];
    }
    
    return self;
}

- (void)setBackgroundColor:(UIColor *)newBackgroundColor {
	[super setBackgroundColor:newBackgroundColor];
	
	[_cellContainer setBackgroundColor:self.backgroundColor];
}

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
    
	if (!CGSizeEqualToSize(frame.size, self.contentSize) && 
        !CGRectEqualToRect(frame, CGRectZero) && dataSource != nil) {
		[self refreshCellLayout];
		[self setNeedsLayout];
	}
}

- (void)setDataSource:(id <HPScrollViewDataSource>)newDataSource {
    if (dataSource != newDataSource) {
        dataSource = newDataSource;
        
        if (!CGRectEqualToRect(self.bounds, CGRectZero)) {
            [self reloadData];
            [self setNeedsLayout];
        }
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    
    if (self.pagingEnabled) {
        _horizontalPageIndex = floorf(self.contentOffset.x / self.bounds.size.width);
    }
}

- (UIView *)dequeueReusablePage {
    UIView *page = [_reusablePages anyObject];
	
    if (page != nil) {
        [[page retain] autorelease];
        
        [_reusablePages removeObject:page];
    }
    
	return page;
}

- (void)removePage:(UIView *)page withIndex:(NSInteger)pageIndex {
    if ([page respondsToSelector:@selector(prepareForReuse)]) {
        [page performSelector:@selector(prepareForReuse)];
    }
    
    [_reusablePages addObject:page];
    
    [page removeFromSuperview];
    
    if ([self.delegate respondsToSelector:@selector(scrollView:didRemovePageWithIndex:)]) {
        [self.delegate scrollView:self didRemovePageWithIndex:pageIndex];
    }
}

- (void)removeHiddenCells {
    CGRect visibleBounds = self.bounds;
	NSIndexSet *visibleIndices = [self indicesOfCellsInRect:visibleBounds];
    
    for (UIView *cell in [_cellContainer subviews]) {
        if (![visibleIndices containsIndex:(cell.tag - kHPScrollViewTagOffset)]) {
            [_reusablePages addObject:cell];
            
            [cell removeFromSuperview];
            
            if ([self.delegate respondsToSelector:@selector(scrollView:didRemoveCell:withIndex:)]) {
                [self.delegate scrollView:self didRemovePageWithIndex:(cell.tag - kHPScrollViewTagOffset)];
            }
        }
    }
}

- (void)refreshVisibleCells {
    for (UIView *cell in [_cellContainer subviews]) {
        [cell setFrame:[dataSource scrollView:self frameForPageWithIndex:(cell.tag - kHPScrollViewTagOffset)]];
    }
}

- (void)layoutSubviews {
	CGRect visibleBounds = UIEdgeInsetsInsetRect(self.bounds, _renderEdgeInsets);
	NSIndexSet *visibleIndices = [self indicesOfCellsInRect:visibleBounds];
    
    if ([visibleIndices isEqualToIndexSet:_currentIndices]) {
        return;
    }
    
	NSMutableIndexSet *oldIndices = [[[self indicesOfCellsInRect:_visibleBounds] mutableCopy] autorelease];
    
    if (_insertedIndices != nil) {
        [oldIndices removeIndexes:_insertedIndices];
        
        [_insertedIndices release], _insertedIndices = nil;
    }
    
	NSUInteger index = [oldIndices firstIndex];
    
	while (index != NSNotFound) {
		if (![visibleIndices containsIndex:index]) {
            for (UIView *subview in [_cellContainer subviews]) {
                if (subview.tag == (index + kHPScrollViewTagOffset)) {
                    [self removePage:subview withIndex:index];
                    
                    break;
                }
            }
		}
		
		index = [oldIndices indexGreaterThanIndex:index];
	}
    
    NSMutableIndexSet *visibleMutableIndices = [[visibleIndices mutableCopy] autorelease];
    
	[visibleMutableIndices removeIndexes:oldIndices];
	
	index = [visibleMutableIndices firstIndex];
	
	while (index != NSNotFound) {
		UIView *cell = [dataSource scrollView:self viewForPageWithIndex:index];
		
		[cell setTag:(index + kHPScrollViewTagOffset)];
		[cell setFrame:[self frameForCellAtIndex:index]];
        
		[_cellContainer addSubview:cell];
		
		index = [visibleMutableIndices indexGreaterThanIndex:index];
	}
    
    if (self.pagingEnabled) {
        _horizontalPageIndex = floorf(self.contentOffset.x / self.bounds.size.width);
    }
    
    [_currentIndices release], _currentIndices = nil;
    
	_visibleBounds = visibleBounds;
    _currentIndices = [visibleIndices copy];
}

- (void)reloadData {
    [_currentIndices release], _currentIndices = nil;
    [_reusablePages release], _reusablePages = nil;
    
	_visibleBounds = CGRectZero;
    _currentIndices = [[NSIndexSet alloc] init];
    _reusablePages = [[NSMutableSet alloc] init];
    
	for (UIView *subview in [_cellContainer subviews]) {
        if (subview == _headerView || subview == _footerView) {
            continue;
        }
        
        [subview removeFromSuperview];
	}
	
	[self refreshCellLayout];
    
    if (_horizontalPageIndex > 0) {
        [self setContentOffset:CGPointMake(_horizontalPageIndex * self.bounds.size.width, 0.0) animated:NO];
    } else {
        [self setContentOffset:CGPointZero animated:NO];
    }
    
	[self setNeedsLayout];
}

- (void)resetData {
    [_currentIndices release], _currentIndices = nil;
    [_reusablePages release], _reusablePages = nil;
    
	_visibleBounds = CGRectZero;
    _currentIndices = [[NSIndexSet alloc] init];
    _reusablePages = [[NSMutableSet alloc] init];
    
	for (UIView *subview in [_cellContainer subviews]) {
        [subview removeFromSuperview];
	}
}

- (void)refreshCellLayout {
	CGRect contentRect = CGRectZero;
	
    if (dataSource) {
        _totalCells = [dataSource numberOfPagesInScrollView:self];
    } else {
        _totalCells = 0;
    }
    
	_cellRects = NSZoneRealloc(NULL, _cellRects, _totalCells * sizeof(*_cellRects));
    
    if (_headerView != nil) {
        CGRect headerViewFrame = CGRectMake(0.0, 0.0, _headerView.frame.size.width, 
                                            _headerView.frame.size.height);
        
        contentRect = CGRectUnion(contentRect, headerViewFrame);
        
        [_headerView setFrame:headerViewFrame];
    }
	
	for (NSInteger i = 0; i < _totalCells; i++) {
		CGRect cellRect = [dataSource scrollView:self frameForPageWithIndex:i];
        
        if (_headerView != nil) {
            cellRect.origin.y += _headerView.frame.size.height;
        }
		
		contentRect = CGRectUnion(contentRect, cellRect);
		
		_cellRects[i] = cellRect;
	}
    
    if (_footerView != nil) {
        CGRect footerViewFrame = CGRectMake(0.0, contentRect.size.height, 
                                            _footerView.frame.size.width, 
                                            _footerView.frame.size.height);
        
        contentRect = CGRectUnion(contentRect, footerViewFrame);
        
        [_footerView setFrame:footerViewFrame];
    }
	
	[self setContentSize:contentRect.size];
    
	[_cellContainer setFrame:CGRectMake(0.0, 0.0, self.contentSize.width, self.contentSize.height)];
}

- (void)insertCells:(NSInteger)cellCount {
    if (cellCount <= 0) {
        return;
    }
    
    if (_insertedIndices != nil) {
        [_insertedIndices release], _insertedIndices = nil;
    }
    
    _insertedIndices = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(_totalCells, cellCount)];
    
    [self refreshCellLayout];
    [self setNeedsLayout];
}

- (NSIndexSet *)indicesOfCellsInRect:(CGRect)rect {
	if (CGRectIsEmpty(rect)) {
		return [NSIndexSet indexSet];
	}
	
	NSMutableIndexSet *indexSet = [[[NSMutableIndexSet alloc] init] autorelease];
	NSUInteger firstIndex = NSNotFound;
	
	for (NSInteger i = 0; i < _totalCells; i++) {
		if (CGRectIntersectsRect(rect, _cellRects[i])) {
			if (firstIndex == NSNotFound) {
				firstIndex = i;
			}
		} else if (firstIndex != NSNotFound) {
			[indexSet addIndexesInRange:NSMakeRange(firstIndex, i - firstIndex)];
			
			firstIndex = NSNotFound;
		}
	}
	
	if (firstIndex != NSNotFound) {
		[indexSet addIndexesInRange:NSMakeRange(firstIndex, _totalCells - firstIndex)];
	}
	
	return indexSet;
}

- (CGRect)frameForCellAtIndex:(NSInteger)index {
    if (index < 0 || index >= _totalCells) {
		return CGRectZero;
	}
    
    return _cellRects[index];
}

- (NSInteger)indexOfCellView:(UIView *)cellView {
    return (cellView.tag - kHPScrollViewTagOffset);
}

- (UIView *)cellViewWithIndex:(NSInteger)cellIndex {
    return [_cellContainer viewWithTag:(cellIndex + kHPScrollViewTagOffset)];
}

#pragma mark - Header and Footer

- (void)setHeaderView:(UIView *)headerView {
    if (_headerView != nil) {
        [_headerView removeFromSuperview];
        
        [_headerView release], _headerView = nil;
    }
    
    if (headerView != nil) {
        _headerView = [headerView retain];
        
        [_cellContainer addSubview:_headerView];
    }
    
    [self refreshCellLayout];
}

- (void)setFooterView:(UIView *)footerView {
    if (_footerView != nil) {
        [_footerView removeFromSuperview];
        
        [_footerView release], _footerView = nil;
    }
    
    if (footerView != nil) {
        _footerView = [footerView retain];
        
        [_cellContainer addSubview:_footerView];
    }
    
    [self refreshCellLayout];
}

#pragma mark - Memory management

- (void)dealloc {
	if (_cellRects != NULL) {
		NSZoneFree(NULL, _cellRects);
	}
    
    [_reusablePages release], _reusablePages = nil;
	[_currentIndices release], _currentIndices = nil;
	[_cellContainer release], _cellContainer = nil;
    [_insertedIndices release], _insertedIndices = nil;
    [_headerView release], _headerView = nil;
    [_footerView release], _footerView = nil;
	
    [super dealloc];
}

@end
