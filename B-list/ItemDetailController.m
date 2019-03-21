//
//  ItemDetailController.m
//  B-list
//
//  Created by Steven Vandeweghe on 2/2/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import "ItemDetailController.h"
#import "BList.h"
#import "BListItem.h"
#import "BListDocument.h"
#import "BListHistoryDocument.h"
#import "ItemsController.h"
#import "B_list-Swift.h"
#import "BCBConstants.h"

enum {
	kMainSection,
	kHistorySection,
	kNumberOfSections
};


@interface ItemDetailController () {
	NSMutableArray *_historyForFiltering;
	NSArray *_filteredHistory;
	id _contentSizeNotificationToken;
}

@property (nonatomic, strong) GenericTableViewCell *nameCell;
@property (nonatomic, strong) GenericTableViewCell *notesCell;

@property (strong, nonatomic) BListHistoryDocument *historyDocument;

@end


@implementation ItemDetailController


- (void)dealloc
{
	if (_contentSizeNotificationToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_contentSizeNotificationToken];
	}
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
																			   target:self 
																			   action:@selector(addListItem)];
	self.navigationItem.rightBarButtonItem = addButton;
	
	__weak __typeof(self) weakSelf = self;
	_contentSizeNotificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:UIContentSizeCategoryDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		[weakSelf.tableView reloadData];
	}];
	
	self.nameCell = [self.tableView dequeueReusableCellWithIdentifier:@"ruid_NameCell"];
	self.notesCell = [self.tableView dequeueReusableCellWithIdentifier:@"ruid_NotesCell"];
	
	BOOL disableAutoCapitalization = [[NSUserDefaults standardUserDefaults] boolForKey:BCDisableAutoCapitalizationKey];
	if (disableAutoCapitalization) {
		self.nameCell.titleTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.notesCell.titleTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	}
}


- (void)viewWillAppear:(BOOL)animated
{
	NSAssert(self.selectedDocument, @"There should be a selected document");
	NSAssert(self.selectedItem, @"There should be a selected item");
	
	[super viewWillAppear:animated];
	
	if (self.newItem) {
		self.title = @"New Item";
	} else {
		self.title = @"Edit Item";
	}
	
	self.nameCell.titleTextField.text = self.selectedItem.title;
	self.notesCell.titleTextField.text = self.selectedItem.notes;
	[self openHistoryDocument];
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self.nameCell.titleTextField becomeFirstResponder];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
	
	if (self.nameCell.titleTextField.text.length == 0 && self.notesCell.titleTextField.text.length == 0) {
		// don't do anything if no data is entered
		[self.selectedDocument.list.items removeObject:self.selectedItem];
	} else {
//		self.selectedItem.title = self.notesCell.titleTextField.text;
		[self storeCurrentItem];
		if (self.newItem) {
			if (self.delegate && [self.delegate respondsToSelector:@selector(itemDetailControllerDidCreateNewItem)]) {
				[self.delegate performSelector:@selector(itemDetailControllerDidCreateNewItem)];
			}
		}
//		[self.selectedDocument saveToURL:self.selectedDocument.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:nil];
	}
	
	[self closeHistoryDocument];
	
	if (_contentSizeNotificationToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_contentSizeNotificationToken];
	}
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return kNumberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == kMainSection) {
		return 2;
	} else {
		return _filteredHistory.count;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == kMainSection) {
		if (indexPath.row == 0) {
			NSAssert(self.nameCell, @"name cell shouldn't be nil");
			return self.nameCell;
		} else {
			NSAssert(self.notesCell, @"notes cell shouldn't be nil");
			return self.notesCell;
		}
	} else {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ruid_HistoryCell" forIndexPath:indexPath];
		NSAssert(cell, @"history cell shouldn't be nil");
		cell.textLabel.text = [_filteredHistory objectAtIndex:indexPath.row];
		return cell;
	}
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == kHistorySection) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		NSString *itemTitle = [_filteredHistory objectAtIndex:indexPath.row];
		self.nameCell.titleTextField.text = itemTitle;
		[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kMainSection] atScrollPosition:UITableViewScrollPositionTop animated:YES];
		[self updateFilteredHistoryForItemTitle:itemTitle];
		[self reloadFilterTable];
	}
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == kHistorySection) {
		return YES;
	}
	return NO;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == kHistorySection) {
		NSString *text = [_filteredHistory objectAtIndex:indexPath.row];
		[self.historyDocument.history removeObject:text];
		[self.historyDocument updateChangeCount:UIDocumentChangeDone];
		[_historyForFiltering removeObject:text];
		[self updateFilteredHistoryForItemTitle:self.nameCell.titleTextField.text];
		[self reloadFilterTable];
	}
}


#pragma mark - TextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	if (![textField.text isEqualToString:self.selectedItem.title]) {
		[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	}
	[self.navigationController popViewControllerAnimated:YES];
	return YES;
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	if (textField == self.nameCell.titleTextField) {
		NSString *changedText = [textField.text stringByReplacingCharactersInRange:range withString:string];
		[self updateFilteredHistoryForItemTitle:changedText];
		[self reloadFilterTable];
	}
	return YES;
}


- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	if (textField == self.nameCell.titleTextField) {
		[self updateFilteredHistoryForItemTitle:textField.text];
	} else {
		_filteredHistory = [NSArray array];
	}
	[self reloadFilterTable];
	return YES;
}


