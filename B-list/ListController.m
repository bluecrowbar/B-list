//
//  ListController.m
//  B-list
//
//  Created by Steven Vandeweghe on 1/30/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import "ListController.h"
#import "ListDetailController.h"
#import "ItemsController.h"
#import "BList.h"
#import "BListItem.h"
#import "BCFileManager.h"
#import "BListDocument.h"
#import "BListHistoryDocument.h"
#import "NSURL+Extras.h"
#import "MBProgressHUD.h"
#import "BListDocument+Extras.h"
#import "BCBConstants.h"
@import QuartzCore;


@interface ListController () {
	NSMetadataQuery *_query;
	id _contentSizeNotificationToken;
}

@property (strong, nonatomic) NSMutableArray *documentURLs;
@property (strong, nonatomic) NSURL *selectedDocumentURL;

@property (strong, nonatomic) ItemsController *itemsController;

@end


@implementation ListController

+ (void)initialize
{
	NSDictionary *defaults = @{ BCiCloudEnabledKey: @NO, BCSignedOutOfiCloudKey:@NO };
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.title = NSLocalizedString(@"Lists", @"Title for ListController");
	
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
																			   target:self 
																			   action:@selector(addList)];
	self.navigationItem.rightBarButtonItem = addButton;
	
	if (!_documentURLs) {
		_documentURLs = [[NSMutableArray alloc] init];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processFiles:) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFiles:) name:NSMetadataQueryDidUpdateNotification object:nil];
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ubiquityIdentityChanged) name:NSUbiquityIdentityDidChangeNotification object:nil];
	
	if ([BListDocument iCloudEnabled]) {
		[self startQuery];
	}
	if (![BListDocument iCloudEnabled]) {
		[self updateForLocalFiles];
	}
	
	[self migrateCDContent];
	
	__weak ListController *weakSelf = self;
	_contentSizeNotificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:UIContentSizeCategoryDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		[weakSelf.tableView reloadData];
	}];
}


- (void)viewDidAppear:(BOOL)animated
{
	[self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:NO];
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
//	if ([BListDocument iCloudEnabled]) {
//		[_query stopQuery];
//	}
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidFinishGatheringNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidUpdateNotification object:nil];
	if (_contentSizeNotificationToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_contentSizeNotificationToken];
	}
}


#pragma mark - TableView data source

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return self.documentURLs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleGray;
		
		UIButton *detailButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
		[detailButton addTarget:self
						 action:@selector(detailButtonTapped:withEvent:)
			   forControlEvents:UIControlEventTouchUpInside];
		cell.accessoryView = detailButton;
	}
	
	cell.textLabel.text = [self.documentURLs[indexPath.row] bc_filenameWithoutExtension];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
}


- (void)detailButtonTapped:(UIControl *)button withEvent:(UIEvent *)event
{
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:[[[event touchesForView:button] anyObject] locationInView:self.tableView]];
    if (indexPath == nil)
        return;
	
    [self.tableView.delegate tableView:self.tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		
		NSURL *documentURL = self.documentURLs[indexPath.row];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
			NSError *error = nil;
			[fc coordinateWritingItemAtURL:documentURL
								   options:NSFileCoordinatorWritingForDeleting
									 error:&error
								byAccessor:^(NSURL *newURL) {
									NSError *deleteError;
									NSFileManager *fm = [[NSFileManager alloc] init];
									NSLog(@"DELETING FILE");
									BOOL success = [fm removeItemAtURL:newURL error:&deleteError];
									if (success) {
										NSLog(@"SUCCESS!");
									} else {
										NSLog(@"FAILED: %@", deleteError.localizedFailureReason);
									}
								}];
			if (error) {
				NSLog(@"%@", error.localizedFailureReason);
			}
		});
		[self.documentURLs removeObjectAtIndex:indexPath.row];
		dispatch_async(dispatch_get_main_queue(), ^{
			[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
		});
	}
}


#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self pushToDocumentAtFileURL:self.documentURLs[indexPath.row] animated:YES];
}


- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	self.selectedDocumentURL = self.documentURLs[indexPath.row];
	ListDetailController *detailController = [self detailController];
	detailController.createdNewList = NO;
	detailController.existingURLs = self.documentURLs;
	detailController.selectedURL = self.selectedDocumentURL;
	
	[self.navigationController pushViewController:detailController animated:YES];
}


#pragma mark - Actions

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[self.tableView setEditing:editing animated:animated];
	[super setEditing:editing animated:animated];
}


