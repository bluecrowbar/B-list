//
//  SettingsViewController.h
//  B-list
//
//  Created by Steven Vandeweghe on 2/8/12.
//  Copyright (c) 2012 Blue Crowbar. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet UITableViewCell *cloudCell;

- (IBAction)close:(id)sender;

@end
