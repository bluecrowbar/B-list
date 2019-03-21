//
//  ItemsController.m
//  B-list
//
//  Created by Steven Vandeweghe on 1/31/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import "ItemsController.h"
#import "ItemDetailController.h"
#import "BList.h"
#import "BListDocument.h"
#import "BListItem.h"
#import "BListDocumentProvider.h"
#import "NSURL+Extras.h"
#import "MBProgressHUD.h"
#import <QuartzCore/QuartzCore.h>
#import "B_list-Swift.h"


NSString * const BCNewItemsAtTopOfListKey = @"NewItemsAtTopOfList";


enum AlertViewTag {
	ClipboardAlertViewTag = 1,
	DeleteItemsAlertViewTag = 2,
	DeleteListAlertViewTag = 3,
	StartOverAlertViewTag = 4
};

enum ActionSheetTag {
	SharingActionSheetTag = 1,
	ClearListActionSheetTag = 2,
	DeletionActionSheetTag = 3
};


@interface ItemsController () <UIGestureRecognizerDelegate> {
	BOOL shouldScrollToInsertedRowAfterRefresh;
	BOOL isBeingPopped;
	id _contentSizeNotificationToken;
}

@property (strong, nonatomic) ItemDetailController *itemDetailController;
@property (strong, nonatomic) UIBarButtonItem *shareButton;
@property (nonatomic, strong) GenericTableViewCell *dummyCell;

@end


@implementation ItemsController {
	NSTimer *_progressTimer;
	BOOL _hideSideMarkerLine;
}


+ (void)initialize
{
	NSDictionary *defaults = @{BCNewItemsAtTopOfListKey: @NO};
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
																			   target:self 
																			   action:@selector(addListItem)];
	self.navigationItem.rightBarButtonItem = addButton;
	
//	UIBarButtonItem *actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction 
//																				  target:self 
//																				  action:@selector(showActionSheet:)];
//	actionButton.style = UIBarButtonItemStyleBordered;
//	UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace 
//																				   target:nil 
//																				   action:nil];
//	
//	if ([UIPrintInteractionController isPrintingAvailable]) {
//		[self setToolbarItems:[NSArray arrayWithObjects:actionButton, flexibleSpace, self.editButtonItem, nil]];
//	} else {
//		[self setToolbarItems:[NSArray arrayWithObjects:flexibleSpace, self.editButtonItem, nil]];
//	}
	
	[self addLongPressGestureRecognizer];
	
	self.dummyCell = [self.tableView dequeueReusableCellWithIdentifier:@"ruid_ItemCell"];
	self.dummyCell.titleLabel.text = @"text";
	self.dummyCell.subtitleLabel.text = @"text";
}


- (void)viewWillAppear:(BOOL)animated
{
//	NSAssert(self.selectedURL, @"We should have a selected URL here");
	NSAssert(self.selectedDocument, @"We should have a document here");
	
    [super viewWillAppear:animated];
	
	isBeingPopped = YES;
	
	[self.tableView reloadData];
	self.title = [self.selectedDocument.fileURL bc_filenameWithoutExtension];
	
//	if (!self.selectedDocument) {
//		BListDocument *doc = [[BListDocument alloc] initWithFileURL:self.selectedURL];
//		self.selectedDocument = doc;
//		[doc openWithCompletionHandler:^(BOOL success) {
//			_list = doc.list;
//			dispatch_async(dispatch_get_main_queue(), ^{
//				[self.tableView reloadData];
//			});
//		}];
//	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentStateChanged:)
                                                 name:UIDocumentStateChangedNotification
                                               object:self.selectedDocument];
	
