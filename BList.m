//
//  BList.m
//  B-list
//
//  Created by Steven Vandeweghe on 3/18/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import "BList.h"
#import "BListItem.h"
#import "BCFileManager.h"

@interface BList ()

@end


@implementation BList

- (id)init
{
	if (self = [super init]) {
		_items = [NSMutableArray array];
	}
	return self;
}


- (NSData *)serialize
{
	NSMutableDictionary *listDict = [NSMutableDictionary dictionaryWithCapacity:3];
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:self.items.count];
	for (BListItem *item in self.items) {
		[items addObject:[item dictionary]];
	}
	[listDict setValue:items forKey:@"items"];
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:listDict options:0 error:&error];
	if (!jsonData) {
		NSLog(@"%@", error.localizedFailureReason);
		return nil;
	}
	return jsonData;
}


- (BOOL)deserializeData:(NSData *)data
{
	NSError *error;
	id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	if (!json) {
		NSLog(@"%@", error.localizedFailureReason);
		return NO;
	}
	[self.items removeAllObjects];
	for (NSDictionary *itemDict in [json valueForKey:@"items"]) {
		BListItem *item = [[BListItem alloc] init];
		item.title = itemDict[@"title"];
		item.notes = itemDict[@"notes"];
		item.checked = [itemDict[@"checked"] boolValue];
		[self.items addObject:item];
	}
	return YES;
}


- (NSString *)description
{
	NSMutableString *itemsDescription = [NSMutableString string];
	[itemsDescription appendString:@"\n"];
	for (BListItem *item in self.items) {
		[itemsDescription appendFormat:@"%@ [%d]\n", item.title, item.checked];
	}
	return [itemsDescription copy];
}


- (NSUInteger)uncheckedItemCount
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"checked == NO"];
	NSArray *uncheckItems = [self.items filteredArrayUsingPredicate:predicate];
	return uncheckItems.count;
}


#pragma mark - Accessors

- (NSUInteger)numberOfContiguousCheckedItemsFromTop
{
	NSUInteger counter = 0;
	for (BListItem *item in self.items) {
		if (item.checked) {
			counter++;
		} else {
			break;
		}
	}
	return counter;
}

@end
