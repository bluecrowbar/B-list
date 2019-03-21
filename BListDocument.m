//
//  BCListDocument.m
//  B-list
//
//  Created by Steven Vandeweghe on 3/26/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import "BListDocument.h"
#import "BList.h"
#import "NSURL+Extras.h"
#import "BCBConstants.h"


@implementation BListDocument

+ (NSString *)documentExtension
{
	return @"blist";
}


+ (NSString *)documentsFolder
{
	return @"Documents";
}


+ (void)createNewDocumentWithTitle:(NSString *)title list:(BList *)list iniCloud:(BOOL)iCloud completion:(void (^)(BListDocument *doc))completion
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL *documentURL;
		if (iCloud) {
			documentURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
		} else {
			documentURL = [NSURL fileURLWithPath:NSHomeDirectory()];
		}
		documentURL = [documentURL URLByAppendingPathComponent:[BListDocument documentsFolder] isDirectory:YES];
		NSString *cleanedUpTitle = [BListDocument cleanedUpTitle:title];
		documentURL = [documentURL URLByAppendingPathComponent:cleanedUpTitle];
		documentURL = [documentURL URLByAppendingPathExtension:[BListDocument documentExtension]];
		BListDocument *doc = [[BListDocument alloc] initWithFileURL:documentURL];
		if (list) {
			doc.list = list;
		}
		[doc saveToURL:doc.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
			if (!success) {
				NSLog(@"Something went wrong while creating a new document!");
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				completion(doc);
			});
		}];
	});
}


+ (BOOL)iCloudEnabled
{
	id token = [[NSFileManager defaultManager] ubiquityIdentityToken];
	if (token && [[NSUserDefaults standardUserDefaults] boolForKey:BCiCloudEnabledKey]) {
		return YES;
	}
	return NO;
}


// replaces forward slash
+ (NSString *)cleanedUpTitle:(NSString *)title
{
	return [title stringByReplacingOccurrencesOfString:@"/" withString:@"\uFF0F"];
}


- (id)initWithFileURL:(NSURL *)url
{
	if (self = [super initWithFileURL:url]) {
		_list = [[BList alloc] init];
	}
	return self;
}


- (id)contentsForType:(NSString *)typeName error:(NSError **)outError
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if (!self.list) {
		self.list = [[BList alloc] init];
	}
	
	return [self.list serialize];
}


- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if (!self.list) {
		_list = [[BList alloc] init];
	}
	[self.list deserializeData:contents];
	if (self.delegate && [self.delegate respondsToSelector:@selector(documentContentsDidChange:)]) {
        [self.delegate documentContentsDidChange:self];
	}
	return YES;
}


#pragma mark - NSFilePresenter

- (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError *errorOrNil))completionHandler
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	[self closeWithCompletionHandler:^(BOOL success) {
		completionHandler(nil);
	}];
}

@end
