//
//  BListEmailBodyProvider.m
//  B-list
//
//  Created by Steven Vandeweghe on 04/04/15.
//  Copyright (c) 2015 Blue Crowbar. All rights reserved.
//

#import "BListEmailBodyProvider.h"
@import MobileCoreServices.UTCoreTypes;


@implementation BListEmailBodyProvider

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
	return @"";
}


- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
	return @"<html><head></head><body><p>Tap the attached file to open it in the <span style=\"white-space:nowrap\">B-list</span> app. You can download the latest version of B-list in the <a href=\"http://itunes.com/apps/blist\">App Store</a>.</p></body></html>";
}


- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(NSString *)activityType
{
	return (id)kUTTypeHTML;
}

@end
