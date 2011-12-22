//
//  HPScrollView.h
//  HPUtils
//
//  Created by Taylan Pince on 11-04-17.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//


@class HPScrollView;


@protocol HPScrollViewDelegate <UIScrollViewDelegate>
@optional
- (void)scrollView:(HPScrollView *)scrollView didRemovePageWithIndex:(NSInteger)pageIndex;
@end


@protocol HPScrollViewDataSource <NSObject>
@required
- (NSInteger)numberOfPagesInScrollView:(HPScrollView *)scrollView;
- (UIView *)scrollView:(HPScrollView *)scrollView viewForPageWithIndex:(NSInteger)pageIndex;
- (CGRect)scrollView:(HPScrollView *)scrollView frameForPageWithIndex:(NSInteger)pageIndex;
@end


@interface HPScrollView : UIScrollView {
@private
	CGRect *_cellRects;
	NSInteger _totalCells;
	CGRect _visibleBounds;
	UIView *_cellContainer;
    NSIndexSet *_currentIndices;
    NSIndexSet *_insertedIndices;
    NSInteger _horizontalPageIndex;
    UIEdgeInsets _renderEdgeInsets;
    NSMutableSet *_reusablePages;
    NSInteger _identifier;
    
    id <HPScrollViewDataSource> dataSource;
}

@property (nonatomic, assign) UIEdgeInsets renderEdgeInsets;
@property (nonatomic, assign) NSInteger identifier;

@property (nonatomic, assign) id <HPScrollViewDelegate> delegate;
@property (nonatomic, assign) id <HPScrollViewDataSource> dataSource;

- (void)resetData;
- (void)reloadData;
- (void)removeHiddenCells;
- (void)refreshCellLayout;
- (void)refreshVisibleCells;
- (void)insertCells:(NSInteger)cellCount;

- (UIView *)dequeueReusablePage;
- (NSInteger)indexOfCellView:(UIView *)cellView;
- (UIView *)cellViewWithIndex:(NSInteger)cellIndex;

@end
