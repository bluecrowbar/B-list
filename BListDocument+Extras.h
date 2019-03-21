//
//  BListDocument+Extras.h
//  B-list
//
//  Created by Steven Vandeweghe on 6/2/14.
//  Copyright (c) 2014 Blue Crowbar. All rights reserved.
//

#import "BListDocument.h"

@interface BListDocument (Extras)

+ (NSString *)bcb_alternativeNameForProposedName:(NSString *)proposedName withExistingURLs:(NSArray *)URLs;

@end
