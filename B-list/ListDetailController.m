//
//  ListDetailController.m
//  B-list
//
//  Created by Steven Vandeweghe on 1/30/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import "ListDetailController.h"
#import "BList.h"
#import "BListDocument.h"
#import "ItemsController.h"
#import "NSURL+Extras.h"
#import "BListDocument+Extras.h"
#import "B_list-Swift.h"
#import "ListDetailTableViewController.h"
#import "BCBConstants.h"


enum {
	kNameSection,
	kActionsSection,
	kNumberOfSections
};


@interface ListDetailController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) ListDetailTableViewController *tableViewController;

@property (nonatomic, strong) GenericTableViewCell *nameCell;

@end



@implementation ListDetailController {
	BOOL _movingToList;
	id _contentSizeNotificationToken;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:_contentSizeNotificationToken];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	self.title = @"List";
	
	self.nameCell = [self.tableViewController.tableView dequeueReusableCellWithIdentifier:@"ruid_NameCell"];
	self.nameCell.titleTextField.delegate = self;
	BOOL disableAutoCapitalization = [[NSUserDefaults standardUserDefaults] boolForKey:BCDisableAutoCapitalizationKey];
	if (disableAutoCapitalization) {
		self.nameCell.titleTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	}
	
	__weak ListDetailController *weakSelf = self;
	_contentSizeNotificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:UIContentSizeCategoryDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
		[weakSelf.tableViewController.tableView reloadData];
	}];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
	if (self.createdNewList) {
		self.nameCell.titleTextField.text = @"";
	} else {
		self.nameCell.titleTextField.text = [self.selectedURL bc_filenameWithoutExtension];
	}
}


- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	if (self.createdNewList) {
		[self.nameCell.titleTextField becomeFirstResponder];
	}
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
	
//	[self.view endEditing:YES];
	
	if (_movingToList) {
		_movingToList = NO;
		return;
	}
	
	NSString *trimmedTitle = [self.nameCell.titleTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	trimmedTitle = [BListDocument cleanedUpTitle:trimmedTitle];
	if (trimmedTitle.length == 0) {
		return;
	}
	
	if (self.createdNewList) {
		self.createdNewList = NO;
		trimmedTitle = [BListDocument bcb_alternativeNameForProposedName:trimmedTitle withExistingURLs:self.existingURLs];
		[BListDocument createNewDocumentWithTitle:trimmedTitle list:nil iniCloud:[BListDocument iCloudEnabled] completion:^(BListDocument *doc) {
			NSLog(@"delegate: %@", self.delegate);
			if ([self.delegate respondsToSelector:@selector(createdNewDocument:)]) {
				[self.delegate performSelector:@selector(createdNewDocument:) withObject:doc];
			}
			[doc closeWithCompletionHandler:nil];
//			[doc closeWithCompletionHandler:^(BOOL success) {
//				if ([self.delegate respondsToSelector:@selector(createdNewDocument:)]) {
//					[self.delegate performSelector:@selector(createdNewDocument:) withObject:doc];
//				}
//			}];
		}];
	} else {
		if (![[self.selectedURL bc_filenameWithoutExtension] isEqualToString:trimmedTitle]) {
			if ([self.delegate respondsToSelector:@selector(changedListWithProposedTitle:)]) {
				[self.delegate performSelector:@selector(changedListWithProposedTitle:) withObject:trimmedTitle];
			}
		}
	}
	
	if (_contentSizeNotificationToken) {
		[[NSNotificationCenter defaultCenter] removeObserver:_contentSizeNotificationToken];
	}
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}


#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField.text.length == 0) {
		return NO;
	}
	if (self.createdNewList) {
		[self createNewListWithProposedTitle:self.nameCell.titleTextField.text copyFromList:nil completion:nil];
	} else {
		[self.navigationController popViewControllerAnimated:YES];
	}
	return YES;
}


#pragma mark - <UITableViewDelegate, UITableViewDataSource>

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (self.createdNewList) {
		return 1;
	} else {
		return kNumberOfSections;
	}
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case kNameSection:
			return 1;
		case kActionsSection:
			return 2;
		default:
			return 0;
	}
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	GenericTableViewCell *cell;
	
	switch (indexPath.section) {
		case kNameSection:
			cell = self.nameCell;
			break;
		case kActionsSection:
			cell = [tableView dequeueReusableCellWithIdentifier:@"ruid_ActionCell" forIndexPath:indexPath];
			switch (indexPath.row) {
				case 0:
					cell.titleLabel.text = @"Uncheck all Items";
					break;
				case 1:
					cell.titleLabel.text = @"Duplicate List";
					break;
				default:
					break;
			}
			break;
		default:
			break;
	}
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	NSAssert(self.selectedURL, @"We should have a URL here.");
	
	switch (indexPath.row) {
		case 0: {
			// uncheck all items
			BListDocument *doc = [[BListDocument alloc] initWithFileURL:self.selectedURL];
			UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
			ItemsController *itemsController = [storyboard instantiateViewControllerWithIdentifier:@"sb_Items"];
			itemsController.delegate = self.delegate;
			itemsController.selectedDocument = doc;
			_movingToList = YES;
			NSArray *viewControllers = self.navigationController.viewControllers;
			[self.navigationController setViewControllers:@[viewControllers[0], itemsController] animated:YES];
			[doc openWithCompletionHandler:^(BOOL success) {
				[itemsController uncheckAllItems];
			}];
			break;
		}
		case 1: {
			// duplicate list
			BListDocument *doc = [[BListDocument alloc] initWithFileURL:self.selectedURL];
			[self createNewListWithProposedTitle:[self.selectedURL bc_filenameWithoutExtension] copyFromList:doc completion:nil];
			break;
		}
			
		default:
			break;
	}
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 50;
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section == kActionsSection) {
		return 30;
	}
	return 0;
}


#pragma mark - Helpers

- (void)createNewListWithProposedTitle:(NSString *)title copyFromList:(BListDocument *)listDocument completion:(dispatch_block_t)completionBlock
{
	NSString *trimmedTitle = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *uniqueTitle = [BListDocument bcb_alternativeNameForProposedName:trimmedTitle withExistingURLs:self.existingURLs];
	[BListDocument createNewDocumentWithTitle:uniqueTitle list:nil iniCloud:[BListDocument iCloudEnabled] completion:^(BListDocument *doc) {
		if (listDocument) {
			[listDocument openWithCompletionHandler:^(BOOL success) {
				if (success) {
					NSMutableArray *items = [[NSMutableArray alloc] initWithArray:listDocument.list.items];
					doc.list.items = items;
				}
				[listDocument closeWithCompletionHandler:nil];
			}];
		}
		if ([self.delegate respondsToSelector:@selector(createdNewDocument:)]) {
			[self.delegate performSelector:@selector(createdNewDocument:) withObject:doc];
		}
		UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
		ItemsController *itemsController = [storyboard instantiateViewControllerWithIdentifier:@"sb_Items"];
		itemsController.delegate = self.delegate;
		itemsController.selectedDocument = doc;
		_movingToList = YES;
		NSArray *viewControllers = self.navigationController.viewControllers;
		[self.navigationController setViewControllers:@[viewControllers[0], itemsController] animated:YES];
	}];
}


#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	ListDetailTableViewController *vc = (id)segue.destinationViewController;
	vc.tableView.delegate = self;
	vc.tableView.dataSource = self;
	self.tableViewController = vc;
}

@end
