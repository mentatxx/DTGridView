//
//  DTGridView.m
//  GridViewTester
//
//  Created by Daniel Tull on 05.12.2008.
//  Copyright 2008 Daniel Tull. All rights reserved.
//

#import "DTGridView.h"
#import "DTGridViewCellInfoProtocol.h"

NSInteger const DTGridViewInvalid = -1;


@interface DTGridViewCellInfo : NSObject <DTGridViewCellInfoProtocol> {
    // x,y positions of cell
	NSUInteger xPosition, yPosition;
    // view bounds
	CGRect frame;
}
@end

@implementation DTGridViewCellInfo
@synthesize xPosition, yPosition, frame;
- (NSString *)description {
	return [NSString stringWithFormat:@"DTGridViewCellInfo: frame=(%i %i; %i %i) x=%i, y=%i", (NSInteger)self.frame.origin.x, (NSInteger)self.frame.origin.y, (NSInteger)self.frame.size.width, (NSInteger)self.frame.size.height, self.xPosition, self.yPosition];
}
@end

@interface DTGridView ()
{
    NSArray* columnWidths;
}
- (void)dctInternal_setupInternals;
- (void)loadData;
- (void)fireEdgeScroll;
- (void)decelerationTimer:(NSTimer *)timer;
- (void)draggingTimer:(NSTimer *)timer;
- (CGFloat)findOffsetXforColumn: (NSInteger) column;

@property (nonatomic, strong) NSTimer *decelerationTimer, *draggingTimer;
@end



@implementation DTGridView

@synthesize delegate;
@synthesize dataSource, numberOfRows, cellOffset, outset;
@synthesize decelerationTimer, draggingTimer;

- (void)dealloc {
	super.delegate = nil;
	self.dataSource = nil;
    
	freeCells = nil;
    gridCellsInfo = nil;
    columnWidths = nil;
}

- (id)initWithFrame:(CGRect)frame {
	
	if (!(self = [super initWithFrame:frame])) return nil;

	[self dctInternal_setupInternals];
	
	return self;
	
}

- (void)awakeFromNib {
	[self dctInternal_setupInternals];
}

- (void)dctInternal_setupInternals {
    [super setDelegate: self];
	numberOfRows = DTGridViewInvalid;
	columnIndexOfSelectedCell = DTGridViewInvalid;
	rowIndexOfSelectedCell = DTGridViewInvalid;
    hasConstantColumnWidth = NO;
    hasConstantRowHeight = NO;
    defaultColumnWidth = DTGridViewInvalid;
    defaultRowHeight = DTGridViewInvalid;
	
	gridCellsInfo = [[NSMutableArray alloc] init];
	freeCells = [[NSMutableArray alloc] init];
}

- (void)setFrame:(CGRect)aFrame {
	
	CGSize oldSize = self.frame.size;
	CGSize newSize = aFrame.size;
	
	if (oldSize.height != newSize.height || oldSize.width != newSize.width) {
		hasResized = YES;
	}
	
	[super setFrame:aFrame];
	
	if (hasResized)  {
		[self setNeedsLayout];
	}
}

- (void)reloadData {
    [self removeAllCells];
	[self loadData];
    [self loadCells];
	[self setNeedsLayout];
	[self setNeedsDisplay];
}

-(void) removeAllCells {
    // completely remove cells, put them to freeCells pool
    for (UIView *v in self.subviews)
        if ([v isKindOfClass:[DTGridViewCell class]]) [self removeCellToPool:(DTGridViewCell *)v];
    // and finally clean pool
    [freeCells removeAllObjects];
}

- (void)drawRect:(CGRect)rect {
	[self didLoad];
}

- (void)didLoad {
	if ([self.delegate respondsToSelector:@selector(gridViewDidLoad:)])
		[self.delegate gridViewDidLoad:self];
}