//	NSNumber *isDownloaded = nil;
//	[self.selectedDocument.fileURL getResourceValue:&isDownloaded forKey:NSURLUbiquitousItemDownloadingStatusKey error:nil];
//	NSLog(@"Downloaded? %@", isDownloaded);
	
	__weak ItemsController *weakSelf = self;
	_contentSizeNotificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:UIContentSizeCategoryDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		[weakSelf.tableView reloadData];
	}];
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	[self.navigationController setToolbarHidden:NO animated:YES];
	[self updateToolbar];
	
	if (shouldScrollToInsertedRowAfterRefresh) {
		BOOL newItemsAtTopOfList = [[NSUserDefaults standardUserDefaults] boolForKey:BCNewItemsAtTopOfListKey];
		if (newItemsAtTopOfList) {
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
		} else {
			NSIndexPath *lastRow = [NSIndexPath indexPathForRow:self.selectedDocument.list.items.count - 1 inSection:0];
			[self.tableView scrollToRowAtIndexPath:lastRow atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
		}
		shouldScrollToInsertedRowAfterRefresh = NO;
	}
	
	if (self.shouldShowDownloadProgress) {
		_progressTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.15] interval:0 target:self selector:@selector(timerFireMethod:) userInfo:nil repeats:NO];
		[[NSRunLoop mainRunLoop] addTimer:_progressTimer forMode:NSDefaultRunLoopMode];
		self.navigationItem.rightBarButtonItem.enabled = NO;
		self.editButtonItem.enabled = NO;
		self.shareButton.enabled = NO;
		self.tableView.userInteractionEnabled = NO;
	}
	
	_hideSideMarkerLine = NO;
	[self.tableView reloadData];
}


- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	self.editing = NO;
#warning force update -> we should probably remove this!
	[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	if (isBeingPopped) {
		[self.selectedDocument closeWithCompletionHandler:^(BOOL success) {
			if (success) {
				NSLog(@"Closed document.");
			} else {
				NSLog(@"Something went wrong while closing document.");
			}
		}];
	}
	[self.navigationController setToolbarHidden:YES animated:YES];
	if (_contentSizeNotificationToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_contentSizeNotificationToken];
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDocumentStateChangedNotification object:self.selectedDocument];
	
	_hideSideMarkerLine = YES;
//	[self.tableView reloadData];
}


#pragma mark - Timer

- (void)timerFireMethod:(NSTimer *)theTimer
{
	[MBProgressHUD showHUDAddedTo:self.tableView animated:YES];
}


#pragma mark - Action sheets

- (void)showSharingSheet:(id)sender
{
	if (self.editing) {
		self.editing = NO;
	}
	
	BListDocumentProvider *itemProvider = [[BListDocumentProvider alloc] initWithPlaceholderItem:[NSURL new]];
	itemProvider.data = [self.selectedDocument.list serialize];
	itemProvider.fileName = [self.selectedDocument.fileURL bc_filenameWithoutExtension];
	
	UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[self.printInfo, self.printFormatter, itemProvider] applicationActivities:nil];
	vc.excludedActivityTypes = @[UIActivityTypeMessage];
	[self presentViewController:vc animated:YES completion:nil];
}


- (void)showDeletionActionSheet
{
	UIAlertController *actionController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	UIAlertAction *action1 = [UIAlertAction actionWithTitle:@"Delete List" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
		[self showDeleteListAlert];
	}];
	UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"Delete All Items" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[self showDeleteAllItemsAlert];
	}];
	UIAlertAction *action3 = [UIAlertAction actionWithTitle:@"Delete Checked Items" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[self deleteCheckedItems];
	}];
	UIAlertAction *action4 = [UIAlertAction actionWithTitle:@"Uncheck All Items" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[self uncheckAllItems];
		[self.tableView reloadData];
	}];
	UIAlertAction *action5 = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	[actionController addAction:action1];
	[actionController addAction:action2];
	[actionController addAction:action3];
	[actionController addAction:action4];
	[actionController addAction:action5];
	[self presentViewController:actionController animated:YES completion:nil];
}


- (void)showClearListActionSheet
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		
	}];
	UIAlertAction *uncheckAction = [UIAlertAction actionWithTitle:@"Uncheck All Items" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		[self uncheckAllItems];
		[self.tableView reloadData];
	}];
	[alertController addAction:cancelAction];
	[alertController addAction:uncheckAction];
	[self presentViewController:alertController animated:YES completion:nil];
}


