//
//  ListController.h
//  B-list
//
//  Created by Steven Vandeweghe on 1/30/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ItemsController.h"
#import "ListDetailController.h"

@interface ListController : UIViewController <ItemsControllerDelegate, ListDetailControllerDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (void)importSharedListFromDictionary:(NSDictionary *)listDictionary; // old
- (void)importSharedListFromJSON:(NSURL *)URL; // new
- (void)updateForiCloudStatus;
- (void)moveDocumentsFromLocalToiCloudWithCompletion:(void (^)(void))completion;

@end
