//
//  DTGridView.h
//  GridViewTester
//
//  Created by Daniel Tull on 05.12.2008.
//  Copyright 2008 Daniel Tull. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DTGridViewCell.h"

/*!
 @enum DTGridViewScrollPosition
 @abstract Used to determine how to position a grid view cell on screen when scrolling to it.
 @constant DTGridViewScrollPositionNone Aligns the cell such that the shortest distance to display as much of the cell is used.
 @constant DTGridViewScrollPositionTopLeft Aligns the cell so that it is in the top left of the grid view.
 @constant DTGridViewScrollPositionTopCenter Aligns the cell so that it is in the top center of the grid view.
 @constant DTGridViewScrollPositionTopRight Aligns the cell so that it is in the top right of the grid view.
 @constant DTGridViewScrollPositionMiddleLeft Aligns the cell so that it is in the middle left of the grid view.
 @constant DTGridViewScrollPositionMiddleCenter Aligns the cell so that it is in the middle center of the grid view.
 @constant DTGridViewScrollPositionMiddleRight Aligns the cell so that it is in the middle right of the grid view.
 @constant DTGridViewScrollPositionBottomLeft Aligns the cell so that it is in the bottom left of the grid view.
 @constant DTGridViewScrollPositionBottomCenter Aligns the cell so that it is in the bottom center of the grid view.
 @constant DTGridViewScrollPositionBottomRight Aligns the cell so that it is in the bottom right of the grid view.
 @discussion In most cases you will want to use DTGridViewScrollPositionNone to just bring the cell to the screen using the quickest route. In the case where the cell is too big to display completely on screen, the position will still be used, in that the center aligned cells will have their middle in the center of the screen, with their edges outside the screen bounds equally as much.
*/
typedef enum {
	DTGridViewScrollPositionNone = 0,
	DTGridViewScrollPositionTopLeft,
	DTGridViewScrollPositionTopCenter,
	DTGridViewScrollPositionTopRight,
	DTGridViewScrollPositionMiddleLeft,
	DTGridViewScrollPositionMiddleCenter,
	DTGridViewScrollPositionMiddleRight,
	DTGridViewScrollPositionBottomLeft,
	DTGridViewScrollPositionBottomCenter,
	DTGridViewScrollPositionBottomRight
} DTGridViewScrollPosition;

/*!
 @enum DTGridViewEdge
 @abstract Categorizes beverages into groups of similar types.
 @constant DTGridViewEdgeTop Sweet, carbonated, non-alcoholic beverages.
 @constant DTGridViewEdgeBottom Sweet, carbonated, non-alcoholic beverages.
 @constant DTGridViewEdgeLeft Sweet, carbonated, non-alcoholic beverages.
 @constant DTGridViewEdgeRight Sweet, carbonated, non-alcoholic beverages.
 @discussion Extended discussion goes here.
 Lorem ipsum....
*/
typedef enum {
	DTGridViewEdgeTop,
	DTGridViewEdgeBottom,
	DTGridViewEdgeLeft,
	DTGridViewEdgeRight
} DTGridViewEdge;

struct DTOutset {
	CGFloat top;
	CGFloat bottom;
	CGFloat left;
	CGFloat right;
};

struct DTRect {
    NSInteger left;
    NSInteger top;
    NSInteger right;
    NSInteger bottom;
};
typedef struct DTRect DTRect;

@class DTGridView;

@protocol DTGridViewDelegate <UIScrollViewDelegate>

@optional
/*!
 Called when the grid view loads.
 */
- (void)gridViewDidLoad:(DTGridView *)gridView;
- (void)gridView:(DTGridView *)gridView selectionMadeAtRow:(NSInteger)rowIndex column:(NSInteger)columnIndex;
- (void)gridView:(DTGridView *)gridView scrolledToEdge:(DTGridViewEdge)edge;
- (void)pagedGridView:(DTGridView *)gridView didScrollToRow:(NSInteger)rowIndex column:(NSInteger)columnIndex;
- (void)gridView:(DTGridView *)gridView didProgrammaticallyScrollToRow:(NSInteger)rowIndex column:(NSInteger)columnIndex;
@end

#pragma mark -

@protocol DTGridViewDataSource
/*!
 Asks the data source to return the number of rows in the grid view.
 The grid view object requesting this information.
 @return The number of rows in the grid view.
 */
- (NSInteger)numberOfRowsInGridView:(DTGridView *)gridView;
/*!
 @abstract Asks the data source to return the number of columns for the given row in the grid view.
 @para The grid view object requesting this information.
 @para The index of the given row.
 @return The number of colums in the row of the grid view.
 */
- (NSInteger)numberOfColumnsInGridView:(DTGridView *)gridView forRowWithIndex:(NSInteger)index;
- (CGFloat)gridView:(DTGridView *)gridView heightForRow:(NSInteger)rowIndex;
- (CGFloat)gridView:(DTGridView *)gridView widthForCellAtRow:(NSInteger)rowIndex column:(NSInteger)columnIndex;
- (DTGridViewCell *)gridView:(DTGridView *)gridView viewForRow:(NSInteger)rowIndex column:(NSInteger)columnIndex;

@optional
- (NSInteger)spacingBetweenRowsInGridView:(DTGridView *)gridView;
- (NSInteger)spacingBetweenColumnsInGridView:(DTGridView *)gridView;
- (BOOL)heightForRowsIsConstant;
- (BOOL)widthForColumnsIsConstant;
- (BOOL)columnsCountIsConstant;

@end

#pragma mark -

