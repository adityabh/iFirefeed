//
//  HomeViewController.h
//  iFirefeed
//
//  Created by Greg Soltis on 4/2/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SparkListViewController.h"

@interface HomeViewController : SparkListViewController

//@property (strong, nonatomic) UINavigationController* navigaationController;
//@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSString* firebaseRoot;

@end
