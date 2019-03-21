//
//  BListDocument+Extras.m
//  B-list
//
//  Created by Steven Vandeweghe on 6/2/14.
//  Copyright (c) 2014 Blue Crowbar. All rights reserved.
//

#import "BListDocument+Extras.h"
#import "NSURL+Extras.h"

@implementation BListDocument (Extras)

+ (NSString *)bcb_alternativeNameForProposedName:(NSString *)proposedName withExistingURLs:(NSArray *)URLs
{
	if (URLs.count == 0) {
		return proposedName;
	}
	
	NSMutableArray *listNames = [[NSMutableArray alloc] initWithCapacity:URLs.count];
	for (NSURL *URL in URLs) {
		NSString *name = [[URL bc_filenameWithoutExtension] lowercaseString];
		// files that were migrated to iCloud Drive start with a dot
		name = [name stringByReplacingOccurrencesOfString:@"." withString:@"" options:0 range:NSMakeRange(0, 1)];
		[listNames addObject:name];
	}
	
	if (![listNames containsObject:[proposedName lowercaseString]]) {
		return proposedName;
	}
	
	NSString *alternativeName = proposedName;
	
	NSError *error = nil;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s\\([0-9]+\\)$" options:0 error:&error];
	NSUInteger numberOfMatches = [regex numberOfMatchesInString:proposedName options:0 range:NSMakeRange(0, proposedName.length)];
	if (numberOfMatches == 1) {
		NSRange range = [regex rangeOfFirstMatchInString:proposedName options:0 range:NSMakeRange(0, proposedName.length)];
		proposedName = [proposedName stringByReplacingCharactersInRange:range withString:@""];
	}
	
	NSInteger i = 0;
	while ([listNames containsObject:[alternativeName lowercaseString]]) {
		i++;
		alternativeName = [NSString stringWithFormat:@"%@ (%ld)", proposedName, (long)i];
	}
	return alternativeName;
}

@end