- (void)loadCells
{
    // add visible cells
    // new style - add by rect
    DTRect vRect = [self getVisibleCellsRect];
    // get spacings
    CGFloat spacingRows = [self findSpacingBetweenRows];
    CGFloat spacingColumns = [self findSpacingBetweenColumns];
    // check and visible cells
    for (NSInteger y = vRect.top; y <= vRect.bottom; y++)
    {
        NSInteger columnsInRow = [self findNumberOfColumnsForRow:y];
        if ( (y>=0)&&(y<numberOfRows) ) {
            for (NSInteger x = vRect.left; (x<= vRect.right) && (x<columnsInRow); x++) 
            {
                // check if hasnt this cell, then add cell
                if ( (x>=0) && (x<[self findNumberOfColumnsForRow:y]) && ![self cellForRow:y column:x]) {
                    DTGridViewCell* newCell = [[self dataSource] gridView:self viewForRow:y column:x];
                    // set geo for cell
                    CGFloat offsetX, offsetY, sizeX, sizeY;
                    if (hasConstantColumnWidth) {
                        offsetX = x*(defaultColumnWidth+spacingColumns);
                        offsetY = y*(defaultRowHeight+spacingRows);
                        sizeX = defaultColumnWidth;
                        sizeY = defaultRowHeight;
                    } else {
                        offsetX = [self findOffsetXforColumn:x];
                        offsetY = y*(defaultRowHeight+spacingRows);
                        sizeX = [[columnWidths objectAtIndex:x] floatValue];
                        sizeY = defaultRowHeight;
                    }
                    CGRect bounds = CGRectMake(offsetX, offsetY, sizeX, sizeY);
                    [newCell setFrame:bounds];
                    newCell.xPosition = x;
                    newCell.yPosition = y;
                    newCell.frame = bounds;
                    // add as subview
                    [self insertSubview:newCell atIndex:0];
                }
            }
        }
    }
    //
    if (hasConstantColumnWidth && hasConstantRowHeight) 
    {

        // put invisible cells to freeCells pool
        for (UIView *v in self.subviews)
            if ([v isKindOfClass:[DTGridViewCell class]])
            {
                int x = [(DTGridViewCell*)v xPosition];
                int y = [(DTGridViewCell*)v yPosition];
                if ( (x<vRect.left) || (x>vRect.right) || (y<vRect.top) || (y>vRect.bottom) ) [self removeCellToPool:(DTGridViewCell*)v];
            }
        
    } else
    { 
        // old-style - see in cells info
        CGRect visibleRect = [self visibleRect];
        // put invisible cells to freeCells pool
        for (UIView *v in self.subviews)
            if ([v isKindOfClass:[DTGridViewCell class]])
            {
                if ([self isOutOfView:(DTGridViewCell*)v Rect:visibleRect ]) [self removeCellToPool:(DTGridViewCell*)v];
            };
        
    };
}

- (void)didEndDragging {}
- (void)didEndDecelerating {}
- (void)didEndMoving {}

- (void)layoutSubviews {
	[self loadCells];
	[super layoutSubviews];
	[self fireEdgeScroll];
	
	if (!self.draggingTimer && !self.decelerationTimer && self.dragging)
		self.draggingTimer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(draggingTimer:) userInfo:nil repeats:NO];		
	
	if (!self.decelerationTimer && self.decelerating) {
		self.decelerationTimer = [NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(decelerationTimer:) userInfo:nil repeats:NO];
		[self.draggingTimer invalidate];
		self.draggingTimer = nil;
	}
}

- (void)decelerationTimer:(NSTimer *)timer {
	self.decelerationTimer = nil;
	[self didEndDecelerating];
	[self didEndMoving];
}

- (void)draggingTimer:(NSTimer *)timer {
	self.draggingTimer = nil;
	[self didEndDragging];
	[self didEndMoving];
}

#pragma mark Adding and Removing Cells

- (CGRect)visibleRect {
    CGRect visibleRect;
    visibleRect.origin = self.contentOffset;
    visibleRect.size = self.bounds.size;
	return visibleRect;
}


#pragma mark -
#pragma mark Finding Infomation from DataSource

- (CGFloat)findWidthForRow:(NSInteger)row column:(NSInteger)column {
    if (hasConstantColumnWidth) {
        return defaultColumnWidth;
    } else {
        return [self.dataSource gridView:self widthForCellAtRow:row column:column];
    }
}

- (NSInteger)findNumberOfRows {
    return numberOfRows;
}