/*!
 @class DTGridView
 @abstract 
 @discussion 
*/
@interface DTGridView : UIScrollView <UIScrollViewDelegate, DTGridViewCellDelegate> {
	
	CGPoint cellOffset;
	
	UIEdgeInsets outset;
	
	NSMutableArray *gridCellsInfo;
	NSMutableArray *freeCells;
    
	
	CGPoint oldContentOffset;
	BOOL hasResized;
	
	BOOL hasLoadedData;
		
	NSInteger numberOfRows;
	
	NSUInteger rowIndexOfSelectedCell;
	NSUInteger columnIndexOfSelectedCell;
	
	NSTimer *decelerationTimer;
	NSTimer *draggingTimer;
    
    BOOL hasConstantRowHeight;
    BOOL hasConstantColumnWidth;
    BOOL hasConstantColumnCount;
    NSInteger defaultRowHeight;
    NSInteger defaultColumnWidth;
}

/*!
 @abstract The object that acts as the data source of the receiving grid view.
 @discussion The data source must adopt the DTGridViewDataSource protocol. The data source is not retained.
*/
@property (nonatomic, retain) IBOutlet NSObject<DTGridViewDataSource> *dataSource;

/*!
 @abstract The object that acts as the delegate of the receiving grid view.
 @discussion The delegate must adopt the DTGridViewDelegate protocol. The delegate is not retained.
*/
@property (nonatomic, assign) IBOutlet id<DTGridViewDelegate> delegate;
/*!
 @abstract The offset for each cell with respect to the cells above and to the right.
 @discussion The x and y values can be either positive or negative; Using negative will overlay the cells by that amount, the outcome of this can never be gauranteed what the ordering of cells will be though.
*/
@property (assign) CGPoint cellOffset;
@property (assign) UIEdgeInsets outset;
@property (nonatomic) NSInteger numberOfRows;

#pragma mark -
#pragma mark Subclass methods

// These methods can be overridden by subclasses. 
// They should never need to be called from outside classes.

- (void)didEndMoving;
- (void)didEndDragging;
- (void)didEndDecelerating;

- (CGFloat)findWidthForRow:(NSInteger)row column:(NSInteger)column;
- (NSInteger)findNumberOfRows;
- (NSInteger)findNumberOfColumnsForRow:(NSInteger)row;
- (CGFloat)findHeightForRow:(NSInteger)row;
- (DTGridViewCell *)findViewForRow:(NSInteger)row column:(NSInteger)column;
- (NSInteger)findSpacingBetweenRows;
- (NSInteger)findSpacingBetweenColumns;

#pragma mark -
#pragma mark Regular methods
/*!
 @abstract Returns a reusable grid view cell object located by its identifier.
 @param identifier A string identifying the cell object to be reused.
 @discussion For performance reasons, grid views should always reuse their cells. This works like the table view's reuse policy.
*/
- (DTGridViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;

/*!
 @abstract Returns a grid view cell object located by its row and column positions.
 @param rowIndex The index of the row of the wanted cell.
 @param columnIndex The index of the column of the wanted cell.
 @return The grid view cell of the grid or nil if the cell is not visible or the indexes is out of range.
 */
- (DTGridViewCell *)cellForRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex;

/*!
 @abstract A constant that identifies a relative position in the receiving table view (top, middle, bottom) for row when scrolling concludes. See “Table View Scroll Position” a descriptions of valid constants.
 @param rowIndex The index of the row to scroll to.
 @param columnIndex The index of the column to scroll to.
 @param position The position the cell should be in once scrolled to.
 @param animated If this 
*/
- (void)scrollViewToRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex scrollPosition:(DTGridViewScrollPosition)position animated:(BOOL)animated;

- (void)selectRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex scrollPosition:(DTGridViewScrollPosition)position animated:(BOOL)animated;

/*!
 @abstract This method should be used by subclasses to know when the grid did appear on screen.
*/
- (void)didLoad;

/*!
 @abstract Call this to reload the grid view's data.
*/
- (void)reloadData;

/*!
 @abstact Internally called to load cells in sight. And unload cells out of view
*/
- (void)loadCells;

/*
 @abstract Internally called to determine range of visible cells. Can be called only for constant row heights and column widths
*/
DTRect DTRectMake( NSInteger left, NSInteger top, NSInteger right, NSInteger bottom );

- (CGRect)visibleRect;
- (DTRect)getVisibleCellsRect;
- (BOOL)isOutOfView: (DTGridViewCell*)v Rect:(CGRect)visibleRect;

/* UIScrollview delegate override */

- (void)scrollViewDidScroll:(UIScrollView *)scrollView;                                               // any offset changes
- (void)scrollViewDidZoom:(UIScrollView *)scrollView __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_2); // any zoom scale changes

// called on start of dragging (may require some time and or distance to move)
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView;
// called on finger up if the user dragged. velocity is in points/second. targetContentOffset may be changed to adjust where the scroll view comes to rest. not called when pagingEnabled is YES
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_5_0);
// called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView;   // called on finger up as we are moving
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;      // called when scroll view grinds to a halt

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView; // called when setContentOffset/scrollRectVisible:animated: finishes. not called if not animating

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView;     // return a view that will be scaled. if delegate returns nil, nothing happens
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_2); // called before the scroll view begins zooming its content
- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale; // scale between minimum and maximum. called after any 'bounce' animations

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView;   // return a yes if you want to scroll to the top. if not defined, assumes YES
- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView;      // called when scrolling animation finished. may be called immediately if already at top

@end
