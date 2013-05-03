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
#import "UserSearchViewController.h"
#import "SparkCell.h"
#import "FirefeedAuth.h"
#import "NSMutableArray+Sorted.h"

@interface SparkListViewController () <ComposeViewControllerDelegate, FirefeedDelegate, UserSearchDelegate>

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

- (UIBarButtonItem *) leftBarButton {
    return [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];
}

- (void) showLoggedInUI {
    UIBarButtonItem* newSparkButton = [[UIBarButtonItem alloc] initWithTitle:@"Spark" style:UIBarButtonItemStylePlain target:self action:@selector(startComposing)];

    [[self.tabBarController.tabBar.items objectAtIndex:1] setEnabled:NO];
    self.navigationItem.rightBarButtonItem = newSparkButton;
    self.navigationItem.leftBarButtonItem = [self leftBarButton];
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

- (void) viewWillAppear:(BOOL)animated {
    CGFloat height = self.view.frame.size.height;
    CGRect tableFrame = self.tableView.frame;
    tableFrame.size.height = height;
    tableFrame.size.width = self.view.frame.size.width;
    self.tableView.frame = tableFrame;
}

- (void) viewDidAppear:(BOOL)animated {
    [self.tableView reloadData];
}

- (void) startSearch {
    UserSearchViewController* searchController = [[UserSearchViewController alloc] initWithNibName:nil bundle:nil];
    searchController.firefeedSearch = [self.firefeed searchAdapter];
    searchController.delegate = self;
    [self.navigationController pushViewController:searchController animated:YES];
}

- (void) userWasSelected:(NSString *)userId {
    [self.navigationController popViewControllerAnimated:NO];
    ProfileViewController* profileViewController = [[ProfileViewController alloc] initWithNibName:@"ProfileViewController" bundle:nil];
    profileViewController.userId = userId;
    [self.navigationController pushViewController:profileViewController animated:YES];
}

- (void) searchWasCancelled {
    [self.navigationController popViewControllerAnimated:NO];
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
            // TODO: a toast here? Notification of some sort?
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
    [self.navigationController pushViewController:profileViewController animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SparkListCell";
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
    [self.sparks insertSorted:spark];
    [self.tableView reloadData];
}

- (void) spark:(FirefeedSpark *)spark wasUpdatedInTimeline:(NSString *)timeline {
    [self.tableView reloadData];
}

- (void) spark:(NSDictionary *)spark wasOverflowedFromTimeline:(NSString *)timeline {

}

- (void) spark:(FirefeedSpark *)spark wasRemovedFromTimeline:(NSString *)timeline {
    [self.sparks removeObject:spark];
    [self.tableView reloadData];
}

- (void) follower:(FirefeedUser *)follower startedFollowing:(FirefeedUser *)followee {
    // No-op?
}

- (void) follower:(FirefeedUser *)follower stoppedFollowing:(FirefeedUser *)followee {
    // No-op?
}

@end
