//
//  BListItem.m
//  B-list
//
//  Created by Steven Vandeweghe on 3/22/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import "BListItem.h"

@implementation BListItem

- (id)init
{
	if (self = [super init]) {
		_title = @"";
		_notes = @"";
	}
	return self;
}


- (NSDictionary *)dictionary
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:3];
	if (self.title) {
		[dict setValue:self.title forKey:@"title"];
	}
	if (self.notes) {
		[dict setValue:self.notes forKey:@"notes"];
	}
	[dict setValue:@(self.checked) forKey:@"checked"];
	return [dict copy];
}

@end
