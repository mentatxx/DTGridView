//
//  DTGridViewCell.m
//  GridViewTester
//
//  Created by Daniel Tull on 06.04.2009.
//  Copyright 2009 Daniel Tull. All rights reserved.
//

#import "DTGridViewCell.h"
#import "DTGridView.h"

#pragma mark Private Methods
@interface DTGridViewCell ()
- (DTGridView *)gridView;
@end



@implementation DTGridViewCell

@synthesize xPosition, yPosition, identifier, selected;
@synthesize highlighted;
@synthesize delegate;

@dynamic frame;

- (id)initWithReuseIdentifier:(NSString *)anIdentifier {
	self = [super initWithFrame:CGRectZero];
	if (self) {
		identifier = [anIdentifier copy];
	}
	return self;
}


- (void)awakeFromNib {
	identifier = nil;
}

- (void)prepareForReuse {
	self.selected = NO;
	self.highlighted = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	self.highlighted = YES;
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	self.highlighted = NO;
	[super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	self.highlighted = NO;
	[[self gridView] selectRow:self.yPosition column:self.xPosition scrollPosition:DTGridViewScrollPositionNone animated:YES];
	[self.delegate gridViewCellWasTouched:self];
	[super touchesEnded:touches withEvent:event];
}

#pragma mark -
#pragma mark Private Methods

- (DTGridView *)gridView {	
	UIResponder *r = [self nextResponder];
	if (![r isKindOfClass:[DTGridView class]]) return nil;
	return (DTGridView *)r;
}

@end