- (NSInteger)findNumberOfColumnsForRow:(NSInteger)row {
	return [self.dataSource numberOfColumnsInGridView:self forRowWithIndex:row];
}

- (CGFloat)findHeightForRow:(NSInteger)row {
    if (hasConstantRowHeight) {
        return defaultRowHeight;
    } else {
        return [self.dataSource gridView:self heightForRow:row];
    }
}

- (DTGridViewCell *)findViewForRow:(NSInteger)row column:(NSInteger)column {
	return [self.dataSource gridView:self viewForRow:row column:column];
}

- (NSInteger)findSpacingBetweenRows {
    if ([self.dataSource respondsToSelector:@selector(spacingBetweenRowsInGridView:)]) {
        return [self.dataSource spacingBetweenRowsInGridView:self];
    } else {
        return 0;
    }
}

- (NSInteger)findSpacingBetweenColumns {
    if ([self.dataSource respondsToSelector:@selector(spacingBetweenColumnsInGridView:)]) {
        return [self.dataSource spacingBetweenColumnsInGridView:self];
    } else {
        return 0;
    }
}


#pragma mark -

- (void)loadData {
	
	hasLoadedData = YES;
	
	if (![self.dataSource respondsToSelector:@selector(numberOfRowsInGridView:)])
		return;
	
	self.numberOfRows = [self.dataSource numberOfRowsInGridView:self];
	
	if (!self.numberOfRows)
		return;
	
    // cache geometry
    hasConstantRowHeight = [self.dataSource respondsToSelector:@selector(heightForRowsIsConstant)] ? [self.dataSource heightForRowsIsConstant] : NO;
    hasConstantColumnWidth = [self.dataSource respondsToSelector:@selector(widthForColumnsIsConstant)] ? [self.dataSource widthForColumnsIsConstant] : NO;
    hasConstantColumnCount = [self.dataSource respondsToSelector:@selector(columnsCountIsConstant)] ? [self.dataSource columnsCountIsConstant] : NO;
    
    if (hasConstantRowHeight) 
    {
        defaultRowHeight = [self.dataSource respondsToSelector:@selector(gridView:heightForRow:)] ? [self.dataSource gridView:self heightForRow:0] : DTGridViewInvalid;
    };
    if (hasConstantColumnWidth) 
    {
        defaultColumnWidth = [self.dataSource respondsToSelector:@selector(gridView:widthForCellAtRow:column:)] ? [self.dataSource gridView:self widthForCellAtRow:0 column:0] : DTGridViewInvalid;
        columnWidths = nil;
    } else
    {
        //
        NSInteger numberOfCols = [self findNumberOfColumnsForRow:0];
        NSMutableArray* widths = [[NSMutableArray alloc] initWithCapacity:numberOfCols];
        for (NSInteger i=0; i<numberOfCols; i++) {
            [widths addObject:[NSNumber numberWithFloat:[self findWidthForRow:0 column:i]]];
        };
        columnWidths = [NSArray arrayWithArray:widths];
        widths = nil;
    }
    
    //
    cellOffset.x = [self findSpacingBetweenColumns];
    cellOffset.y = [self findSpacingBetweenRows];
    
    if (hasConstantColumnWidth && hasConstantRowHeight) {
        CGFloat maxHeight = numberOfRows*(defaultRowHeight + cellOffset.y);
        CGFloat maxWidth = 0;
        if (!hasConstantColumnCount) {
            // variable column count for rows
            // it is really slow for huge tables
            for (NSInteger i=0; i<numberOfRows; i++)
                if (maxWidth < [self findNumberOfColumnsForRow:i]) {
                    maxWidth = [self findNumberOfColumnsForRow:i];
                };
            maxWidth = maxWidth * (defaultColumnWidth + cellOffset.x);
        } else {
            // constant column count for rows
            maxWidth = (defaultColumnWidth + cellOffset.x)*[self findNumberOfColumnsForRow:0];
        }
        self.contentSize = CGSizeMake(maxWidth, maxHeight);
        gridCellsInfo = nil;
    } else 
    {
        
        NSMutableArray *cellInfoArrayRows = [[NSMutableArray alloc] init];
        
        CGFloat maxHeight = 0;
        CGFloat maxWidth = 0;
        
        
        for (NSInteger i = 0; i < self.numberOfRows; i++) {
            
            NSInteger numberOfCols = [self findNumberOfColumnsForRow:i];
            
            NSMutableArray *cellInfoArrayCols = [[NSMutableArray alloc] init];
            
            CGFloat height = [self findHeightForRow:i];
            
            for (NSInteger j = 0; j < numberOfCols; j++) {
                DTGridViewCellInfo *info = [[DTGridViewCellInfo alloc] init];
                
                info.xPosition = j;
                info.yPosition = i;
                
                CGFloat y;
                CGFloat x;
                
                CGFloat width = [self findWidthForRow:i column:j];
                
                if (i == 0) {
                    y = 0.0f;
                } else {
                    DTGridViewCellInfo *previousCellRow = [[cellInfoArrayRows objectAtIndex:i-1] objectAtIndex:0];
                    y = previousCellRow.frame.origin.y + previousCellRow.frame.size.height;
                    
                    if (cellOffset.y != 0)
                        y += cellOffset.y;
                    previousCellRow = nil;
                }
                
                if (j == 0) {
                    x = 0.0f;
                } else {
                    DTGridViewCellInfo *previousCellRow = [cellInfoArrayCols objectAtIndex:j-1];
                    x = previousCellRow.frame.origin.x + previousCellRow.frame.size.width;
                    if (cellOffset.x != 0)
                        x += cellOffset.x;
                    previousCellRow = nil;
                }
                
                if (maxHeight < y + height)
                    maxHeight = y + height;
                
                if (maxWidth < x + width)
                    maxWidth = x + width;
                
                info.frame = CGRectMake(x,y,width,height);
                
                [cellInfoArrayCols addObject:info];
                
            }
            
            [cellInfoArrayRows addObject:cellInfoArrayCols];
        }
        
        
        self.contentSize = CGSizeMake(maxWidth, maxHeight);
        
        gridCellsInfo = cellInfoArrayRows;
    }
    
}

