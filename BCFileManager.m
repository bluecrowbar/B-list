//
//  BCFileManager.m
//  B-list
//
//  Created by Steven Vandeweghe on 3/25/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import "BCFileManager.h"

@implementation BCFileManager

+ (NSString *)localPath
{
	NSArray *dirs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
	if (dirs.count == 0) {
		return nil;
	}
	return [NSString stringWithFormat:@"%@/Lists", [dirs[0] path]];
}

@end
