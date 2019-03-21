//
//  BCListDocument.h
//  B-list
//
//  Created by Steven Vandeweghe on 3/26/13.
//  Copyright (c) 2013 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BListDocumentDelegate;
@class BList;

@interface BListDocument : UIDocument

@property (strong, nonatomic) BList *list;
@property (weak, nonatomic) id<BListDocumentDelegate> delegate;

+ (NSString *)documentExtension;
+ (NSString *)documentsFolder;
+ (void)createNewDocumentWithTitle:(NSString *)title list:(BList *)list iniCloud:(BOOL)iCloud completion:(void (^)(BListDocument *doc))completion;
+ (NSString *)cleanedUpTitle:(NSString *)title;
+ (BOOL)iCloudEnabled;

@end



@protocol BListDocumentDelegate <NSObject>

@optional
- (void)documentContentsDidChange:(BListDocument *)document;

@end
