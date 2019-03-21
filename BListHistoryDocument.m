//
//  BListHistoryDocument.m
//  B-list
//
//  Created by Steven Vandeweghe on 4/8/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import "BListHistoryDocument.h"

@implementation BListHistoryDocument

- (id)initWithFileURL:(NSURL *)url
{
	if (self = [super initWithFileURL:url]) {
		_history = [[NSMutableArray alloc] init];
	}
	return self;
}


- (id)contentsForType:(NSString *)typeName error:(NSError **)outError
{
	NSError *error;
	NSData *JSONData = [NSJSONSerialization dataWithJSONObject:self.history options:0 error:&error];
	if (!JSONData) {
		NSLog(@"%@", error.localizedDescription);
	}
	return JSONData;
}


- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError
{
	NSError *error;
	NSMutableArray *history = [NSJSONSerialization JSONObjectWithData:contents options:NSJSONReadingMutableContainers error:&error];
	self.history = history;
	if (!history) {
		NSLog(@"%@", error.localizedDescription);
		return NO;
	}
	return YES;
}

@end
