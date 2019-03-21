//
//  AppDelegate.m
//  B-list
//
//  Created by Steven Vandeweghe on 1/30/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import "AppDelegate.h"
#import "ListController.h"
#import "BList.h"
#import "BListItem.h"
#import "BListDocument.h"
#import "BCBConstants.h"


@interface AppDelegate ()
@end


@implementation AppDelegate {
	NSDictionary *importedListDictionary;
}

@synthesize window = _window;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

@synthesize listController;


+ (void)initialize
{
	NSDictionary *defaults = @{ BCFirstRunKey: @YES, BCDisableAutoCapitalizationKey: @NO };
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// iCloud
	[self initializeiCloudAccess];
	
	// set up window and viewcontrollers
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.tintColor = [UIColor colorWithRed:0 green:174.0/255 blue:239.0/255 alpha:1];
	self.listController = [[ListController alloc] init];
	self.listController.managedObjectContext = self.managedObjectContext;
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:self.listController];
	self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];
	
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	/*
	 Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	 Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	 */
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self cleanInbox];
	
	[self saveContext];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	/*
	 Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	 If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	 */
	
	[self saveContext];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	/*
	 Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	 */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	/*
	 Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	 */
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self checkiCloudStatus];
//	[self.listController updateForiCloudStatus];
	
//	if ([[NSUserDefaults standardUserDefaults] boolForKey:BCSignedOutOfiCloudKey]) {
//		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCSignedOutOfiCloudKey];
//		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"iCloud" message:@"You can now enable iCloud again by tapping the iCloud button." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//		[alert show];
//	}
}

- (void)applicationWillTerminate:(UIApplication *)application
{
//	// Saves changes in the application's managed object context before the application terminates.
//	[self saveContext];
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
        {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}


- (NSArray *)existingListNames
{
	NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"List"];
	NSArray *lists = [self.managedObjectContext executeFetchRequest:request error:nil];
	if (!lists) {
		return nil;
	}
	
	NSMutableArray *names = [NSMutableArray array];
	for (id list in lists) {
		if ([list valueForKey:@"name"]) {
			[names addObject:[list valueForKey:@"name"]];
		}
	}
	return [names copy];
}


//- (NSString *)alternativeNameForExistingName:(NSString *)existingName
//{
//	NSArray *existingNames = [self existingListNames];
//	if (![existingNames containsObject:existingName]) {
//		return existingName;
//	}
//	NSInteger i = 0;
//	NSString *alternativeName = existingName;
//	while ([existingNames containsObject:alternativeName]) {
//		i++;
//		alternativeName = [NSString stringWithFormat:@"%@ (%d)", existingName, i];
//	}
//	return alternativeName;
//}


- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	NSString *extension = [url pathExtension];
	if ([extension isEqualToString:@"B-list"]) {
		NSError *error;
		id list = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfURL:url] options:NSPropertyListImmutable format:NULL error:&error];
		if (list) {
			[self.listController importSharedListFromDictionary:list];
		}
	} else {
		UINavigationController *navController = (id)self.window.rootViewController;
		[navController popToRootViewControllerAnimated:NO];
		[self.listController importSharedListFromJSON:url];
	}
	return YES;
}


#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"B_list" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil)
    {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"B_list.sqlite"];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error])
    {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}



//- (void)migrateCDContent
//{
//	[MBProgressHUD showHUDAddedTo:self.window animated:YES];
//	NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"List"];
//	NSError *error;
//	NSArray *lists = [self.managedObjectContext executeFetchRequest:request error:&error];
//	NSLog(@"Migrating %d lists.", lists.count);
//	for (NSManagedObject *list in lists) {
//		NSString *title = [list valueForKey:@"name"];
//		NSURL *documentURL = [NSURL fileURLWithPath:NSHomeDirectory()];
//		documentURL = [documentURL URLByAppendingPathComponent:[BListDocument documentsFolder] isDirectory:YES];
//		documentURL = [documentURL URLByAppendingPathComponent:title];
//		documentURL = [documentURL URLByAppendingPathExtension:[BListDocument documentExtension]];
//		BListDocument *doc = [[BListDocument alloc] initWithFileURL:documentURL];
//		NSSet *items = [list valueForKey:@"items"];
//		NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES];
//		NSArray *itemsSortedByIndex = [items sortedArrayUsingDescriptors:@[sortDescriptor]];
//		for (NSManagedObject *item in itemsSortedByIndex) {
//			BListItem *newItem = [[BListItem alloc] init];
//			newItem.title = [item valueForKey:@"name"];
//			newItem.notes = [item valueForKey:@"notes"];
//			newItem.checked = [[item valueForKey:@"checked"] boolValue];
//			[doc.list.items addObject:newItem];
//		}
//		[doc saveToURL:doc.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
//			NSLog(@"document saved. success: %d", success);
//			[doc closeWithCompletionHandler:^(BOOL success) {
//				NSLog(@"document closed. success: %d", success);
//			}];
//		}];
//		[self.managedObjectContext deleteObject:list];
//	}
//	[self.managedObjectContext save:nil];
//	[MBProgressHUD hideHUDForView:self.window animated:NO];
//}


/*
Inbox is used for storing emailed attachments.
Cleaning the inbox is needed because we use the filename as the name for the list.
If we don't clean up afterwards, iOS will rename the new if an old one still exists.
 */
- (void)cleanInbox
{
	NSString *inboxPath = [NSString stringWithFormat:@"%@/Documents/Inbox", NSHomeDirectory()];
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:inboxPath];
	[enumerator skipDescendants];
	NSError *error;
	for (NSString *path in enumerator) {
		NSString *fullPath = [inboxPath stringByAppendingPathComponent:path];
		BOOL success = [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&error];
		if (!success) {
			NSLog(@"%@", error.localizedDescription);
		}
	}
}


