//
//  SparkListViewController.h
//  iFirefeed
//
//  Created by Greg Soltis on 4/9/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Firefeed.h"

@interface SparkListViewController : UIViewController

- (void) hideTabBar:(UITabBarController *)tabbarcontroller;
- (void) showTabBar:(UITabBarController *)tabbarcontroller;
- (void) startComposing;
- (void) logout;
// Override this
- (NSString *) title;

- (void) showLoggedInUI;
- (void) showLoggedOutUI;

- (void) userDidUpdate:(FirefeedUser *)user;

@property (strong, nonatomic) Firefeed* firefeed;
@property (weak, nonatomic) IBOutlet UITableView* tableView;
@property (strong, nonatomic) NSString* currentFeedId;

@end