#pragma mark - Alerts

- (void)showClipboardAlert
{
	NSUInteger numberOfItems = [self importItemsFromClipboardCountOnly:YES];
	NSString *message;
	if (numberOfItems == 1) {
		message = @"There is 1 item on the Clipboard. Would you like to add it to this list?";
	} else {
		message = [NSString stringWithFormat:@"There are %lu items on the Clipboard. Would you like to add them to this list?", (unsigned long)numberOfItems];
	}
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Import from Clipboard" message:message preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil];
	UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[self importItemsFromClipboardCountOnly:NO];
		[self.tableView reloadData];
		[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	}];
	[alertController addAction:noAction];
	[alertController addAction:yesAction];
	[self presentViewController:alertController animated:YES completion:nil];
}


- (void)showDeleteListAlert
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Delete List" message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[self deleteList];
	}];
	[alertController addAction:cancelAction];
	[alertController addAction:deleteAction];
	[self presentViewController:alertController animated:YES completion:nil];
}


- (void)showDeleteAllItemsAlert
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Delete All Items" message:@"Are you sure?" preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
	UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[self deleteAllItems];
	}];
	[alertController addAction:cancelAction];
	[alertController addAction:deleteAction];
	[self presentViewController:alertController animated:YES completion:nil];
}


#pragma mark - Printing

- (UIPrintInfo *)printInfo
{
	UIPrintInfo *info = [UIPrintInfo printInfo];
	info.outputType = UIPrintInfoOutputGeneral;
	info.jobName = [self.selectedDocument.fileURL bc_filenameWithoutExtension];
	return info;
}


- (UIMarkupTextPrintFormatter *)printFormatter
{
	NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"print" ofType:@"html"];
	NSMutableString *htmlSource = [[NSMutableString alloc] initWithContentsOfFile:htmlPath
																		 encoding:NSASCIIStringEncoding 
																			error:nil];
	[htmlSource appendFormat:@"<tr><td id=\"listname\">%@</td></tr>", [self.selectedDocument.fileURL bc_filenameWithoutExtension]];
	for (BListItem *item in self.selectedDocument.list.items) {
		NSString *itemName = item.title;
		if (!itemName) {
			itemName = @"-";
		}
		NSString *notes = item.notes;
		if (!notes) {
			notes = @"";
		}
		[htmlSource appendFormat:@"<tr><td class=\"item\"><div class=\"itemname\">%@</div><div class=\"notes\">%@</div></td></tr>",
		 itemName, notes];
	}
	[htmlSource appendString:@"</table></body></html>"];
	
	UIMarkupTextPrintFormatter *formatter = [[UIMarkupTextPrintFormatter alloc] initWithMarkupText:htmlSource];
	
	return formatter;
}


#pragma mark -


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}


#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.selectedDocument.list.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	GenericTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ruid_ItemCell"];
	NSAssert(cell, @"cell can't be nil");
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	BListItem *item = self.selectedDocument.list.items[indexPath.row];
	NSAttributedString *titleString;
	NSAttributedString *notesString;
	if (!item.title) {
		item.title = @"";
	}
	if (!item.notes) {
		item.notes = @"";
	}
	if (item.checked) {
		titleString = [[NSAttributedString alloc] initWithString:item.title attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.80 alpha:1.0]}];
		notesString = [[NSAttributedString alloc] initWithString:item.notes attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.85 alpha:1.0]}];
	} else {
		titleString = [[NSAttributedString alloc] initWithString:item.title attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.0 alpha:1.0]}];
		notesString = [[NSAttributedString alloc] initWithString:item.notes attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.5 alpha:1.0]}];
	}
	cell.titleLabel.attributedText = titleString;
	cell.subtitleLabel.attributedText = notesString;
	
	if (indexPath.row < self.selectedDocument.list.numberOfContiguousCheckedItemsFromTop && !_hideSideMarkerLine) {
		cell.sideMarkerView.backgroundColor = [UIColor colorWithRed:1.000 green:0.285 blue:0.438 alpha:1.000];
	} else {
		cell.sideMarkerView.backgroundColor = [UIColor clearColor];
	}
	
    return cell;
}


