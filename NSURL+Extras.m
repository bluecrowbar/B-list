//
//  NSURL+Extras.m
//  B-list
//
//  Created by Steven Vandeweghe on 3/29/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import "NSURL+Extras.h"

@implementation NSURL (Extras)

- (NSString *)bc_filenameWithoutExtension
{
	// do this twice because the file extension could be .blist.icloud
	return [[[self lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension];
}

@end
