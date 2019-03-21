//
//  BList.h
//  B-list
//
//  Created by Steven Vandeweghe on 3/18/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BList : NSObject

@property (strong, nonatomic) NSMutableArray *items;
@property (nonatomic, assign, readonly) NSUInteger numberOfContiguousCheckedItemsFromTop;

- (NSData *)serialize;
- (BOOL)deserializeData:(NSData *)data;

- (NSUInteger)uncheckedItemCount;

@end