- (void)tableView:(UITableView *)tableView willDisplayCell:(GenericTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self configureCell:cell];
	
	BListItem *item = self.selectedDocument.list.items[indexPath.row];
	if (item.checked) {
		cell.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:1.0];
		cell.accessoryType = UITableViewCellAccessoryDetailButton;
	}
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self configureCell:self.dummyCell];
	[self.dummyCell setNeedsLayout];
	[self.dummyCell layoutIfNeeded];
	return MAX(58, 10 + self.dummyCell.titleLabel.bounds.size.height + self.dummyCell.subtitleLabel.bounds.size.height + 11);
}


- (void)detailButtonTapped:(UIControl *)button withEvent:(UIEvent *)event
{
    NSIndexPath * indexPath = [self.tableView indexPathForRowAtPoint:[[[event touchesForView:button] anyObject] locationInView:self.tableView]];
    if (indexPath == nil)
        return;
	
    [self.tableView.delegate tableView:self.tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	GenericTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (tableView.isEditing) {
		cell.sideMarkerView.hidden = YES;
	} else {
		cell.sideMarkerView.hidden = NO;
	}
	return YES;
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[self.selectedDocument.list.items removeObjectAtIndex:indexPath.row];
//		[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
//		[self.selectedDocument autosaveWithCompletionHandler:nil];
		[self.selectedDocument saveToURL:self.selectedDocument.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:nil];
//		[self.selectedList save];
		[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
		[self updateToolbar];
	}
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//		[self.fetchedResultsController.managedObjectContext deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
//    }   
//    else if (editingStyle == UITableViewCellEditingStyleInsert) {
//        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
//    }   
}
//
//
//
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
	id movedItem = [self.selectedDocument.list.items objectAtIndex:fromIndexPath.row];
	[self.selectedDocument.list.items removeObjectAtIndex:fromIndexPath.row];
	[self.selectedDocument.list.items insertObject:movedItem atIndex:toIndexPath.row];
	[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	[tableView reloadData];
}


- (void)configureCell:(GenericTableViewCell *)cell
{
	cell.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
	cell.subtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
}


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	BOOL checked = [self.selectedDocument.list.items[indexPath.row] checked];
	[self.selectedDocument.list.items[indexPath.row] setChecked:!checked];
	[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	[self.tableView reloadData];
}


- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	self.itemDetailController.selectedDocument = self.selectedDocument;
	self.itemDetailController.selectedItem = self.selectedDocument.list.items[indexPath.row];
	self.itemDetailController.newItem = NO;
	isBeingPopped = NO;
	[self.navigationController pushViewController:self.itemDetailController animated:YES];
}


#pragma mark - Actions

- (void)addListItem
{
	if (self.isEditing) {
		self.editing = NO;
	}
	
	BListItem *item = [[BListItem alloc] init];
	BOOL newItemsAtTopOfList = [[NSUserDefaults standardUserDefaults] boolForKey:BCNewItemsAtTopOfListKey];
	if (newItemsAtTopOfList) {
		[self.selectedDocument.list.items insertObject:item atIndex:0];
	} else {
		[self.selectedDocument.list.items addObject:item];
	}
	
	self.itemDetailController.selectedDocument = self.selectedDocument;
	self.itemDetailController.selectedItem = item;
	self.itemDetailController.newItem = YES;
	isBeingPopped = NO;
	[self.navigationController pushViewController:self.itemDetailController animated:YES];
}


