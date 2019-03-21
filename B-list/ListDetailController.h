//
//  ListDetailController.h
//  B-list
//
//  Created by Steven Vandeweghe on 1/30/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BListDocument;

@interface ListDetailController : UIViewController

@property (nonatomic, copy) NSString *listName;

@property (nonatomic, assign) BOOL createdNewList;

@property (nonatomic, strong) NSURL *selectedURL;

@property (weak, nonatomic) id delegate;

@property (strong, nonatomic) NSArray *existingURLs;

@end



@protocol ListDetailControllerDelegate <NSObject>

- (void)createdNewDocument:(BListDocument *)document;
- (void)changedListWithProposedTitle:(NSString *)proposedTitle;

@end
