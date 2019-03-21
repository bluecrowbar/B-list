//
//  ItemDetailController.h
//  B-list
//
//  Created by Steven Vandeweghe on 2/2/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BListItem, BListDocument;

@interface ItemDetailController : UITableViewController <UITextFieldDelegate>

@property (strong, nonatomic) BListDocument *selectedDocument;
@property (strong, nonatomic) BListItem *selectedItem;

@property (assign, nonatomic) BOOL newItem;

@property (weak, nonatomic) id delegate;

@end


@protocol ItemDetailControllerDelegate <NSObject>

- (void)itemDetailControllerDidCreateNewItem;

@end