- (void)deleteAllItems
{
	if (self.selectedDocument.list.items.count > 0) {
		[self.selectedDocument.list.items removeAllObjects];
		[self.tableView reloadData];
		[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	}
}


- (void)deleteCheckedItems
{
	NSArray *allItems = self.selectedDocument.list.items;
	BOOL shouldSaveDocument = NO;
	for (NSInteger index = allItems.count - 1; index >= 0; index--) {
		BListItem *item = allItems[index];
		if (item.checked) {
			[self.selectedDocument.list.items removeObject:item];
			NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
			[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
			shouldSaveDocument = YES;
		}
	}
	if (shouldSaveDocument) {
		[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	}
}


- (void)uncheckAllItems
{
	for (BListItem *item in self.selectedDocument.list.items) {
		item.checked = NO;
	}
	[self.tableView setEditing:NO animated:YES];
	[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
}


- (void)deleteListAction
{
	if (self.selectedDocument.list.items.count > 0) {
		[self showDeleteListAlert];
	} else {
		[self deleteList];
	}
}


- (void)deleteList
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self.selectedDocument closeWithCompletionHandler:^(BOOL success) {
			NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
			[fc coordinateWritingItemAtURL:self.selectedDocument.fileURL options:NSFileCoordinatorWritingForDeleting error:nil byAccessor:^(NSURL *newURL) {
				NSError *error;
				BOOL success = [[NSFileManager defaultManager] removeItemAtURL:newURL error:&error];
				if (!success) {
					NSLog(@"%@", error.localizedDescription);
				}
			}];
			dispatch_async(dispatch_get_main_queue(), ^{
				if (self.delegate) {
					if ([self.delegate respondsToSelector:@selector(itemsControllerDidDeleteDocument:)]) {
						[self.delegate performSelector:@selector(itemsControllerDidDeleteDocument:) withObject:self.selectedDocument];
					}
				}
				[self.navigationController popViewControllerAnimated:YES];
				
			});
		}];
	});
}


- (void)updateToolbar
{
	if (!self.shareButton) {
		self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
																	 target:self
																	 action:@selector(showSharingSheet:)];
		self.shareButton.style = UIBarButtonItemStylePlain;
	}
	
	UIBarButtonItem *trashButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
																				 target:self
																				 action:@selector(showDeletionActionSheet)];
	trashButton.style = UIBarButtonItemStylePlain;
	
	UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
																				   target:nil 
																				   action:nil];
	UIBarButtonItem *fixedSpaceNarrow = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
																				target:nil
																				action:nil];
	fixedSpaceNarrow.width = 3;
	
	if (self.isEditing) {
		[self setToolbarItems:@[fixedSpaceNarrow, trashButton, flexibleSpace, self.editButtonItem]];
	} else {
		[self setToolbarItems:@[self.shareButton, flexibleSpace, self.editButtonItem]];
	}
}


- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing:editing animated:animated];
	[self updateToolbar];
}


