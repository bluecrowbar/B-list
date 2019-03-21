//
//  BListDocumentProvider.m
//  B-list
//
//  Created by Steven Vandeweghe on 04/04/15.
//  Copyright (c) 2015 Blue Crowbar. All rights reserved.
//

#import "BListDocumentProvider.h"
@import MobileCoreServices.UTCoreTypes;


@implementation BListDocumentProvider

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
	NSURL *tmpURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
	tmpURL = [tmpURL URLByAppendingPathComponent:self.fileName];
	tmpURL = [tmpURL URLByAppendingPathExtension:@"blist"];
	
	[self.data writeToURL:tmpURL atomically:YES];
	
	return tmpURL;
}


- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
	return self.fileName;
}


- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(NSString *)activityType
{
	return self.fileName;
}


- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType
{
	return (id)kUTTypeFileURL;
}

@end
