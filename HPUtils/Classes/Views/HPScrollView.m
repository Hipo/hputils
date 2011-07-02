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
- (void)refreshCellLayout;
- (void)removePage:(UIView *)page withIndex:(NSInteger)pageIndex;
- (CGRect)frameForCellAtIndex:(NSInteger)index;
- (NSIndexSet *)indicesOfCellsInRect:(CGRect)rect;
@end


@implementation HPScrollView

@dynamic delegate;
@synthesize dataSource;
@synthesize renderEdgeInsets = _renderEdgeInsets;

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
		[self reloadData];
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

- (void)layoutSubviews {
	CGRect visibleBounds = UIEdgeInsetsInsetRect(self.bounds, _renderEdgeInsets);
	NSIndexSet *visibleIndices = [self indicesOfCellsInRect:visibleBounds];
    
    if ([visibleIndices isEqualToIndexSet:_currentIndices]) {
        return;
    }
    
	NSIndexSet *oldIndices = [self indicesOfCellsInRect:_visibleBounds];
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

- (void)refreshCellLayout {
	CGRect contentRect = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height);
	
    if (dataSource) {
        _totalCells = [dataSource numberOfPagesInScrollView:self];
    } else {
        _totalCells = 0;
    }
    
	_cellRects = NSZoneRealloc(NULL, _cellRects, _totalCells * sizeof(*_cellRects));
	
	for (NSInteger i = 0; i < _totalCells; i++) {
		CGRect cellRect = [dataSource scrollView:self frameForPageWithIndex:i];
		
		contentRect = CGRectUnion(contentRect, cellRect);
		
		_cellRects[i] = cellRect;
	}
	
	[self setContentSize:contentRect.size];
    
	[_cellContainer setFrame:CGRectMake(0.0, 0.0, self.contentSize.width, self.contentSize.height)];
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

- (void)dealloc {
	if (_cellRects != NULL) {
		NSZoneFree(NULL, _cellRects);
	}
    
    [_reusablePages release], _reusablePages = nil;
	[_currentIndices release], _currentIndices = nil;
	[_cellContainer release], _cellContainer = nil;
	
    [super dealloc];
}

@end
