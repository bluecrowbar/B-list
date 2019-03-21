//
//  ListPageRenderer.m
//  B-list
//
//  Created by Steven Vandeweghe on 2/6/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import "ListPageRenderer.h"
#import "AppDelegate.h"

@implementation ListPageRenderer

@synthesize list;


- (id)init
{
	if (self = [super init]) {
		self.headerHeight = 40.0;
		self.footerHeight = 40.0;
	}
	return self;
}


- (NSInteger)numberOfPages
{
	return 1;
}


- (void)drawContentForPageAtIndex:(NSInteger)index inRect:(CGRect)contentRect
{
	NSAssert(self.list, @"There must be a list");
	
	CGFloat xMargin = contentRect.origin.x + 20;
	
	UIBezierPath *headerPath = [UIBezierPath bezierPath];
	CGFloat rowHeight = 34.0;
	CGFloat cornerRadius = 8.0;
	[headerPath moveToPoint:CGPointMake(xMargin, self.headerHeight + rowHeight)];
	[headerPath addLineToPoint:CGPointMake(xMargin, self.headerHeight + cornerRadius)];
	[headerPath addArcWithCenter:CGPointMake(xMargin + cornerRadius, self.headerHeight + cornerRadius)
						  radius:cornerRadius startAngle:M_PI endAngle:3 * M_PI_2 clockwise:YES];
	[headerPath addLineToPoint:CGPointMake(xMargin + 250, self.headerHeight)];
	
	[headerPath stroke];
	
	UIFont *itemNameFont = [UIFont systemFontOfSize:14.0];
	UIFont *itemNotesFont = [UIFont systemFontOfSize:11.0];
	
	NSArray *items = [[self.list valueForKey:@"items"] allObjects];
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
	NSArray *sortedItems = [items sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]];
	
	CGFloat y = self.headerHeight;
	
	CGFloat verticalShiftAfterLine;
	CGFloat verticalShiftAfterItemName;
	CGFloat verticalShiftAfterItemNotes;
	
	for (NSManagedObject *item in sortedItems) {
		
		NSString *name = [item valueForKey:@"name"];
		NSString *notes = [item valueForKey:@"notes"];
		
		if (notes == nil || [notes length] == 0) {
			verticalShiftAfterLine = 7.0;
			verticalShiftAfterItemName = 27.0;
		} else {
			verticalShiftAfterLine = 2.0;
			verticalShiftAfterItemName = 15.0;
			verticalShiftAfterItemNotes = 17.0;
		}
		
		UIBezierPath *line = [UIBezierPath bezierPathWithRect:CGRectMake(xMargin, y, 250, 0)];
		[[UIColor colorWithWhite:0.85 alpha:1.0] set];
		[line setLineWidth:0.5];
		[line stroke];
		
		y += verticalShiftAfterLine;
		
		[[UIColor blackColor] set];
		[name drawAtPoint:CGPointMake(xMargin, y) withFont:itemNameFont];
		
		y += verticalShiftAfterItemName;
		
		if (notes != nil && [notes length] > 0) {
			[[UIColor grayColor] set];
			[notes drawAtPoint:CGPointMake(xMargin, y) withFont:itemNotesFont];
			y += verticalShiftAfterItemNotes;
		}
	}
	
	UIBezierPath *line = [UIBezierPath bezierPathWithRect:CGRectMake(xMargin, y, 250, 0)];
	[[UIColor colorWithWhite:0.85 alpha:1.0] set];
	[line setLineWidth:0.5];
	[line fill];
}

@end
