//
//  SparkListViewController.m
//  iFirefeed
//
//  Created by Greg Soltis on 4/9/13.
//  Copyright (c) 2013 Firebase. All rights reserved.
//

#import "SparkListViewController.h"
#import "ComposeViewController.h"
#import "ProfileViewController.h"
#import "SparkCell.h"

@interface SparkListViewController () <ComposeViewControllerDelegate, FirefeedDelegate>

@property (strong, nonatomic) NSMutableArray* sparks;
@property (strong, nonatomic) UIColor* textColor;

@end

@implementation SparkListViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.firefeed = [[Firefeed alloc] initWithUrl:kFirebaseRoot];
        self.firefeed.delegate = self;
        self.sparks = [[NSMutableArray alloc] init];
        self.textColor = [UIColor colorWithRed:0x7b / 255.0f green:0x5f / 255.0f blue:0x11 / 255.0f alpha:1.0f];
    }
    return self;
}

- (NSString *) title {
    return @"Override me";
}

- (UINavigationItem *) navigationItem {
    UINavigationItem* item = [super navigationItem];
    UILabel* titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100.0f, 44.0f)];
    titleLabel.text = [self title];
    titleLabel.textColor = self.textColor;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    item.titleView = titleLabel;
    return item;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //self.tableView.autoresizingMask = UIViewAutoresizingNone;
    self.tableView.separatorColor = self.textColor;
    self.tableView.rowHeight = 72.0f;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) logout {
    [self.firefeed logout];
}


- (void) showLoggedInUI {
    UIBarButtonItem* newSparkButton = [[UIBarButtonItem alloc] initWithTitle:@"Spark" style:UIBarButtonItemStylePlain target:self action:@selector(startComposing)];
    UIBarButtonItem* logoutButton = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];
    [[self.tabBarController.tabBar.items objectAtIndex:1] setEnabled:NO];
    self.navigationItem.rightBarButtonItem = newSparkButton;
    self.navigationItem.leftBarButtonItem = logoutButton;
    [[self.tabBarController.tabBar.items objectAtIndex:0] setEnabled:YES];
    [[self.tabBarController.tabBar.items objectAtIndex:1] setEnabled:YES];
    if (self.currentFeedId) {
        [self.firefeed stopObservingTimeline:self.currentFeedId];
    }
    [self.sparks removeAllObjects];
}

- (void) showLoggedOutUI {
    // Override
}

- (void) loginStateDidChange:(FirefeedUser *)user {
    if (user) {
        [self showLoggedInUI];
    } else {
        [self showLoggedOutUI];
    }
}

// Some tabbar animation stuff. Let's us have our own tab bar in navigator subviews
- (void) viewWillAppear:(BOOL)animated {
    [self showTabBar:self.tabBarController];
}

- (void) viewDidAppear:(BOOL)animated {
    [self.tableView reloadData];
}

- (void) hideTabBar:(UITabBarController *)tabbarcontroller {
    NSMutableArray* otherViews = [[NSMutableArray alloc] init];
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.35];
    CGFloat hiddenX = -self.view.frame.size.width;

    for(UIView *view in tabbarcontroller.view.subviews)
    {
        if ([view isKindOfClass:[UITabBar class]]) {
            [view setFrame:CGRectMake(hiddenX, view.frame.origin.y, view.frame.size.width, view.frame.size.height)];
        } else {
            [otherViews addObject:view];
        }
    }

    [UIView commitAnimations];
    CGFloat height = self.tabBarController.view.frame.size.height;
    for (UIView* view in otherViews) {
        [view setFrame:CGRectMake(view.frame.origin.x, view.frame.origin.y, view.frame.size.width, height)];
    }
}

- (void)showTabBar:(UITabBarController *) tabbarcontroller {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.35];
    for(UIView *view in tabbarcontroller.view.subviews)
    {
        if ([view isKindOfClass:[UITabBar class]]) {
            [view setFrame:CGRectMake(0, view.frame.origin.y, view.frame.size.width, view.frame.size.height)];
        }
    }
    
    [UIView commitAnimations];
}

- (void) startComposing {
    ComposeViewController* composeView = [[ComposeViewController alloc] init];
    composeView.delegate = self;
    [composeView presentFromRootViewControllerWithText:@"" submitButtonTitle:@"Post" headerTitle:@"New Spark" characterLimit:141];
}

- (void) composeViewController:(ComposeViewController *)composeViewController didFinishWithText:(NSString *)text {
    if (text) {
        // Post the text
        [self.firefeed postSpark:text completionBlock:^(NSError *err) {
            // TODO: a toast here?
        }];
    } else {
        // user cancelled
    }
    [composeViewController dismissViewControllerAnimated:YES completion:nil];
}


- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 72.0f;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)aTableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    return self.sparks.count;
}

- (void) showProfileForButton:(UIButton *)button {
    NSInteger index = button.tag;
    FirefeedSpark* spark = [self.sparks objectAtIndex:(self.sparks.count - index - 1)];
    ProfileViewController* profileViewController = [[ProfileViewController alloc] initWithNibName:@"ProfileViewController" bundle:nil];
    profileViewController.userId = spark.authorId;
    [self hideTabBar:self.tabBarController];
    [self.navigationController pushViewController:profileViewController animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    SparkCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        NSArray *nib =  [[NSBundle mainBundle] loadNibNamed:@"SparkCell" owner:self options: nil];
        cell = [nib objectAtIndex:0];
    }

    // Put in reverse order
    FirefeedSpark* spark = [self.sparks objectAtIndex:(self.sparks.count - indexPath.row - 1)];
    [cell configureForSpark:spark atRow:indexPath.row target:self selector:@selector(showProfileForButton:)];

    return cell;
}

- (void) userDidUpdate:(FirefeedUser *)user {
    
}

- (void) spark:(NSDictionary *)spark wasAddedToTimeline:(NSString *)timeline {
    [self.sparks addObject:spark];
    [self.tableView reloadData];
}

- (void) spark:(NSDictionary *)spark wasOverflowedFromTimeline:(NSString *)timeline {

}

- (void) follower:(FirefeedUser *)follower startedFollowing:(FirefeedUser *)followee {
    // No-op?
}

- (void) follower:(FirefeedUser *)follower stoppedFollowing:(FirefeedUser *)followee {
    // No-op?
}

@end