#pragma mark - iCloud

- (void)initializeiCloudAccess
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		(void)[[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	});
}


- (void)checkiCloudStatus
{
	id currentToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
	NSData *currentTokenData = nil;
	if (currentToken) {
		currentTokenData = [NSKeyedArchiver archivedDataWithRootObject:currentToken];
		[[NSUserDefaults standardUserDefaults] setValue:currentTokenData forKey:BCiCloudTokenKey];
	} else {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:BCiCloudTokenKey];
	}
	NSData *previousTokenData = [[NSUserDefaults standardUserDefaults] valueForKey:BCiCloudPreviousTokenKey];
	[[NSUserDefaults standardUserDefaults] setValue:currentTokenData forKey:BCiCloudPreviousTokenKey];
	BOOL iCloudEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:BCiCloudEnabledKey];
	BOOL previousiCloudEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:BCPreviousiCloudEnabledKey];
	BOOL firstRun = [[NSUserDefaults standardUserDefaults] boolForKey:BCFirstRunKey];
	if (firstRun) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCFirstRunKey];
	}
	NSString *device = [[UIDevice currentDevice] model];
	
	// First run
	if (firstRun) {
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCFirstRunKey];
		if (iCloudEnabled) {
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:BCPreviousiCloudEnabledKey];
		}
		return;
	}
	
	// Switched iCloud on for the app
	if (iCloudEnabled && !previousiCloudEnabled) {
		if (currentToken) {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"iCloud On" message:[NSString stringWithFormat:@"You\u2019re using iCloud. Any lists that are on this %@ will be moved to iCloud and synced with your other devices.", device] preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[self.listController moveDocumentsFromLocalToiCloudWithCompletion:nil];
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:BCPreviousiCloudEnabledKey];
				[self.listController.navigationController popToRootViewControllerAnimated:YES];
				[self.listController updateForiCloudStatus];
			}];
			[alertController addAction:defaultAction];
			[self.listController presentViewController:alertController animated:YES completion:nil];
		} else {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"iCloud Off" message:[NSString stringWithFormat:@"iCloud is not enabled on this %@. Use the Settings app to switch iCloud on for Documents & Data.", device] preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCiCloudEnabledKey];
				[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCPreviousiCloudEnabledKey];
				[self.listController.navigationController popToRootViewControllerAnimated:YES];
				[self.listController updateForiCloudStatus];
			}];
			[alertController addAction:defaultAction];
			[self.listController presentViewController:alertController animated:YES completion:nil];
		}
		return;
	}
	
	// Switched iCloud off for the app
	if (!iCloudEnabled && previousiCloudEnabled) {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"iCloud Off" message:@"You\u2019ve switched iCloud off. Any lists that are stored in iCloud will be unavailable until iCloud is enabled again." preferredStyle:UIAlertControllerStyleAlert];
		UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:BCiCloudPreviousTokenKey];
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCPreviousiCloudEnabledKey];
			[self.listController.navigationController popToRootViewControllerAnimated:YES];
			[self.listController updateForiCloudStatus];
		}];
		[alertController addAction:defaultAction];
		[self.listController presentViewController:alertController animated:YES completion:nil];
		return;
	}
	
	// Switched iCloud off for the device
	if (previousTokenData && !currentToken) {
		if (iCloudEnabled) {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"iCloud Off" message:[NSString stringWithFormat:@"iCloud is not enabled on this %@. Use the Settings app to switch iCloud on for Documents & Data.", device] preferredStyle:UIAlertControllerStyleAlert];
			UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCiCloudEnabledKey];
				[[NSUserDefaults standardUserDefaults] setBool:NO forKey:BCPreviousiCloudEnabledKey];
				[self.listController.navigationController popToRootViewControllerAnimated:YES];
				[self.listController updateForiCloudStatus];
			}];
			[alertController addAction:defaultAction];
			[self.listController presentViewController:alertController animated:YES completion:nil];
			return;
		}
	}
	
	if (previousTokenData && currentTokenData && !([currentTokenData isEqualToData:previousTokenData])) {
		if (iCloudEnabled) {
			[self.listController updateForiCloudStatus];
			return;
		}
	}
}


#pragma mark - Use for testing

- (void)populateCoreDataWithTestData
{
	NSManagedObject *list1 = [NSEntityDescription insertNewObjectForEntityForName:@"List" inManagedObjectContext:self.managedObjectContext];
	[list1 setValue:@"list A" forKey:@"name"];
	NSManagedObject *item1 = [NSEntityDescription insertNewObjectForEntityForName:@"ListItem" inManagedObjectContext:self.managedObjectContext];
	[item1 setValue:@0 forKey:@"index"];
	[item1 setValue:@"item 1" forKey:@"name"];
	[item1 setValue:@"notes 1" forKey:@"notes"];
	[item1 setValue:@NO forKey:@"checked"];
	NSManagedObject *item2 = [NSEntityDescription insertNewObjectForEntityForName:@"ListItem" inManagedObjectContext:self.managedObjectContext];
	[item2 setValue:@1 forKey:@"index"];
	[item2 setValue:@"item 2" forKey:@"name"];
	[item2 setValue:@"notes 2" forKey:@"notes"];
	[item2 setValue:@YES forKey:@"checked"];
	[list1 setValue:[NSSet setWithArray:@[item1, item2]] forKey:@"items"];
	NSManagedObject *list2 = [NSEntityDescription insertNewObjectForEntityForName:@"List" inManagedObjectContext:self.managedObjectContext];
	[list2 setValue:@"list A" forKey:@"name"]; // use an existing name to test the renaming of lists
	[self.managedObjectContext save:nil];
}

@end