- (void)addList
{
	ListDetailController *detailController = [self detailController];
	detailController.createdNewList = YES;
	detailController.existingURLs = self.documentURLs;
	[self.navigationController pushViewController:detailController animated:YES];
}


- (void)updateForiCloudStatus
{
	[_query stopQuery];
	_query = nil;
	[self.documentURLs removeAllObjects];
	
	if ([BListDocument iCloudEnabled]) {
		[self startQuery];
	} else {
		[self stopQuery];
		[self updateForLocalFiles];
	}
	
	[self.tableView reloadData];
}



#pragma mark - Query methods

//- (void)setupQuery
//{
//	if (!_query) {
//		_query = [[NSMetadataQuery alloc] init];
//		_query.searchScopes = @[NSMetadataQueryUbiquitousDocumentsScope];
//		_query.predicate = [NSPredicate predicateWithFormat:@"%K ENDSWITH '.blist'", NSMetadataItemFSNameKey];
//		[_query setNotificationBatchingInterval:0.5];
//	}
//}

- (void)startQuery
{
	if (!_query) {
		_query = [[NSMetadataQuery alloc] init];
		_query.searchScopes = @[NSMetadataQueryUbiquitousDocumentsScope];
		_query.predicate = [NSPredicate predicateWithFormat:@"%K ENDSWITH '.blist'", NSMetadataItemFSNameKey];
		[_query setNotificationBatchingInterval:5];
		[_query startQuery];
	}
}


- (void)stopQuery
{
	[_query stopQuery];
	_query = nil;
}


- (void)processFiles:(NSNotification *)notification
{
	NSLog(@"%s %@ RESULTS: %@", __PRETTY_FUNCTION__, notification, [_query.results valueForKey:NSMetadataItemURLKey]);
	
	NSMutableArray *discoveredFiles = [NSMutableArray array];
	
	// Always disable updates while processing results.
	[_query disableUpdates];
	
	// The query reports all files found, every time.
	for (NSInteger index = 0; index < _query.resultCount; index++) {
		NSURL *fileURL = [[_query resultAtIndex:index] valueForAttribute:NSMetadataItemURLKey];
		[discoveredFiles addObject:fileURL];
	}
	
	// Update the list of documents.
	[self.documentURLs removeAllObjects];
	[self.documentURLs addObjectsFromArray:discoveredFiles];
	[self sortListDocumentURLs];
	
	[self.tableView reloadData];
	
	// Reenable query updates.
	[_query enableUpdates];
}


- (void)updateFiles:(NSNotification *)notification
{
	// START DEBUG
	NSLog(@"%s %@ RESULTS: %@", __PRETTY_FUNCTION__, notification, [_query.results valueForKey:NSMetadataItemURLKey]);
	
//	NSMutableArray *allItems = [NSMutableArray new];
//	[allItems addObjectsFromArray:notification.userInfo[NSMetadataQueryUpdateChangedItemsKey]];
//	[allItems addObjectsFromArray:notification.userInfo[NSMetadataQueryUpdateAddedItemsKey]];
//	[allItems addObjectsFromArray:notification.userInfo[NSMetadataQueryUpdateRemovedItemsKey]];
//	
//	[allItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//		NSMetadataItem *item = obj;
//		NSArray *attributes = item.attributes;
//		[attributes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//			NSLog(@"item %p -- %@: %@", item, obj, [item valueForAttribute:obj]);
//		}];
//		NSLog(@"\n\n\n-------------------------\n\n\n");
//	}];
	// END DEBUG
	
	// Always disable updates while processing results.
	[_query disableUpdates];
	
	// Update the list of documents.
	NSArray *addedItems = notification.userInfo[NSMetadataQueryUpdateAddedItemsKey];
	if (addedItems.count > 0) {
		NSLog(@"ADDED %@", addedItems);
	}
	NSArray *removedItems = notification.userInfo[NSMetadataQueryUpdateRemovedItemsKey];
	if (removedItems.count > 0) {
		NSLog(@"REMOVED %@", removedItems);
	}
	[self.documentURLs addObjectsFromArray:[addedItems valueForKey:NSMetadataItemURLKey]];
	[self.documentURLs removeObjectsInArray:[removedItems valueForKey:NSMetadataItemURLKey]];
	[self sortListDocumentURLs];
	
	if (addedItems.count + removedItems.count > 0) {
		[self.tableView reloadData];
	}
	
	// Reenable query updates.
	[_query enableUpdates];
}


#pragma mark - Helpers

