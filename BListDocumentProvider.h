//
//  BListDocumentProvider.h
//  B-list
//
//  Created by Steven Vandeweghe on 04/04/15.
//  Copyright (c) 2015 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BListDocumentProvider : UIActivityItemProvider

@property (nonatomic, strong) NSData *data;
@property (nonatomic, copy) NSString *fileName;

@end