-(void)removeCellToPool:(DTGridViewCell *)cell
{
    // add to free cells pool
    [freeCells addObject:cell];
    // remove from superview
    [cell removeFromSuperview];
}


#pragma mark Public methods

- (DTGridViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier {
	
    DTGridViewCell* result = nil;
	for (DTGridViewCell *c in freeCells) {
		if ([c.identifier isEqualToString:identifier]) {
			[c prepareForReuse];
            result = c;
            break;
		}
	}
    if (result) [freeCells removeObject:result];
	return result;
}

- (DTGridViewCell *)cellForRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex {
	
	for (UIView *v in self.subviews) {
		if ([v isKindOfClass:[DTGridViewCell class]]) {
			DTGridViewCell *c = (DTGridViewCell *)v;
			if (c.xPosition == columnIndex && c.yPosition == rowIndex)
				return c;
		}
	}
	
	return nil;
}

- (void)scrollViewToRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex scrollPosition:(DTGridViewScrollPosition)position animated:(BOOL)animated {
	
	CGFloat xPos = 0, yPos = 0;
	
	CGRect cellFrame = [[[gridCellsInfo objectAtIndex:rowIndex] objectAtIndex:columnIndex] frame];		
	
	// working out x co-ord
	
	if (position == DTGridViewScrollPositionTopLeft || position == DTGridViewScrollPositionMiddleLeft || position == DTGridViewScrollPositionBottomLeft)
		xPos = cellFrame.origin.x;
	
	else if (position == DTGridViewScrollPositionTopRight || position == DTGridViewScrollPositionMiddleRight || position == DTGridViewScrollPositionBottomRight)
		xPos = cellFrame.origin.x + cellFrame.size.width - self.frame.size.width;
	
	else if (position == DTGridViewScrollPositionTopCenter || position == DTGridViewScrollPositionMiddleCenter || position == DTGridViewScrollPositionBottomCenter)
		xPos = (cellFrame.origin.x + (cellFrame.size.width / 2)) - (self.frame.size.width / 2);
	
	else if (position == DTGridViewScrollPositionNone) {
		
		BOOL isBig = NO;
		
		if (cellFrame.size.width > self.frame.size.width)
			isBig = YES;
		
		if ((cellFrame.origin.x < self.contentOffset.x)
		&& ((cellFrame.origin.x + cellFrame.size.width) > (self.contentOffset.x + self.frame.size.width)))
			xPos = self.contentOffset.x;
		
		else if (cellFrame.origin.x < self.contentOffset.x)
			if (isBig)
				xPos = (cellFrame.origin.x + cellFrame.size.width) - self.frame.size.width;
			else 
				xPos = cellFrame.origin.x;
		
			else if ((cellFrame.origin.x + cellFrame.size.width) > (self.contentOffset.x + self.frame.size.width))
				if (isBig)
					xPos = cellFrame.origin.x;
				else
					xPos = (cellFrame.origin.x + cellFrame.size.width) - self.frame.size.width;
				else
					xPos = self.contentOffset.x;
	}
	
	// working out y co-ord
	
	if (position == DTGridViewScrollPositionTopLeft || position == DTGridViewScrollPositionTopCenter || position == DTGridViewScrollPositionTopRight) {
		yPos = cellFrame.origin.y;
		
	} else if (position == DTGridViewScrollPositionBottomLeft || position == DTGridViewScrollPositionBottomCenter || position == DTGridViewScrollPositionBottomRight) {
		yPos = cellFrame.origin.y + cellFrame.size.height - self.frame.size.height;
		
	} else if (position == DTGridViewScrollPositionMiddleLeft || position == DTGridViewScrollPositionMiddleCenter || position == DTGridViewScrollPositionMiddleRight) {
		yPos = (cellFrame.origin.y + (cellFrame.size.height / 2)) - (self.frame.size.height / 2);
		
	} else if (position == DTGridViewScrollPositionNone) {
		BOOL isBig = NO;
		
		if (cellFrame.size.height > self.frame.size.height)
			isBig = YES;
		
		if ((cellFrame.origin.y < self.contentOffset.y)
		&& ((cellFrame.origin.y + cellFrame.size.height) > (self.contentOffset.y + self.frame.size.height)))
			yPos = self.contentOffset.y;
		
		else if (cellFrame.origin.y < self.contentOffset.y)
			if (isBig)
				yPos = (cellFrame.origin.y + cellFrame.size.height) - self.frame.size.height;
			else
				yPos = cellFrame.origin.y;
			else if ((cellFrame.origin.y + cellFrame.size.height) > (self.contentOffset.y + self.frame.size.height))
				if (isBig)
					yPos = cellFrame.origin.y;
				else
					yPos = (cellFrame.origin.y + cellFrame.size.height) - self.frame.size.height;
				else
					yPos = self.contentOffset.y;
	}
	
	if (xPos == self.contentOffset.x && yPos == self.contentOffset.y)
		return;
	
	if (xPos > self.contentSize.width - self.frame.size.width)
		xPos = self.contentSize.width - self.frame.size.width;
	else if (xPos < 0)
		xPos = 0.0f;
	
	if (yPos > self.contentSize.height - self.frame.size.height)
		yPos = self.contentSize.height - self.frame.size.height;
	else if (yPos < 0)
		yPos = 0.0f;	
	
	[self scrollRectToVisible:CGRectMake(xPos, yPos, self.frame.size.width, self.frame.size.height) animated:animated];
	
	if (!animated)
		[self loadCells];
	
	if ([self.delegate respondsToSelector:@selector(gridView:didProgrammaticallyScrollToRow:column:)])
		[self.delegate gridView:self didProgrammaticallyScrollToRow:rowIndex column:columnIndex];
		
	
}

- (void)selectRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex scrollPosition:(DTGridViewScrollPosition)position animated:(BOOL)animated {
	
	for (UIView *v in self.subviews) {
		if ([v isKindOfClass:[DTGridViewCell class]]) {
			DTGridViewCell *c = (DTGridViewCell *)v;
			if (c.xPosition == columnIndex && c.yPosition == rowIndex)
				c.selected = YES;
			else if (c.xPosition == columnIndexOfSelectedCell && c.yPosition == rowIndexOfSelectedCell)
				c.selected = NO;
		}
	}
	rowIndexOfSelectedCell = rowIndex;
	columnIndexOfSelectedCell = columnIndex;
	
	[self scrollViewToRow:rowIndex column:columnIndex scrollPosition:position animated:animated];
}

- (void)fireEdgeScroll {
	
	if (self.pagingEnabled)
		if ([self.delegate respondsToSelector:@selector(pagedGridView:didScrollToRow:column:)])
			[self.delegate pagedGridView:self didScrollToRow:((NSInteger)(self.contentOffset.y / self.frame.size.height)) column:((NSInteger)(self.contentOffset.x / self.frame.size.width))];
	
	if ([self.delegate respondsToSelector:@selector(gridView:scrolledToEdge:)]) {
		
		if (self.contentOffset.x <= 0)
			[self.delegate gridView:self scrolledToEdge:DTGridViewEdgeLeft];
		
		if (self.contentOffset.x >= self.contentSize.width - self.frame.size.width)
			[self.delegate gridView:self scrolledToEdge:DTGridViewEdgeRight];
		
		if (self.contentOffset.y <= 0)
			[self.delegate gridView:self scrolledToEdge:DTGridViewEdgeTop];
		
		if (self.contentOffset.y >= self.contentSize.height - self.frame.size.height)
			[self.delegate gridView:self scrolledToEdge:DTGridViewEdgeBottom];
	}
}

- (void)gridViewCellWasTouched:(DTGridViewCell *)cell {
	
	[self bringSubviewToFront:cell];
	
	if ([self.delegate respondsToSelector:@selector(gridView:selectionMadeAtRow:column:)])
		[self.delegate gridView:self selectionMadeAtRow:cell.yPosition column:cell.xPosition];
}


#pragma mark -
#pragma mark Accessors

- (NSInteger)numberOfRows {
	if (numberOfRows == DTGridViewInvalid) {
		numberOfRows = [self.dataSource numberOfRowsInGridView:self];
	}
	
	return numberOfRows;
}

#pragma mark -------------------------
#pragma mark Big grid internals

DTRect DTRectMake( NSInteger left, NSInteger top, NSInteger right, NSInteger bottom )
{
    DTRect result;
    result.left = left;
    result.top = top;
    result.right = right;
    result.bottom = bottom;
    return result;
}

-(DTRect)getVisibleCellsRect
{
    if (hasConstantRowHeight && hasConstantColumnWidth) {
        CGRect visibleRect = [self visibleRect];
        DTRect result = DTRectMake(0,0,0,0);
        result.left = visibleRect.origin.x / (defaultColumnWidth+[self findSpacingBetweenColumns]);
        result.top = visibleRect.origin.y / (defaultRowHeight+[self findSpacingBetweenRows]);
        result.right = (visibleRect.origin.x + visibleRect.size.width) / (defaultColumnWidth+[self findSpacingBetweenColumns])+1;
        result.bottom = (visibleRect.origin.y + visibleRect.size.height) / (defaultRowHeight+[self findSpacingBetweenRows])+1;
        return result;
    } else {
        // TODO: use quicksearch
        // get screen rect
        CGRect visibleRect = [self visibleRect];
        // find top
        NSInteger rTop = [gridCellsInfo count]-1;
        for (NSInteger i=0; i<[gridCellsInfo count]; i++) {
            DTGridViewCellInfo* cell = [[gridCellsInfo objectAtIndex:i] objectAtIndex:0];
            if (  cell.frame.origin.y+cell.frame.size.height >= visibleRect.origin.y ) { rTop = i-1; break; };
        }
        if (rTop<0) rTop=0;
        // find bottom
        NSInteger rBottom = 0;
        for (NSInteger i=[gridCellsInfo count]-1; i>=0; i--) {
            DTGridViewCellInfo* cell = [[gridCellsInfo objectAtIndex:i] objectAtIndex:0];
            if (  cell.frame.origin.y <= visibleRect.origin.y+visibleRect.size.height ) { rBottom = i+1; break; };
        }
        if (rBottom>=[gridCellsInfo count]) rBottom = [gridCellsInfo count]-1;
        // case "no data" - return rTop = 0, rBottom = -1
        if (rTop>rBottom) return DTRectMake(0, 0, -1, -1);
        
        // find left
        NSInteger rLeft = [self findNumberOfColumnsForRow:rTop]-1;
        NSInteger rRight = 0;
        for (NSInteger i=rTop; i<=rBottom; i++) {
            NSArray* row = [gridCellsInfo objectAtIndex:i];
            for (NSInteger j=0; j<[row count]; j++) {
                DTGridViewCellInfo* cell = [row objectAtIndex: j];
                if (cell.frame.origin.x + cell.frame.size.width >= visibleRect.origin.x ) { if (rLeft>j-1) { rLeft = j-1; }; break; };
            }
            for (NSInteger j=[row count]-1; j>=0; j--) {
                DTGridViewCellInfo* cell = [row objectAtIndex: j];
                if (cell.frame.origin.x <= visibleRect.origin.x+visibleRect.size.width) { if (rRight<j+1) { rRight = j+1; }; break; };
            }
        }
        if (rLeft<0) rLeft = 0;
        DTRect result = DTRectMake(rLeft, rTop, rRight, rBottom);
        return result;
    }
}

-(CGFloat)findOffsetXforColumn:(NSInteger)column
{
    CGFloat result = 0;
    CGFloat spacing = [self findSpacingBetweenColumns];
    for (NSInteger i=0; i<column; i++) {
        result = result + [[columnWidths objectAtIndex:i] floatValue] + spacing;
    }
    return result;
}

- (BOOL)isOutOfView: (DTGridViewCell*)v Rect:(CGRect)visibleRect
{
    return (v.frame.origin.x > visibleRect.origin.x + visibleRect.size.width) || (v.frame.origin.x + v.frame.size.width < visibleRect.origin.x ) ||
    (v.frame.origin.y > visibleRect.origin.y + visibleRect.size.height) || (v.frame.origin.y + v.frame.size.height < visibleRect.origin.y );
}

/* UIScrollView delegate override */

// any offset change
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self loadCells];
    if ([self.delegate respondsToSelector:@selector(scrollViewDidScroll:)]) {[self.delegate scrollViewDidScroll:scrollView]; };
}