- (ListDetailController *)detailController
{
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
	ListDetailController *detailController = [storyboard instantiateViewControllerWithIdentifier:@"sb_ListDetailScene"];
	detailController.delegate = self;
	return detailController;
}


- (void)sortListDocumentURLs
{
	[self.documentURLs sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		NSString *title1 = [obj1 bc_filenameWithoutExtension];
		NSString *title2 = [obj2 bc_filenameWithoutExtension];
		return [title1 compare:title2 options:NSCaseInsensitiveSearch | NSNumericSearch];
	}];
}


- (void)updateForLocalFiles
{
	self.documentURLs = [[self localURLs] mutableCopy];
	[self sortListDocumentURLs];
	[self.tableView reloadData];
}


- (NSArray *)localURLs
{
	NSMutableArray *blistDocURLs = [[NSMutableArray alloc] init];
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
	for (NSURL *URL in enumerator) {
		if ([[URL pathExtension] isEqualToString:[BListDocument documentExtension]]) {
			[blistDocURLs addObject:URL];
		}
	}
	return [blistDocURLs copy];
}


- (NSArray *)existingURLs
{
	NSURL *baseURL;
	if ([BListDocument iCloudEnabled]) {
		baseURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	} else {
		baseURL = [NSURL fileURLWithPath:NSHomeDirectory()];
	}
	baseURL = [baseURL URLByAppendingPathComponent:@"Documents" isDirectory:YES];
	if (!baseURL) {
		return @[];
	}
	NSArray *existingFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:baseURL includingPropertiesForKeys:nil options:0 error:nil];
	// get the files that have the .blist extension or end in .blist.icloud (after migration to iCloud Drive)
	NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
		BOOL existsAsBlist = [[(NSURL *)evaluatedObject pathExtension] isEqualToString:[BListDocument documentExtension]];
		BOOL existsAsOldiCloud = [[[[(NSURL *)evaluatedObject absoluteString] stringByDeletingPathExtension] pathExtension] isEqualToString:[BListDocument documentExtension]];
		return existsAsBlist || existsAsOldiCloud;
	}];
	return [existingFiles filteredArrayUsingPredicate:predicate];
}


- (void)pushToDocumentAtFileURL:(NSURL *)URL animated:(BOOL)animated
{
	BListDocument *doc = [[BListDocument alloc] initWithFileURL:URL];
	self.itemsController.selectedDocument = doc;
	[doc openWithCompletionHandler:^(BOOL success) {
		NSLog(@"%d", success);
		if (success) {
			NSLog(@"Openend document %@", doc);
		}
	}];
	self.itemsController.shouldShowDownloadProgress = YES;
	[self.navigationController pushViewController:self.itemsController animated:animated];
}


#pragma mark - Accessors

- (ItemsController *)itemsController
{
	if (!_itemsController) {
		UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
		ItemsController *itemsController = [storyboard instantiateViewControllerWithIdentifier:@"sb_Items"];
		itemsController.delegate = self;
		_itemsController = itemsController;
	}
	return _itemsController;
}


#pragma mark - ItemsControllerDelegate

- (void)itemsControllerDidDeleteDocument:(BListDocument *)doc
{
	[self.documentURLs removeObject:doc.fileURL];
	[self.tableView reloadData];
}


#pragma mark - ListDetailControllerDelegate

- (void)createdNewDocument:(BListDocument *)document
{
	if (![BListDocument iCloudEnabled]) {
		[self.documentURLs addObject:document.fileURL];
		[self sortListDocumentURLs];
		[self.tableView reloadData];
	}
}


- (void)changedListWithProposedTitle:(NSString *)proposedTitle
{
	NSMutableArray *existingURLs = [[NSMutableArray arrayWithArray:self.documentURLs] mutableCopy];
	[existingURLs removeObject:self.selectedDocumentURL];
	NSString *title = [BListDocument bcb_alternativeNameForProposedName:proposedTitle withExistingURLs:existingURLs];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL *renamedDocumentURL;
		if ([BListDocument iCloudEnabled]) {
			renamedDocumentURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
		} else {
			renamedDocumentURL = [NSURL fileURLWithPath:NSHomeDirectory()];
		}
		renamedDocumentURL = [renamedDocumentURL URLByAppendingPathComponent:[BListDocument documentsFolder] isDirectory:YES];
		renamedDocumentURL = [renamedDocumentURL URLByAppendingPathComponent:title];
		renamedDocumentURL = [renamedDocumentURL URLByAppendingPathExtension:[BListDocument documentExtension]];
		NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[fc coordinateWritingItemAtURL:self.selectedDocumentURL options:NSFileCoordinatorWritingForMoving error:nil byAccessor:^(NSURL *newURL) {
			NSFileManager *fm = [[NSFileManager alloc] init];
			[fm moveItemAtURL:newURL toURL:renamedDocumentURL error:nil];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.documentURLs removeObject:self.selectedDocumentURL];
				[self.documentURLs addObject:renamedDocumentURL];
				[self sortListDocumentURLs];
				[self.tableView reloadData];
			});
		}];
	});
}


