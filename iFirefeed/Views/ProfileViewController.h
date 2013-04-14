//
//  ProfileViewController.h
//  iFirefeed
//
//  Created by Greg Soltis on 4/4/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Firefeed.h"
#import "MOGlassButton.h"

@interface ProfileViewController : UIViewController

@property (strong, nonatomic) NSString* userId;

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIImageView *profileImage;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITabBar *tabBar;
@property (weak, nonatomic) IBOutlet UITextView *bioTextView;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet MOGlassButton *actionButton;
@property (weak, nonatomic) IBOutlet UITabBarItem *sparksTab;
@property (weak, nonatomic) IBOutlet UITabBarItem *followingTab;
@property (weak, nonatomic) IBOutlet UITabBarItem *followersTab;

@end
