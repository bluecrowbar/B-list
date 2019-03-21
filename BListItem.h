//
//  BListItem.h
//  B-list
//
//  Created by Steven Vandeweghe on 3/22/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BListItem : NSObject

@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) NSString *notes;
@property (assign, nonatomic) BOOL checked;

- (NSDictionary *)dictionary;

@end