#pragma mark - Importing

// This is for files that were mailed from version 1.x of the app.

// We can't use self.documentURLs here since they might not have been loaded yet
- (void)importSharedListFromDictionary:(NSDictionary *)listDictionary
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSArray *existingURLs = [self existingURLs];
		NSString *title = [BListDocument bcb_alternativeNameForProposedName:[listDictionary valueForKey:@"name"] withExistingURLs:existingURLs];
		NSArray *items = [listDictionary valueForKey:@"items"];
		NSArray *sortedItems = [items sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
			return [[obj1 valueForKey:@"index"] compare:[obj2 valueForKey:@"index"]];
		}];
		
		BList *list = [[BList alloc] init];
		for (id item in sortedItems) {
			BListItem *newItem = [[BListItem alloc] init];
			newItem.title = [item valueForKey:@"name"];
			newItem.notes = [item valueForKey:@"notes"];
			newItem.checked = [[item valueForKey:@"checked"] boolValue];
			[list.items addObject:newItem];
		}
		
		[BListDocument createNewDocumentWithTitle:title list:list iniCloud:[BListDocument iCloudEnabled] completion:^(BListDocument *doc) {
			[self.documentURLs addObject:doc.fileURL];
			[self sortListDocumentURLs];
			[self.tableView reloadData];
			[doc closeWithCompletionHandler:nil];
		}];
	});
}


// This is for files that were mailed from version 2.0 and higher.

// We can't use self.documentURLs here since they might not have been loaded yet
- (void)importSharedListFromJSON:(NSURL *)URL
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSArray *existingURLs = [self existingURLs];
		NSString *title = [BListDocument bcb_alternativeNameForProposedName:[URL bc_filenameWithoutExtension] withExistingURLs:existingURLs];
		NSData *data = [NSData dataWithContentsOfURL:URL];
		if (data == nil) {
			return;
		}
		BList *list = [[BList alloc] init];
		BOOL success = [list deserializeData:data];
		if (!success) {
			dispatch_async(dispatch_get_main_queue(), ^{
				UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Oops..." message:@"That doesn\u2019t look like a valid B-list file" preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
				[alertController addAction:defaultAction];
				[self presentViewController:alertController animated:YES completion:nil];
			});
			return;
		}
		[BListDocument createNewDocumentWithTitle:title list:list iniCloud:[BListDocument iCloudEnabled] completion:^(BListDocument *doc) {
			[self.documentURLs addObject:doc.fileURL];
			[self sortListDocumentURLs];
			[self.tableView reloadData];
			[doc closeWithCompletionHandler:nil];
			dispatch_async(dispatch_get_main_queue(), ^{
				[self pushToDocumentAtFileURL:doc.fileURL animated:YES];
			});
		}];
	});
}


//#pragma mark -
//
//- (void)createNewDocumentWithTitle:(NSString *)title list:(BList *)list iniCloud:(BOOL)iCloud completion:(void (^)(BListDocument *doc))completion
//{
//	title = [BListDocument alternativeNameForProposedName:title withExistingURLs:self.documentURLs];
//	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//		NSURL *documentURL;
//		if (iCloud) {
//			documentURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
//		} else {
//			documentURL = [NSURL fileURLWithPath:NSHomeDirectory()];
//		}
//		documentURL = [documentURL URLByAppendingPathComponent:[BListDocument documentsFolder] isDirectory:YES];
//		documentURL = [documentURL URLByAppendingPathComponent:title];
//		documentURL = [documentURL URLByAppendingPathExtension:[BListDocument documentExtension]];
//		BListDocument *doc = [[BListDocument alloc] initWithFileURL:documentURL];
//		if (list) {
//			doc.list = list;
//		}
//		[self.documentURLs addObject:documentURL];
//		[doc saveToURL:doc.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
//			completion(doc);
//		}];
//	});
//}


#pragma mark - iCloud