- (NSUInteger)importItemsFromClipboardCountOnly:(BOOL)countOnly
{
	UIPasteboard *pb = [UIPasteboard generalPasteboard];
	NSLog(@"%@", pb.pasteboardTypes);
	NSIndexSet *indexSet = [pb itemSetWithPasteboardTypes:UIPasteboardTypeListString];
	NSLog(@"%@", indexSet);
	NSArray *items = [pb valuesForPasteboardType:@"public.text" inItemSet:indexSet];
	NSLog(@"%@", items);
	if (items.count > 0) {
		NSString *itemsString = items[0];
		itemsString = [itemsString stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		NSArray *separateItems = [itemsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		if (countOnly) {
			return separateItems.count;
		}
		if (separateItems.count > 500) {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Warning" message:@"There are too many items to import" preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				
			}];
			[alertController addAction:defaultAction];
			[self presentViewController:alertController animated:YES completion:nil];
			return separateItems.count;
		}
		for (NSString *item in separateItems) {
			NSString *trimmedItem = [item stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -*"]];
			if (trimmedItem.length > 0) {
				BListItem *listItem = [[BListItem alloc] init];
				listItem.title = trimmedItem;
				[self.selectedDocument.list.items addObject:listItem];
			}
		}
		return separateItems.count;
	}
	return 0;
}


- (void)eraseClipboard
{
	
}


#pragma mark - Accessors

- (ItemDetailController *)itemDetailController
{
	if (!_itemDetailController) {
		UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
		_itemDetailController = [storyboard instantiateViewControllerWithIdentifier:@"sb_ItemDetailScene"];
		_itemDetailController.delegate = self;
	}
	return _itemDetailController;
}


#pragma mark -

- (void)documentStateChanged:(NSNotification *)notification
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	
	if (self.shouldShowDownloadProgress) {
		self.shouldShowDownloadProgress = NO;
		NSLog(@"%@", _progressTimer);
		[_progressTimer invalidate];
		[MBProgressHUD hideHUDForView:self.tableView animated:NO];
		self.navigationItem.rightBarButtonItem.enabled = YES;
		self.editButtonItem.enabled = YES;
		self.shareButton.enabled = YES;
		self.tableView.userInteractionEnabled = YES;
	}
	
	UIDocumentState state = self.selectedDocument.documentState;
    if (state & UIDocumentStateEditingDisabled) {
        // Disable editing in your UI
		NSLog(@"UIDocumentStateEditingDisabled");
    }
	
    if (state & UIDocumentStateInConflict) {
        // Show a discrete indication of a merge conflict
        NSLog(@"UIDocumentStateInConflict");
		NSLog(@"%lu other versions found...", (unsigned long)[[NSFileVersion otherVersionsOfItemAtURL:self.selectedDocument.fileURL] count]);
		[NSFileVersion removeOtherVersionsOfItemAtURL:self.selectedDocument.fileURL error:nil];
//		NSArray *unresolvedVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:self.selectedDocument.fileURL];
//		for (NSFileVersion *version in unresolvedVersions) {
//			version.resolved = YES;
//		}
    }
	
    if (state & UIDocumentStateSavingError) {
        // Document could not be saved
        NSLog(@"UIDocumentStateSavingError");
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Not saved" message:@"There was a problem while saving this list." preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Oops!" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
			
		}];
		[alertController addAction:defaultAction];
		[self presentViewController:alertController animated:YES completion:nil];
		[self.selectedDocument saveToURL:self.selectedDocument.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
			NSLog(@"success on saving: %d", success);
		}];
    }
	
    if (state == UIDocumentStateNormal) {
        // Document is normal
        // Clear any conflict/error indicators in your UI
        NSLog(@"UIDocumentStateNormal");
    }
	
	[self updateToolbar];
	[self.tableView reloadData];
}


#pragma mark - ItemDetailControllerDelegate

- (void)itemDetailControllerDidCreateNewItem
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	shouldScrollToInsertedRowAfterRefresh = YES;
}


#pragma mark -

- (void)addLongPressGestureRecognizer
{
	UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
	gr.delegate = self;
	[self.tableView addGestureRecognizer:gr];
}


- (void)longPressAction:(UILongPressGestureRecognizer *)gestureRecognizer
{
	if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		CGPoint location = [gestureRecognizer locationInView:self.tableView];
		CGRect targetRect = CGRectMake(location.x, location.y, 1, 1);
		[self becomeFirstResponder];
		UIMenuController *menuController = [UIMenuController sharedMenuController];
		[menuController setTargetRect:targetRect inView:self.tableView];
		[menuController setMenuVisible:YES animated:YES];
	}
}


- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
	NSUInteger numberOfItemsOnClipboard = [self importItemsFromClipboardCountOnly:YES];
	if (action == @selector(paste:) && numberOfItemsOnClipboard > 0) {
		return YES;
	}
	return NO;
}


- (void)paste:(id)sender
{
	[self showClipboardAlert];
}


- (BOOL)canBecomeFirstResponder
{
	return YES;
}


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
	if (self.isEditing) {
		return NO;
	}
	return YES;
}

@end
