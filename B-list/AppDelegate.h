//
//  AppDelegate.h
//  B-list
//
//  Created by Steven Vandeweghe on 1/30/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ListController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, NSNetServiceDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, strong) ListController *listController;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