// If existing documents in iCloud are older, they'll be overwritten by local ones with the same name
- (void)moveDocumentsFromLocalToiCloudWithCompletion:(void (^)(void))completion
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[MBProgressHUD showHUDAddedTo:self.view.window animated:YES];
	});
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		[NSThread sleepForTimeInterval:0.5];
		for (NSURL *URL in [self localURLs]) {
			NSURL *destination = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
			destination = [destination URLByAppendingPathComponent:[BListDocument documentsFolder] isDirectory:YES];
			destination = [destination URLByAppendingPathComponent:[URL bc_filenameWithoutExtension]];
			destination = [destination URLByAppendingPathExtension:[BListDocument documentExtension]];
			NSError *error;
			id value;
			BOOL success = [destination getResourceValue:&value forKey:NSURLIsUbiquitousItemKey error:&error];
			if (success && [value intValue] == 1) {
				NSDate *localDate, *cloudDate;
				[URL getResourceValue:&localDate forKey:NSURLAttributeModificationDateKey error:nil];
				[destination getResourceValue:&cloudDate forKey:NSURLAttributeModificationDateKey error:nil];
				NSLog(@"local: %@ -- iCloud: %@", localDate, cloudDate);
				if ([localDate compare:cloudDate] == NSOrderedDescending) {
					// when the local file is more recent:
					NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
					[fc coordinateWritingItemAtURL:destination options:NSFileCoordinatorWritingForReplacing error:nil byAccessor:^(NSURL *newURL) {
						NSError *error;
						BOOL success = [[NSFileManager defaultManager] replaceItemAtURL:newURL withItemAtURL:URL backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:nil error:&error];
						if (!success) {
							NSLog(@"%@", error.localizedDescription);
						}
					}];
				} else {
					// when the iCloud file is more recent:
					[[NSFileManager defaultManager] removeItemAtURL:URL error:nil];
				}
			} else {
				success = [[NSFileManager defaultManager] setUbiquitous:YES itemAtURL:URL destinationURL:destination error:&error];
				if (!success) {
					NSLog(@"moveDocumentsFromLocalToiCloud: %@", error.localizedDescription);
				}
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
//			[self.documentURLs removeAllObjects];
			[self copyLocalHistoryToiCloud];
			if (completion) {
				completion();
			}
			[MBProgressHUD hideHUDForView:self.view.window animated:YES];
		});
	});
}


// Not used.
- (void)moveDocumentsFromiCloudToLocal
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[MBProgressHUD showHUDAddedTo:self.view.window animated:YES];
	});
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		[NSThread sleepForTimeInterval:0.5];
		for (NSURL *URL in self.documentURLs) {
			NSURL *destination = [NSURL fileURLWithPath:NSHomeDirectory()];
			destination = [destination URLByAppendingPathComponent:[BListDocument documentsFolder] isDirectory:YES];
			destination = [destination URLByAppendingPathComponent:[URL bc_filenameWithoutExtension]];
			destination = [destination URLByAppendingPathExtension:[BListDocument documentExtension]];
			NSError *error;
			BOOL success = [[NSFileManager defaultManager] setUbiquitous:YES itemAtURL:URL destinationURL:destination error:&error];
			if (!success) {
				NSLog(@"moveDocumentsFromiCloudToLocal: %@", error.localizedDescription);
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.view.window animated:YES];
		});
	});
}


- (void)copyLocalHistoryToiCloud
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSURL *localURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/history.json"]];
		NSURL *destination = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
		destination = [destination URLByAppendingPathComponent:@"Documents/history.json"];
		NSError *error;
		id value;
		BOOL success = [destination getResourceValue:&value forKey:NSURLIsUbiquitousItemKey error:&error];
		if (success && [value intValue] == 1) {
			BListHistoryDocument *cloudDoc = [[BListHistoryDocument alloc] initWithFileURL:destination];
			[cloudDoc openWithCompletionHandler:^(BOOL success) {
				BListHistoryDocument *localDoc = [[BListHistoryDocument alloc] initWithFileURL:localURL];
				[localDoc openWithCompletionHandler:^(BOOL success) {
					NSArray *localHistory = [localDoc.history copy];
					[localDoc closeWithCompletionHandler:nil];
					NSArray *cloudHistory = [cloudDoc.history copy];
					NSArray *mergedArray = [self mergeHistoryArray:cloudHistory withArray:localHistory];
					cloudDoc.history = [mergedArray mutableCopy];
					[cloudDoc updateChangeCount:YES];
					[cloudDoc closeWithCompletionHandler:^(BOOL success) {
						NSLog(@"%d", success);
					}];
				}];
			}];
		} else if ([value intValue] == 0) {
			NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
			[fc coordinateWritingItemAtURL:destination options:NSFileCoordinatorWritingForReplacing error:&error byAccessor:^(NSURL *newURL) {
				NSError *error;
				BOOL success = [[NSFileManager defaultManager] copyItemAtURL:localURL toURL:newURL error:&error];
				if (!success) {
					NSLog(@"moveLocalHistoryToiCloud: %@", error.localizedDescription);
				}
			}];
		}
	});
}


