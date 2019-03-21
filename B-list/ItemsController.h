//
//  ItemsController.h
//  B-list
//
//  Created by Steven Vandeweghe on 1/31/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "ItemDetailController.h"

extern NSString * const BCNewItemsAtTopOfListKey;

@class BListDocument;


@interface ItemsController : UITableViewController <UIActionSheetDelegate, MFMailComposeViewControllerDelegate, ItemDetailControllerDelegate>

@property (strong, nonatomic) BListDocument *selectedDocument;
@property (assign, nonatomic) BOOL shouldShowDownloadProgress;
@property (weak, nonatomic) id delegate;

- (void)uncheckAllItems;

@end


@protocol ItemsControllerDelegate <NSObject>

- (void)itemsControllerDidDeleteDocument:(BListDocument *)doc;

@end