#pragma mark -

- (void)storeCurrentItem
{
	NSString *newName = [self.nameCell.titleTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
//	if (newName.length == 0) {
//		newName = @"New Item";
//	}
	
	if (![newName isEqualToString:self.selectedItem.title] || ![self.notesCell.titleTextField.text isEqualToString:self.selectedItem.notes]) {
		self.selectedItem.title = newName;
		self.selectedItem.notes = self.notesCell.titleTextField.text;
		[self.selectedDocument updateChangeCount:UIDocumentChangeDone];
	}
	
	if (self.historyDocument) {
		if (![self.historyDocument.history containsObject:newName] && newName.length > 2) {
			NSLog(@"Adding item %@ to history.", newName);
			[self.historyDocument.history addObject:newName];
			[self.historyDocument updateChangeCount:UIDocumentChangeDone];
		}
	}
}


- (void)addListItem
{
	// don't do anything if no data is entered
	if (self.nameCell.titleTextField.text.length == 0 && self.notesCell.titleTextField.text.length == 0) {
		return;
	}
	
	if (self.newItem) {
		if (self.delegate && [self.delegate respondsToSelector:@selector(itemDetailControllerDidCreateNewItem)]) {
			[self.delegate performSelector:@selector(itemDetailControllerDidCreateNewItem)];
		}
	}
	
	[UIView animateWithDuration:0.1 animations:^{
		self.nameCell.alpha = 0.0;
		self.notesCell.alpha = 0.0;
	} completion:^(BOOL finished) {
		NSLog(@"%d", finished);
		// save the current item
		[self storeCurrentItem];
		[self.selectedDocument saveToURL:self.selectedDocument.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:nil];
		
		// create a new item
		BListItem *item = [[BListItem alloc] init];
		BOOL newItemsAtTopOfList = [[NSUserDefaults standardUserDefaults] boolForKey:BCNewItemsAtTopOfListKey];
		if (newItemsAtTopOfList) {
			[self.selectedDocument.list.items insertObject:item atIndex:0];
		} else {
			[self.selectedDocument.list.items addObject:item];
		}
		self.selectedItem = item;
		
		// clean up the text fields
		self.nameCell.titleTextField.text = @"";
		self.notesCell.titleTextField.text = @"";
		[self.nameCell.titleTextField becomeFirstResponder];
		
		[UIView animateWithDuration:0.0 animations:^{
			self.nameCell.alpha = 1.0;
			self.notesCell.alpha = 1.0;
		} completion:^(BOOL finished) {
			
		}];
	}];
}


- (void)openHistoryDocument
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL *historyURL;
		if ([BListDocument iCloudEnabled]) {
			historyURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
			historyURL = [historyURL URLByAppendingPathComponent:@"Documents"];
		} else {
			historyURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]];
		}
		historyURL = [historyURL URLByAppendingPathComponent:@"history.json"];
		BListHistoryDocument *doc = [[BListHistoryDocument alloc] initWithFileURL:historyURL];
		self.historyDocument = doc;
		if ([[NSFileManager defaultManager] fileExistsAtPath:historyURL.path]) {
			NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL:historyURL];
			NSArray *otherVersions = [NSFileVersion otherVersionsOfItemAtURL:historyURL];
			if (otherVersions.count > 0) {
				NSLog(@"%lu other versions of history file found", (unsigned long)otherVersions.count);
				[NSFileVersion removeOtherVersionsOfItemAtURL:historyURL error:nil];
				currentVersion.resolved = YES;
			}
			[doc openWithCompletionHandler:^(BOOL success) {
				if (success) {
					NSArray *sortedHistory = [doc.history copy];
					sortedHistory = [sortedHistory sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
						return [obj1 compare:obj2 options:NSCaseInsensitiveSearch | NSNumericSearch];
					}];
					_historyForFiltering = [sortedHistory mutableCopy];
					for (BListItem *item in self.selectedDocument.list.items) {
						[_historyForFiltering removeObject:item.title];
					}
					dispatch_async(dispatch_get_main_queue(), ^{
						[self reloadFilterTable];
					});
				}
			}];
		} else {
			[doc saveToURL:doc.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
				// TODO: reload?
			}];
		}
	});
}


- (void)closeHistoryDocument
{
	if (self.historyDocument) {
		if (self.historyDocument.documentState & UIDocumentStateInConflict) {
			[NSFileVersion removeOtherVersionsOfItemAtURL:self.historyDocument.fileURL error:nil];
		}
		[self.historyDocument closeWithCompletionHandler:nil];
		self.historyDocument = nil;
	}
}


- (void)updateFilteredHistoryForItemTitle:(NSString *)itemTitle
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] %@", itemTitle];
	_filteredHistory = [_historyForFiltering filteredArrayUsingPredicate:predicate];
	if (_filteredHistory.count == 1 && [_filteredHistory[0] isEqualToString:itemTitle]) {
		_filteredHistory = [NSArray array];
	}
}


#pragma mark - Helper stuff

- (void)reloadFilterTable
{
	NSIndexSet *one = [NSIndexSet indexSetWithIndex:kHistorySection];
	[self.tableView reloadSections:one withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end