- (NSArray *)mergeHistoryArray:(NSArray *)historyArray withArray:(NSArray *)otherHistoryArray
{
	NSMutableArray *tmpArray = [NSMutableArray arrayWithCapacity:historyArray.count];
	[tmpArray addObjectsFromArray:historyArray];
	for (NSString *item in otherHistoryArray) {
		if (![tmpArray containsObject:item]) {
			[tmpArray addObject:item];
		}
	}
	return [tmpArray copy];
}


- (void)ubiquityIdentityChanged
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	BOOL iCloudEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:BCiCloudEnabledKey];
	if (iCloudEnabled) {
		// switch iCloud off
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCiCloudEnabledKey];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:BCSignedOutOfiCloudKey];
		[self stopQuery];
		[self updateForLocalFiles];
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"iCloud" message:@"You have signed out of the iCloud account that was previously used. Sign back in to access your lists." preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
			[self.navigationController popToRootViewControllerAnimated:YES];
		}];
		[alertController addAction:defaultAction];
		[self presentViewController:alertController animated:YES completion:nil];
	}
	[self.tableView reloadData];
}


#pragma mark - Core Data migration

- (void)migrateCDContent
{
	[self.managedObjectContext performBlock:^{
		NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"List"];
		NSError *error;
		NSArray *lists = [self.managedObjectContext executeFetchRequest:request error:&error];
		if (lists.count == 0) {
			return;
		}
		NSLog(@"Migrating %lu lists.", (unsigned long)lists.count);
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD showHUDAddedTo:self.tableView animated:YES];
		});
		NSURL *baseURL;
		if ([BListDocument iCloudEnabled]) {
			baseURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
		} else {
			baseURL = [NSURL fileURLWithPath:NSHomeDirectory()];
		}
		baseURL = [baseURL URLByAppendingPathComponent:@"Documents" isDirectory:YES];
		NSArray *existingFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:baseURL includingPropertiesForKeys:nil options:0 error:nil];
		NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
			return [[(NSURL *)evaluatedObject pathExtension] isEqualToString:[BListDocument documentExtension]];
		}];
		NSMutableArray *existingBlistFiles = [[existingFiles filteredArrayUsingPredicate:predicate] mutableCopy];
		
		for (NSManagedObject *list in lists) {
			NSString *title = [list valueForKey:@"name"];
			title = [BListDocument bcb_alternativeNameForProposedName:title withExistingURLs:existingBlistFiles];
			NSURL *documentURL = baseURL;
			documentURL = [documentURL URLByAppendingPathComponent:title];
			documentURL = [documentURL URLByAppendingPathExtension:[BListDocument documentExtension]];
			[existingBlistFiles addObject:documentURL];
			BListDocument *doc = [[BListDocument alloc] initWithFileURL:documentURL];
			NSSet *items = [list valueForKey:@"items"];
			NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES];
			NSArray *itemsSortedByIndex = [items sortedArrayUsingDescriptors:@[sortDescriptor]];
			for (NSManagedObject *item in itemsSortedByIndex) {
				BListItem *newItem = [[BListItem alloc] init];
				newItem.title = [item valueForKey:@"name"];
				newItem.notes = [item valueForKey:@"notes"];
				newItem.checked = [[item valueForKey:@"checked"] boolValue];
				[doc.list.items addObject:newItem];
			}
			[doc saveToURL:doc.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
				NSLog(@"document saved. success: %d", success);
				[doc closeWithCompletionHandler:^(BOOL success) {
					NSLog(@"document closed. success: %d", success);
				}];
			}];
			[self.managedObjectContext deleteObject:list];
		}
		[self.managedObjectContext save:nil];
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.tableView animated:NO];
			[self sortListDocumentURLs];
			NSLog(@"refreshing UI");
			[self.tableView reloadData];
		});
		NSLog(@"end %s", __PRETTY_FUNCTION__);
	}];
}

@end