// any zoom scale changes
- (void)scrollViewDidZoom:(UIScrollView *)scrollView __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_2)
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidZoom:)]) {[self.delegate scrollViewDidZoom:scrollView]; };
   
}

// called on start of dragging (may require some time and or distance to move)
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {[self.delegate scrollViewWillBeginDragging:scrollView]; };
}

// called on finger up if the user dragged. velocity is in points/second. targetContentOffset may be changed to adjust where the scroll view comes to rest. not called when pagingEnabled is YES
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_5_0)
{
    if ([self.delegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) 
    {
        [self.delegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset]; 
    };
}

// called on finger up if the user dragged. decelerate is true if it will continue moving afterwards
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {[self.delegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate]; };
}

// called on finger up as we are moving
- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) {[self.delegate scrollViewWillBeginDecelerating:scrollView]; };
}

// called when scroll view grinds to a halt
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {[self.delegate scrollViewDidEndDecelerating:scrollView]; };
}

// called when setContentOffset/scrollRectVisible:animated: finishes. not called if not animating
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {[self.delegate scrollViewDidEndScrollingAnimation:scrollView]; };
}

// return a view that will be scaled. if delegate returns nil, nothing happens
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {return [self.delegate viewForZoomingInScrollView:scrollView]; } else { return nil; };
}

// called before the scroll view begins zooming its content
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_2)
{
    if ([self.delegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)]) {[self.delegate scrollViewWillBeginZooming:scrollView withView:view]; };
}

// scale between minimum and maximum. called after any 'bounce' animations
- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)]) {[self.delegate scrollViewDidEndZooming:scrollView withView:view atScale:scale]; };
}

// return a yes if you want to scroll to the top. if not defined, assumes YES
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)]) {return [self.delegate scrollViewShouldScrollToTop:scrollView]; } else { return YES; };
}

// called when scrolling animation finished. may be called immediately if already at top
- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
    if ([self.delegate respondsToSelector:@selector(scrollViewDidScrollToTop:)]) {[self.delegate scrollViewDidScrollToTop:scrollView]; };
}


@end

