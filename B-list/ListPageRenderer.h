//
//  ListPageRenderer.h
//  B-list
//
//  Created by Steven Vandeweghe on 2/6/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ListPageRenderer : UIPrintPageRenderer

@property (nonatomic, strong) NSManagedObject *list;

@end
